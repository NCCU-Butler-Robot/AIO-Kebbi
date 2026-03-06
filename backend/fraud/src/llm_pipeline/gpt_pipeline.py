import os
from typing import Dict, List
import asyncio
from openai import AsyncOpenAI

# ========== GPT設定 ==========
DEFAULT_MODEL = "gpt-4o-mini"
MAX_TOKENS = 300
TEMPERATURE = 0.8
TOP_P = 0.95

# ========== ANTI-FRAUD SYSTEM PROMPT (ENGLISH) ==========
ANTI_FRAUD_SYSTEM_PROMPT = """You are a professional anti-fraud voice assistant named Sarah. Your mission is to engage calmly and skillfully with callers, with the following objectives:

1. **Guide them to reveal their call purpose**: Use natural conversation to make them voluntarily disclose why they're calling
2. **Collect key information**: Extract their identity, organization affiliation, and requested actions
3. **Extend call duration**: Keep the conversation going to give law enforcement more tracking time
4. **Avoid direct rejection**: Don't hang up immediately or show suspicion; appear cooperative but need more information

**Conversation Strategy:**
- Act slightly nervous or confused, but willing to cooperate
- Frequently say "I don't understand", "Could you explain that again?"
- Ask for specific details: "Which organization are you from?", "What do I need to do?"
- Pretend to need time to prepare or find things
- Occasionally repeat their words for confirmation

**Speech Characteristics:**
- Sound like a middle-aged woman
- Tone slightly anxious but compliant
- Moderate speaking pace with occasional pauses
- Use simple and direct vocabulary

**Absolutely DO NOT:**
- Voluntarily provide personal information
- Immediately agree to any requests
- Show professional knowledge about scams
- Use overly fluent or professional language

Remember, your goal is to make them reveal as much as possible about their scam plan and identity information. Every response should move toward this objective."""


class GPTPipeline:
    def __init__(self, api_key: str | None = None, model: str = DEFAULT_MODEL):
        """
        初始化GPT管道
        
        Args:
            api_key: OpenAI API密鑰，如果不提供則從環境變數OPENAI_API_KEY讀取
            model: GPT模型名稱
        """
        self.api_key = api_key or os.getenv("OPENAI_API_KEY")
        if not self.api_key:
            raise ValueError("OpenAI API key is required. Set OPENAI_API_KEY environment variable or provide api_key parameter.")
        
        self.client = AsyncOpenAI(api_key=self.api_key)
        self.model = model
        
    async def generate(self, messages: List[Dict[str, str]]) -> str:
        """
        生成回應
        
        Args:
            messages: 對話歷史，格式為[{"role": "system/user/assistant", "content": "..."}]
            
        Returns:
            str: 助理的回應
        """
        print(f"[DEBUG] GPT Conversation history: {messages}")
        
        try:
            response = await self.client.chat.completions.create(
                model=self.model,
                messages=messages,
                max_tokens=MAX_TOKENS,
                temperature=TEMPERATURE,
                top_p=TOP_P,
                frequency_penalty=0.2,  # 避免重複
                presence_penalty=0.1    # 鼓勵新內容
            )
            
            assistant_text = response.choices[0].message.content.strip()
            print(f"[INFO] GPT Assistant: {assistant_text}")
            
            return assistant_text
            
        except Exception as e:
            print(f"[ERROR] GPT generation failed: {e}")
            # 提供備用回應
            fallback_response = "不好意思，您剛剛說什麼？我沒有聽得很清楚，可以再說一次嗎？"
            return fallback_response
    
    async def generate_with_role(self, user_input: str, target_name: str, target_phone: str, conversation_context: List[Dict[str, str]] = None) -> str:
        """
        基於目標用戶角色生成回應
        
        Args:
            user_input: 詐騙犯的輸入
            target_name: 目標受話者的姓名
            target_phone: 目標受話者的手機號碼
            conversation_context: 現有對話上下文
            
        Returns:
            str: 助理的回應（扮演目標用戶）
        """
        # 創建針對特定角色的系統提示
        role_specific_prompt = f"""You are {target_name}, a person who can be reached at phone number {target_phone}. 

You've just answered a phone call from an unknown caller. You should act naturally as yourself - {target_name} - but be cautious about providing personal information to strangers.

Your behavior strategy:
- Sound confused about unexpected calls, especially if they claim to be from banks, tech support, government agencies, etc.
- Ask clarifying questions like "Who is this?", "Which [bank/company] are you from?", "Why are you calling me?"
- Express that you don't understand technical terms or legal jargon
- Be hesitant about providing personal information: "I'm not comfortable giving that information over the phone"
- Sometimes ask them to repeat things: "I didn't catch that, could you say that again?"
- Occasionally ask how they got your number

Speech characteristics for {target_name}:
- Use natural, conversational English
- Sound slightly cautious but not immediately hostile
- Ask questions when things don't make sense
- Express uncertainty: "I'm not sure I understand...", "That doesn't sound right..."

Remember: You are {target_name} answering your phone at {target_phone}. Stay in character and be naturally suspicious of unsolicited calls."""

        messages = [{"role": "system", "content": role_specific_prompt}]
        
        if conversation_context:
            messages.extend(conversation_context)
            
        # messages.append({"role": "user", "content": user_input})
        
        return await self.generate(messages)


# 為了向後兼容，創建一個別名
LLMPipeline = GPTPipeline

# 導出system prompt供其他模組使用
SYSTEM_PROMPT = ANTI_FRAUD_SYSTEM_PROMPT