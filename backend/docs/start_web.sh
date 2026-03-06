#!/bin/bash

# AIO-Kebbi Web Service Startup Script

set -e

echo "================================================"
echo "  AIO-Kebbi Anti-Fraud System - Web Interface  "
echo "================================================"
echo ""

# Check if .env exists
if [ ! -f .env ]; then
    echo "⚠️  Warning: .env file not found!"
    echo "   Please create a .env file with required environment variables."
    echo "   See .env.example for reference."
    echo ""
    read -p "Continue anyway? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Check if OPENAI_API_KEY is set
if [ -f .env ]; then
    source .env
    if [ -z "$OPENAI_API_KEY" ]; then
        echo "⚠️  Warning: OPENAI_API_KEY is not set in .env"
        echo "   The anti-fraud service will work, but audio responses will be disabled."
        echo "   Set OPENAI_API_KEY to enable text-to-speech functionality."
        echo ""
    fi
fi

echo "🚀 Starting AIO-Kebbi services..."
echo ""

# Build and start services
docker compose up --build -d

echo ""
echo "⏳ Waiting for services to be ready..."
sleep 5

# Check service status
echo ""
echo "📊 Service Status:"
docker compose ps

echo ""
echo "✅ Services started successfully!"
echo ""
echo "================================================"
echo "  Access the Web Interface:                    "
echo "  http://localhost:8100/                       "
echo "================================================"
echo ""
echo "Quick Start:"
echo "1. Open http://localhost:8100/ in your browser"
echo "2. Click 'Register' to create a new account"
echo "3. Login with your credentials"
echo "4. Use the anti-fraud call interface"
echo ""
echo "📝 View logs:"
echo "   docker compose logs -f"
echo ""
echo "🛑 Stop services:"
echo "   docker compose down"
echo ""
