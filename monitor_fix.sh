# Create a fixed monitoring script
cat > monitor_fixed.sh << 'EOF'
#!/bin/bash

echo "🖥️  System Resources:"
echo "===================="

# Memory usage
echo "📊 Memory Usage:"
free -h

echo ""
echo "💾 Disk Usage:"
df -h

echo ""
echo "�� Docker Containers:"
docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}"

echo ""
echo "�� Service Health:"
# Test actual endpoints instead of /health
curl -s http://localhost:8080/ >/dev/null && echo "✅ API Gateway: OK" || echo "❌ API Gateway: DOWN"
curl -s http://localhost:8081/ >/dev/null && echo "✅ Auth Service: OK" || echo "❌ Auth Service: DOWN"
curl -s http://localhost:8082/ >/dev/null && echo "✅ User Service: OK" || echo "❌ User Service: DOWN"
curl -s http://localhost:8083/ >/dev/null && echo "✅ E-commerce Service: OK" || echo "❌ E-commerce Service: DOWN"
curl -s http://localhost:8084/ >/dev/null && echo "✅ Payment Service: OK" || echo "❌ Payment Service: DOWN"
curl -s http://localhost:8085/ >/dev/null && echo "✅ Notification Service: OK" || echo "❌ Notification Service: DOWN"
curl -s http://localhost:8086/ >/dev/null && echo "✅ Content Service: OK" || echo "❌ Content Service: DOWN"
curl -s http://localhost:8087/ >/dev/null && echo "✅ Analytics Service: OK" || echo "❌ Analytics Service: DOWN"
curl -s http://localhost:8088/ >/dev/null && echo "✅ Verification Service: OK" || echo "❌ Verification Service: DOWN"
curl -s http://localhost:8089/ >/dev/null && echo "✅ Emergency Service: OK" || echo "❌ Emergency Service: DOWN"
curl -s http://localhost:8090/ >/dev/null && echo "✅ Temple Service: OK" || echo "❌ Temple Service: DOWN"

echo ""
echo "🌐 Core Services:"
curl -s http://localhost:3000 >/dev/null && echo "✅ Grafana: OK" || echo "❌ Grafana: DOWN"
curl -s http://localhost:9001 >/dev/null && echo "✅ MinIO Console: OK" || echo "❌ MinIO Console: DOWN"
curl -s http://localhost:9090 >/dev/null && echo "✅ Prometheus: OK" || echo "❌ Prometheus: DOWN"

echo ""
echo "📈 Database Connections:"
docker exec shivish-postgres psql -U shivish_user -d shivish_platform -c "SELECT count(*) as active_connections FROM pg_stat_activity;" 2>/dev/null || echo "❌ PostgreSQL: Not accessible"

echo ""
echo "🔄 Redis Status:"
docker exec shivish-redis redis-cli ping 2>/dev/null || echo "❌ Redis: Not accessible"

echo ""
echo "�� ClickHouse Status:"
curl -s http://localhost:8123 >/dev/null && echo "✅ ClickHouse: OK" || echo "❌ ClickHouse: DOWN"
EOF

chmod +x monitor_fixed.sh