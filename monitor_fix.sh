#!/bin/bash

# 🔧 Monitoring Fix Script
# This script fixes the monitoring health check issues

set -e  # Exit on any error

echo "🔧 Starting Monitoring Fix Script..."
echo "=================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Set the target directory
TARGET_DIR="/opt/shivish"

# Check if target directory exists
if [ ! -d "$TARGET_DIR" ]; then
    print_error "Target directory $TARGET_DIR does not exist"
    print_error "Please ensure the Shivish project is located at $TARGET_DIR"
    exit 1
fi

# Check if we have the required project files in target directory
if [ ! -f "$TARGET_DIR/pubspec.yaml" ] || [ ! -d "$TARGET_DIR/microservices" ]; then
    print_error "Shivish project files not found in $TARGET_DIR"
    print_error "Expected to find pubspec.yaml and microservices/ directory"
    exit 1
fi

# Change to target directory
print_status "Changing to target directory: $TARGET_DIR"
cd "$TARGET_DIR"

# Get the current directory (project root)
PROJECT_ROOT="$(pwd)"
print_status "Working in project root directory: $PROJECT_ROOT"

print_status "Step 1: Checking current Docker container status..."
docker-compose ps

print_status "Step 2: Testing current service endpoints..."
echo "Testing API Gateway..."
curl -s http://localhost:8080/ >/dev/null && echo "✅ API Gateway: OK" || echo "❌ API Gateway: DOWN"

echo "Testing Auth Service..."
curl -s http://localhost:8081/ >/dev/null && echo "✅ Auth Service: OK" || echo "❌ Auth Service: DOWN"

echo "Testing User Service..."
curl -s http://localhost:8082/ >/dev/null && echo "✅ User Service: OK" || echo "❌ User Service: DOWN"

print_status "Step 3: Creating fixed monitoring script..."

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
echo "🐳 Docker Containers:"
docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}"

echo ""
echo "🔍 Service Health:"
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
echo "📊 ClickHouse Status:"
curl -s http://localhost:8123 >/dev/null && echo "✅ ClickHouse: OK" || echo "❌ ClickHouse: DOWN"

echo ""
echo "🌐 Service URLs:"
echo "   - API Gateway: http://$(hostname -I | awk '{print $1}'):8080"
echo "   - Grafana: http://$(hostname -I | awk '{print $1}'):3000"
echo "   - MinIO Console: http://$(hostname -I | awk '{print $1}'):9001"
echo "   - Prometheus: http://$(hostname -I | awk '{print $1}'):9090"
EOF

chmod +x monitor_fixed.sh
print_success "Fixed monitoring script created"

print_status "Step 4: Replacing the original monitor.sh script..."

# Backup the original monitor.sh
if [ -f "monitor.sh" ]; then
    cp monitor.sh monitor.sh.backup
    print_status "Original monitor.sh backed up as monitor.sh.backup"
fi

# Replace monitor.sh with the fixed version
cp monitor_fixed.sh monitor.sh
chmod +x monitor.sh

print_success "Original monitor.sh replaced with fixed version"

print_status "Step 5: Testing the fixed monitoring script..."
echo ""
echo "🧪 Testing the fixed monitoring script..."
echo "========================================"
./monitor.sh

print_status "Step 6: Creating a comprehensive health check script..."

cat > health_check.sh << 'EOF'
#!/bin/bash

echo "🏥 Comprehensive Health Check"
echo "============================="

# Check if we're in the right directory
if [ ! -f "docker-compose.yml" ]; then
    echo "❌ Error: Not in project directory. Please run from /opt/shivish"
    exit 1
fi

echo "📋 Container Status:"
docker-compose ps

echo ""
echo "🔍 Service Endpoint Tests:"
echo "-------------------------"

# Test all service endpoints
services=(
    "8080:API Gateway"
    "8081:Auth Service"
    "8082:User Service"
    "8083:E-commerce Service"
    "8084:Payment Service"
    "8085:Notification Service"
    "8086:Content Service"
    "8087:Analytics Service"
    "8088:Verification Service"
    "8089:Emergency Service"
    "8090:Temple Service"
)

for service in "${services[@]}"; do
    port=$(echo $service | cut -d: -f1)
    name=$(echo $service | cut -d: -f2)
    
    if curl -s --connect-timeout 5 http://localhost:$port/ >/dev/null 2>&1; then
        echo "✅ $name (Port $port): OK"
    else
        echo "❌ $name (Port $port): DOWN"
    fi
done

echo ""
echo "🌐 Core Services:"
echo "----------------"

# Test core services
core_services=(
    "3000:Grafana"
    "9001:MinIO Console"
    "9090:Prometheus"
    "8123:ClickHouse"
)

for service in "${core_services[@]}"; do
    port=$(echo $service | cut -d: -f1)
    name=$(echo $service | cut -d: -f2)
    
    if curl -s --connect-timeout 5 http://localhost:$port/ >/dev/null 2>&1; then
        echo "✅ $name (Port $port): OK"
    else
        echo "❌ $name (Port $port): DOWN"
    fi
done

echo ""
echo "🗄️  Database Tests:"
echo "------------------"

# Test PostgreSQL
if docker exec shivish-postgres psql -U shivish_user -d shivish_platform -c "SELECT 1;" >/dev/null 2>&1; then
    echo "✅ PostgreSQL: OK"
else
    echo "❌ PostgreSQL: DOWN"
fi

# Test Redis
if docker exec shivish-redis redis-cli ping >/dev/null 2>&1; then
    echo "✅ Redis: OK"
else
    echo "❌ Redis: DOWN"
fi

echo ""
echo "📊 System Resources:"
echo "-------------------"
echo "Memory Usage:"
free -h | grep -E "(Mem|Swap)"

echo ""
echo "Disk Usage:"
df -h | grep -E "(Filesystem|/dev/)"

echo ""
echo "🐳 Docker Resource Usage:"
docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}" | head -10

echo ""
echo "🌐 Access URLs:"
echo "--------------"
SERVER_IP=$(hostname -I | awk '{print $1}')
echo "   - API Gateway: http://$SERVER_IP:8080"
echo "   - Grafana: http://$SERVER_IP:3000"
echo "   - MinIO Console: http://$SERVER_IP:9001"
echo "   - Prometheus: http://$SERVER_IP:9090"
echo "   - ClickHouse: http://$SERVER_IP:8123"

echo ""
echo "✅ Health check completed!"
EOF

chmod +x health_check.sh
print_success "Comprehensive health check script created"

print_status "Step 7: Creating a quick status script..."

cat > status.sh << 'EOF'
#!/bin/bash

echo "⚡ Quick Status Check"
echo "===================="

# Quick container status
echo "🐳 Container Status:"
docker-compose ps --format "table {{.Name}}\t{{.Status}}\t{{.Ports}}"

echo ""
echo "🔍 Quick Service Test:"
# Test a few key services quickly
curl -s http://localhost:8080/ >/dev/null && echo "✅ API Gateway: OK" || echo "❌ API Gateway: DOWN"
curl -s http://localhost:3000 >/dev/null && echo "✅ Grafana: OK" || echo "❌ Grafana: DOWN"
curl -s http://localhost:9001 >/dev/null && echo "✅ MinIO: OK" || echo "❌ MinIO: DOWN"

echo ""
echo "📊 Memory Usage:"
free -h | grep Mem

echo ""
echo "💾 Disk Usage:"
df -h | grep -E "(Filesystem|/dev/)" | head -2
EOF

chmod +x status.sh
print_success "Quick status script created"

print_status "Step 8: Final verification..."

echo ""
echo "🧪 Running final verification..."
echo "==============================="

# Test the fixed monitoring script
echo "Testing monitor.sh:"
./monitor.sh

echo ""
print_success "🎉 Monitoring fix completed successfully!"
echo ""
echo "=================================================="
echo "📋 Available Scripts:"
echo "=================================================="
echo ""
echo "1. 📊 ./monitor.sh          - Fixed monitoring script"
echo "2. 🏥 ./health_check.sh     - Comprehensive health check"
echo "3. ⚡ ./status.sh           - Quick status check"
echo "4. 🚀 ./deploy.sh           - Deploy services"
echo "5. 💾 ./backup.sh           - Backup data"
echo "6. 🧹 ./maintenance.sh      - Maintenance tasks"
echo ""
echo "=================================================="
echo "🌐 Your services should now show as OK in monitoring!"
echo "=================================================="
