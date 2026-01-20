import asyncio
import json
import os
from contextlib import asynccontextmanager
from copy import deepcopy

import firebase_admin
from fastapi import FastAPI, Header, HTTPException
from firebase_admin import messaging
from pydantic import BaseModel
from pywebpush import WebPushException, webpush

# from apns2.client import APNsClient
# from apns2.payload import Payload
from .db_manager.database import (
    close_db_connection,
    connect_to_db,
    delete_subscription,
    get_all_subscriptions,
    get_subscriptions_by_user,
    save_subscription,
)

# VAPID keys - should be set in environment
VAPID_PRIVATE_KEY = os.getenv("VAPID_PRIVATE_KEY")
VAPID_CLAIMS = {
    "sub": "mailto:" + os.getenv("VAPID_EMAIL", "test@example.com"),
}

# Firebase initialization
firebase_app = None
if os.getenv("FIREBASE_CREDENTIALS_PATH"):
    firebase_app = firebase_admin.initialize_app(
        firebase_admin.credentials.Certificate(os.getenv("FIREBASE_CREDENTIALS_PATH"))
    )
    print("[INFO] Firebase app initialized successfully.")

# APNs initialization
# apns_client = None
# if os.getenv("APNS_AUTH_KEY_PATH") and os.getenv("APNS_KEY_ID") and os.getenv("APNS_TEAM_ID"):
#     apns_client = APNsClient(
#         credentials=os.getenv("APNS_AUTH_KEY_PATH"),
#         key_id=os.getenv("APNS_KEY_ID"),
#         team_id=os.getenv("APNS_TEAM_ID"),
#         use_sandbox=bool(os.getenv("APNS_USE_SANDBOX", "false").lower() == "true")
#     )


class PushSubscriptionKeys(BaseModel):
    p256dh: str
    auth: str


class PushSubscription(BaseModel):
    endpoint: str
    keys: PushSubscriptionKeys | None = None
    expirationTime: int | None = None


class SubscribeRequest(BaseModel):
    # user_id: str | None = None
    pushSubscription: PushSubscription | None = None
    fcm_token: str | None = None
    apns_token: str | None = None
    platform: str # "web", "fcm", "apns"


class NotificationPayload(BaseModel):
    title: str
    body: str
    icon: str | None = None
    tag: str | None = None
    data: dict | None = None


@asynccontextmanager
async def lifespan(app: FastAPI):
    await connect_to_db()
    yield
    await close_db_connection()


app = FastAPI(lifespan=lifespan)


@app.post("/api/push/subscribe")
async def subscribe(
    subscription: SubscribeRequest,
    x_user_id: str | None = Header(None, alias="X-User-Id"),
    x_username: str | None = Header(None, alias="X-Username"),
    x_installation_id: str | None = Header(None, alias="X-Installation-Id"),
):
    """Save or update a push subscription in the database."""
    print("Subscription request: ", subscription)
    try:
        if not x_user_id:
            raise HTTPException(
                status_code=400, detail="X-User-Id header is required."
            )
        user_id = x_user_id
        platform = subscription.platform
        if subscription.pushSubscription:
            push_sub = subscription.pushSubscription.model_dump()
            await save_subscription(user_id, push_sub, platform)
        elif subscription.fcm_token:
            # For FCM, create a dict with endpoint as token, no keys
            push_sub = {"endpoint": subscription.fcm_token}
            await save_subscription(user_id, push_sub, "fcm")
        elif subscription.apns_token:
            # For APNs, create a dict with endpoint as token, no keys
            push_sub = {"endpoint": subscription.apns_token}
            await save_subscription(user_id, push_sub, "apns")
        else:
            raise HTTPException(
                status_code=400,
                detail="Either pushSubscription, fcm_token, or apns_token must be provided",
            )

        return {"message": "Subscription saved!", "user_id": user_id}

    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/notify")
async def notify_all(payload: NotificationPayload):
    """Send a push notification to all users. Payload example: { "title": "System Alert", "body": "New update available.", "icon": "/static/icons/alert.png", "tag": "web-push", "data": { "url": "/updates" } }"""
    print(payload)
    payload_dict = payload.model_dump()  # convert to dict
    results = await get_all_subscriptions()

    if not results:
        print("WARNING: No subscriptions found. Notification not sent.")
        return {"sent": 0, "failed": 0}

    success, failed = 0, 0
    for row in results:
        if await send_push(row, payload_dict):
            success += 1
        else:
            failed += 1


@app.post("/notify/user/{user_id}")
async def notify_user(user_id: str, payload: NotificationPayload):
    """Send a push notification to a specific user."""
    print(f"Notifying user {user_id}: {payload}")
    payload_dict = payload.model_dump()
    results = await get_subscriptions_by_user(user_id)

    if not results:
        print(
            f"WARNING: No subscriptions found for user {user_id}. Notification not sent."
        )
        return {"sent": 0, "failed": 0}

    success, failed = 0, 0
    for row in results:
        if await send_push(row, payload_dict):
            success += 1
        else:
            failed += 1

    return {"sent": success, "failed": failed}


async def send_push_to_user(user_id: str, payload: dict):
    """Send push notifications to all subscriptions of a specific user."""
    results = await get_subscriptions_by_user(user_id)
    if not results:
        print(f"WARNING: No subscriptions found for user {user_id}.")
        return 0, 0  # sent, failed

    success, failed = 0, 0
    for row in results:
        if await send_push(row, payload):
            success += 1
        else:
            failed += 1
    return success, failed


async def send_push(subscription, payload):
    print("Sending push: ", subscription)
    endpoint = subscription["endpoint"]
    platform = subscription.get("platform", "web")
    if platform == "web":
        # Web Push
        try:
            await asyncio.to_thread(
                webpush,
                subscription_info={
                    "endpoint": endpoint,
                    "keys": {
                        "p256dh": subscription["p256dh"],
                        "auth": subscription["auth"],
                    },
                },
                data=json.dumps(payload),
                vapid_private_key=VAPID_PRIVATE_KEY,
                vapid_claims=deepcopy(VAPID_CLAIMS),
            )
            return True
        except WebPushException as ex:
            # Check if subscription is gone or unsubscribed
            print("ERROR", ex, type(ex))
            print("response", ex.response)
            print("status code", ex.response.status_code, type(ex.response.status_code))
            if ex.response is not None and ex.response.status_code == 410:
                print("Subscription is gone")
                # Remove subscription from database
                await delete_subscription(endpoint, platform)
                print(f"Removed expired subscription: {endpoint}")
            else:
                print(f"Push failed for {endpoint}: {ex}")
            return False
    elif platform == "fcm":
        # FCM Token
        if not firebase_app:
            print("Firebase not initialized")
            return False
        try:
            message = messaging.Message(
                notification=messaging.Notification(
                    title=payload.get("title", ""), body=payload.get("body", "")
                ),
                token=endpoint,
                data={k: str(v) for k, v in (payload.get("data") or {}).items()},
            )
            response = await asyncio.to_thread(messaging.send, message)
            print(f"Successfully sent FCM message: {response}")
            return True
        except Exception as ex:
            print(f"FCM push failed for {endpoint}: {ex}")
            # For FCM, if invalid token, perhaps remove, but FCM has specific errors
            if "registration-token-not-registered" in str(ex):
                print("FCM token invalid, removing")
                await delete_subscription(endpoint, platform)
            return False
    elif platform == "apns":
        # APNs Token
        # if not apns_client:
        #     print("APNs not initialized")
        #     return False
        # try:
        #     payload = Payload(
        #         alert={"title": payload.get("title", ""), "body": payload.get("body", "")},
        #         sound="default",
        #         badge=1,
        #         custom=payload.get("data", {})
        #     )
        #     response = await asyncio.to_thread(apns_client.send_notification, endpoint, payload)
        #     print(f"Successfully sent APNs message: {response}")
        #     return True
        # except Exception as ex:
        #     print(f"APNs push failed for {endpoint}: {ex}")
        #     # Handle invalid tokens, etc.
        #     return False
        print("APNs push not implemented.")
        return False
    else:
        print(f"Unknown platform {platform}")
        return False


if __name__ == "__main__":
    import uvicorn

    uvicorn.run(app, host="0.0.0.0", port=8000)
