import asyncio
from typing import Dict, List

from ..db_manager.database import (
    add_message as db_add_message,  # Alias to avoid name conflict
)
from ..db_manager.database import (
    create_conversation as db_create_conversation,  # Alias to avoid name conflict
)
from ..llm_pipeline import LLMPipeline


async def handle_fraud_chat_message(
    user_id: str,
    prompt: str,
    target_user_uuid: str,
    target_name: str,
    target_phone: str,
    llm_pipeline: LLMPipeline,
    generate_lock: asyncio.Lock,
    conversation,
) -> Dict[str, str]:
    """
    處理反詐騙對話訊息，AI會扮演目標用戶

    Args:
        user_id: 詐騙犯的用戶ID
        prompt: 詐騙犯的輸入
        target_name: 目標受話者姓名
        target_phone: 目標受話者手機號碼
        llm_pipeline: LLM管道
        generate_lock: 生成鎖

    Returns:
        Dict: 包含回應、對話ID、訊息ID等資訊
    """
    conversation_id: str
    messages_history: List[Dict[str, str]]

    if conversation:
        conversation_id = conversation["conversation_id"]
        messages_history = conversation["messages"]

    else:
        conversation_id = await db_create_conversation(user_id, target_user_uuid)
        # 不使用固定的 system prompt，而是在generate_with_role中動態創建
        messages_history = []

    messages_history.append({"role": "user", "content": prompt})
    await db_add_message(conversation_id, "user", prompt)

    async with generate_lock:
        # 使用角色扮演的generate方法
        assistant_response = await llm_pipeline.generate_with_role(
            prompt,
            target_name,
            target_phone,
            messages_history[:],  # 排除剛加入的user message
        )

    assistant_message_id = await db_add_message(
        conversation_id, "assistant", assistant_response
    )

    return {
        "response": assistant_response,
        "conversation_id": conversation_id,
        "message_id": assistant_message_id,
        "target_name": target_name,
        "target_phone": target_phone,
    }
