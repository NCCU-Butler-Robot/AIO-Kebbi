import asyncio
from io import BytesIO
import redis.asyncio as redis
from gtts import gTTS
import uuid


async def tts_worker():
    """
    Connects to Redis and serially processes jobs from the 'app_stream' using a consumer group.
    """
    r = redis.from_url("redis://redis:6379/0")
    stream_name = "app_stream"
    group_name = "tts_group"
    consumer_name = f"tts_worker_{uuid.uuid4()}"

    try:
        # Create the stream and consumer group if they don't exist.
        await r.xgroup_create(stream_name, group_name, id="0", mkstream=True)
        print(f"[TTS Worker] Consumer group '{group_name}' created or already exists.")
    except redis.exceptions.ResponseError as e:
        if "BUSYGROUP" not in str(e):
            raise  # Re-raise if it's not the expected "group already exists" error
        print(f"[TTS Worker] Consumer group '{group_name}' already exists.")

    print(f"[TTS Worker] {consumer_name} waiting for jobs...")

    while True:
        try:
            # Read from the stream. '>' means get new messages. BLOCK 0 means wait forever.
            response = await r.xreadgroup(group_name, consumer_name, {stream_name: ">"}, count=1, block=0)
            
            if not response:
                continue

            stream, messages = response[0]
            stream_message_id, data = messages[0]

            # Decode byte keys and values from Redis
            decoded_data = {k.decode('utf-8'): v.decode('utf-8') for k, v in data.items()}

            if decoded_data.get("type") == "tts_generation_request":
                print(f"[TTS Worker] Received job {stream_message_id} for installation_id: {decoded_data.get('installation_id')}")
                
                # Generate audio in a separate thread to avoid blocking the event loop.
                def generate_audio():
                    mp3_fp = BytesIO()
                    tts = gTTS(decoded_data["text"], lang="en")
                    tts.write_to_fp(mp3_fp)
                    mp3_fp.seek(0)
                    return mp3_fp.read()

                audio_bytes = await asyncio.to_thread(generate_audio)

                # Store the binary audio in Redis with a short expiry
                audio_key = f"audio:{uuid.uuid4()}"
                await r.setex(audio_key, 60, audio_bytes)

                # Add the audio delivery event back to the stream for the gateway to process
                delivery_event = {
                    "type": "audio_delivery",
                    "user_id": decoded_data["user_id"],
                    "installation_id": decoded_data["installation_id"],
                    "conversation_id": decoded_data["conversation_id"],
                    "message_id": decoded_data["message_id"],
                    "audio_key": audio_key,
                }
                await r.xadd(stream_name, delivery_event)
                print(f"[TTS Worker] Added audio_delivery event for job {stream_message_id}")
            
            # Acknowledge the message so it's not delivered again.
            await r.xack(stream_name, group_name, stream_message_id)

        except Exception as e:
            print(f"[TTS Worker] Error in main dispatcher loop: {e}")
            await asyncio.sleep(5)


if __name__ == "__main__":
    asyncio.run(tts_worker())
