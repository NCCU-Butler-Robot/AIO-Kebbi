import os
import uuid
from contextlib import asynccontextmanager
from datetime import datetime, timedelta, timezone
from typing import Optional

import asyncpg
from fastapi import Depends, FastAPI, HTTPException, Request, Response, status
from fastapi.security import OAuth2PasswordBearer, OAuth2PasswordRequestForm
from jose import JWTError, jwt
from passlib.context import CryptContext
from pydantic import BaseModel, ConfigDict

# --- Configuration using os.getenv ---
# This section explicitly defines and loads every configuration variable
# from the environment, as passed in by Docker.

# JWT Settings
JWT_SECRET_KEY = os.getenv("JWT_SECRET_KEY")
JWT_REFRESH_SECRET_KEY = os.getenv(
    "JWT_REFRESH_SECRET_KEY"
)  # Use a DIFFERENT secret for refresh tokens
ALGORITHM = os.getenv("JWT_ALGORITHM", "HS256")
ACCESS_TOKEN_EXPIRE_MINUTES = int(os.getenv("ACCESS_TOKEN_EXPIRE_MINUTES", "15"))
REFRESH_TOKEN_EXPIRE_DAYS = int(os.getenv("REFRESH_TOKEN_EXPIRE_DAYS", "7"))

# Database Connection Settings
DB_DATABASE_NAME = os.getenv("DB_DATABASE_NAME")
DB_USERNAME = os.getenv("DB_USERNAME")
DB_PASSWORD = os.getenv("DB_PASSWORD")
DB_HOST = os.getenv("DB_HOST")
DB_PORT = os.getenv("DB_PORT", "5432")

# Check that critical secrets are loaded
if not JWT_SECRET_KEY or not JWT_REFRESH_SECRET_KEY:
    raise ValueError(
        "JWT_SECRET_KEY and JWT_REFRESH_SECRET_KEY must be set in the environment"
    )

# Construct the database URL from the environment variables
DATABASE_URL = (
    f"postgresql://{DB_USERNAME}:{DB_PASSWORD}@{DB_HOST}:{DB_PORT}/{DB_DATABASE_NAME}"
)

# --- Password Hashing & Token URL ---
pwd_context = CryptContext(schemes=["argon2"], deprecated="auto")
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/auth/login")

# --- Database Pool Management ---
pool: Optional[asyncpg.Pool] = None


@asynccontextmanager
async def lifespan(app: FastAPI):
    global pool
    try:
        pool = await asyncpg.create_pool(DATABASE_URL)
        print("Database pool created successfully.")
        yield
    finally:
        if pool:
            await pool.close()
            print("Database pool closed.")


async def get_db_connection():
    if pool is None:
        raise HTTPException(
            status_code=503, detail="Database connection is not available."
        )
    async with pool.acquire() as connection:
        yield connection


# --- Pydantic Models ---
class UserBase(BaseModel):
    username: str
    email: str
    phone_number: str
    name: str


class UserCreate(UserBase):
    password: str


class User(UserBase):
    uuid: uuid.UUID
    model_config = ConfigDict(from_attributes=True)


class UserInDB(User):
    hashed_password: str


class Token(BaseModel):
    access_token: str
    token_type: str = "bearer"


class TokenData(BaseModel):
    username: Optional[str] = None


# --- Main Application Instance ---
app = FastAPI(lifespan=lifespan)


# --- Utility Functions ---
def verify_password(plain_password, hashed_password):
    return pwd_context.verify(plain_password, hashed_password)


def get_password_hash(password):
    return pwd_context.hash(password)


def create_access_token(data: dict):
    to_encode = data.copy()
    expire = datetime.now(timezone.utc) + timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    to_encode.update({"exp": expire})
    encoded_jwt = jwt.encode(to_encode, JWT_SECRET_KEY, algorithm=ALGORITHM)
    return encoded_jwt


async def create_refresh_token(conn: asyncpg.Connection, user_uuid: uuid.UUID) -> str:
    token_payload = {
        "sub": str(user_uuid),
        "jti": str(uuid.uuid4()),  # Unique token ID
    }
    encoded_jwt = jwt.encode(token_payload, JWT_REFRESH_SECRET_KEY, algorithm=ALGORITHM)

    # Store the refresh token in the database so it can be revoked
    refresh_token_expires_at = datetime.now(timezone.utc) + timedelta(
        days=REFRESH_TOKEN_EXPIRE_DAYS
    )
    await conn.execute(
        "INSERT INTO refresh_tokens (user_uuid, token, expires_at) VALUES ($1, $2, $3)",
        user_uuid,
        encoded_jwt,
        refresh_token_expires_at,
    )
    return encoded_jwt


async def get_user_from_db(
    conn: asyncpg.Connection, username: str
) -> Optional[UserInDB]:
    row = await conn.fetchrow(
        "SELECT uuid, username, email, phone_number, name, hashed_password FROM users WHERE username = $1",
        username,
    )
    return UserInDB(**row) if row else None


async def get_refresh_token_from_db(
    conn: asyncpg.Connection, token: str
) -> Optional[dict]:
    # Update last_used_at timestamp and retrieve token details
    row = await conn.fetchrow(
        "UPDATE refresh_tokens SET last_used_at = NOW() WHERE token = $1 AND revoked_at IS NULL RETURNING user_uuid, expires_at",
        token,
    )
    return dict(row) if row else None


async def revoke_refresh_token_in_db(conn: asyncpg.Connection, token: str):
    await conn.execute(
        "UPDATE refresh_tokens SET revoked_at = NOW() WHERE token = $1", token
    )


# --- Dependency for User Authentication ---
async def get_current_user(
    token: str = Depends(oauth2_scheme),
    conn: asyncpg.Connection = Depends(get_db_connection),
):
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Could not validate credentials",
        headers={"WWW-Authenticate": "Bearer"},
    )
    try:
        payload = jwt.decode(token, JWT_SECRET_KEY, algorithms=[ALGORITHM])
        username: str = payload.get("sub")
        if username is None:
            raise credentials_exception
    except JWTError:
        raise credentials_exception

    user = await get_user_from_db(conn, username)
    if user is None:
        raise credentials_exception
    return user


# --- API Endpoints ---


@app.post("/auth/login", response_model=Token)
async def login_for_access_token(
    response: Response,
    form_data: OAuth2PasswordRequestForm = Depends(),
    conn: asyncpg.Connection = Depends(get_db_connection),
):
    user = await get_user_from_db(conn, form_data.username)
    if not user or not verify_password(form_data.password, user.hashed_password):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect username or password",
        )

    access_token = create_access_token(data={"sub": user.username})
    refresh_token = await create_refresh_token(conn, user.uuid)

    if REFRESH_TOKEN_EXPIRE_DAYS > 0:
        refresh_token_expires = timedelta(days=REFRESH_TOKEN_EXPIRE_DAYS)
    else:
        refresh_token_expires = timedelta(
            days=365 * 100
        )  # Effectively, never expires (100 years)

    # Set the refresh token in a secure, HttpOnly cookie
    response.set_cookie(
        key="refresh_token",
        value=refresh_token,
        httponly=True,
        secure=True,
        samesite="strict",
        expires=refresh_token_expires,
    )
    return {"access_token": access_token}


@app.post("/auth/refresh_token", response_model=Token)
async def refresh_access_token(
    request_obj: Request,
    response: Response,
    conn: asyncpg.Connection = Depends(get_db_connection),
):
    refresh_token = request_obj.cookies.get("refresh_token")
    if not refresh_token:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED, detail="Refresh token not found"
        )

    try:
        payload = jwt.decode(
            refresh_token, JWT_REFRESH_SECRET_KEY, algorithms=[ALGORITHM]
        )
        user_uuid: str = payload.get("sub")
        if user_uuid is None:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid refresh token payload",
            )
    except JWTError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid refresh token"
        )

    db_token = await get_refresh_token_from_db(conn, refresh_token)

    if (
        not db_token
        or str(db_token["user_uuid"]) != user_uuid
        or (
            db_token["expires_at"]
            and db_token["expires_at"] < datetime.now(timezone.utc)
        )
    ):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired refresh token",
        )

    # Revoke the old refresh token
    await revoke_refresh_token_in_db(conn, refresh_token)

    # Get user to create new tokens
    user_row = await conn.fetchrow(
        "SELECT username FROM users WHERE uuid = $1", user_uuid
    )
    if not user_row:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED, detail="User not found"
        )

    new_access_token = create_access_token(data={"sub": user_row["username"]})
    new_refresh_token = await create_refresh_token(conn, uuid.UUID(user_uuid))

    if REFRESH_TOKEN_EXPIRE_DAYS > 0:
        new_refresh_token_expires = timedelta(days=REFRESH_TOKEN_EXPIRE_DAYS)
    else:
        new_refresh_token_expires = timedelta(
            days=365 * 100
        )  # Effectively, never expires (100 years)

    response.set_cookie(
        key="refresh_token",
        value=new_refresh_token,
        httponly=True,
        secure=True,
        samesite="strict",
        expires=new_refresh_token_expires,
    )

    return {"access_token": new_access_token, "token_type": "bearer"}


@app.post("/auth/logout")
async def logout(
    response: Response, conn: asyncpg.Connection = Depends(get_db_connection)
):
    # This endpoint needs to be fully implemented
    # It involves finding the refresh token in the DB and marking it as revoked.
    response.delete_cookie(key="refresh_token")
    return {"message": "Successfully logged out"}


# Endpoint for Nginx to validate JWT efficiently
@app.get("/auth/validate")
async def validate_token_for_nginx(
    request: Response, token: str = Depends(oauth2_scheme)
):
    try:
        payload = jwt.decode(token, JWT_SECRET_KEY, algorithms=[ALGORITHM])
        username: str = payload.get("sub")
        if username is None:
            raise JWTError("Username not in token payload")
    except JWTError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid token"
        )

    # Pass validated user info back to Nginx via response headers
    request.headers["X-User-Username"] = username
    return Response(status_code=status.HTTP_200_OK)


@app.post("/auth/register", response_model=User)
async def register_user(
    user_data: UserCreate, conn: asyncpg.Connection = Depends(get_db_connection)
):
    hashed_password = get_password_hash(user_data.password)
    try:
        new_user_row = await conn.fetchrow(
            """
            INSERT INTO users (uuid, name, username, email, phone_number, hashed_password)
            VALUES ($1, $2, $3, $4, $5, $6)
            RETURNING uuid, name, username, email, phone_number
            """,
            uuid.uuid4(),
            user_data.name,
            user_data.username,
            user_data.email,
            user_data.phone_number,
            hashed_password,
        )
        return User(**new_user_row)
    except asyncpg.exceptions.UniqueViolationError as e:
        constraint_name = e.constraint_name or ""
        if "users_email_key" in constraint_name:
            raise HTTPException(
                status_code=400, detail="An account with this email already exists."
            )
        if "users_phone_number_key" in constraint_name:
            raise HTTPException(
                status_code=400,
                detail="An account with this phone number already exists.",
            )
        raise HTTPException(
            status_code=400, detail="An account with this username already exists."
        )
    except Exception:
        raise HTTPException(
            status_code=500, detail="An unexpected error occurred during registration."
        )


@app.get("/auth/status", response_model=User)
async def read_users_me(current_user: UserInDB = Depends(get_current_user)):
    return current_user


if __name__ == "__main__":
    import uvicorn

    uvicorn.run(app, host="0.0.0.0", port=8000)
