import asyncio
import json
from contextlib import asynccontextmanager
from typing import Optional
from datetime import datetime, timezone
import uuid

from fastapi import FastAPI, Header, HTTPException
from fastapi.responses import Response
from pydantic import BaseModel

# Import the database module itself to access its global variables correctly.
from .db_manager import database, get_user_latest_conversation

# Import specific functions needed.
from .dialogue.conversation_manager import handle_fraud_chat_message  # Updated import
from .llm_pipeline import LLMPipeline  # SYSTEM_PROMPT no longer directly imported here
from .tts_service import TTSService


class FraudMessage(BaseModel):
    prompt: str
    phone_number: str  # 受話者的手機號碼

class NotificationPayload(BaseModel):
    title: str | None = None
    body: str | None = None
    icon: str | None = None
    tag: str | None = None
    data: dict | None = None
    silent: bool = False
    android_priority: str | None = None


llm: LLMPipeline | None = None
tts_service: TTSService | None = None
generate_lock = asyncio.Lock()


async def get_user_by_phone(phone_number: str) -> Optional[dict]:
    """
    透過手機號碼查詢用戶資訊
    
    Args:
        phone_number: 手機號碼
        
    Returns:
        dict: 用戶資訊 (包含 name, username 等)，如果找不到則返回 None
    """
    try:
        if database.pool:
            async with database.pool.acquire() as conn:
                query = """
                    SELECT uuid, username, name, email, phone_number 
                    FROM users 
                    WHERE phone_number = $1
                """
                result = await conn.fetchrow(query, phone_number)
                if result:
                    return {
                        "uuid": str(result["uuid"]),
                        "username": result["username"],
                        "name": result["name"],
                        "email": result["email"],
                        "phone_number": result["phone_number"]
                    }
        return None
    except Exception as e:
        print(f"[ERROR] Failed to query user by phone {phone_number}: {e}")
        return None


@asynccontextmanager
async def lifespan(app: FastAPI):
    global llm, tts_service
    await database.connect_to_db()
    # Check if the redis_client was successfully initialized before using it.
    if database.redis_client:
        await database.redis_client.ping()  # Establishes connection and checks health
    else:
        raise RuntimeError(
            "Redis client could not be initialized. Application cannot start."
        )
    
    # 初始化GPT管道 - 確保環境變數OPENAI_API_KEY已設置
    try:
        llm = LLMPipeline()  # 這現在會使用GPT
        print("[INFO] GPT-based fraud detection service initialized successfully")
    except Exception as e:
        print(f"[ERROR] Failed to initialize GPT pipeline: {e}")
        raise RuntimeError(f"Cannot start fraud service without GPT pipeline: {e}")
    
    tts_service = TTSService()
    yield
    await database.close_db_connection()
    await database.close_redis_connection()


async def notify_callee_event(caller_user_id: str, caller_name: str, callee_user_id: str, conversation_id: str, call_token: str):
    """Publishes events to Redis for other services to consume."""
    # Event for the socket gateway to broadcast the text message
    notification_payload = NotificationPayload(
        data={
            "type": "incoming_call",
            "call_token": call_token,
            "caller_name": caller_name,
            "caller_user_id": caller_user_id,
        },
        silent=True,
        android_priority="high"
    )
    gateway_event = {
        "type": "call_notify",
        "service": "anti-fraud",
        "caller_user_id": caller_user_id,
        "callee_user_id": callee_user_id,
        "conversation_id": conversation_id,
        "payload": json.dumps(notification_payload.model_dump())
    }
    # Ensure the client is available before publishing
    if database.redis_client:
        # XADD adds events to a stream. The '*' generates a unique ID.
        await database.redis_client.xadd("push_notification_stream", gateway_event)
        print(
            f"[Anti-Fraud Service] Added call_notify to push_notification_stream for caller {caller_user_id} > callee {callee_user_id}"
        )
    else:
        print(
            "[Anti-Fraud Service] ERROR: Redis client not available. Cannot publish events."
        )


app = FastAPI(
    title="Anti-Fraud Communication Service",
    description="A GPT-powered service designed to engage with scammers and extract information about their schemes",
    version="1.0.0",
    lifespan=lifespan
)


@app.get("/health")
async def health_check():
    """
    Health Check Endpoint
    
    Returns the health status of the anti-fraud service and its components.
    """
    try:
        # 檢查Redis連接
        if database.redis_client:
            await database.redis_client.ping()
            redis_status = "healthy"
        else:
            redis_status = "disconnected"
        
        # 檢查LLM狀態
        llm_status = "healthy" if llm else "not_initialized"
        
        return {
            "status": "healthy",
            "service": "anti-fraud",
            "components": {
                "redis": redis_status,
                "llm": llm_status,
                "tts": "healthy" if tts_service else "not_initialized"
            }
        }
    except Exception as e:
        return {
            "status": "unhealthy",
            "error": str(e)
        }

async def check_conversation_duration(conversation, caller_user_id, target_user, max_duration):
    """檢查對話持續時間是否超過限制"""
    target_name = target_user.get("name", target_user.get("username", "Unknown"))
    target_id = target_user.get("uuid", "")

    if conversation:
        duration = (datetime.now(timezone.utc) - conversation["created_at"]).total_seconds()
        conversation["duration"] = duration
        
        # Check if the conversation already passed 2 minutes and 45 seconds
        if duration > max_duration:
            print(f"[INFO] Conversation duration {duration} seconds exceeded limit of {max_duration} seconds for {target_name} ({target_id})")
            # Call publish_events to notify socket gateway to end the call
            # This requires a message_id, but we may not have one yet.
            # We will use a placeholder or decide on a better strategy.
            # For now, let's assume we can create a temporary or system message id.

            return False # Indicate that the duration limit has been exceeded
    return True # Duration is within limit


@app.post("/api/fraud/")
async def fraud_chat_message(
    message: FraudMessage,
    x_user_id: str | None = Header(None, alias="X-User-Id"),
    x_username: str | None = Header(None, alias="X-Username"),
    x_installation_id: str | None = Header(None, alias="X-Installation-Id"),
):
    """
    反詐騙對話API
    AI會扮演透過手機號碼查詢到的目標用戶
    """
    print(
        f"[DEBUG] Anti-fraud service received message from {x_username} ({x_user_id}) targeting phone {message.phone_number}: {message.prompt}"
    )

    if not all([x_user_id, x_installation_id]):
        raise HTTPException(
            status_code=400,
            detail="X-User-Id and X-Installation-Id headers are required.",
        )

    # 透過手機號碼查詢目標用戶
    target_user = await get_user_by_phone(message.phone_number)
    if not target_user:
        raise HTTPException(
            status_code=404,
            detail=f"No user found with phone number {message.phone_number}"
        )
    
    target_name = target_user.get("name", target_user.get("username", "Unknown"))
    target_id = target_user.get("uuid", "")

    conversation = await get_user_latest_conversation(target_id)
    in_time_limit = await check_conversation_duration(conversation, x_user_id, target_user, max_duration=165)
    if not in_time_limit:
        call_token = await database.set_call_token(x_user_id, target_id)
        await notify_callee_event(
            caller_user_id=x_user_id,
            caller_name=x_username,
            callee_user_id=target_id,
            call_token=call_token,
            conversation_id=conversation.get("conversation_id", "") if conversation else ""
        )
        return {
            "status": "initiate_socketio",
            "call_token": call_token
        }

    print(f"[INFO] AI will role-play as: {target_name} ({message.phone_number})")

    # 處理對話，AI扮演目標用戶
    response_data = await handle_fraud_chat_message(
        user_id=x_user_id,
        prompt=message.prompt,
        target_name=target_name,
        target_phone=message.phone_number,
        llm_pipeline=llm,
        generate_lock=generate_lock,
        conversation=conversation,
    )
    
    assistant_response = response_data["response"]
    conversation_id = response_data["conversation_id"]
    assistant_message_id = response_data["message_id"]

    in_time_limit = await check_conversation_duration(conversation, x_user_id, target_user, max_duration=165)
    if not in_time_limit:
        # await publish_events(
        #     caller_user_id=x_user_id,
        #     callee_user_id=target_id,
        #     text="Conversation duration exceeded limit.",
        #     conversation_id=conversation.get("conversation_id", "") if conversation else ""
        # )
        call_token = await database.set_call_token(x_user_id, target_id)
        return {
            "status": "initiate_socketio",
            "call_token": call_token
        }


    # Generate audio from text using TTS service
    try:
        audio_bytes = await tts_service.generate_speech_bytes(assistant_response)
        
        # Create response with audio file and text in headers
        response = Response(
            content=audio_bytes,
            media_type="audio/mpeg",
            headers={
                "X-Response-Text": assistant_response,
                "X-Message-Id": assistant_message_id,
                "X-Conversation-Id": conversation_id,
                "X-Recipient-User-Id": x_user_id,
                "X-Source-Installation-Id": x_installation_id,
                "X-Service-Type": "anti-fraud",
                "X-Target-Name": target_name,
                "X-Target-Phone": message.phone_number,
                "Content-Disposition": f"attachment; filename={target_name}_response.mp3"
            }
        )
        
        # # Asynchronously publish events to Redis (for socket gateway)
        # asyncio.create_task(
        #     publish_events(x_user_id, x_installation_id, assistant_response, assistant_message_id, conversation_id)
        # )
        
        return response
        
    except Exception as e:
        print(f"[ERROR] TTS generation failed: {e}")
        # Fallback to JSON response if TTS fails
        return {
            "message": assistant_response,
            "message_id": assistant_message_id,
            "conversation_id": conversation_id,
            "recipient_user_id": x_user_id,
            "source_installation_id": x_installation_id,
            "service_type": "anti-fraud",
            "target_name": target_name,
            "target_phone": message.phone_number,
            "error": "TTS generation failed"
        }


if __name__ == "__main__":
    import uvicorn

    uvicorn.run(app, host="0.0.0.0", port=8000)
