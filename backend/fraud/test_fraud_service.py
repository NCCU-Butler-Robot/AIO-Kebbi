#!/usr/bin/env python3
"""
Anti-Fraud Service Test Script
Test the /api/fraud/ endpoint with sample scammer messages
"""

import asyncio
import httpx
import json
from typing import Dict, Any

BASE_URL = "http://localhost:8000"
HEADERS = {
    "X-User-Id": "test-user-001",
    "X-Username": "test-user",
    "X-Installation-Id": "device-001",
    "Content-Type": "application/json"
}

# Test cases simulating different scam scenarios
TEST_CASES = [
    {
        "name": "Bank Scam Opening",
        "message": {
            "prompt": "Hello, this is customer service from your bank. We've detected some suspicious activity on your account.",
            "phone_number": "0987654325"
        },
        "expected_behavior": "Should ask for clarification about which bank and what kind of activity, acting as the phone owner"
    },
    {
        "name": "Tech Support Scam",
        "message": {
            "prompt": "This is Microsoft technical support. Your computer is infected with viruses and we need remote access to fix it.",
            "phone_number": "0987654325"
        },
        "expected_behavior": "Should appear confused about technical terms and ask for more details, as the phone owner"
    },
    {
        "name": "IRS/Tax Scam",
        "message": {
            "prompt": "This is the Internal Revenue Service. You owe back taxes and must pay immediately or face arrest.",
            "phone_number": "0987654325"
        },
        "expected_behavior": "Should sound worried but ask for verification and specifics, as the phone owner"
    },
    {
        "name": "Lottery Scam",
        "message": {
            "prompt": "Congratulations! You've won $1 million in our lottery. To claim your prize, we need to verify your information.",
            "phone_number": "0987654325"
        },
        "expected_behavior": "Should express surprise and ask how they were selected, as the phone owner"
    },
    {
        "name": "Social Security Scam",
        "message": {
            "prompt": "Your Social Security number has been suspended due to suspicious activity. Press 1 to speak to an agent.",
            "phone_number": "0987654325"
        },
        "expected_behavior": "Should sound confused about how SSN can be suspended and ask for clarification, as the phone owner"
    }
]

async def test_fraud_endpoint(message: dict, test_name: str):
    """Test the fraud detection endpoint"""
    print(f"\n{'='*50}")
    print(f"Testing: {test_name}")
    print(f"Input: {message['prompt']}")
    print(f"Target Phone: {message['phone_number']}")
    print(f"{'='*50}")
    
    try:
        async with httpx.AsyncClient(timeout=30.0) as client:
            response = await client.post(
                f"{BASE_URL}/api/fraud/",
                headers=HEADERS,
                json=message
            )
            
            print(f"Status Code: {response.status_code}")
            
            if response.status_code == 200:
                # Check if response is audio (MP3) or JSON
                if response.headers.get("content-type") == "audio/mpeg":
                    response_text = response.headers.get("X-Response-Text", "No text in headers")
                    message_id = response.headers.get("X-Message-Id", "No message ID")
                    conversation_id = response.headers.get("X-Conversation-Id", "No conversation ID")
                    service_type = response.headers.get("X-Service-Type", "No service type")
                    target_name = response.headers.get("X-Target-Name", "No target name")
                    target_phone = response.headers.get("X-Target-Phone", "No target phone")
                    
                    print(f"Response Type: Audio (MP3)")
                    print(f"Service Type: {service_type}")
                    print(f"Target Name: {target_name}")
                    print(f"Target Phone: {target_phone}")
                    print(f"Message ID: {message_id}")
                    print(f"Conversation ID: {conversation_id}")
                    print(f"Role-Playing Response: {response_text}")
                else:
                    # JSON response
                    data = response.json()
                    print(f"Response Type: JSON")
                    print(f"Role-Playing Response: {data.get('message', 'No message')}")
                    print(f"Target Name: {data.get('target_name', 'No target name')}")
                    print(f"Target Phone: {data.get('target_phone', 'No target phone')}")
                    if 'error' in data:
                        print(f"Error: {data['error']}")
            else:
                print(f"Error: {response.text}")
                
    except Exception as e:
        print(f"Request failed: {e}")

async def test_health_check():
    """Test the health check endpoint"""
    print("Testing Health Check Endpoint...")
    try:
        async with httpx.AsyncClient() as client:
            response = await client.get(f"{BASE_URL}/health")
            print(f"Health Check Status: {response.status_code}")
            if response.status_code == 200:
                data = response.json()
                print(f"Service Status: {data.get('status', 'unknown')}")
                print(f"Service Type: {data.get('service', 'unknown')}")
                components = data.get('components', {})
                for component, status in components.items():
                    print(f"  {component}: {status}")
            else:
                print(f"Health check failed: {response.text}")
    except Exception as e:
        print(f"Health check failed: {e}")

async def main():
    """Run all tests"""
    print("Anti-Fraud Service Test Suite")
    print("============================")
    
    # Test health check first
    await test_health_check()
    
    # Test each fraud scenario
    for test_case in TEST_CASES:
        await test_fraud_endpoint(test_case["message"], test_case["name"])
        print(f"\nExpected Behavior: {test_case['expected_behavior']}")
        
        # Wait between tests
        await asyncio.sleep(2)
    
    print(f"\n{'='*50}")
    print("All tests completed!")
    print("Check the responses to ensure the AI is:")
    print("- Role-playing as the specific phone owner (name from database)")
    print("- Acting naturally suspicious of unsolicited calls")
    print("- Asking clarifying questions about the caller's identity")
    print("- Not immediately providing personal information")
    print("- Expressing confusion about unexpected calls")
    print("- Asking how the caller got their number")

if __name__ == "__main__":
    asyncio.run(main())