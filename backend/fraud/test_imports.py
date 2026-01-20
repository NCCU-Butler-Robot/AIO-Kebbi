#!/usr/bin/env python3
"""
測試fraud服務的導入是否正確工作
"""

import sys
import os

# 添加src目錄到Python路徑
sys.path.insert(0, '/home/fintech/projects/AIO-Kebbi/backend/fraud/src')

try:
    print("Testing imports...")
    
    # 測試db_manager導入
    from db_manager import database
    print("✅ db_manager import successful")
    
    # 測試llm_pipeline導入
    from llm_pipeline import LLMPipeline, SYSTEM_PROMPT
    print("✅ llm_pipeline import successful")
    
    # 測試dialogue導入
    from dialogue.conversation_manager import handle_fraud_chat_message
    print("✅ dialogue import successful")
    
    # 測試tts_service導入
    from tts_service import TTSService
    print("✅ tts_service import successful")
    
    print("\n🎉 All imports successful!")
    
except ImportError as e:
    print(f"❌ Import error: {e}")
    sys.exit(1)
except Exception as e:
    print(f"❌ Unexpected error: {e}")
    sys.exit(1)