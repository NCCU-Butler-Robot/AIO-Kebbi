import openai
import os
from pathlib import Path

class TTSService:
    """
    文字轉語音服務
    使用 OpenAI TTS API 生成語音
    """
    
    def __init__(self):
        self.client = openai.OpenAI(api_key=os.getenv("OPENAI_API_KEY"))
        self.model = os.getenv("TTS_MODEL", "tts-1")
        self.voice = os.getenv("VOICE_MODEL", "alloy")  # alloy, echo, fable, onyx, nova, shimmer
    
    async def generate_speech_bytes(self, text: str) -> bytes:
        """
        將文字轉換為語音二進位數據
        
        Args:
            text: 要轉換的文字
            
        Returns:
            語音檔案的二進位數據
        """
        try:
            # 呼叫 OpenAI TTS API
            response = self.client.audio.speech.create(
                model=self.model,
                voice=self.voice,
                input=text
            )
            
            # 直接返回二進位數據
            return response.content
            
        except Exception as e:
            raise Exception(f"TTS 生成失敗: {str(e)}")