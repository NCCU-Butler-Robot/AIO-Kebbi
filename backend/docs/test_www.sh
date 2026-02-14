#!/bin/bash

# Test the www service and nginx configuration

echo "Testing AIO-Kebbi Web Service..."
echo ""

# Test 1: Check if nginx is running
echo "1. Checking nginx status..."
if docker ps | grep -q "nginx"; then
    echo "   ✓ nginx is running"
else
    echo "   ✗ nginx is NOT running"
    echo "   Starting nginx..."
    cd /home/fintech/projects/AIO-Kebbi/backend
    docker compose up -d nginx
    sleep 2
fi

# Test 2: Check if www service is running
echo ""
echo "2. Checking www service status..."
if docker ps | grep -q "www"; then
    echo "   ✓ www service is running"
else
    echo "   ✗ www service is NOT running"
fi

# Test 3: Test nginx -> www routing
echo ""
echo "3. Testing web interface accessibility..."
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8100/)
if [ "$HTTP_CODE" = "200" ]; then
    echo "   ✓ Web interface is accessible (HTTP $HTTP_CODE)"
else
    echo "   ✗ Web interface returned HTTP $HTTP_CODE"
fi

# Test 4: Test health endpoint
echo ""
echo "4. Testing www service health endpoint..."
HEALTH=$(curl -s http://localhost:8100/health 2>&1)
if echo "$HEALTH" | grep -q "healthy"; then
    echo "   ✓ Health check passed: $HEALTH"
else
    echo "   ✗ Health check failed: $HEALTH"
fi

# Test 5: Check logs for errors
echo ""
echo "5. Checking nginx logs for errors..."
NGINX_ERRORS=$(docker compose -f /home/fintech/projects/AIO-Kebbi/backend/docker-compose.yml logs nginx 2>&1 | grep -i "error" | wc -l)
if [ "$NGINX_ERRORS" -eq 0 ]; then
    echo "   ✓ No errors in nginx logs"
else
    echo "   ⚠ Found $NGINX_ERRORS error(s) in nginx logs"
    echo "   Run 'docker compose logs nginx' to see details"
fi

echo ""
echo "6. Checking www service logs..."
WWW_ERRORS=$(docker compose -f /home/fintech/projects/AIO-Kebbi/backend/docker-compose.yml logs www 2>&1 | grep -i "error" | wc -l)
if [ "$WWW_ERRORS" -eq 0 ]; then
    echo "   ✓ No errors in www service logs"
else
    echo "   ⚠ Found $WWW_ERRORS error(s) in www service logs"
    echo "   Run 'docker compose logs www' to see details"
fi

echo ""
echo "============================================"
echo "Summary:"
echo "  Web Interface: http://localhost:8100/"
echo "  Health Check:  http://localhost:8100/health"
echo ""
echo "Quick Actions:"
echo "  - View logs: docker compose logs -f www"
echo "  - Restart:   docker compose restart www nginx"
echo "  - Stop all:  docker compose down"
echo "============================================"
