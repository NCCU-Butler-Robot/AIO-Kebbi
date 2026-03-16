# 直接導入GPT實現
from .gpt_pipeline import ANTI_FRAUD_SYSTEM_PROMPT, GPTPipeline

# 為了向後兼容性，創建別名
LLMPipeline = GPTPipeline
SYSTEM_PROMPT = ANTI_FRAUD_SYSTEM_PROMPT
