import socketio
import uvicorn
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

# Create FastAPI app and mount Socket.IO
app = FastAPI()
app.mount("/", socketio.ASGIApp(sio))

# Store user info per session
connected_users = {}


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

        if user_id and username:
            connected_users[sid] = {"user_id": user_id, "username": username}
            print(f"Connected: {sid} - User: {username} (ID: {user_id})")
            return True
        else:
            print(f"Connection rejected: {sid} - Missing user headers")
            return False
    else:
        print(f"Connection rejected: {sid} - No ASGI scope")
        return False


@sio.event
async def disconnect(sid):
    if sid in connected_users:
        user_info = connected_users.pop(sid)
        print(f"Disconnected: {sid} - User: {user_info['username']}")
    else:
        print(f"Disconnected: {sid}")


# Example event handler
@sio.event
async def message(sid, data):
    user_info = connected_users.get(sid)
    if user_info:
        print(f"Message from {user_info['username']}: {data}")
        # Echo back or handle as needed
        await sio.emit("response", f"Hello {user_info['username']}: {data}", to=sid)
    else:
        await sio.emit("error", "Unauthorized", to=sid)


if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=5000)
