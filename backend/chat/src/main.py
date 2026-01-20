import asyncio
import json
from contextlib import asynccontextmanager

# from typing import List, Dict # Not directly used in main.py anymore
from fastapi import FastAPI, Header, HTTPException
from pydantic import BaseModel

# Import the database module itself to access its global variables correctly.
from .db_manager import database

# Import specific functions needed.
from .dialogue.conversation_manager import handle_chat_message  # New import
from .llm_pipeline import LLMPipeline  # SYSTEM_PROMPT no longer directly imported here


class UserMessage(BaseModel):
    prompt: str


llm: LLMPipeline | None = None
generate_lock = asyncio.Lock()


@asynccontextmanager
async def lifespan(app: FastAPI):
    global llm
    await database.connect_to_db()
    # Check if the redis_client was successfully initialized before using it.
    if database.redis_client:
        await database.redis_client.ping()  # Establishes connection and checks health
    else:
        raise RuntimeError(
            "Redis client could not be initialized. Application cannot start."
        )
    llm = LLMPipeline()
    yield
    await database.close_db_connection()
    await database.close_redis_connection()


async def publish_events(user_id: str, installation_id: str, text: str, message_id: str, conversation_id: str):
    """Publishes events to Redis for other services to consume."""
    # Event for the socket gateway to broadcast the text message
    gateway_event = {
        "type": "text_broadcast",
        "user_id": user_id,
        "conversation_id": conversation_id,
        "message_id": message_id,
        "text": text,
    }
    # Event for the TTS service to generate audio for the specific device
    tts_event = {
        "type": "tts_generation_request",
        "user_id": user_id,
        "installation_id": installation_id,
        "conversation_id": conversation_id,
        "message_id": message_id,
        "text": text,
    }
    # Ensure the client is available before publishing
    if database.redis_client:
        # XADD adds events to a stream. The '*' generates a unique ID.
        await database.redis_client.xadd("app_stream", gateway_event)
        await database.redis_client.xadd("app_stream", tts_event)
        print(
            f"[Chat Service] Added text_broadcast and tts_generation_request to stream for user {user_id}"
        )
    else:
        print(
            "[Chat Service] ERROR: Redis client not available. Cannot publish events."
        )


app = FastAPI(lifespan=lifespan)


@app.post("/api/chat/")
async def chat_message(
    message: UserMessage,
    x_user_id: str | None = Header(None, alias="X-User-Id"),
    x_username: str | None = Header(None, alias="X-Username"),
    x_installation_id: str | None = Header(None, alias="X-Installation-Id"),
):
    print(
        f"[DEBUG] Received message from {x_username} ({x_user_id}) on device {x_installation_id}: {message.prompt}"
    )

    if not all([x_user_id, x_installation_id]):
        raise HTTPException(
            status_code=400,
            detail="X-User-Id and X-Installation-Id headers are required.",
        )

    # NOTE: Assumes handle_chat_message is updated to return a dictionary
    # e.g., {'response': '...', 'message_id': '...'}
    response_data = await handle_chat_message(
        user_id=x_user_id,
        prompt=message.prompt,
        llm_pipeline=llm,
        generate_lock=generate_lock,
    )
    assistant_response = response_data["response"]
    conversation_id = response_data["conversation_id"]
    assistant_message_id = response_data["message_id"]

    # Asynchronously publish events to Redis
    asyncio.create_task(
        publish_events(x_user_id, x_installation_id, assistant_response, assistant_message_id, conversation_id)
    )

    return {
        "message": assistant_response,
        "message_id": assistant_message_id,
        "conversation_id": conversation_id,
        "recipient_user_id": x_user_id,
        "source_installation_id": x_installation_id,
    }


if __name__ == "__main__":
    import uvicorn

    uvicorn.run(app, host="0.0.0.0", port=8000)
