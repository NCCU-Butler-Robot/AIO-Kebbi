import asyncio
import json
from io import BytesIO
import redis.asyncio as redis
from gtts import gTTS
import uuid


async def tts_worker():
    """
    Connects to Redis and listens for 'tts_generation_request' events.
    """
    r = redis.from_url("redis://redis:6379/0")
    async with r.pubsub() as pubsub:
        await pubsub.subscribe("app_events")
        print("[TTS Worker] Subscribed to 'app_events' channel.")
        while True:
            try:
                message = await pubsub.get_message(ignore_subscribe_messages=True, timeout=None)
                if message and message["type"] == "message":
                    data = json.loads(message["data"])
                    if data.get("type") == "tts_generation_request":
                        user_id = data.get("user_id")
                        installation_id = data.get("installation_id")
                        text = data.get("text")
                        conversation_id = data.get("conversation_id")
                        message_id = data.get("message_id")

                        if not all([user_id, installation_id, text, message_id, conversation_id]):
                            print(f"[TTS Worker] Skipping malformed job: {data}")
                            continue

                        print(
                            f"[TTS Worker] Received job for installation_id: {installation_id}"
                        )

                        # 1. Generate audio bytes in memory using gTTS
                        mp3_fp = BytesIO()
                        tts = gTTS(text, lang="en")
                        tts.write_to_fp(mp3_fp)
                        mp3_fp.seek(0)
                        audio_bytes = mp3_fp.read()

                        # 2. Store the binary audio in Redis with a short expiry
                        audio_key = f"audio:{uuid.uuid4()}"
                        # Set to expire in 60 seconds, plenty of time for delivery
                        await r.setex(audio_key, 60, audio_bytes)

                        # 3. Publish a new event with the key to the audio data
                        delivery_event = {
                            "type": "audio_delivery",
                            "user_id": user_id,
                            "installation_id": installation_id,
                            "conversation_id": conversation_id,
                            "message_id": message_id,
                            "audio_key": audio_key,
                        }
                        await r.publish("app_events", json.dumps(delivery_event))
                        print(
                            f"[TTS Worker] Published audio_delivery for installation_id: {installation_id}"
                        )
            except Exception as e:
                print(f"[TTS Worker] Error: {e}")
                await asyncio.sleep(5)

if __name__ == "__main__":
    asyncio.run(tts_worker())
