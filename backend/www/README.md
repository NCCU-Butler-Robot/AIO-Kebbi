# AIO-Kebbi Web Interface

A modern web interface for the AIO-Kebbi Anti-Fraud Protection System, built with FastAPI, Bootstrap 5, and integrated Speech-to-Text functionality.

## Features

- **User Authentication**
  - Login page with secure authentication
  - Registration page for new users
  - Token-based authentication with JWT

- **Anti-Fraud Call Interface**
  - Real-time voice-to-text conversion using Web Speech API
  - Manual text input as an alternative
  - Audio playback of AI responses
  - Conversation transcript display
  - Recipient phone number input

- **Modern UI/UX**
  - Responsive design with Bootstrap 5
  - Clean and intuitive interface
  - Mobile-friendly layout
  - Real-time status updates

## Technology Stack

- **Backend**: FastAPI
- **Frontend**: HTML5, Bootstrap 5, Vanilla JavaScript
- **Speech Recognition**: Web Speech API (Browser-based STT)
- **Containerization**: Docker
- **Reverse Proxy**: Nginx

## Project Structure

```
www/
├── src/
│   └── main.py              # FastAPI application
├── templates/               # Jinja2 templates
│   ├── base.html           # Base template with navbar
│   ├── index.html          # Landing page
│   ├── login.html          # Login page
│   ├── register.html       # Registration page
│   └── call.html           # Anti-fraud call interface
├── static/                 # Static assets
│   ├── css/
│   │   └── style.css       # Custom styles
│   └── js/
│       ├── auth.js         # Authentication utilities
│       └── call.js         # Call interface with STT
├── Dockerfile              # Container configuration
└── pyproject.toml          # Python dependencies
```

## Installation & Usage

### Using Docker Compose (Recommended)

1. Navigate to the backend directory:
```bash
cd backend
```

2. Start all services:
```bash
docker compose up --build
```

3. Access the web interface:
```
http://localhost:8100/
```

### Standalone Development

1. Install dependencies:
```bash
cd www
pip install -e .
```

2. Run the development server:
```bash
uvicorn src.main:app --reload --host 0.0.0.0 --port 8000
```

3. Access the interface:
```
http://localhost:8000/
```

## User Guide

### 1. Registration
- Navigate to the registration page
- Fill in your details:
  - Username
  - Email
  - Phone Number
  - Full Name
  - Password (minimum 8 characters)
- Click "Register"
- You'll be redirected to the login page

### 2. Login
- Enter your username and password
- Click "Login"
- You'll be redirected to the call interface

### 3. Using the Anti-Fraud Call Interface

#### Voice Input (Recommended)
1. Enter the recipient's phone number
2. Click "Start Recording"
3. Speak clearly in English
4. Click "Stop Recording"
5. Your speech will be converted to text and sent to the AI
6. The AI's response will appear in the transcript with audio playback

#### Manual Text Input (Alternative)
1. Enter the recipient's phone number
2. Type your message in the text field
3. Press Enter or click "Send"
4. The AI's response will appear in the transcript with audio playback

### 4. Browser Compatibility

The Speech-to-Text feature requires a modern browser:
- ✅ Google Chrome (Recommended)
- ✅ Microsoft Edge
- ✅ Safari (iOS 14.5+)
- ❌ Firefox (Limited support)

## API Endpoints

### Web Pages
- `GET /` - Landing page
- `GET /login` - Login page
- `GET /register` - Registration page
- `GET /call` - Anti-fraud call interface (requires authentication)

### Health Check
- `GET /health` - Service health check

## Configuration

The service is configured through nginx to proxy requests to the appropriate backend services:

- `/` → www service (web interface)
- `/auth/*` → auth service (public authentication)
- `/api/*` → Various backend services (requires authentication)

## Environment Variables

No additional environment variables are required for the www service. It relies on the existing backend services:

- Auth service: `/auth/login`, `/auth/register`
- Fraud service: `/api/fraud/`

## Features in Detail

### Speech-to-Text (STT)
- Uses browser's built-in Web Speech API
- No server-side processing required
- Real-time conversion
- Supports English language (en-US)
- Fallback to manual input if not supported

### Authentication Flow
1. User registers or logs in
2. JWT access token is stored in localStorage
3. Token is included in all API requests
4. Protected pages require valid token
5. Logout clears the token

### Anti-Fraud AI Integration
- Sends voice/text to `/api/fraud/` endpoint
- Receives AI response as audio file
- Displays transcript in real-time
- Plays audio response automatically
- Maintains conversation history

## Development

### Adding New Pages

1. Create a new template in `templates/`:
```html
{% extends "base.html" %}

{% block title %}New Page{% endblock %}

{% block content %}
<!-- Your content here -->
{% endblock %}
```

2. Add a route in `src/main.py`:
```python
@app.get("/new-page", response_class=HTMLResponse)
async def new_page(request: Request):
    return templates.TemplateResponse("new-page.html", {"request": request})
```

### Customizing Styles

Edit `static/css/style.css` to customize the appearance:
```css
/* Add your custom styles */
.custom-class {
    /* ... */
}
```

### Adding JavaScript Functionality

Create a new file in `static/js/` and include it in your template:
```html
{% block extra_js %}
<script src="/static/js/your-script.js"></script>
{% endblock %}
```

## Security Considerations

- JWT tokens are stored in localStorage
- All API calls use HTTPS in production
- CORS is configured for cross-origin requests
- XSS protection through HTML escaping
- Authentication required for sensitive endpoints

## Troubleshooting

### Speech Recognition Not Working
- Ensure you're using a supported browser (Chrome/Edge)
- Check microphone permissions
- Try manual text input as fallback

### Authentication Errors
- Clear localStorage and login again
- Check that auth service is running
- Verify token hasn't expired

### Audio Playback Issues
- Check that OPENAI_API_KEY is set
- Verify fraud service is running
- Check browser audio permissions

## Future Enhancements

- [ ] Multi-language support
- [ ] Voice activity detection
- [ ] Conversation export/download
- [ ] Real-time collaboration
- [ ] Advanced analytics dashboard
- [ ] Mobile app integration

## License

Copyright © 2026 AIO-Kebbi Anti-Fraud System. All rights reserved.
