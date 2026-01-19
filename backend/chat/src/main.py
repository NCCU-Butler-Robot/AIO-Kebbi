import asyncio
from contextlib import asynccontextmanager

# from typing import List, Dict # Not directly used in main.py anymore
from fastapi import FastAPI, Header, HTTPException
from pydantic import BaseModel

from .db_manager.database import (
    close_db_connection,
    # These are now handled by conversation_manager
    # get_user_latest_conversation,
    # create_conversation,
    # add_message,
    connect_to_db,
)
from .dialogue.conversation_manager import handle_chat_message  # New import
from .llm_pipeline import LLMPipeline  # SYSTEM_PROMPT no longer directly imported here


class UserMessage(BaseModel):
    prompt: str


llm: LLMPipeline | None = None
generate_lock = asyncio.Lock()


@asynccontextmanager
async def lifespan(app: FastAPI):
    global llm
    await connect_to_db()  # Connect to DB on startup
    llm = LLMPipeline()
    yield
    await close_db_connection()  # Close DB connection on shutdown


app = FastAPI(lifespan=lifespan)


@app.post("/api/chat/")
async def chat_message(
    message: UserMessage,
    x_user_id: str | None = Header(None, alias="X-User-Id"),
    x_username: str | None = Header(None, alias="X-Username"),
):
    print(f"[DEBUG] Received message from {x_username} ({x_user_id}): {message.prompt}")

    if not x_user_id:
        raise HTTPException(status_code=400, detail="X-User-Id header is required.")

    assistant_response = await handle_chat_message(
        user_id=x_user_id,
        prompt=message.prompt,
        llm_pipeline=llm,
        generate_lock=generate_lock,
    )

    return {"message": assistant_response}


if __name__ == "__main__":
    import uvicorn

    uvicorn.run(app, host="0.0.0.0", port=8000)
