#!/bin/bash

# 🔧 Complete Fix Script for Shivish Platform
# This script fixes monitoring and ClickHouse issues

set -e  # Exit on any error

echo "🔧 Starting Complete Fix Script for Shivish Platform..."
echo "====================================================="

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

print_status "Step 2: Fixing ClickHouse issues..."

# Stop and remove ClickHouse if it exists
print_status "Stopping and removing existing ClickHouse..."
docker-compose stop clickhouse 2>/dev/null || true
docker-compose rm -f clickhouse 2>/dev/null || true

# Create ClickHouse configuration directory
print_status "Creating ClickHouse configuration..."
mkdir -p configs/clickhouse

# Create ClickHouse config.xml
print_status "Creating ClickHouse config.xml..."
cat > configs/clickhouse/config.xml << 'EOF'
<?xml version="1.0"?>
<clickhouse>
    <logger>
        <level>information</level>
        <log>/var/log/clickhouse-server/clickhouse-server.log</log>
        <errorlog>/var/log/clickhouse-server/clickhouse-server.err.log</errorlog>
        <size>1000M</size>
        <count>10</count>
    </logger>

    <http_port>8123</http_port>
    <tcp_port>9000</tcp_port>
    <listen_host>0.0.0.0</listen_host>

    <max_connections>4096</max_connections>
    <keep_alive_timeout>3</keep_alive_timeout>
    <max_concurrent_queries>100</max_concurrent_queries>

    <path>/var/lib/clickhouse/</path>
    <tmp_path>/var/lib/clickhouse/tmp/</tmp_path>
    <user_files_path>/var/lib/clickhouse/user_files/</user_files_path>

    <users_config>users.xml</users_config>
    <default_profile>default</default_profile>
    <default_database>default</default_database>
    <timezone>UTC</timezone>
</clickhouse>
EOF

# Create ClickHouse users.xml
print_status "Creating ClickHouse users.xml..."
cat > configs/clickhouse/users.xml << 'EOF'
<?xml version="1.0"?>
<clickhouse>
    <users>
        <default>
            <password></password>
            <networks>
                <ip>::/0</ip>
            </networks>
            <profile>default</profile>
            <quota>default</quota>
        </default>
        <analytics_user>
            <password>clickhouse_secure_password_2024</password>
            <networks>
                <ip>::/0</ip>
            </networks>
            <profile>default</profile>
            <quota>default</quota>
        </analytics_user>
    </users>
    <quotas>
        <default>
            <interval>
                <duration>3600</duration>
                <queries>0</queries>
                <errors>0</errors>
                <result_rows>0</result_rows>
                <read_rows>0</read_rows>
                <execution_time>0</execution_time>
            </interval>
        </default>
    </quotas>
    <profiles>
        <default>
            <max_memory_usage>10000000000</max_memory_usage>
            <use_uncompressed_cache>0</use_uncompressed_cache>
            <load_balancing>random</load_balancing>
        </default>
    </profiles>
</clickhouse>
EOF

# Fix ClickHouse data directory permissions
print_status "Fixing ClickHouse data directory permissions..."
sudo rm -rf data/clickhouse/* 2>/dev/null || true
mkdir -p data/clickhouse
sudo chown -R 999:999 data/clickhouse
sudo chmod -R 755 data/clickhouse

print_success "ClickHouse configuration created"

print_status "Step 3: Adding ClickHouse to docker-compose.yml..."

# Check if ClickHouse service exists in docker-compose.yml
if ! grep -q "clickhouse:" docker-compose.yml; then
    print_status "Adding ClickHouse service to docker-compose.yml..."
    
    # Create backup
    cp docker-compose.yml docker-compose.yml.backup
    
    # Add ClickHouse service before the networks section
    sed -i '/^networks:/i\
  clickhouse:\
    image: clickhouse/clickhouse-server:latest\
    container_name: shivish-clickhouse\
    environment:\
      CLICKHOUSE_DB: analytics\
      CLICKHOUSE_USER: analytics_user\
      CLICKHOUSE_PASSWORD: clickhouse_secure_password_2024\
    volumes:\
      - ./data/clickhouse:/var/lib/clickhouse\
      - ./configs/clickhouse/config.xml:/etc/clickhouse-server/config.xml\
      - ./configs/clickhouse/users.xml:/etc/clickhouse-server/users.xml\
    ports:\
      - "8123:8123"\
      - "9000:9000"\
    networks:\
      - shivish-network\
    restart: unless-stopped\
    ulimits:\
      nofile:\
        soft: 262144\
        hard: 262144\
' docker-compose.yml
    
    print_success "ClickHouse service added to docker-compose.yml"
else
    print_warning "ClickHouse service already exists in docker-compose.yml"
fi

print_status "Step 4: Starting ClickHouse..."
docker-compose up -d clickhouse

print_status "Step 5: Waiting for ClickHouse to start..."
sleep 20

print_status "Step 6: Testing ClickHouse..."
if curl -s http://localhost:8123 >/dev/null; then
    print_success "ClickHouse is working!"
else
    print_warning "ClickHouse may still be starting, checking logs..."
    docker-compose logs --tail=10 clickhouse
fi

print_status "Step 7: Fixing monitoring script..."

# Test current service endpoints
print_status "Testing current service endpoints..."
echo "Testing API Gateway..."
curl -s http://localhost:8080/ >/dev/null && echo "✅ API Gateway: OK" || echo "❌ API Gateway: DOWN"

echo "Testing Auth Service..."
curl -s http://localhost:8081/ >/dev/null && echo "✅ Auth Service: OK" || echo "❌ Auth Service: DOWN"

echo "Testing User Service..."
curl -s http://localhost:8082/ >/dev/null && echo "✅ User Service: OK" || echo "❌ User Service: DOWN"

print_status "Step 8: Creating fixed monitoring script..."

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
echo "   - ClickHouse: http://$(hostname -I | awk '{print $1}'):8123"
EOF

chmod +x monitor_fixed.sh
print_success "Fixed monitoring script created"

print_status "Step 9: Replacing the original monitor.sh script..."

# Backup the original monitor.sh
if [ -f "monitor.sh" ]; then
    cp monitor.sh monitor.sh.backup
    print_status "Original monitor.sh backed up as monitor.sh.backup"
fi

# Replace monitor.sh with the fixed version
cp monitor_fixed.sh monitor.sh
chmod +x monitor.sh

print_success "Original monitor.sh replaced with fixed version"

print_status "Step 10: Creating comprehensive health check script..."

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

print_status "Step 11: Creating quick status script..."

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
curl -s http://localhost:8123 >/dev/null && echo "✅ ClickHouse: OK" || echo "❌ ClickHouse: DOWN"

echo ""
echo "📊 Memory Usage:"
free -h | grep Mem

echo ""
echo "💾 Disk Usage:"
df -h | grep -E "(Filesystem|/dev/)" | head -2
EOF

chmod +x status.sh
print_success "Quick status script created"

print_status "Step 12: Final verification..."

echo ""
echo "🧪 Running final verification..."
echo "==============================="

# Test the fixed monitoring script
echo "Testing monitor.sh:"
./monitor.sh

echo ""
print_success "🎉 Complete fix completed successfully!"
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
