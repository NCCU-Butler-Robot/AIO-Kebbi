#!/bin/bash

# Anti-Fraud Service 啟動腳本

echo "=== Anti-Fraud Communication Service ==="
echo "設置基於GPT的反詐騙語音助理服務"
echo

# 檢查是否設置了OpenAI API密鑰
if [ -z "$OPENAI_API_KEY" ]; then
    echo "❌ Error: OPENAI_API_KEY environment variable not set"
    echo "Please run: export OPENAI_API_KEY='your-api-key-here'"
    echo "Or create a .env file and set the API key"
    exit 1
fi

echo "✅ OPENAI_API_KEY detected"

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    echo "❌ Error: Docker is not running, please start Docker first"
    exit 1
fi

echo "✅ Docker is running"

# Check if .env file exists
if [ ! -f ".env" ]; then
    echo "⚠️  Warning: .env file not found"
    echo "Recommend creating a .env file to manage environment variables"
    echo "You can refer to .env.example file"
fi

# Build and start services
echo "🏗️  Building service image..."
docker-compose build

echo "🚀 Starting anti-fraud service..."
docker-compose up -d

echo
echo "📋 Service Status:"
docker-compose ps

echo
echo "🔗 Service Access:"
echo "  - Health Check: http://localhost:8000/health"
echo "  - API Documentation: http://localhost:8000/docs"
echo "  - Redis: localhost:6379"
echo "  - PostgreSQL: localhost:5432"

echo
echo "📝 View Logs:"
echo "  docker-compose logs -f fraud-service"

echo
echo "⭐ Anti-fraud service is now running!"
echo "Use the following endpoint for conversation: POST /api/fraud/"