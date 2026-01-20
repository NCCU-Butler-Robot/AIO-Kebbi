# Authentication Service

This service handles user authentication and authorization within the AIO-Kebbi project. It provides functionalities for user registration, login, token management (access and refresh tokens), and token validation.

## Features

*   User Registration with password hashing.
*   User Login with access token generation.
*   Refresh Token mechanism for renewing access tokens without re-authenticating.
*   Secure HttpOnly cookies for refresh tokens.
*   Token Validation endpoint for use with API gateways (e.g., Nginx).
*   Password hashing using Argon2.
*   Database interaction with PostgreSQL.

## Technologies Used

*   **FastAPI**: A modern, fast (high-performance) web framework for building APIs with Python 3.8+.
*   **asyncpg**: A fast PostgreSQL client library for Python/asyncio.
*   **python-jose**: For JSON Web Token (JWT) handling.
*   **Passlib**: A comprehensive password hashing framework for Python, used with `argon2-cffi`.
*   **python-dotenv**: For loading environment variables from a `.env` file.
*   **Uvicorn**: An ASGI web server, used to run the FastAPI application.
*   **uv**: A modern Python package installer and resolver.



## Configuration

The following environment variables are used to configure the authentication service:

*   `JWT_SECRET_KEY`: Secret key for signing access tokens. **Mandatory.**
*   `JWT_REFRESH_SECRET_KEY`: Secret key for signing refresh tokens. **Mandatory.**
*   `JWT_ALGORITHM`: The JWT signing algorithm (default: `HS256`).
*   `ACCESS_TOKEN_EXPIRE_MINUTES`: Expiration time for access tokens in minutes (default: `15`).
*   `REFRESH_TOKEN_EXPIRE_DAYS`: Expiration time for refresh tokens in days (default: `7`). If set to `0`, tokens will effectively never expire (100 years).
*   `DB_DATABASE_NAME`: PostgreSQL database name.
*   `DB_USERNAME`: PostgreSQL username.
*   `DB_PASSWORD`: PostgreSQL password.
*   `DB_HOST`: PostgreSQL host.
*   `DB_PORT`: PostgreSQL port (default: `5432`).

## API Endpoints

All endpoints are prefixed with `/auth`.

### 1. Register a new user

`POST /auth/register`

Creates a new user account.

**Request Body Example**:
```json
{
  "username": "testuser",
  "email": "test@example.com",
  "phone_number": "1234567890",
  "name": "Test User",
  "password": "securepassword123"
}
```

**Response Body Example (Success)**:
```json
{
  "uuid": "a1b2c3d4-e5f6-7890-1234-567890abcdef",
  "username": "testuser",
  "email": "test@example.com",
  "phone_number": "1234567890",
  "name": "Test User"
}
```

### 2. User Login

`POST /auth/login`

Authenticates a user and issues an access token and an HttpOnly refresh token cookie.

**Request Body (x-www-form-urlencoded) Example**:
```
username=testuser&password=securepassword123
```

**Response Body Example (Success)**:
```json
{
  "access_token": "eyJhbGciOiJIUzI1Ni...",
  "token_type": "bearer"
}
```
A `Set-Cookie` header will also be present with the `refresh_token`.

### 3. Refresh Access Token

`POST /auth/refresh_token`

Given the `refresh_token` in an HttpOnly cookie (which is automatically sent by the browser), this endpoint issues a new `access_token` and a new `refresh_token`.

**Request**:
Requires the `refresh_token` cookie to be sent with the request.

**Response Body Example (Success)**:
```json
{
  "access_token": "eyJhbGciOiJIUzI1Ni...",
  "token_type": "bearer"
}
```
A new `Set-Cookie` header will be present with the updated `refresh_token`.

### 4. Logout

`POST /auth/logout`

This endpoint receives the `refresh_token` via an HttpOnly cookie (automatically sent by the browser), invalidates it in the database, and clears the client-side `refresh_token` cookie.

**Response Body Example (Success)**:
```json
{
  "message": "Successfully logged out"
}
```

### 5. Validate Token for Nginx

`GET /auth/validate`

An internal endpoint primarily for Nginx or other API gateways to validate the provided access token efficiently. It returns a 200 OK status on successful validation and sets `X-User-Username` header.

**Request**:
Requires an `Authorization: Bearer <access_token>` header.

**Response (Success)**:
HTTP 200 OK with `X-User-Username` header set.

### 6. Get Current User Status

`GET /auth/status`

Retrieves the details of the currently authenticated user.

**Request**:
Requires an `Authorization: Bearer <access_token>` header.

**Response Body Example (Success)**:
```json
{
  "uuid": "a1b2c3d4-e5f6-7890-1234-567890abcdef",
  "username": "testuser",
  "email": "test@example.com",
  "phone_number": "1234567890",
  "name": "Test User"
}
```

## Testing API Endpoints with `curl`

The `auth/test.md` file contains `curl` commands to test these endpoints. Here are quick examples:

### Register
```bash
curl -X POST "http://localhost:8100/auth/register" \
-H "Content-Type: application/json" \
-d '{
  "username": "newuser3",
  "email": "newuser3@example.com",
  "phone_number": "0987654323",
  "name": "New Test User Three",
  "password": "strongpassword123"
}'
```

### Login
```bash
curl -c /tmp/cookies.txt -X POST "http://localhost:8100/auth/login" \
-H "Content-Type: application/x-www-form-urlencoded" \
-d "username=newuser3&password=strongpassword123"
```

### Authenticated Endpoint
```bash
curl -X GET "http://localhost:8100/auth/status" \
-H "Authorization: Bearer YOUR_ACCESS_TOKEN"
```

### Refresh Token
```bash
curl -b /tmp/cookies.txt -c /tmp/cookies.txt -X POST "http://localhost:8100/auth/refresh_token"
```