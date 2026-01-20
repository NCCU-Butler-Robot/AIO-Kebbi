import asyncio
import json
import socketio
import uvicorn
import redis.asyncio as redis
from contextlib import asynccontextmanager
from fastapi import FastAPI

# 1. Set up Redis manager for scaling across multiple instances
# 'redis://' assumes redis is running locally on default port 6379
mgr = socketio.AsyncRedisManager(
    "redis://redis:6379/0"
)  # Use 'redis' as service name in Docker

# 2. Attach it to your server
sio = socketio.AsyncServer(
    async_mode="asgi",
    client_manager=mgr,
    cors_allowed_origins="*",  # Allow all origins (Nginx handles CORS, but this is for direct access if needed)
)


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Manages application startup and shutdown events."""
    # Start the Redis listener as a background task
    listener_task = asyncio.create_task(redis_listener())
    print("[Socket Gateway] Lifespan startup: Redis listener task created.")
    yield
    # On shutdown, gracefully cancel the background task
    print("[Socket Gateway] Lifespan shutdown: Cancelling Redis listener task.")
    listener_task.cancel()


# Create FastAPI app and mount Socket.IO
app = FastAPI(lifespan=lifespan)
app.mount("/", socketio.ASGIApp(sio))


async def process_text_broadcast(data):
    """A dedicated, concurrent task for handling text broadcasts."""
    try:
        user_id = data.get("user_id")
        text = data.get("text")
        conversation_id = data.get("conversation_id")
        message_id = data.get("message_id")
        if all([user_id, text, message_id, conversation_id]):
            print(f"[Socket Gateway] Broadcasting text to user_id: {user_id}")
            # This await only blocks this small task, not the main listener.
            await sio.emit("new_message", {"conversation_id": conversation_id, "message_id": message_id, "message": text}, room=user_id)
    except Exception as e:
        print(f"[Socket Gateway] Error processing text broadcast: {e}")

async def process_audio_delivery(redis_client, data):
    """A dedicated, concurrent task for handling audio delivery."""
    try:
        user_id = data.get("user_id")
        installation_id = data.get("installation_id")
        conversation_id = data.get("conversation_id")
        message_id = data.get("message_id")
        audio_key = data.get("audio_key")

        if not all([user_id, installation_id, conversation_id, message_id, audio_key]):
            return

        audio_data = await redis_client.get(audio_key)
        if audio_data:
            await redis_client.delete(audio_key)
            for sid in sio.rooms(user_id):
                session = await sio.get_session(sid)
                if session and session.get("installation_id") == installation_id:
                    # This await only blocks this small task.
                    await sio.emit("audio_message", {"conversation_id": conversation_id, "message_id": message_id, "audio": audio_data}, to=sid)
                    print(f"[Socket Gateway] Sent audio to user {user_id} on device {installation_id}")
                    break
    except Exception as e:
        print(f"[Socket Gateway] Error processing audio delivery: {e}")


async def redis_listener():
    """Listens to Redis and DISPATCHES messages to concurrent worker tasks."""
    r = redis.from_url("redis://redis:6379/0")
    async with r.pubsub() as pubsub:
        await pubsub.subscribe("app_events")
        print("[Socket Gateway] Subscribed to 'app_events' channel.")
        while True:
            try:
                # Use a longer timeout or None to wait indefinitely for a message
                message = await pubsub.get_message(ignore_subscribe_messages=True, timeout=None)
                if message and message["type"] == "message":
                    data = json.loads(message["data"])
                    event_type = data.get("type")
                    
                    # --- THE KEY CHANGE: Create a background task for each message ---
                    if event_type == "text_broadcast":
                        # Don't await here! Just start the task.
                        asyncio.create_task(process_text_broadcast(data))
                    elif event_type == "audio_delivery":
                        # Don't await here! Pass the redis client to the task.
                        asyncio.create_task(process_audio_delivery(r, data))
            except Exception as e:
                print(f"[Socket Gateway] Error in Redis listener dispatcher: {e}")
                await asyncio.sleep(5) # Avoid fast-spinning on persistent errors


@sio.event
async def connect(sid, environ, auth):
    # 1. Access the ASGI scope
    scope = environ.get("asgi.scope")

    if scope:
        # 2. Extract headers (they are a list of [b'name', b'value'] tuples)
        headers = dict(scope.get("headers", []))

        # 3. Get specific headers (must use byte keys)
        user_id = headers.get(b"x-user-id", b"").decode()
        username = headers.get(b"x-username", b"").decode()
        installation_id = headers.get(b"x-installation-id", b"").decode()

        if user_id and username and installation_id:
            # Store user info in the session for this connection
            await sio.save_session(
                sid,
                {"user_id": user_id, "username": username, "installation_id": installation_id},
            )
            # Join a room named after the user_id for easy broadcasting
            sio.enter_room(sid, user_id)
            print(f"Connected: {sid} - User: {username} (ID: {user_id}) on device {installation_id}")
            return True
        else:
            print(f"Connection rejected: {sid} - Missing user/installation headers")
            return False
    else:
        print(f"Connection rejected: {sid} - No ASGI scope")
        return False

@sio.event
async def disconnect(sid):
    # Use get_session for a simple read-only operation before the session is destroyed.
    session = await sio.get_session(sid)
    if session:
        # Leave the user-specific room.
        sio.leave_room(sid, session["user_id"])
        print(f"Disconnected: {sid} - User: {session['username']}")
    else:
        print(f"Disconnected: {sid}")


# Example event handler
@sio.event
async def message(sid, data):
    async with sio.session(sid) as session:
        if session:
            user_info = session
            print(f"Message from {user_info['username']}: {data}")
            # Echo back or handle as needed
            await sio.emit("response", f"Hello {user_info['username']}: {data}", to=sid)
        else:
            await sio.emit("error", "Unauthorized", to=sid)


if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=5000)
