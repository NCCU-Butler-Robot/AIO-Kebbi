
from fastapi import FastAPI, Header, Request
from pydantic import BaseModel

app = FastAPI()

class UserMessage(BaseModel):
    prompt: str

@app.post("/api/chat/")
async def chat_message(
    message: UserMessage,
    x_user_id: str | None = Header(None, alias="X-User-Id"),
    x_username: str | None = Header(None, alias="X-Username"),
):

    if x_user_id and x_username:
        return {"message": f"Hello, {x_username} (ID: {x_user_id}), your prompt was: {message.prompt}"}
    return {"message": "Hello, This prompt will be ignored by chat if authenticated"}

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)