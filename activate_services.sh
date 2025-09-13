#!/bin/bash

echo "🚀 Activating Shivish Services with SSL..."
echo "=========================================="

# Change to project directory
cd /opt/shivish

# Get external IP
EXTERNAL_IP=$(curl -s ifconfig.me 2>/dev/null || curl -s ipinfo.io/ip 2>/dev/null || curl -s icanhazip.com 2>/dev/null)
INTERNAL_IP=$(hostname -I | awk '{print $1}')

echo "🌐 External IP: $EXTERNAL_IP"
echo "🏠 Internal IP: $INTERNAL_IP"

# Step 1: Start all services
echo ""
echo "📦 Starting all services..."
docker-compose -f docker-compose-production.yml up -d

# Wait for services to start
echo "⏳ Waiting for services to start (30 seconds)..."
sleep 30

# Step 2: Check service status
echo ""
echo "🔍 Checking service status..."
docker-compose -f docker-compose-production.yml ps

# Step 3: Test HTTP connection
echo ""
echo "🧪 Testing HTTP connection..."
if curl -s http://$EXTERNAL_IP/api/ >/dev/null; then
    echo "✅ HTTP connection working!"
else
    echo "❌ HTTP connection not working"
fi

# Step 4: Test HTTPS connection
echo ""
echo "🔒 Testing HTTPS connection..."
if curl -s -k https://$EXTERNAL_IP/api/ >/dev/null; then
    echo "✅ HTTPS connection working!"
else
    echo "❌ HTTPS connection not working"
fi

# Step 5: Test individual services
echo ""
echo "🔍 Testing individual services..."
echo "Testing Auth Service..."
curl -s http://$EXTERNAL_IP/auth/health >/dev/null && echo "✅ Auth Service: OK" || echo "❌ Auth Service: DOWN"

echo "Testing User Service..."
curl -s http://$EXTERNAL_IP/users/health >/dev/null && echo "✅ User Service: OK" || echo "❌ User Service: DOWN"

echo "Testing API Gateway..."
curl -s http://$EXTERNAL_IP/api/health >/dev/null && echo "✅ API Gateway: OK" || echo "❌ API Gateway: DOWN"

# Step 6: Show production URLs
echo ""
echo "🌐 Production URLs for your Flutter app:"
echo "========================================"
echo ""
echo "🔒 HTTPS URLs (Secure - Recommended):"
echo "   Main API: https://$EXTERNAL_IP/api/"
echo "   Auth Service: https://$EXTERNAL_IP/auth/"
echo "   User Service: https://$EXTERNAL_IP/users/"
echo "   E-commerce Service: https://$EXTERNAL_IP/ecommerce/"
echo "   Payment Service: https://$EXTERNAL_IP/payments/"
echo "   Notification Service: https://$EXTERNAL_IP/notifications/"
echo "   Content Service: https://$EXTERNAL_IP/content/"
echo "   Analytics Service: https://$EXTERNAL_IP/analytics/"
echo "   Verification Service: https://$EXTERNAL_IP/verification/"
echo "   Emergency Service: https://$EXTERNAL_IP/emergency/"
echo "   Temple Service: https://$EXTERNAL_IP/temple/"
echo ""
echo "🌐 HTTP URLs (Alternative):"
echo "   Main API: http://$EXTERNAL_IP/api/"
echo "   Auth Service: http://$EXTERNAL_IP/auth/"
echo "   User Service: http://$EXTERNAL_IP/users/"
echo ""
echo "📱 Flutter App Configuration:"
echo "============================="
echo ""
echo "// For HTTPS (Recommended)"
echo "const String API_BASE_URL = 'https://$EXTERNAL_IP/api/';"
echo ""
echo "// For HTTP (Simpler, no SSL warnings)"
echo "const String API_BASE_URL = 'http://$EXTERNAL_IP/api/';"
echo ""
echo "🧪 Test your setup:"
echo "==================="
echo "1. Open in browser: http://$EXTERNAL_IP/api/"
echo "2. Test HTTPS: https://$EXTERNAL_IP/api/"
echo "3. Check all services: ./monitor_production.sh"
echo ""
echo "✅ Services activated successfully!"
echo "🎉 Your Shivish platform is now live and ready for production!"
