import os
from typing import Dict, List, Optional
import redis.asyncio as redis

import asyncpg

# Database connection pool
pool: asyncpg.Pool | None = None
# Redis client instance
redis_client: redis.Redis | None = None

async def connect_to_db():
    global pool, redis_client
    try:
        # --- PostgreSQL Connection ---
        pool = await asyncpg.create_pool(
            host=os.getenv("DB_HOST", "db"),
            port=os.getenv("DB_PORT", "5432"),
            user=os.getenv("DB_USERNAME", "kebbi"),
            password=os.getenv("DB_PASSWORD", "kebbi"),
            database=os.getenv("DB_DATABASE_NAME", "kebbi")
        )
        print("[INFO] Database connection pool created successfully.")

        # --- Redis Connection ---
        redis_client = redis.from_url("redis://redis:6379/0", decode_responses=True)
        print("[INFO] Redis client created successfully.")
    except Exception as e:
        print(f"[ERROR] Failed to create database connection pool: {e}")
        raise


async def close_db_connection():
    global pool
    if pool:
        await pool.close()
        print("[INFO] Database connection pool closed.")

async def close_redis_connection():
    global redis_client
    if redis_client:
        await redis_client.close()
        print("[INFO] Redis client connection closed.")


async def save_subscription(user_id: str, push_sub: dict, platform: str) -> str:
    """Save or update a push subscription. Returns the user_id."""
    if pool is None:
        raise Exception("Database connection pool is not initialized.")
    async with pool.acquire() as conn:
        # user_id is the uuid string
        keys = push_sub.get("keys", {})
        await conn.execute(
            """
            INSERT INTO push_notification (endpoint, userid, expiration_time, p256dh, auth, platform)
            VALUES ($1, $2, $3, $4, $5, $6)
            ON CONFLICT (endpoint)
            DO UPDATE SET
                userid = EXCLUDED.userid,
                expiration_time = EXCLUDED.expiration_time,
                p256dh = EXCLUDED.p256dh,
                auth = EXCLUDED.auth,
                platform = EXCLUDED.platform,
                updated_at = NOW();
        """,
            push_sub.get("endpoint"),
            user_id,
            push_sub.get("expirationTime"),
            keys.get("p256dh"),
            keys.get("auth"),
            platform,
        )
        return user_id


async def get_all_subscriptions() -> List[Dict]:
    """Get all push subscriptions."""
    if pool is None:
        raise Exception("Database connection pool is not initialized.")
    async with pool.acquire() as conn:
        results = await conn.fetch(
            "SELECT endpoint, p256dh, auth, platform FROM push_notification"
        )
        return [
            {
                "endpoint": r["endpoint"],
                "p256dh": r["p256dh"],
                "auth": r["auth"],
                "platform": r["platform"],
            }
            for r in results
        ]


async def get_subscriptions_by_user(user_id: str) -> List[Dict]:
    """Get push subscriptions for a specific user."""
    if pool is None:
        raise Exception("Database connection pool is not initialized.")
    async with pool.acquire() as conn:
        results = await conn.fetch(
            "SELECT endpoint, p256dh, auth, platform FROM push_notification WHERE userid = $1",
            user_id,
        )
        return [
            {
                "endpoint": r["endpoint"],
                "p256dh": r["p256dh"],
                "auth": r["auth"],
                "platform": r["platform"],
            }
            for r in results
        ]


async def delete_subscription(endpoint: str, platform: str):
    """Delete a push subscription by endpoint."""
    if pool is None:
        raise Exception("Database connection pool is not initialized.")
    async with pool.acquire() as conn:
        await conn.execute(
            "DELETE FROM push_notification WHERE endpoint = $1 AND platform = $2",
            endpoint,
            platform,
        )
