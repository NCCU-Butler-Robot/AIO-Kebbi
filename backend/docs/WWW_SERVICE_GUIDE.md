# AIO-Kebbi Web Interface - Quick Start Guide

## 🎯 Overview

A complete web interface has been added to the AIO-Kebbi Anti-Fraud System with the following features:
- User registration and login
- Anti-fraud call interface with Speech-to-Text (STT)
- Modern UI built with Bootstrap 5
- Full Docker integration with nginx reverse proxy

## 📁 What's New

```
backend/www/
├── src/
│   └── main.py              # FastAPI server
├── templates/
│   ├── base.html            # Base template with navbar
│   ├── index.html           # Landing page
│   ├── login.html           # Login page  
│   ├── register.html        # Registration page
│   └── call.html            # Anti-fraud call interface
├── static/
│   ├── css/style.css        # Custom styling
│   └── js/
│       ├── auth.js          # Authentication utilities
│       └── call.js          # STT + API integration
├── Dockerfile
├── pyproject.toml
└── README.md
```

## 🚀 Quick Start

### 1. Start All Services

```bash
cd /home/fintech/projects/AIO-Kebbi/backend
docker compose up --build
```

### 2. Access the Web Interface

Open your browser and navigate to:
```
http://localhost:8100/
```

### 3. Test the Complete Flow

#### Step 1: Register a New User
1. Click "Register" or go to `http://localhost:8100/register`
2. Fill in the form:
   - Username: `testuser`
   - Email: `test@example.com`
   - Phone Number: `0912345678`
   - Full Name: `Test User`
   - Password: `password123` (minimum 8 characters)
3. Click "Register"
4. You'll be redirected to the login page

#### Step 2: Login
1. Go to `http://localhost:8100/login`
2. Enter your credentials:
   - Username: `testuser`
   - Password: `password123`
3. Click "Login"
4. You'll be redirected to the call interface

#### Step 3: Use the Anti-Fraud Call Interface
1. Enter a recipient phone number (e.g., `+1234567890`)
2. **Option A: Voice Input** (Recommended for Chrome/Edge)
   - Click "Start Recording"
   - Say something like: "Hello, this is customer service from your bank"
   - Click "Stop Recording"
   - Your speech will be converted to text automatically
3. **Option B: Manual Text Input**
   - Type your message in the text field
   - Press Enter or click "Send"
4. The AI will respond with:
   - Text transcript in the conversation box
   - Audio playback (if OPENAI_API_KEY is set)

## 🔧 Configuration

### Environment Variables

The www service uses the existing backend services, so ensure these are set in your `.env` file:

```bash
# Required for audio responses
OPENAI_API_KEY=your_openai_api_key_here

# Required for authentication
JWT_SECRET_KEY=your_secret_key
JWT_REFRESH_SECRET_KEY=your_refresh_secret_key

# Database connection
DB_HOST=db
DB_PORT=5432
DB_USERNAME=postgres
DB_PASSWORD=your_password
DB_DATABASE_NAME=aio_kebbi
```

### Nginx Configuration

The nginx configuration has been updated to route traffic:

- `/` → www service (web interface)
- `/auth/*` → auth service (login/register)
- `/api/fraud/*` → fraud service (anti-fraud AI)
- `/api/*` → other backend services (chat, etc.)

## 🧪 Testing

### Browser Compatibility

For the Speech-to-Text feature:
- ✅ **Google Chrome** (Recommended)
- ✅ **Microsoft Edge**
- ✅ **Safari** (iOS 14.5+)
- ⚠️ **Firefox** (Limited support)

### Testing STT Functionality

1. Make sure you're using Chrome or Edge
2. Grant microphone permissions when prompted
3. The status badge will show "Listening..." when recording
4. Speak clearly in English
5. Check the browser console for debug messages

### Testing Without Microphone

If you don't have a microphone or prefer not to use it:
1. Use the manual text input field
2. Type your message
3. Press Enter or click "Send"

## 📊 Architecture

```
User Browser
    ↓
Nginx (Port 8100)
    ├─→ www:8000       (Web Interface - Static files & pages)
    ├─→ auth:8000      (Authentication - /auth/*)
    └─→ fraud:8000     (Anti-Fraud AI - /api/fraud/*)
```

## 🎨 Features

### Authentication System
- JWT-based authentication
- Token stored in localStorage
- Automatic token inclusion in API calls
- Protected routes (call page requires login)

### Speech-to-Text (STT)
- Browser-based Web Speech API
- Real-time voice recognition
- No server-side processing needed
- Automatic language detection (English)
- Fallback to manual input

### Anti-Fraud Integration
- Direct integration with `/api/fraud/` API
- Receives audio responses from OpenAI TTS
- Displays conversation transcript
- Audio playback controls
- Conversation history management

### Modern UI/UX
- Responsive design (mobile-friendly)
- Bootstrap 5 components
- Animated transitions
- Real-time status updates
- Clean and intuitive interface

## 🐛 Troubleshooting

### Issue: Speech Recognition Not Working
**Solution:**
- Use Chrome or Edge browser
- Check microphone permissions in browser settings
- Make sure microphone is not muted
- Use manual text input as fallback

### Issue: Authentication Failed
**Solution:**
- Clear localStorage: `localStorage.clear()` in browser console
- Login again
- Check that auth service is running: `docker compose ps`

### Issue: No Audio Response
**Solution:**
- Verify `OPENAI_API_KEY` is set in `.env`
- Check fraud service logs: `docker compose logs fraud`
- The system will fallback to JSON response if TTS fails

### Issue: 404 Not Found
**Solution:**
- Restart nginx: `docker compose restart nginx`
- Check nginx logs: `docker compose logs nginx`
- Verify all services are running: `docker compose ps`

## 📝 API Flow

### Registration
```
POST /auth/register
Content-Type: application/json

{
  "username": "testuser",
  "email": "test@example.com",
  "phone_number": "0912345678",
  "name": "Test User",
  "password": "password123"
}
```

### Login
```
POST /auth/login
Content-Type: application/x-www-form-urlencoded

username=testuser&password=password123

Response:
{
  "access_token": "eyJhbG...",
  "token_type": "bearer"
}
```

### Anti-Fraud Call
```
POST /api/fraud/
Authorization: Bearer <access_token>
Content-Type: application/json
X-Installation-Id: web-interface

{
  "prompt": "Hello, this is customer service"
}

Response:
Content-Type: audio/mpeg
Headers:
  X-Response-Text: "I don't understand, which bank..."
  X-Message-Id: "xxx"
  X-Conversation-Id: "xxx"
  X-Service-Type: "anti-fraud"
```

## 🔐 Security Notes

- Tokens are stored in localStorage (client-side)
- Use HTTPS in production
- CORS is configured for development
- XSS protection through HTML escaping
- Authentication required for protected routes

## 📚 Documentation

For more detailed information, see:
- [Web Interface README](backend/www/README.md)
- [Postman Testing Guide](POSTMAN_TESTING_GUIDE.md)
- [Integration Summary](INTEGRATION_SUMMARY.md)

## 🎉 Next Steps

1. Test the registration and login flow
2. Try the voice input feature
3. Test the anti-fraud conversation
4. Customize the UI in `static/css/style.css`
5. Add new features or pages as needed

## 💡 Tips

- Keep the browser console open to see debug messages
- The conversation transcript auto-scrolls to the bottom
- You can clear the conversation with the "Clear Conversation" button
- The AI responds in English for anti-fraud scenarios
- Audio responses are played automatically

---

**Need Help?** Check the logs:
```bash
# View all logs
docker compose logs -f

# View specific service logs
docker compose logs www -f
docker compose logs nginx -f
docker compose logs fraud -f
```
