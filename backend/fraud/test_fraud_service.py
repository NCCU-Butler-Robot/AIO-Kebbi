#!/usr/bin/env python3
"""
Anti-Fraud Service Test Suite
測試流程：
1. 健康檢查
2. 登入取得 JWT Token
3. 詐騙場景測試（單輪）
4. 多輪對話測試
5. MP3 音訊回應測試
6. 邊界情況測試
"""

import asyncio
import httpx
from typing import Optional

NGINX_URL = "http://nginx:80"
FRAUD_DIRECT_URL = "http://localhost:8000"
AUTH_ENDPOINT = f"{NGINX_URL}/auth/login"
FRAUD_ENDPOINT = f"{NGINX_URL}/api/fraud/"
HEALTH_ENDPOINT = f"{FRAUD_DIRECT_URL}/health"

# 預設用戶
CALLER = {
    "username": "alice",
    "password": "passAlice1",
    "uuid": "11111111-1111-1111-1111-111111111111",
    "phone": "0911000001",
}

TARGET = {
    "username": "bob",
    "password": "passBob1",
    "uuid": "22222222-2222-2222-2222-222222222222",
    "phone": "0911000002",
}

# 詐騙場景測試案例
SCAM_TEST_CASES = [
    {
        "name": "Bank Scam Opening",
        "message": {
            "prompt": "Hello, this is customer service from your bank. We've detected some suspicious activity on your account.",
            "phone_number": TARGET["phone"],
        },
        "expected_behavior": "Should ask for clarification about which bank and what kind of activity, acting as the phone owner",
    },
    {
        "name": "Tech Support Scam",
        "message": {
            "prompt": "This is Microsoft technical support. Your computer is infected with viruses and we need remote access to fix it.",
            "phone_number": TARGET["phone"],
        },
        "expected_behavior": "Should appear confused about technical terms and ask for more details, as the phone owner",
    },
    {
        "name": "IRS/Tax Scam",
        "message": {
            "prompt": "This is the Internal Revenue Service. You owe back taxes and must pay immediately or face arrest.",
            "phone_number": TARGET["phone"],
        },
        "expected_behavior": "Should sound worried but ask for verification and specifics, as the phone owner",
    },
    {
        "name": "Lottery Scam",
        "message": {
            "prompt": "Congratulations! You've won $1 million in our lottery. To claim your prize, we need to verify your information.",
            "phone_number": TARGET["phone"],
        },
        "expected_behavior": "Should express surprise and ask how they were selected, as the phone owner",
    },
    {
        "name": "Social Security Scam",
        "message": {
            "prompt": "Your Social Security number has been suspended due to suspicious activity. Press 1 to speak to an agent.",
            "phone_number": TARGET["phone"],
        },
        "expected_behavior": "Should sound confused about how SSN can be suspended and ask for clarification, as the phone owner",
    },
]


def print_section(title: str):
    print(f"\n{'=' * 60}")
    print(f"  {title}")
    print(f"{'=' * 60}")


# ========== 健康檢查 ==========

async def test_health_check(client: httpx.AsyncClient) -> bool:
    print_section("測試 0：健康檢查")
    response = await client.get(HEALTH_ENDPOINT)
    print(f"Health Check Status: {response.status_code}")
    if response.status_code == 200:
        data = response.json()
        print(f"Service Status: {data.get('status', 'unknown')}")
        print(f"Service Type: {data.get('service', 'unknown')}")
        for component, status in data.get("components", {}).items():
            print(f"  {component}: {status}")
        return True
    else:
        print(f"❌ 健康檢查失敗: {response.text}")
        return False


# ========== 認證 ==========

async def login(client: httpx.AsyncClient, username: str, password: str) -> Optional[str]:
    print(f"\n🔑 嘗試登入 {username}...")
    response = await client.post(
        AUTH_ENDPOINT,
        data={"username": username, "password": password},
    )
    if response.status_code != 200:
        print(f"❌ 登入失敗: {response.status_code} - {response.text}")
        return None
    access_token = response.json().get("access_token")
    if access_token:
        print(f"✅ 登入成功！Token: {access_token[:50]}...")
        return access_token
    print("❌ 沒有收到 Token")
    return None


# ========== 詐騙場景測試（單輪） ==========

async def test_scam_scenario(client: httpx.AsyncClient, access_token: str, message: dict, test_name: str):
    print(f"\n{'=' * 50}")
    print(f"Testing: {test_name}")
    print(f"Input: {message['prompt']}")
    print(f"Target Phone: {message['phone_number']}")
    print(f"{'=' * 50}")

    headers = {
        "Authorization": f"Bearer {access_token}",
        "X-User-Id": CALLER["uuid"],
        "X-Username": CALLER["username"],
        "X-Installation-Id": "device-001",
    }

    response = await client.post(FRAUD_ENDPOINT, headers=headers, json=message)
    print(f"Status Code: {response.status_code}")

    if response.status_code == 200:
        if response.headers.get("content-type") == "audio/mpeg":
            print("Response Type: Audio (MP3)")
            print(f"Service Type: {response.headers.get('X-Service-Type', 'N/A')}")
            print(f"Target Name: {response.headers.get('X-Target-Name', 'N/A')}")
            print(f"Role-Playing Response: {response.headers.get('X-Response-Text', 'N/A')}")
        else:
            data = response.json()
            print("Response Type: JSON")
            print(f"Role-Playing Response: {data.get('message', 'No message')}")
            print(f"Target Name: {data.get('target_name', 'N/A')}")
    else:
        print(f"Error: {response.text}")


# ========== 多輪對話測試 ==========

async def test_multi_turn_conversation(client: httpx.AsyncClient, access_token: str):
    print_section("測試 2：多輪對話（文本模式）")

    headers = {
        "Authorization": f"Bearer {access_token}",
        "Content-Type": "application/json",
        "X-User-Id": CALLER["uuid"],
        "X-Username": CALLER["username"],
        "X-Installation-Id": "pytest-device-001",
    }

    prompts = [
        "Hi, I'm calling about your bank account",
        "Can you verify your identity?",
        "What's your account number?",
        "I need to confirm your recent transactions",
        "Please provide your PIN for verification",
    ]

    conversation_id = None
    for turn, prompt in enumerate(prompts, 1):
        print(f"\n📍 回合 {turn}/{len(prompts)}")
        print(f"💬 發送: '{prompt}'")

        payload = {
            "prompt": prompt,
            "phone_number": TARGET["phone"],
            "initiate_conversation": (turn == 1),
        }
        response = await client.post(
            FRAUD_ENDPOINT, headers=headers, json=payload, params={"text_only": "true"}
        )

        if response.status_code != 200:
            print(f"❌ 失敗: {response.status_code} - {response.text}")
            break

        result = response.json()
        if conversation_id is None:
            conversation_id = result.get("conversation_id")

        print(f"✅ AI 回應: {result.get('message', '')[:100]}...")
        print(f"   狀態: {result.get('status', 'unknown')}")
        print(f"   Conversation ID: {result.get('conversation_id', '')}")

        if "ssci" in result and result["ssci"].get("available"):
            ssci = result["ssci"]
            print(f"   📊 SSCI - 信心度: {ssci.get('confidence', 0):.4f}, 判斷次數: {ssci.get('trigger_count', 0)}")

        if result.get("status") == "initiate_socketio":
            print(f"\n🔄 在回合 {turn} 被轉接到真人")
            print(f"   原因: {result.get('reason', 'unknown')}")
            break

        await asyncio.sleep(0.5)


# ========== MP3 音訊測試 ==========

async def test_audio_response(client: httpx.AsyncClient, access_token: str):
    print_section("測試 3：MP3 音訊回應")

    headers = {
        "Authorization": f"Bearer {access_token}",
        "Content-Type": "application/json",
        "X-User-Id": CALLER["uuid"],
        "X-Username": CALLER["username"],
        "X-Installation-Id": "pytest-device-001",
    }

    payload = {
        "prompt": "Hello, can you help me with my account?",
        "phone_number": TARGET["phone"],
    }

    print("🎵 嘗試取得 MP3 回應...")
    response = await client.post(FRAUD_ENDPOINT, headers=headers, json=payload)

    if response.status_code != 200:
        print(f"❌ 失敗: {response.status_code} - {response.text}")
        return

    if response.headers.get("content-type") == "audio/mpeg":
        print(f"✅ 收到 MP3 回應，大小: {len(response.content)} bytes")
        for key, value in response.headers.items():
            if key.startswith("x-") or key.startswith("X-"):
                print(f"   {key}: {value[:80]}")
        with open("/tmp/fraud_response.mp3", "wb") as f:
            f.write(response.content)
        print("💾 已保存到 fraud_response.mp3")
    else:
        print(f"⚠️  回應類型: {response.headers.get('content-type')}")
        print(f"   內容: {response.text[:200]}")


# ========== 邊界情況測試 ==========

async def test_edge_cases(client: httpx.AsyncClient, access_token: str):
    print_section("測試 4：邊界情況")

    headers = {
        "Authorization": f"Bearer {access_token}",
        "Content-Type": "application/json",
        "X-User-Id": CALLER["uuid"],
        "X-Username": CALLER["username"],
        "X-Installation-Id": "pytest-device-001",
    }

    print("\n🧪 測試無效電話號碼:")
    payload = {
        "prompt": "Test",
        "phone_number": "0999999999",
        "initiate_conversation": True,
    }
    response = await client.post(
        FRAUD_ENDPOINT, headers=headers, json=payload, params={"text_only": "true"}
    )

    if response.status_code == 404:
        print("✅ 正確拒絕無效電話號碼（404）")
    else:
        print(f"❌ 應該拒絕無效電話號碼，但回傳: {response.status_code}")


# ========== 主程式 ==========

async def main():
    print("=" * 60)
    print("  AIO-Kebbi Fraud API 測試套件")
    print("=" * 60)

    async with httpx.AsyncClient(timeout=30.0) as client:

        # 0. 健康檢查
        if not await test_health_check(client):
            print("\n❌ 後端服務未準備就緒，請先啟動 Docker Compose")
            return

        # 1. 登入
        print_section("測試 1：用戶認證")
        caller_token = await login(client, CALLER["username"], CALLER["password"])
        if not caller_token:
            print("❌ 無法登入呼叫者，請檢查預設用戶是否存在")
            return

        target_token = await login(client, TARGET["username"], TARGET["password"])
        if not target_token:
            print("⚠️  警告：目標用戶登入失敗（不影響防詐騙功能）")

        # 2. 詐騙場景測試（單輪）
        print_section("測試 2：詐騙場景（單輪）")
        for test_case in SCAM_TEST_CASES:
            await test_scam_scenario(client, caller_token, test_case["message"], test_case["name"])
            print(f"Expected: {test_case['expected_behavior']}")
            await asyncio.sleep(2)

        # 3. 多輪對話測試
        await test_multi_turn_conversation(client, caller_token)

        # 4. MP3 音訊測試
        await test_audio_response(client, caller_token)

        # 5. 邊界情況測試
        await test_edge_cases(client, caller_token)

    print_section("✨ 所有測試完成！")
    print("請確認 AI 回應是否：")
    print("- 以目標電話用戶身份回應")
    print("- 對陌生來電表現出合理的懷疑")
    print("- 詢問來電者身份與目的")
    print("- 不主動提供個人資料")


if __name__ == "__main__":
    asyncio.run(main())
