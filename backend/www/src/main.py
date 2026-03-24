"""
AIO-Kebbi Web Interface Service
FastAPI server for serving web UI and proxying API calls
"""

from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import HTMLResponse
from fastapi.staticfiles import StaticFiles
from fastapi.templating import Jinja2Templates

app = FastAPI(title="AIO-Kebbi Web Interface")

# CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Mount static files
app.mount("/web/static", StaticFiles(directory="static"), name="static")

# Templates
templates = Jinja2Templates(directory="templates")


@app.get("/web/", response_class=HTMLResponse)
async def root(request: Request):
    """Redirect to login page"""
    return templates.TemplateResponse("index.html", {"request": request})


@app.get("/web/login", response_class=HTMLResponse)
async def login_page(request: Request):
    """Login page"""
    return templates.TemplateResponse("login.html", {"request": request})


@app.get("/web/register", response_class=HTMLResponse)
async def register_page(request: Request):
    """Register page"""
    return templates.TemplateResponse("register.html", {"request": request})


@app.get("/web/call", response_class=HTMLResponse)
async def call_page(request: Request):
    """Anti-fraud call page"""
    return templates.TemplateResponse("call.html", {"request": request})


@app.get("/web/health")
async def health_check():
    """Health check endpoint"""
    return {"status": "healthy", "service": "www"}


if __name__ == "__main__":
    import uvicorn

    uvicorn.run(app, host="0.0.0.0", port=8000)
