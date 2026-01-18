import os
import asyncpg
from typing import Dict, Optional
import uuid

from ..llm_pipeline.pipeline import SYSTEM_PROMPT # New import


# Database connection pool
pool: asyncpg.Pool | None = None

async def connect_to_db():
    global pool
    try:
        pool = await asyncpg.create_pool(
            host=os.getenv("DB_HOST", "db"),
            port=os.getenv("DB_PORT", "5432"),
            user=os.getenv("DB_USERNAME", "kebbi"),
            password=os.getenv("DB_PASSWORD", "kebbi"),
            database=os.getenv("DB_DATABASE_NAME", "kebbi")
        )
        print("[INFO] Database connection pool created successfully.")
    except Exception as e:
        print(f"[ERROR] Failed to create database connection pool: {e}")
        raise

async def close_db_connection():
    global pool
    if pool:
        await pool.close()
        print("[INFO] Database connection pool closed.")

async def get_user_latest_conversation(user_uuid: str) -> Optional[Dict]:
    """Retrieves the latest conversation for a given user."""
    if pool is None:
        raise Exception("Database connection pool is not initialized.")
    async with pool.acquire() as conn:
        conversation_record = await conn.fetchrow(
            """
            SELECT id, title FROM conversations
            WHERE user_uuid = $1
            ORDER BY updated_at DESC
            LIMIT 1;
            """,
            uuid.UUID(user_uuid)
        )

        if not conversation_record:
            return None

        messages_records = await conn.fetch(
            """
            SELECT role, content FROM messages
            WHERE conversation_id = $1
            ORDER BY created_at ASC;
            """,
            conversation_record['id']
        )

        messages = [{"role": r["role"], "content": r["content"]} for r in messages_records]
        return {
            "conversation_id": str(conversation_record['id']),
            "title": conversation_record['title'],
            "messages": messages
        }

async def create_conversation(user_uuid: str) -> str: # Removed system_prompt parameter
    """Creates a new conversation and adds the system message."""
    if pool is None:
        raise Exception("Database connection pool is not initialized.")
    async with pool.acquire() as conn:
        conversation_id = uuid.uuid4()
        await conn.execute(
            """
            INSERT INTO conversations (id, user_uuid)
            VALUES ($1, $2);
            """,
            conversation_id, uuid.UUID(user_uuid)
        )
        await add_message(str(conversation_id), "system", SYSTEM_PROMPT) # Use imported SYSTEM_PROMPT
        return str(conversation_id)

async def add_message(conversation_id: str, role: str, content: str) -> None:
    """Adds a message to an existing conversation."""
    if pool is None:
        raise Exception("Database connection pool is not initialized.")
    async with pool.acquire() as conn:
        await conn.execute(
            """
            INSERT INTO messages (conversation_id, role, content)
            VALUES ($1, $2, $3);
            """,
            uuid.UUID(conversation_id), role, content
        )
        # Update conversation's updated_at timestamp
        await conn.execute(
            """
            UPDATE conversations
            SET updated_at = NOW()
            WHERE id = $1;
            """,
            uuid.UUID(conversation_id)
        )
