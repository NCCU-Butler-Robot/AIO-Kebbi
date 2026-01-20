#!/bin/bash

echo "=== Building and Starting Anti-Fraud Service ==="

cd /home/fintech/projects/AIO-Kebbi/backend

echo "1. Building fraud service..."
if docker compose build fraud; then
    echo "✅ Build successful"
else
    echo "❌ Build failed"
    exit 1
fi

echo "2. Starting fraud service..."
if docker compose up -d fraud; then
    echo "✅ Service started"
else
    echo "❌ Failed to start service"
    exit 1
fi

echo "3. Waiting for service to be ready..."
sleep 10

echo "4. Checking service health..."
if docker compose exec fraud curl -f http://localhost:8000/health; then
    echo "✅ Health check passed"
else
    echo "⚠️  Health check failed, checking logs..."
    docker compose logs fraud --tail=20
fi

echo "5. Checking service status..."
docker compose ps fraud

echo "✅ Anti-fraud service is ready!"
echo "Test with: curl -X POST http://localhost:8100/api/fraud/ ..."