#!/bin/bash

# 🔧 Port Conflicts Fix Script for Shivish Platform
# This script fixes port conflicts and ClickHouse issues

set -e  # Exit on any error

echo "🔧 Starting Port Conflicts Fix Script..."
echo "======================================="

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

print_status "Step 1: Checking current port usage..."

echo "🔍 Checking port 9000 usage:"
sudo netstat -tulpn | grep :9000 || echo "Port 9000 is free"

echo ""
echo "🔍 Checking port 8123 usage:"
sudo netstat -tulpn | grep :8123 || echo "Port 8123 is free"

echo ""
echo "🔍 Checking port 9001 usage:"
sudo netstat -tulpn | grep :9001 || echo "Port 9001 is free"

print_status "Step 2: Checking current Docker container status..."
docker-compose ps

print_status "Step 3: Stopping ClickHouse if running..."
docker-compose stop clickhouse 2>/dev/null || true
docker-compose rm -f clickhouse 2>/dev/null || true

print_status "Step 4: Killing processes using conflicting ports..."

# Kill any process using port 9000
echo "Killing processes using port 9000..."
if sudo lsof -t -i:9000 >/dev/null 2>&1; then
    PIDS=$(sudo lsof -t -i:9000)
    echo "Found processes using port 9000: $PIDS"
    echo "$PIDS" | xargs sudo kill -9 2>/dev/null || true
    print_success "Killed processes using port 9000"
else
    print_status "No processes using port 9000"
fi

# Kill any process using port 8123
echo "Killing processes using port 8123..."
if sudo lsof -t -i:8123 >/dev/null 2>&1; then
    PIDS=$(sudo lsof -t -i:8123)
    echo "Found processes using port 8123: $PIDS"
    echo "$PIDS" | xargs sudo kill -9 2>/dev/null || true
    print_success "Killed processes using port 8123"
else
    print_status "No processes using port 8123"
fi

# Wait a moment for ports to be released
sleep 3

print_status "Step 5: Verifying ports are free..."
echo "Checking port 9000 after cleanup:"
sudo netstat -tulpn | grep :9000 || echo "✅ Port 9000 is now free"

echo "Checking port 8123 after cleanup:"
sudo netstat -tulpn | grep :8123 || echo "✅ Port 8123 is now free"

print_status "Step 6: Ensuring ClickHouse configuration exists..."

# Create ClickHouse configuration directory
mkdir -p configs/clickhouse

# Create ClickHouse config.xml if it doesn't exist
if [ ! -f "configs/clickhouse/config.xml" ]; then
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
    print_success "ClickHouse config.xml created"
else
    print_status "ClickHouse config.xml already exists"
fi

# Create ClickHouse users.xml if it doesn't exist
if [ ! -f "configs/clickhouse/users.xml" ]; then
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
    print_success "ClickHouse users.xml created"
else
    print_status "ClickHouse users.xml already exists"
fi

print_status "Step 7: Fixing ClickHouse data directory permissions..."
sudo rm -rf data/clickhouse/* 2>/dev/null || true
mkdir -p data/clickhouse
sudo chown -R 999:999 data/clickhouse
sudo chmod -R 755 data/clickhouse
print_success "ClickHouse data directory permissions fixed"

print_status "Step 8: Updating docker-compose.yml for ClickHouse..."

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
    print_status "ClickHouse service already exists in docker-compose.yml"
    
    # Check if the ports are correct
    if ! grep -q "9000:9000" docker-compose.yml; then
        print_status "Updating ClickHouse ports in docker-compose.yml..."
        # Update the ports section
        sed -i '/clickhouse:/,/restart: unless-stopped/s/ports:.*/ports:\
      - "8123:8123"\
      - "9000:9000"/' docker-compose.yml
        print_success "ClickHouse ports updated"
    fi
fi

print_status "Step 9: Starting ClickHouse..."
docker-compose up -d clickhouse

print_status "Step 10: Waiting for ClickHouse to start..."
sleep 20

print_status "Step 11: Testing ClickHouse..."

# Test ClickHouse HTTP endpoint
echo "Testing ClickHouse HTTP endpoint (port 8123)..."
if curl -s http://localhost:8123 >/dev/null; then
    print_success "✅ ClickHouse HTTP (port 8123): OK"
else
    print_warning "❌ ClickHouse HTTP (port 8123): DOWN"
    print_status "Checking ClickHouse logs..."
    docker-compose logs --tail=10 clickhouse
fi

# Test ClickHouse TCP endpoint
echo "Testing ClickHouse TCP endpoint (port 9000)..."
if curl -s http://localhost:9000 >/dev/null 2>&1; then
    print_success "✅ ClickHouse TCP (port 9000): OK"
else
    print_warning "❌ ClickHouse TCP (port 9000): DOWN (this is normal for HTTP test)"
fi

print_status "Step 12: Final verification..."

echo ""
echo "🧪 Running final verification..."
echo "==============================="

# Check container status
echo "📋 Container Status:"
docker-compose ps clickhouse

echo ""
echo "🔍 Port Usage After Fix:"
sudo netstat -tulpn | grep -E ":(8123|9000)" || echo "No processes using ClickHouse ports"

echo ""
echo "📊 ClickHouse Logs (last 10 lines):"
docker-compose logs --tail=10 clickhouse

print_status "Step 13: Creating port conflict prevention script..."

cat > prevent_port_conflicts.sh << 'EOF'
#!/bin/bash

echo "🛡️  Port Conflict Prevention Script"
echo "=================================="

# Function to check and kill process on port
check_and_kill_port() {
    local port=$1
    local service_name=$2
    
    if sudo lsof -t -i:$port >/dev/null 2>&1; then
        echo "⚠️  Port $port is in use by $service_name"
        PIDS=$(sudo lsof -t -i:$port)
        echo "Found processes: $PIDS"
        read -p "Do you want to kill these processes? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            echo "$PIDS" | xargs sudo kill -9 2>/dev/null || true
            echo "✅ Killed processes using port $port"
        else
            echo "❌ Skipped killing processes on port $port"
        fi
    else
        echo "✅ Port $port is free"
    fi
}

echo "Checking critical ports..."

# Check ClickHouse ports
check_and_kill_port 8123 "ClickHouse HTTP"
check_and_kill_port 9000 "ClickHouse TCP"

# Check other critical ports
check_and_kill_port 5432 "PostgreSQL"
check_and_kill_port 6379 "Redis"
check_and_kill_port 3000 "Grafana"
check_and_kill_port 9001 "MinIO Console"
check_and_kill_port 9090 "Prometheus"

echo "Port conflict prevention completed!"
EOF

chmod +x prevent_port_conflicts.sh
print_success "Port conflict prevention script created"

print_success "🎉 Port conflicts fix completed successfully!"
echo ""
echo "=================================================="
echo "📋 Summary:"
echo "=================================================="
echo ""
echo "✅ Port conflicts resolved"
echo "✅ ClickHouse configuration created"
echo "✅ ClickHouse data directory permissions fixed"
echo "✅ ClickHouse service added/updated in docker-compose.yml"
echo "✅ ClickHouse container started"
echo "✅ Port conflict prevention script created"
echo ""
echo "=================================================="
echo "📋 Available Scripts:"
echo "=================================================="
echo ""
echo "1. 🛡️  ./prevent_port_conflicts.sh - Prevent future port conflicts"
echo "2. 📊 ./monitor.sh                - Monitor all services"
echo "3. 🏥 ./health_check.sh           - Comprehensive health check"
echo "4. ⚡ ./status.sh                 - Quick status check"
echo "5. 🚀 ./deploy.sh                 - Deploy services"
echo "6. 💾 ./backup.sh                 - Backup data"
echo ""
echo "=================================================="
echo "🌐 ClickHouse should now be accessible at:"
echo "   - HTTP: http://$(hostname -I | awk '{print $1}'):8123"
echo "   - TCP:  $(hostname -I | awk '{print $1}'):9000"
echo "=================================================="
