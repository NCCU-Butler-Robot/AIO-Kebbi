# AIO-Kebbi API Specification

This document describes all API endpoints for the AIO-Kebbi anti-fraud and elder care system.

## Base URL

| Environment | URL |
|------------|-----|
| Development | `http://localhost:8100` |
| Production | `https://your-domain.com` |

---

## Authentication

All `/api/*` endpoints require JWT authentication.

### How Authentication Works

1. Client sends `Authorization: Bearer <access_token>` header
2. Nginx validates token via `/auth/validate` endpoint (internal)
3. Nginx injects `X-User-Id` and `X-Username` headers for backend services
4. Backend services trust these headers (no re-validation needed)

---

## Error Responses

All endpoints may return error responses in the following format:

| Status Code | Description |
|-------------|-------------|
| 400 | Bad Request - Invalid input |
| 401 | Unauthorized - Invalid or missing token |
| 403 | Forbidden - Access denied |
| 404 | Not Found |
| 422 | Validation Error |
| 500 | Internal Server Error |

### Error Format

```json
{
  "detail": "error message"
}
```

For validation errors:
```json
{
  "detail": [
    {
      "loc": ["body", "field_name"],
      "msg": "error description",
      "type": "value_error"
    }
  ]
}
```

---

## Authentication Endpoints

### POST /auth/register

Register a new user.

| Item | Details |
|------|---------|
| **Method** | POST |
| **Path** | `/auth/register` |
| **Auth Required** | No |
| **Content-Type** | `application/json` |

#### Request Body

```json
{
  "username": "string",
  "email": "string",
  "phone_number": "string",
  "name": "string",
  "password": "string"
}
```

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `username` | string | Yes | Unique username |
| `email` | string | Yes | User email |
| `phone_number` | string | Yes | Phone number |
| `name` | string | Yes | Display name |
| `password` | string | Yes | Password (will be hashed) |

#### Response

**Success (200)**:
```json
{
  "username": "string",
  "email": "string",
  "phone_number": "string",
  "name": "string",
  "uuid": "uuid-string"
}
```

**Error (422)**: Validation error

---

### POST /auth/login

Authenticate user and obtain access token.

| Item | Details |
|------|---------|
| **Method** | POST |
| **Path** | `/auth/login` |
| **Auth Required** | No |
| **Content-Type** | `application/x-www-form-urlencoded` |

#### Request Body (Form Data)

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `username` | string | Yes | Username |
| `password` | string | Yes | Password |

#### Response

**Success (200)**:
```json
{
  "access_token": "eyJhbGc...",
  "token_type": "bearer"
}
```

**Cookie Set**: `refresh_token` (HTTP-only, secure, 7 days)

**Error (401)**: `{"detail": "Incorrect username or password"}`

---

### POST /auth/refresh_token

Refresh expired access token using refresh cookie.

| Item | Details |
|------|---------|
| **Method** | POST |
| **Path** | `/auth/refresh_token` |
| **Auth Required** | No (uses cookie) |

#### Request

Automatically uses `refresh_token` HTTP-only cookie set during login.

#### Response

**Success (200)**:
```json
{
  "access_token": "eyJhbGc...",
  "token_type": "bearer"
}
```

**Actions**:
- Revokes old refresh token
- Issues new refresh token (cookie rotated)
- Returns new access token

---

### POST /auth/logout

Logout user and revoke refresh token.

| Item | Details |
|------|---------|
| **Method** | POST |
| **Path** | `/auth/logout` |
| **Auth Required** | No (uses cookie) |

#### Response

**Success (200)**:
```json
{
  "message": "Successfully logged out"
}
```

**Actions**:
- Revokes current refresh token in database
- Clears `refresh_token` cookie

---

### GET /auth/status

Get current authenticated user information.

| Item | Details |
|------|---------|
| **Method** | GET |
| **Path** | `/auth/status` |
| **Auth Required** | Yes |

#### Headers

```
Authorization: Bearer <access_token>
```

#### Response

**Success (200)**:
```json
{
  "username": "string",
  "email": "string",
  "phone_number": "string",
  "name": "string",
  "uuid": "uuid-string"
}
```

---

### GET /auth/validate (Internal)

Validate JWT token. Used by Nginx for request authentication.

| Item | Details |
|------|---------|
| **Method** | GET |
| **Path** | `/auth/validate` |
| **Auth Required** | Yes (Bearer token) |

#### Headers

```
Authorization: Bearer <access_token>
```

#### Response

Returns `200 OK` with these headers:

| Header | Description |
|--------|-------------|
| `X-User-Id` | User UUID |
| `X-Username` | Username |

**Note**: This endpoint is for internal use only. External access is blocked by Nginx (returns 403).

---

## Chat Endpoints

### POST /api/chat/

Butler AI chat endpoint with TTS audio response.

| Item | Details |
|------|---------|
| **Method** | POST |
| **Path** | `/api/chat/` |
| **Auth Required** | Yes |
| **Content-Type** | `application/json` |

#### Headers

```
Authorization: Bearer <access_token>
X-User-Id: <uuid> (injected by Nginx)
X-Username: <string> (injected by Nginx)
X-Installation-Id: <uuid> (optional)
```

#### Query Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `text_only` | string | No | Set to `true` to return JSON instead of audio |
| `initiate_conversation` | bool | No | Set to `true` to start new conversation |

#### Request Body

```json
{
  "prompt": "Hello, how are you?",
  "initiate_conversation": false
}
```

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `prompt` | string | Yes | User message |
| `initiate_conversation` | boolean | No | Start new conversation if true |

#### Response (Audio - Default)

**Content-Type**: `audio/mpeg`

**Response Headers**:

| Header | Description | Example |
|--------|-------------|---------|
| `X-Response-Text` | URL-encoded AI response text | `Hello%21%20I%27m%20doing%20great...` |
| `X-Message-Id` | Message UUID | `abc123-def456-...` |
| `X-Conversation-Id` | Conversation UUID | `conv789-ghi012-...` |
| `X-Recipient-User-Id` | User UUID | `user123-abc-...` |
| `X-Source-Installation-Id` | Installation UUID | `inst456-def-...` |
| `Content-Disposition` | File download header | `attachment; filename=response.mp3` |

**Body**: MP3 audio stream

#### Response (JSON - text_only=true)

**Content-Type**: `application/json`

```json
{
  "message": "Hello! I'm doing great, thank you for asking!",
  "message_id": "abc123-def456-...",
  "conversation_id": "conv789-ghi012-...",
  "recipient_user_id": "user123-abc-...",
  "source_installation_id": "inst456-def-..."
}
```

#### Error Response

When `text_only=true` or on error:
```json
{
  "detail": "error message"
}
```

---

## Fraud Endpoints

### POST /api/fraud/

Anti-fraud AI call endpoint with voice interaction.

| Item | Details |
|------|---------|
| **Method** | POST |
| **Path** | `/api/fraud/` |
| **Auth Required** | Yes |
| **Content-Type** | `application/json` |

#### Headers

```
Authorization: Bearer <access_token>
X-User-Id: <uuid> (injected by Nginx)
X-Username: <string> (injected by Nginx)
X-Installation-Id: <uuid> (optional)
```

#### Query Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `text_only` | string | No | Set to `true` to return JSON instead of audio |
| `initiate_conversation` | bool | No | Set to `true` to start new call |

#### Request Body

```json
{
  "prompt": "Hello, this is the bank",
  "phone_number": "0912345678",
  "initiate_conversation": false
}
```

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `prompt` | string | Yes | Initial message to AI |
| `phone_number` | string | Yes | Target phone number to call |
| `initiate_conversation` | boolean | No | Start new call if true |

#### Response (Audio - Default)

**Content-Type**: `audio/mpeg`

**Response Headers**:

| Header | Description | Example |
|--------|-------------|---------|
| `X-Response-Text` | URL-encoded AI response text | `Hello%20this%20is%20the%20bank...` |
| `X-Message-Id` | Message UUID | `msg123-abc-...` |
| `X-Conversation-Id` | Conversation UUID | `call456-def-...` |
| `X-Recipient-User-Id` | User UUID | `user123-abc-...` |
| `X-Source-Installation-Id` | Installation UUID | `inst789-ghi-...` |
| `X-Service-Type` | Service identifier | `anti-fraud` |
| `X-Target-Name` | Target user name | `John Doe` |
| `X-Target-Phone` | Target phone number | `0912345678` |
| `Content-Disposition` | File download header | `attachment; filename=John_Doe_response.mp3` |

**SSCI Headers** (included when SSCI is available):

| Header | Type | Description |
|--------|------|-------------|
| `X-SSCI-Available` | boolean | Whether SSCI analysis is available |
| `X-SSCI-Updated` | boolean | Whether SSCI was updated |
| `X-SSCI-Trigger-Count` | integer | Number of triggers activated |
| `X-SSCI-Raw-Inference-Count` | integer | Number of inferences made |
| `X-SSCI-Confidence` | float | SSCI confidence score (0.0-1.0) |
| `X-SSCI-Evidence` | float | Evidence score (0.0-1.0) |
| `X-SSCI-Agreement` | float | Agreement score (0.0-1.0) |
| `X-SSCI-Stability` | float | Stability score (0.0-1.0) |
| `X-SSCI-Nk` | integer | Number of samples |
| `X-SSCI-Latest-Decision` | boolean | Latest trigger decision |
| `X-SSCI-Decision-Label` | string | Decision label: `scam`, `normal`, or `unknown` |
| `X-SSCI-Scam-Probability` | float | Scam probability (0.0-1.0) |

**Body**: MP3 audio stream

#### Response (JSON - text_only=true)

**Content-Type**: `application/json`

```json
{
  "status": "initiate_socketio",
  "call_token": "token-string",
  "reason": "normal_conversation_detected"
}
```

Or on error:
```json
{
  "status": "error",
  "message": "error description"
}
```

---

## Food Recognition Endpoints

### POST /api/food-recognition/

Recognize food from image and provide recipe suggestions.

| Item | Details |
|------|---------|
| **Method** | POST |
| **Path** | `/api/food-recognition/` |
| **Auth Required** | Yes |
| **Content-Type** | `multipart/form-data` |

#### Headers

```
Authorization: Bearer <access_token>
X-User-Id: <uuid> (injected by Nginx)
```

#### Request Body

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `file` | binary | Yes | Image file (JPEG, PNG, max 50MB) |

#### Response

**Success (200)**:
```json
{
  "predictions": [
    {
      "class": "pizza",
      "confidence": 0.95
    },
    {
      "class": "burger",
      "confidence": 0.03
    }
  ],
  "recipe": "https://example.com/recipe/pizza"
}
```

| Field | Type | Description |
|-------|------|-------------|
| `predictions` | array | List of predictions with class name and confidence |
| `predictions[].class` | string | Food class name |
| `predictions[].confidence` | float | Confidence score (0.0-1.0) |
| `recipe` | string | Optional URL to recipe (if available) |

**Error (400)**:
```json
{
  "detail": "No image file provided"
}
```

---

## Push Notification Endpoints

### POST /api/push/subscribe/

Subscribe to push notifications (FCM or Web Push).

| Item | Details |
|------|---------|
| **Method** | POST |
| **Path** | `/api/push/subscribe/` |
| **Auth Required** | Yes |
| **Content-Type** | `application/json` |

#### Headers

```
Authorization: Bearer <access_token>
X-User-Id: <uuid> (injected by Nginx)
```

#### Request Body (FCM)

```json
{
  "fcm_token": "fcm-token-string",
  "platform": "fcm"
}
```

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `fcm_token` | string | Yes | Firebase Cloud Messaging token |
| `platform` | string | Yes | Must be `fcm` |

#### Request Body (Web Push)

```json
{
  "pushSubscription": {
    "endpoint": "https://fcm.googleapis.com/fcm/send/...",
    "keys": {
      "p256dh": "base64-encoded-key",
      "auth": "base64-encoded-key"
    }
  },
  "platform": "web"
}
```

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `pushSubscription.endpoint` | string | Yes | Push subscription endpoint URL |
| `pushSubscription.keys.p256dh` | string | Yes | P-256 DH key |
| `pushSubscription.keys.auth` | string | Yes | Auth key |
| `platform` | string | Yes | Must be `web` |

#### Response

**Success (200)**:
```json
{
  "message": "Subscription saved!",
  "user_id": "uuid-string"
}
```

---

### GET /api/push/vapid_public_key

Get VAPID public key for Web Push subscription.

| Item | Details |
|------|---------|
| **Method** | GET |
| **Path** | `/api/push/vapid_public_key` |
| **Auth Required** | Yes |

#### Headers

```
Authorization: Bearer <access_token>
```

#### Response

**Success (200)**:
```json
{
  "public_key": "BE9tBod9puuOivpChDptMLxVfNNC9WrC8kZUlcdoyfghVaL9ty5eQgpq8z+OMQJDwLStKX+cUDWZg2RfKEDuT9w="
}
```

---

### POST /notify

Send push notification to all subscribed users.

| Item | Details |
|------|---------|
| **Method** | POST |
| **Path** | `/notify` |
| **Auth Required** | No |

#### Request Body

```json
{
  "title": "System Alert",
  "body": "New update available",
  "icon": "/static/icons/alert.png",
  "tag": "web-push",
  "data": {
    "url": "/updates"
  },
  "silent": false
}
```

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `title` | string | No | Notification title |
| `body` | string | No | Notification body |
| `icon` | string | No | Icon URL |
| `tag` | string | No | Notification tag |
| `data` | object | No | Custom data payload |
| `silent` | boolean | No | Send silent notification |

#### Response

**Success (200)**:
```json
{
  "sent": 5,
  "failed": 2
}
```

| Field | Type | Description |
|-------|------|-------------|
| `sent` | integer | Number of notifications sent |
| `failed` | integer | Number of notifications failed |

**Note**: Invalid subscriptions are automatically removed from the database.

---

### POST /notify/user/{user_id}

Send push notification to specific user.

| Item | Details |
|------|---------|
| **Method** | POST |
| **Path** | `/notify/user/{user_id}` |
| **Auth Required** | No |

#### Path Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `user_id` | string | Target user UUID |

#### Request Body

Same as `/notify` endpoint.

#### Response

**Success (200)**:
```json
{
  "sent": 1,
  "failed": 0
}
```

**Warning**: Returns `sent: 0, failed: 0` if user has no subscriptions.

---

## WebSocket (Socket.IO)

### Connection

| Item | Details |
|------|---------|
| **Path** | `/socket.io/` |
| **Protocol** | WebSocket (Socket.IO) |

#### Authentication

Pass access token during connection:
```javascript
const socket = io('http://localhost:8100', {
  auth: {
    access_token: 'eyJhbGc...'
  }
});
```

#### Events

| Event | Direction | Description |
|-------|-----------|-------------|
| `connect` | - | Connection established |
| `disconnect` | - | Connection closed |
| `text_message` | Server → Client | Text message broadcast |
| `audio_data` | Server → Client | Audio data chunk |
| `call_state` | Server → Client | Call state update |

---

## Notes

1. **Nginx Behavior**: All `/api/*` endpoints are validated by Nginx before reaching backend services. Invalid tokens return 401.

2. **Audio Responses**: Chat and Fraud endpoints return MP3 audio by default. Use `text_only=true` query parameter to get JSON response.

3. **Response Headers**: When receiving audio responses, the text content is available in response headers (`X-Response-Text`). Remember to URL-decode the value.

4. **Token Refresh**: Use `/auth/refresh_token` with the refresh cookie to get new access token. The old refresh token is automatically revoked (token rotation).

5. **Push Notifications**: 
   - FCM tokens: Used for Android/iOS push notifications
   - Web Push: Uses VAPID keys, requires service worker on client
   - Invalid subscriptions are automatically removed on send failure

6. **SSCI (Spam/Scam Confidence Index)**: Fraud endpoint includes SSCI headers providing real-time scam probability analysis during calls.

---

## Appendix: Postman Collection

A Postman collection with all endpoints is available at:
`backend/apis.postman_collection.json`

Import this file into Postman to test all endpoints.
