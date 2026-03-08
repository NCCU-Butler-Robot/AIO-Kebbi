# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

AIO-Kebbi is an anti-fraud protection system with two main components:
- **Backend**: Python microservices orchestrated via Docker Compose
- **Frontend**: Flutter mobile app targeting Android/iOS/Web

## Backend

### Running the Stack

```bash
cd backend

# Production
docker compose up --build

# Development (with hot-reload volumes)
docker compose -f docker-compose.dev.yml up --build
```

All services are exposed through Nginx on **port 8100**.

### Services

| Service | Port (internal) | Description |
|---|---|---|
| `auth` | 8000 | FastAPI JWT auth service (PostgreSQL-backed) |
| `chat` | 8000 | FastAPI AI chat + food recognition + TTS (OpenAI) |
| `fraud` | 8000 | FastAPI GPT-4 anti-fraud voice assistant |
| `socket_gateway` | 5000 | WebSocket gateway (Redis pub/sub) |
| `push_notification` | 8000 | FCM push notifications |
| `www` | 8000 | FastAPI web interface (Jinja2/Bootstrap 5) |
| `nginx` | **8100** | Reverse proxy / router |
| `redis` | 6379 | Pub/sub for socket_gateway |
| `db` | 5432 | PostgreSQL 18 |

### Nginx Routing

- `/` → `www` (public)
- `/auth/*` → `auth` (public)
- `/api/*` → JWT-validated via `auth/validate`, then routed:
  - `/api/chat/` → `chat`
  - `/api/fraud/` → `fraud`
  - `/api/food-recognition/` → `chat`
  - `/api/push/` → `push_notification`
- `/socket.io/` → `socket_gateway` (WebSocket; auth currently commented out)

### Authentication Flow

Nginx validates all `/api/*` requests by calling `GET /auth/validate` internally. On success, it injects `X-User-ID` and `X-Username` headers into backend requests. Backend services trust these headers and should not re-validate the JWT.

### Required Environment Variables

Create a `.env` in `backend/` with:

```env
# JWT
JWT_SECRET_KEY=
JWT_REFRESH_SECRET_KEY=
JWT_ALGORITHM=HS256
ACCESS_TOKEN_EXPIRE_MINUTES=15
REFRESH_TOKEN_EXPIRE_DAYS=7

# Database
DB_HOST=db
DB_PORT=5432
DB_USERNAME=
DB_PASSWORD=
DB_DATABASE_NAME=

# OpenAI (used by chat and fraud services)
OPENAI_API_KEY=
TTS_MODEL=tts-1
VOICE_MODEL=alloy
OPENAI_MODEL=gpt-4o-mini

# Food recognition
FOOD_API_URL=https://food.bestweiwei.dpdns.org

# Docker secrets (set as environment variables for dev)
HF_TOKEN=
GIT_AUTH_TOKEN=
```

The `push_notification` service also requires a Firebase credentials file at:
`backend/secrets/aio-kebbi-firebase-adminsdk-fbsvc-0d7dde61d4.json`

### Backend Package Management

All Python services use **`uv`** (not pip) with `pyproject.toml`. Each service has its own `pyproject.toml` and `uv.lock`.

### Chat/Fraud Service Structure

Both `chat` and `fraud` services share the same internal module layout under `src/`:
- `main.py` — FastAPI app entry point
- `db_manager/` — Database access
- `dialogue/` — Conversation/session logic
- `food_recognition/` — Food recognition integration
- `llm_pipeline/` — LLM interaction
- `tts_service/` — OpenAI TTS integration

The `chat` API returns **MP3 audio** directly with text in custom response headers (`X-Response-Text`, `X-Message-Id`, `X-Conversation-Id`, etc.).

---

## Frontend (Flutter)

### Running

```bash
cd frontend

# Get dependencies
flutter pub get

# Run on device/emulator
flutter run

# Run for specific platform
flutter run -d android
flutter run -d ios
flutter run -d chrome
```

### Testing

```bash
cd frontend
flutter test                        # all tests
flutter test test/widget_test.dart  # single test file
flutter analyze                     # lint
```

### Key Configuration

**`lib/config/api_config.dart`** — central config file:
- `apiBaseUrl`: REST API base (currently `https://scamdemo.dddanielliu.com`)
- `socketBaseUrl` / `wsBase`: WebSocket server
- `devBypassLogin`: when `true`, skips real auth and uses `devFakeAccessToken` — **must set to `false` for production**
- `mockLogin` / `mockWs`: feature flags for using mock data instead of real services

### Architecture

- **State management**: `provider` package (`AuthProvider`, `CallProvider`)
- **DI**: `get_it` via `lib/di/service_locator.dart` (currently only registers `ApiService`)
- **Services** (`lib/services/`): `ApiService` (REST), `WebSocketService`, `AudioService`, `AlertService`, `SecureStorage`, `KebbiService`
- **Pages** (`lib/pages/`): `LoginPage`, `WelcomePage`, `MenuPage`, `CallPage`, `MonitorPage`, `ButlerChatPage`, `StatsPage`, `FoodRecognitionPage`, `WebviewPage`
- `AuthGuard` widget (`lib/widgets/auth_guard.dart`) gates access to protected pages

### Incomplete Features

Per the frontend README:
- **Butler AI chat** (`ButlerChatPage`): UI demo only, not connected to `/api/chat/`
- **AI voice responses**: TTS not yet integrated
- **Food recognition**: opens external URL demo; image upload to `/api/food-recognition/` not implemented
- **Login**: `devBypassLogin = true` bypasses real auth; real token flow needs backend to be live
