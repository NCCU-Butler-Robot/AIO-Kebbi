# import asyncpg

import redis.asyncio as redis

# Database connection pool
# pool: asyncpg.Pool | None = None
# Redis client instance
redis_client: redis.Redis | None = None


async def connect_to_db():
    global redis_client
    try:
        # --- PostgreSQL Connection ---
        # pool = await asyncpg.create_pool(
        #     host=os.getenv("DB_HOST", "db"),
        #     port=os.getenv("DB_PORT", "5432"),
        #     user=os.getenv("DB_USERNAME", "kebbi"),
        #     password=os.getenv("DB_PASSWORD", "kebbi"),
        #     database=os.getenv("DB_DATABASE_NAME", "kebbi")
        # )
        # print("[INFO] Database connection pool created successfully.")

        # --- Redis Connection ---
        redis_client = redis.from_url("redis://redis:6379/0", decode_responses=True)
        print("[INFO] Redis client created successfully.")
    except Exception as e:
        print(f"[ERROR] Failed to create database connection pool: {e}")
        raise


# async def close_db_connection():
#     global pool
#     if pool:
#         await pool.close()
#         print("[INFO] Database connection pool closed.")


async def close_redis_connection():
    global redis_client
    if redis_client:
        await redis_client.close()
        print("[INFO] Redis client connection closed.")
