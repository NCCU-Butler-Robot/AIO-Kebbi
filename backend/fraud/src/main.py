import asyncio
import json
import math
import os
import urllib.parse
from contextlib import asynccontextmanager
from datetime import datetime, timezone
from typing import Any, Optional

import httpx
from fastapi import FastAPI, Header, HTTPException, Query
from fastapi.middleware.cors import CORSMiddleware
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
    initiate_conversation: Optional[bool] = False


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

# 詐騙檢測API配置
fraud_api_url: str | None = os.getenv("FRAUD_DETECTION_API_URL")
if not fraud_api_url:
    raise RuntimeError("Environment variable FRAUD_DETECTION_API_URL is not set.")
FRAUD_DETECTION_API_URL = fraud_api_url

# 用於存儲每個對話的檢測結果
conversation_detection_results = {}

# ===== SSCI (Streaming Scam Confidence Index) Parameters =====
# 每次目前判斷約等於 2 句（caller + receiver），所以每 3 次判斷對應 Δn=6。
INFERENCES_PER_TRIGGER = 3
SENTENCES_PER_INFERENCE = 2
DELTA_N = INFERENCES_PER_TRIGGER * SENTENCES_PER_INFERENCE  # = 6
LAMBDA = 4.0
TAU = 6.0
BETA_PRIOR_A = 0.05
BETA_PRIOR_B = 0.05
ZETA = 200.0
ETA = 1.5
SSCI_SCAM_THRESHOLD = 0.65


def _extract_trigger_results(raw_results: list[bool]) -> list[bool]:
    """
    從逐次判斷結果中，取第 3、6、9... 筆作為 trigger 決策序列。
    例如 [F, T, F, T, T, T] -> [F, T]
    """
    if not raw_results:
        return []
    return [
        raw_results[idx]
        for idx in range(INFERENCES_PER_TRIGGER - 1, len(raw_results), INFERENCES_PER_TRIGGER)
    ]


def _compute_ssci(trigger_results: list[bool]) -> dict[str, Any] | None:
    """
    依照 SSCI 定義計算目前 trigger 的 confidence 與三個子分數。
    """
    if not trigger_results:
        return None

    k = len(trigger_results)
    y_k = trigger_results[-1]
    n_values = [DELTA_N * i for i in range(1, k + 1)]  # 6, 12, 18, ...
    n_k = float(n_values[-1])

    # Phase 1: Evidence by length
    evidence = 1.0 - math.exp(-(n_k / LAMBDA))

    # Phase 2: Historical agreement (exclude current trigger, with beta smoothing)
    if k == 1:
        agreement = 0.5
    else:
        weighted_match_sum = 0.0
        weight_sum = 0.0
        for j in range(k - 1):
            n_j = float(n_values[j])
            weight = math.exp(-((n_k - n_j) / TAU))
            weight_sum += weight
            if trigger_results[j] == y_k:
                weighted_match_sum += weight

        agreement = (weighted_match_sum + BETA_PRIOR_A) / (
            weight_sum + BETA_PRIOR_A + BETA_PRIOR_B
        )

    # Phase 3: Recent stability (EMA over flips)
    if k == 1:
        flip_ema = 0.0
        stability = 0.5
        rho_k = 0.0
        c_k = 0
    else:
        flip_ema = 0.0
        prev_n = float(n_values[0])
        rho_k = 0.0
        c_k = 0
        for idx in range(1, k):
            curr_n = float(n_values[idx])
            delta_n = curr_n - prev_n
            rho_k = 1.0 - math.exp(-(delta_n / ZETA))
            c_k = 1 if trigger_results[idx] != trigger_results[idx - 1] else 0
            flip_ema = ((1.0 - rho_k) * flip_ema) + (rho_k * float(c_k))
            prev_n = curr_n

        stability = math.exp(-(ETA * flip_ema))

    confidence = evidence * agreement * stability

    return {
        "available": True,
        "trigger_index": k,
        "n_k": int(n_k),
        "latest_trigger_decision": y_k,
        "trigger_results": trigger_results,
        "evidence": evidence,
        "agreement": agreement,
        "stability": stability,
        "flip_ema": flip_ema,
        "rho_k": rho_k,
        "c_k": c_k,
        "confidence": confidence,
    }


def _build_ssci_payload(raw_results: list[bool], updated: bool) -> dict[str, Any]:
    trigger_results = _extract_trigger_results(raw_results)
    ssci_result = _compute_ssci(trigger_results)

    payload: dict[str, Any] = {
        "available": False,
        "updated": updated,
        "raw_inference_count": len(raw_results),
        "trigger_count": len(trigger_results),
        "trigger_every_inferences": INFERENCES_PER_TRIGGER,
        "sentences_per_inference": SENTENCES_PER_INFERENCE,
        "delta_n": DELTA_N,
    }

    if not ssci_result:
        return payload

    payload.update(ssci_result)
    return payload


def _build_ssci_headers(ssci_payload: dict[str, Any]) -> dict[str, str]:
    headers = {
        "X-SSCI-Available": str(ssci_payload.get("available", False)).lower(),
        "X-SSCI-Updated": str(ssci_payload.get("updated", False)).lower(),
        "X-SSCI-Trigger-Count": str(ssci_payload.get("trigger_count", 0)),
        "X-SSCI-Raw-Inference-Count": str(ssci_payload.get("raw_inference_count", 0)),
    }

    if ssci_payload.get("available"):
        headers.update(
            {
                "X-SSCI-Confidence": f"{float(ssci_payload.get('confidence', 0.0)):.6f}",
                "X-SSCI-Evidence": f"{float(ssci_payload.get('evidence', 0.0)):.6f}",
                "X-SSCI-Agreement": f"{float(ssci_payload.get('agreement', 0.0)):.6f}",
                "X-SSCI-Stability": f"{float(ssci_payload.get('stability', 0.0)):.6f}",
                "X-SSCI-Nk": str(ssci_payload.get("n_k", 0)),
                "X-SSCI-Latest-Decision": str(
                    bool(ssci_payload.get("latest_trigger_decision", False))
                ).lower(),
            }
        )

    return headers


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
                        "phone_number": result["phone_number"],
                    }
        return None
    except Exception as e:
        print(f"[ERROR] Failed to query user by phone {phone_number}: {e}")
        return None


async def format_conversation_for_detection(conversation_id: str) -> str:
    """
    格式化對話歷史為詐騙檢測API所需的格式
    格式: caller:...receiver:...caller:...receiver:...
    注意：只包含user和assistant的對話內容，不包含system prompt

    Args:
        conversation_id: 對話ID

    Returns:
        str: 格式化後的對話文本
    """
    try:
        if database.pool:
            async with database.pool.acquire() as conn:
                query = """
                    SELECT role, content, created_at 
                    FROM fraud_messages 
                    WHERE conversation_id = $1 
                    AND role IN ('user', 'assistant')
                    ORDER BY created_at ASC
                """
                messages = await conn.fetch(query, conversation_id)

                formatted_parts = []
                for msg in messages:
                    role = msg["role"]
                    content = msg["content"].strip()

                    # user對應caller, assistant對應receiver
                    if role == "user":
                        formatted_parts.append(f"caller: {content}")
                    elif role == "assistant":
                        formatted_parts.append(f"receiver: {content}")

                formatted_text = " ".join(formatted_parts)
                print(
                    f"[DEBUG] Formatted conversation for detection ({len(messages)} messages): {formatted_text[:200]}..."
                )
                return formatted_text
        return ""
    except Exception as e:
        print(f"[ERROR] Failed to format conversation {conversation_id}: {e}")
        return ""


async def call_fraud_detection_api(conversation_text: str) -> bool | None:
    """
    調用詐騙檢測API

    Args:
        conversation_text: 格式化後的對話文本

    Returns:
        bool: True表示可能是詐騙，False表示正常對話，None表示API調用失敗
    """
    try:
        print(
            f"[DEBUG] Calling fraud detection API with text length: {len(conversation_text)}"
        )
        async with httpx.AsyncClient(timeout=10.0) as client:
            response = await client.post(
                FRAUD_DETECTION_API_URL,
                json={"text": conversation_text},
                headers={"Content-Type": "application/json"},
            )

            print(f"[DEBUG] Fraud detection API status: {response.status_code}")
            print(
                f"[DEBUG] Response content type: {response.headers.get('content-type')}"
            )
            print(f"[DEBUG] Raw response: {response.text}")

            if response.status_code == 200:
                # API返回純文本 "True" 或 "False"
                response_text = response.text.strip()

                if response_text.lower() == "true":
                    prediction = True
                    print("[INFO] Fraud detection result: True (possible scam)")
                elif response_text.lower() == "false":
                    prediction = False
                    print("[INFO] Fraud detection result: False (normal conversation)")
                else:
                    # 如果返回其他內容，嘗試解析JSON
                    try:
                        result = response.json()
                        print(f"[DEBUG] Parsed JSON response: {result}")
                        prediction = result.get(
                            "prediction", result.get("result", None)
                        )
                        print(f"[INFO] Fraud detection result: {prediction}")
                    except json.JSONDecodeError:
                        print(f"[ERROR] Unexpected response format: {response_text}")
                        return None

                return prediction
            else:
                print(
                    f"[WARNING] Fraud detection API returned status {response.status_code}"
                )
                print(f"[WARNING] Response body: {response.text}")
                return None
    except httpx.TimeoutException as e:
        print(f"[ERROR] Fraud detection API timeout: {e}")
        return None
    except httpx.RequestError as e:
        print(f"[ERROR] Fraud detection API request error: {e}")
        return None
    except Exception as e:
        print(f"[ERROR] Failed to call fraud detection API: {e}")
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


async def notify_callee_event(
    caller_user_id: str,
    caller_name: str,
    callee_user_id: str,
    conversation_id: str,
    call_token: str,
):
    """Publishes events to Redis for other services to consume."""
    # Event for the socket gateway to broadcast the text message
    notification_payload = NotificationPayload(
        title="來電通知",
        body=f"偵測到來自 {caller_name} 的來電",
        data={
            "type": "incoming_call",
            "call_token": call_token,
            "caller_name": caller_name,
            "caller_user_id": caller_user_id,
        },
        silent=False, # TODO in the future change to callstylenotification
        android_priority="high",
    )
    gateway_event = {
        "type": "call_notify",
        "service": "anti-fraud",
        "caller_user_id": caller_user_id,
        "callee_user_id": callee_user_id,
        "conversation_id": conversation_id,
        "payload": json.dumps(notification_payload.model_dump()),
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
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
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
                "tts": "healthy" if tts_service else "not_initialized",
            },
        }
    except Exception as e:
        return {"status": "unhealthy", "error": str(e)}


async def check_conversation_duration(
    conversation, caller_user_id, target_user, max_duration
):
    """檢查對話持續時間是否超過限制"""
    target_name = target_user.get("name", target_user.get("username", ""))
    target_id = target_user.get("uuid", "")

    if conversation:
        duration = (
            datetime.now(timezone.utc)
            - conversation["created_at"].replace(tzinfo=timezone.utc)
        ).total_seconds()
        print(
            f"[INFO] Conversation duration for {conversation.get('conversation_id', '') if conversation else ''}: {duration} seconds"
        )
        # Check if the conversation already passed 2 minutes and 45 seconds
        if duration > max_duration:
            print(
                f"[INFO] Conversation duration {duration} seconds exceeded limit of {max_duration} seconds for {target_name} ({target_id})"
            )
            # Call publish_events to notify socket gateway to end the call
            # This requires a message_id, but we may not have one yet.
            # We will use a placeholder or decide on a better strategy.
            # For now, let's assume we can create a temporary or system message id.

            return False  # Indicate that the duration limit has been exceeded
    return True  # Duration is within limit


@app.post("/api/fraud/")
async def fraud_chat_message(
    message: FraudMessage,
    x_user_id: str | None = Header(None, alias="X-User-Id"),
    x_username: str | None = Header(None, alias="X-Username"),
    x_installation_id: str | None = Header("", alias="X-Installation-Id"),
    text_only: str = Query(None),
):
    """
    反詐騙對話API
    AI會扮演透過手機號碼查詢到的目標用戶
    """
    print(
        f"[DEBUG] Anti-fraud service received message from {x_username} ({x_user_id}) targeting phone {message.phone_number}: {message.prompt}"
    )

    if not x_user_id:
        raise HTTPException(
            status_code=400,
            detail="X-User-Id header is required.",
        )
    # if not x_installation_id:
    #     raise HTTPException(
    #         status_code=400,
    #         detail="X-Installation-Id header is required.",
    #     )

    # 透過手機號碼查詢目標用戶
    target_user = await get_user_by_phone(message.phone_number)
    if not target_user:
        raise HTTPException(
            status_code=404,
            detail=f"No user found with phone number {message.phone_number}",
        )

    target_name = target_user.get("name", target_user.get("username", "Unknown"))
    target_id = target_user.get("uuid", "")

    conversation = (
        await get_user_latest_conversation(x_user_id, target_id)
        if not message.initiate_conversation
        else None
    )
    # in_time_limit = await check_conversation_duration(conversation, x_user_id, target_user, max_duration=165)
    # # def check_is_fraud_whole():
    # #     conversation_detection_results.get()
    # if not in_time_limit:
    #     call_token = await database.set_call_token(x_user_id, target_id, expiration_seconds=300)
    #     await notify_callee_event(
    #         caller_user_id=x_user_id,
    #         caller_name=x_username,
    #         callee_user_id=target_id,
    #         call_token=call_token,
    #         conversation_id=conversation.get("conversation_id", "") if conversation else ""
    #     )
    #     return {
    #         "status": "initiate_socketio",
    #         "call_token": call_token
    #     }

    print(f"[INFO] AI will role-play as: {target_name} ({message.phone_number})")

    # 處理對話，AI扮演目標用戶
    response_data = await handle_fraud_chat_message(
        user_id=x_user_id,
        prompt=message.prompt,
        target_user_uuid=target_id,
        target_name=target_name,
        target_phone=message.phone_number,
        llm_pipeline=llm,
        generate_lock=generate_lock,
        conversation=conversation,
    )

    assistant_response = response_data["response"]
    conversation_id = response_data["conversation_id"]
    assistant_message_id = response_data["message_id"]
    ssci_updated = False

    # 每次GPT回覆後，調用詐騙檢測API
    conversation_text = await format_conversation_for_detection(conversation_id)
    if conversation_text:
        detection_result = await call_fraud_detection_api(conversation_text)

        # 初始化該對話的檢測結果列表（如果還沒有）
        if conversation_id not in conversation_detection_results:
            conversation_detection_results[conversation_id] = []

        # 存儲檢測結果
        if detection_result is not None:
            conversation_detection_results[conversation_id].append(detection_result)
            ssci_updated = (
                len(conversation_detection_results[conversation_id]) % INFERENCES_PER_TRIGGER
                == 0
            )
            print(
                f"[INFO] Conversation {conversation_id} detection results so far: {conversation_detection_results[conversation_id]}"
            )

    raw_detection_results = conversation_detection_results.get(conversation_id, [])
    ssci_payload = _build_ssci_payload(raw_detection_results, updated=ssci_updated)

    # 檢查對話是否超過3分鐘（180秒）
    in_time_limit = await check_conversation_duration(
        conversation, x_user_id, target_user, max_duration=180
    )
    if not in_time_limit:
        # 超過3分鐘後，改為以 SSCI confidence 判斷
        if ssci_payload.get("available"):
            ssci_confidence = float(ssci_payload.get("confidence", 0.0))
            is_scam_by_ssci = ssci_confidence > SSCI_SCAM_THRESHOLD

            print(
                f"[INFO] Conversation {conversation_id} - SSCI confidence: {ssci_confidence:.6f}, threshold: {SSCI_SCAM_THRESHOLD:.2f}, scam={is_scam_by_ssci}"
            )

            if not is_scam_by_ssci:
                print(
                    "[INFO] SSCI indicates normal conversation (confidence <= threshold). Notifying real user to take over."
                )
                call_token = await database.set_call_token(
                    x_user_id, target_id, expiration_seconds=300
                )
                await notify_callee_event(
                    caller_user_id=x_user_id,
                    caller_name=x_username,
                    callee_user_id=target_id,
                    call_token=call_token,
                    conversation_id=conversation_id,
                )

                # 清理該對話的檢測結果
                conversation_detection_results.pop(conversation_id, None)

                return {
                    "status": "initiate_socketio",
                    "call_token": call_token,
                    "reason": "ssci_below_threshold_normal_conversation",
                    "ssci": ssci_payload,
                }
            else:
                print(
                    "[INFO] SSCI indicates potential scam (confidence > threshold). Continuing AI conversation."
                )
                # 繼續處理，返回正常的音頻響應
        else:
            # 若 SSCI 尚不可用（例如外部判斷持續失敗），預設觸發通知（安全起見）
            print(
                "[WARNING] SSCI is unavailable. Notifying real user as precaution."
            )
            call_token = await database.set_call_token(
                x_user_id, target_id, expiration_seconds=300
            )
            await notify_callee_event(
                caller_user_id=x_user_id,
                caller_name=x_username,
                callee_user_id=target_id,
                call_token=call_token,
                conversation_id=conversation_id,
            )

            return {
                "status": "initiate_socketio",
                "call_token": call_token,
                "reason": "ssci_unavailable",
                "ssci": ssci_payload,
            }

    if text_only == "true":
        return {
            "message": assistant_response,
            "message_id": assistant_message_id,
            "conversation_id": conversation_id,
            "recipient_user_id": x_user_id,
            "source_installation_id": x_installation_id,
            "service_type": "anti-fraud",
            "target_name": target_name,
            "target_phone": message.phone_number,
            "ssci": ssci_payload,
        }

    # Generate audio from text using TTS service
    try:
        audio_bytes = await tts_service.generate_speech_bytes(assistant_response)

        # Create response with audio file and text in headers
        response = Response(
            content=audio_bytes,
            media_type="audio/mpeg",
            headers={
                "X-Response-Text": urllib.parse.quote(assistant_response),
                "X-Message-Id": assistant_message_id,
                "X-Conversation-Id": conversation_id,
                "X-Recipient-User-Id": x_user_id,
                "X-Source-Installation-Id": x_installation_id,
                "X-Service-Type": "anti-fraud",
                "X-Target-Name": target_name,
                "X-Target-Phone": message.phone_number,
                "Content-Disposition": f"attachment; filename={target_name}_response.mp3",
                **_build_ssci_headers(ssci_payload),
            },
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
            "status": "error",
            "error_type": "tts_generation_error",
            "error_message": f"TTS generation failed: {e}",
            "message": assistant_response,
            "message_id": assistant_message_id,
            "conversation_id": conversation_id,
            "recipient_user_id": x_user_id,
            "source_installation_id": x_installation_id,
            "service_type": "anti-fraud",
            "target_name": target_name,
            "target_phone": message.phone_number,
            "ssci": ssci_payload,
        }


if __name__ == "__main__":
    import uvicorn

    uvicorn.run(app, host="0.0.0.0", port=8000)
