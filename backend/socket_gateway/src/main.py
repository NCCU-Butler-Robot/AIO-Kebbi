import asyncio
import json
import os
import time
from contextlib import asynccontextmanager

import socketio
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from jose import jwt

from .db_manager import database

# JWT Settings
JWT_SECRET_KEY = os.getenv("JWT_SECRET_KEY")
JWT_ALGORITHM = os.getenv("JWT_ALGORITHM", "HS256")

if not JWT_SECRET_KEY:
    raise ValueError("JWT_SECRET_KEY must be set in the environment")

# 1. Set up Redis manager for scaling across multiple instances
# 'redis://' assumes redis is running locally on default port 6379
# mgr = socketio.AsyncRedisManager(
#     "redis://redis:6379/0"
# )  # Use 'redis' as service name in Docker

# 2. Attach it to your server
sio = socketio.AsyncServer(
    async_mode="asgi",
    # client_manager=mgr,
    cors_allowed_origins="*",  # Allow all origins (Nginx handles CORS, but this is for direct access if needed)
)


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Manages application startup and shutdown events."""
    # Start the Redis listener as a background task
    # listener_task = asyncio.create_task(redis_listener())
    # print("[Socket Gateway] Lifespan startup: Redis listener task created.")
    await database.connect_to_db()
    # Check if the redis_client was successfully initialized before using it.
    if database.redis_client:
        await database.redis_client.ping()  # Establishes connection and checks health
    else:
        raise RuntimeError(
            "Redis client could not be initialized. Application cannot start."
        )
    yield
    await database.close_redis_connection()
    # On shutdown, gracefully cancel the background task
    print("[Socket Gateway] Lifespan shutdown: Cancelling Redis listener task.")
    # listener_task.cancel()


# Create FastAPI app and mount Socket.IO
app = FastAPI(lifespan=lifespan)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)
app.mount("/", socketio.ASGIApp(sio))


# async def process_text_broadcast(data):
#     """A dedicated, concurrent task for handling text broadcasts."""
#     try:
#         user_id = data.get("user_id")
#         text = data.get("text")
#         conversation_id = data.get("conversation_id")
#         message_id = data.get("message_id")
#         if all([user_id, text, message_id, conversation_id]):
#             print(f"[Socket Gateway] Broadcasting text to user_id: {user_id}")
#             # This await only blocks this small task, not the main listener.
#             await sio.emit("new_message", {"conversation_id": conversation_id, "message_id": message_id, "message": text}, room=user_id)
#     except Exception as e:
#         print(f"[Socket Gateway] Error processing text broadcast: {e}")

# async def process_audio_delivery(redis_client, data):
#     """A dedicated, concurrent task for handling audio delivery."""
#     try:
#         user_id = data.get("user_id")
#         installation_id = data.get("installation_id")
#         conversation_id = data.get("conversation_id")
#         message_id = data.get("message_id")
#         audio_key = data.get("audio_key")

#         if not all([user_id, installation_id, conversation_id, message_id, audio_key]):
#             return

#         audio_data = await redis_client.get(audio_key)
#         if audio_data:
#             await redis_client.delete(audio_key)
#             for sid in sio.rooms(user_id):
#                 session = await sio.get_session(sid)
#                 if session and session.get("installation_id") == installation_id:
#                     # This await only blocks this small task.
#                     await sio.emit("audio_message", {"conversation_id": conversation_id, "message_id": message_id, "audio": audio_data}, to=sid)
#                     print(f"[Socket Gateway] Sent audio to user {user_id} on device {installation_id}")
#                     break
#     except Exception as e:
#         print(f"[Socket Gateway] Error processing audio delivery: {e}")


# async def redis_listener():
#     """Reads from a Redis Stream and dispatches messages to concurrent worker tasks."""
#     r = redis.from_url("redis://redis:6379/0")
#     stream_name = "app_stream"
#     group_name = "gateway_group"
#     consumer_name = f"gateway_worker_{uuid.uuid4()}"

#     try:
#         await r.xgroup_create(stream_name, group_name, id="0", mkstream=True)
#         print(f"[Socket Gateway] Consumer group '{group_name}' created or already exists.")
#     except redis.exceptions.ResponseError as e:
#         if "BUSYGROUP" not in str(e):
#             raise
#         print(f"[Socket Gateway] Consumer group '{group_name}' already exists.")

#     print(f"[Socket Gateway] {consumer_name} waiting for jobs...")
#     while True:
#         try:
#             response = await r.xreadgroup(group_name, consumer_name, {stream_name: ">"}, count=1, block=0)
#             if not response:
#                 continue

#             stream, messages = response[0]
#             message_id, data = messages[0]
#             decoded_data = {k.decode('utf-8'): v.decode('utf-8') for k, v in data.items()}
#             event_type = decoded_data.get("type")

#             if event_type == "text_broadcast":
#                 asyncio.create_task(process_text_broadcast(decoded_data))
#             elif event_type == "audio_delivery":
#                 asyncio.create_task(process_audio_delivery(r, decoded_data))

#             await r.xack(stream_name, group_name, message_id)
#         except Exception as e:
#             print(f"[Socket Gateway] Error in Redis listener dispatcher: {e}")
#             await asyncio.sleep(5)


@sio.event
async def connect(sid, environ, auth):
    # 1. Access the ASGI scope
    # scope = environ.get("asgi.scope")

    # if scope:
    #     # 2. Extract headers (they are a list of [b'name', b'value'] tuples)
    #     headers = dict(scope.get("headers", []))

    #     # 3. Get specific headers (must use byte keys)
    #     user_id = headers.get(b"x-user-id", b"").decode()
    #     username = headers.get(b"x-username", b"").decode()
    #     installation_id = headers.get(b"x-installation-id", b"").decode()

    #     if user_id and username:
    #         # Join a room named after the user_id for easy broadcasting
    #         print(f"Connected: {sid} - User: {username} (ID: {user_id}) on device {installation_id}")

    access_token = auth.get("access_token")
    call_token = auth.get("call_token")
    payload = jwt.decode(access_token, JWT_SECRET_KEY, algorithms=[JWT_ALGORITHM])

    username: str | None = payload.get("user_name")
    user_id: str | None = payload.get("user_id")

    if user_id and call_token:
        key = f"call_token:{call_token}"

        if not database.redis_client:
            print("Redis client not initialized")
            return False

        await database.redis_client.expire(key, 300)

        value = await database.redis_client.get(key)

        if not value:
            print("Invalid or expired call_token")
            return False

        data = json.loads(value)

        caller_id = data["caller"]
        callee_id = data["callee"]

        room = f"call:{caller_id}_{callee_id}__{call_token}"
        # Store user info in the session for this connection
        await sio.save_session(
            sid,
            {
                "username": username,
                "user_id": user_id,
                "role": "caller"
                if caller_id == user_id
                else "callee"
                if callee_id == user_id
                else "unknown",
                "caller_id": caller_id,
                "callee_id": callee_id,
                "call_token": call_token,
                "room": room,
            },
        )

        await sio.enter_room(sid, room)

        return True
    else:
        print(f"Connection rejected: {sid} - Missing user/installation headers")
        return False
    # else:
    #     print(f"Connection rejected: {sid} - No ASGI scope")
    #     return False


@sio.event
async def disconnect(sid):
    # Use get_session for a simple read-only operation before the session is destroyed.
    session = await sio.get_session(sid)
    if session:
        room = session.get("room")
        if room:
            await sio.leave_room(sid, room)
            print(
                f"Left room: {room} for SID: {sid}. User: {session.get('username')} ({session.get('role')})"
            )

        else:
            print(f"Disconnected: {sid} (no room info) DEBUG: {session}")
    else:
        print(f"Disconnected: {sid}")


# Example event handler
# @sio.event
# async def message(sid, data):
#     async with sio.session(sid) as session:
#         if session:
#             user_info = session
#             print(f"Message from {user_info['username']}: {data}")
#             # Echo back or handle as needed
#             await sio.emit("response", f"Hello {user_info['username']}: {data}", to=sid)
#         else:
#             await sio.emit("error", "Unauthorized", to=sid)


async def refresh_key(key):
    if not database.redis_client:
        print("Redis client not initialized")
        return False
    try:
        await database.redis_client.expire(key, 300)
    except Exception as e:
        print(f"Error refreshing call_token {key}: {e}")


@sio.on("audio_chunk")
async def handle_audio_chunk(sid, metadata, chunk):
    """
    chunk: raw PCM bytes
    metadata: dict, e.g. {"sequence": 1, "timestamp": 123456}
    """
    received_timestamp = time.time()
    async with sio.session(sid) as session:
        if not session:
            return

        room = session.get("room")
        if not room:
            return

        call_token = session.get("call_token")
        key = f"call_token:{call_token}"

        asyncio.create_task(refresh_key(key))

        # username = session.get("username")
        # user_id = session.get("user_id")
        # role = session.get("role")
        # original_timestamp = metadata.get("timestamp")/1000.0
        # print(f"Received audio chunk from {username}, delay {received_timestamp - original_timestamp} s")

        # Broadcast to everyone else in the room
        await sio.emit(
            "audio_chunk",
            {
                "metadata": metadata,
                "chunk": chunk,  # raw bytes
            },
            room=room,
            skip_sid=sid,  # optional: skip the sender
        )


if __name__ == "__main__":
    import uvicorn

    uvicorn.run(app, host="0.0.0.0", port=5000)
