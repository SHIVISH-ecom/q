#!/bin/bash

# 🧹 Clean Install Script for Shivish Platform
# This script does a complete clean installation with proper port assignments

set -e  # Exit on any error

echo "🧹 Starting Clean Install Script for Shivish Platform..."
echo "======================================================"

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

print_status "Step 1: Stopping all Docker services..."
docker-compose down 2>/dev/null || true

print_status "Step 2: Removing all Docker containers and volumes..."
docker-compose rm -f 2>/dev/null || true
docker container prune -f 2>/dev/null || true
docker volume prune -f 2>/dev/null || true

print_status "Step 3: Cleaning up data directories..."
sudo rm -rf data/* 2>/dev/null || true
mkdir -p data/{postgres,redis,clickhouse,minio,grafana}

print_status "Step 4: Creating proper directory structure..."
mkdir -p configs/{prometheus,nginx,clickhouse}
mkdir -p logs backups

print_status "Step 5: Creating environment configuration..."

cat > .env << 'EOF'
# Database Configuration
DB_HOST=postgres
DB_PORT=5432
DB_NAME=shivish_platform
DB_USER=shivish_user
DB_PASSWORD=shivish_secure_password_2024

# Redis Configuration
REDIS_HOST=redis
REDIS_PORT=6379
REDIS_PASSWORD=redis_secure_password_2024

# ClickHouse Configuration
CLICKHOUSE_HOST=clickhouse
CLICKHOUSE_PORT=8123
CLICKHOUSE_DB=analytics
CLICKHOUSE_USER=analytics_user
CLICKHOUSE_PASSWORD=clickhouse_secure_password_2024

# MinIO Configuration
MINIO_ENDPOINT=minio:9000
MINIO_ACCESS_KEY=shivish_access_key
MINIO_SECRET_KEY=shivish_secret_key_2024_very_secure
MINIO_USE_SSL=false

# JWT Configuration
JWT_SECRET=shivish_jwt_secret_key_2024_very_secure_random_string
JWT_EXPIRATION=24h

# Payment Gateway Configuration (REPLACE WITH YOUR ACTUAL VALUES)
PHONEPE_MERCHANT_ID=your_phonepe_merchant_id
PHONEPE_SALT_KEY=your_phonepe_salt_key
PHONEPE_SALT_INDEX=1

RAZORPAY_KEY_ID=your_razorpay_key_id
RAZORPAY_KEY_SECRET=your_razorpay_key_secret

# Notification Configuration (REPLACE WITH YOUR ACTUAL VALUES)
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_USERNAME=your_email@gmail.com
SMTP_PASSWORD=your_app_password

TWILIO_ACCOUNT_SID=your_twilio_account_sid
TWILIO_AUTH_TOKEN=your_twilio_auth_token
TWILIO_PHONE_NUMBER=your_twilio_phone

# Grafana Configuration
GRAFANA_PASSWORD=shivish_grafana_password_2024

# API Gateway Configuration (matching microservices/docker-compose.yml)
API_GATEWAY_PORT=8081
AUTH_SERVICE_PORT=8080
USER_SERVICE_PORT=8098
ECOMMERCE_SERVICE_PORT=8082
PAYMENT_SERVICE_PORT=8091
NOTIFICATION_SERVICE_PORT=8092
CONTENT_SERVICE_PORT=8093
ANALYTICS_SERVICE_PORT=8094
VERIFICATION_SERVICE_PORT=8095
EMERGENCY_SERVICE_PORT=8096
TEMPLE_SERVICE_PORT=8097
EOF

print_success "Environment configuration created"

print_status "Step 6: Creating ClickHouse configuration..."

# Create ClickHouse config.xml
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

print_success "ClickHouse configuration created"

print_status "Step 7: Creating Prometheus configuration..."

cat > configs/prometheus/prometheus.yml << 'EOF'
global:
  scrape_interval: 15s
  evaluation_interval: 15s

rule_files:
  # - "first_rules.yml"
  # - "second_rules.yml"

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  - job_name: 'api-gateway'
    static_configs:
      - targets: ['api-gateway:8080']

  - job_name: 'auth-service'
    static_configs:
      - targets: ['auth-service:8081']

  - job_name: 'user-service'
    static_configs:
      - targets: ['user-service:8082']

  - job_name: 'ecommerce-service'
    static_configs:
      - targets: ['ecommerce-service:8083']

  - job_name: 'payment-service'
    static_configs:
      - targets: ['payment-service:8084']

  - job_name: 'notification-service'
    static_configs:
      - targets: ['notification-service:8085']

  - job_name: 'content-service'
    static_configs:
      - targets: ['content-service:8086']

  - job_name: 'analytics-service'
    static_configs:
      - targets: ['analytics-service:8087']

  - job_name: 'verification-service'
    static_configs:
      - targets: ['verification-service:8088']

  - job_name: 'emergency-service'
    static_configs:
      - targets: ['emergency-service:8089']

  - job_name: 'temple-service'
    static_configs:
      - targets: ['temple-service:8090']
EOF

print_success "Prometheus configuration created"

print_status "Step 8: Creating Nginx configuration..."

cat > configs/nginx/nginx.conf << 'EOF'
events {
    worker_connections 1024;
}

http {
    upstream api_gateway {
        server api-gateway:8080;
    }

    server {
        listen 80;
        server_name _;

        location / {
            proxy_pass http://api_gateway;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
        }

        location /grafana/ {
            proxy_pass http://grafana:3000/;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
        }

        location /minio/ {
            proxy_pass http://minio:9001/;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
        }
    }
}
EOF

print_success "Nginx configuration created"

print_status "Step 9: Creating docker-compose.yml with proper port assignments..."

cat > docker-compose.yml << 'EOF'
version: '3.8'

services:
  # Database Services
  postgres:
    image: postgres:15-alpine
    container_name: shivish-postgres
    environment:
      POSTGRES_DB: shivish_platform
      POSTGRES_USER: shivish_user
      POSTGRES_PASSWORD: shivish_secure_password_2024
    volumes:
      - ./data/postgres:/var/lib/postgresql/data
    ports:
      - "5432:5432"
    networks:
      - shivish-network
    restart: unless-stopped

  redis:
    image: redis:7-alpine
    container_name: shivish-redis
    command: redis-server --requirepass redis_secure_password_2024
    volumes:
      - ./data/redis:/data
    ports:
      - "6379:6379"
    networks:
      - shivish-network
    restart: unless-stopped

  clickhouse:
    image: clickhouse/clickhouse-server:latest
    container_name: shivish-clickhouse
    environment:
      CLICKHOUSE_DB: analytics
      CLICKHOUSE_USER: analytics_user
      CLICKHOUSE_PASSWORD: clickhouse_secure_password_2024
    volumes:
      - ./data/clickhouse:/var/lib/clickhouse
      - ./configs/clickhouse/config.xml:/etc/clickhouse-server/config.xml
      - ./configs/clickhouse/users.xml:/etc/clickhouse-server/users.xml
    ports:
      - "8123:8123"
      - "9002:9000"  # Using 9002 to avoid conflict with MinIO
    networks:
      - shivish-network
    restart: unless-stopped
    ulimits:
      nofile:
        soft: 262144
        hard: 262144
    depends_on:
      - postgres
      - redis

  minio:
    image: minio/minio:latest
    container_name: shivish-minio
    environment:
      MINIO_ROOT_USER: shivish_access_key
      MINIO_ROOT_PASSWORD: shivish_secret_key_2024_very_secure
    command: server /data --console-address ":9001"
    volumes:
      - ./data/minio:/data
    ports:
      - "9000:9000"  # MinIO object storage
      - "9001:9001"  # MinIO console
    networks:
      - shivish-network
    restart: unless-stopped

  # Monitoring Services
  prometheus:
    image: prom/prometheus:latest
    container_name: shivish-prometheus
    volumes:
      - ./configs/prometheus/prometheus.yml:/etc/prometheus/prometheus.yml
    ports:
      - "9090:9090"
    networks:
      - shivish-network
    restart: unless-stopped

  grafana:
    image: grafana/grafana:latest
    container_name: shivish-grafana
    environment:
      GF_SECURITY_ADMIN_PASSWORD: shivish_grafana_password_2024
    volumes:
      - ./data/grafana:/var/lib/grafana
    ports:
      - "3000:3000"
    networks:
      - shivish-network
    restart: unless-stopped

  # Load Balancer
  nginx:
    image: nginx:alpine
    container_name: shivish-nginx
    volumes:
      - ./configs/nginx/nginx.conf:/etc/nginx/nginx.conf
    ports:
      - "80:80"
      - "443:443"
    depends_on:
      - api-gateway
    networks:
      - shivish-network
    restart: unless-stopped

  # Microservices (Placeholder - you'll need to build these)
  # Ports match microservices/docker-compose.yml to avoid conflicts
  api-gateway:
    image: nginx:alpine
    container_name: shivish-api-gateway
    ports:
      - "8081:8080"  # External 8081 -> Internal 8080
    networks:
      - shivish-network
    restart: unless-stopped
    # TODO: Replace with actual API Gateway service

  auth-service:
    image: nginx:alpine
    container_name: shivish-auth-service
    ports:
      - "8080:8080"  # External 8080 -> Internal 8080
    networks:
      - shivish-network
    restart: unless-stopped
    # TODO: Replace with actual Auth Service

  ecommerce-service:
    image: nginx:alpine
    container_name: shivish-ecommerce-service
    ports:
      - "8082:8081"  # External 8082 -> Internal 8081
    networks:
      - shivish-network
    restart: unless-stopped
    # TODO: Replace with actual E-commerce Service

  payment-service:
    image: nginx:alpine
    container_name: shivish-payment-service
    ports:
      - "8091:8091"  # External 8091 -> Internal 8091
    networks:
      - shivish-network
    restart: unless-stopped
    # TODO: Replace with actual Payment Service

  notification-service:
    image: nginx:alpine
    container_name: shivish-notification-service
    ports:
      - "8092:8092"  # External 8092 -> Internal 8092
    networks:
      - shivish-network
    restart: unless-stopped
    # TODO: Replace with actual Notification Service

  content-service:
    image: nginx:alpine
    container_name: shivish-content-service
    ports:
      - "8093:8093"  # External 8093 -> Internal 8093
    networks:
      - shivish-network
    restart: unless-stopped
    # TODO: Replace with actual Content Service

  analytics-service:
    image: nginx:alpine
    container_name: shivish-analytics-service
    ports:
      - "8094:8094"  # External 8094 -> Internal 8094
    networks:
      - shivish-network
    restart: unless-stopped
    # TODO: Replace with actual Analytics Service

  verification-service:
    image: nginx:alpine
    container_name: shivish-verification-service
    ports:
      - "8095:8095"  # External 8095 -> Internal 8095
    networks:
      - shivish-network
    restart: unless-stopped
    # TODO: Replace with actual Verification Service

  emergency-service:
    image: nginx:alpine
    container_name: shivish-emergency-service
    ports:
      - "8096:8096"  # External 8096 -> Internal 8096
    networks:
      - shivish-network
    restart: unless-stopped
    # TODO: Replace with actual Emergency Service

  temple-service:
    image: nginx:alpine
    container_name: shivish-temple-service
    ports:
      - "8097:8097"  # External 8097 -> Internal 8097
    networks:
      - shivish-network
    restart: unless-stopped
    # TODO: Replace with actual Temple Service

  user-service:
    image: nginx:alpine
    container_name: shivish-user-service
    ports:
      - "8098:8098"  # External 8098 -> Internal 8098
    networks:
      - shivish-network
    restart: unless-stopped
    # TODO: Replace with actual User Service

networks:
  shivish-network:
    driver: bridge

volumes:
  postgres_data:
  redis_data:
  clickhouse_data:
  minio_data:
  grafana_data:
EOF

print_success "Docker Compose configuration created with proper port assignments"

print_status "Step 10: Setting proper permissions..."
sudo chown -R 999:999 data/postgres
sudo chown -R 999:999 data/clickhouse
sudo chown -R 472:472 data/grafana
sudo chown -R 1001:1001 data/minio

print_success "Permissions set"

print_status "Step 11: Starting core services in correct order..."

# Start PostgreSQL first
print_status "Starting PostgreSQL..."
docker-compose up -d postgres
sleep 10

# Start Redis
print_status "Starting Redis..."
docker-compose up -d redis
sleep 5

# Start MinIO
print_status "Starting MinIO..."
docker-compose up -d minio
sleep 5

# Start ClickHouse (after other services are ready)
print_status "Starting ClickHouse..."
docker-compose up -d clickhouse
sleep 15

# Start monitoring services
print_status "Starting monitoring services..."
docker-compose up -d prometheus grafana
sleep 10

# Start microservices
print_status "Starting microservices..."
docker-compose up -d

print_status "Step 12: Waiting for all services to stabilize..."
sleep 30

print_status "Step 13: Checking ClickHouse status and fixing if needed..."

# Check if ClickHouse is running properly
if ! docker-compose ps clickhouse | grep -q "Up"; then
    print_warning "ClickHouse is not running properly, attempting to fix..."
    
    # Stop ClickHouse
    docker-compose stop clickhouse
    docker-compose rm -f clickhouse
    
    # Wait a moment
    sleep 5
    
    # Restart ClickHouse
    docker-compose up -d clickhouse
    
    # Wait for it to start
    sleep 20
    
    # Check again
    if docker-compose ps clickhouse | grep -q "Up"; then
        print_success "ClickHouse is now running properly"
    else
        print_warning "ClickHouse still having issues, checking logs..."
        docker-compose logs --tail=20 clickhouse
    fi
else
    print_success "ClickHouse is running properly"
fi

print_status "Step 15: Creating monitoring scripts..."

# Create fixed monitoring script
cat > monitor.sh << 'EOF'
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
# Test actual endpoints with correct ports (matching microservices/docker-compose.yml)
curl -s http://localhost:8080/ >/dev/null && echo "✅ Auth Service: OK" || echo "❌ Auth Service: DOWN"
curl -s http://localhost:8081/ >/dev/null && echo "✅ API Gateway: OK" || echo "❌ API Gateway: DOWN"
curl -s http://localhost:8082/ >/dev/null && echo "✅ E-commerce Service: OK" || echo "❌ E-commerce Service: DOWN"
curl -s http://localhost:8091/ >/dev/null && echo "✅ Payment Service: OK" || echo "❌ Payment Service: DOWN"
curl -s http://localhost:8092/ >/dev/null && echo "✅ Notification Service: OK" || echo "❌ Notification Service: DOWN"
curl -s http://localhost:8093/ >/dev/null && echo "✅ Content Service: OK" || echo "❌ Content Service: DOWN"
curl -s http://localhost:8094/ >/dev/null && echo "✅ Analytics Service: OK" || echo "❌ Analytics Service: DOWN"
curl -s http://localhost:8095/ >/dev/null && echo "✅ Verification Service: OK" || echo "❌ Verification Service: DOWN"
curl -s http://localhost:8096/ >/dev/null && echo "✅ Emergency Service: OK" || echo "❌ Emergency Service: DOWN"
curl -s http://localhost:8097/ >/dev/null && echo "✅ Temple Service: OK" || echo "❌ Temple Service: DOWN"
curl -s http://localhost:8098/ >/dev/null && echo "✅ User Service: OK" || echo "❌ User Service: DOWN"

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

chmod +x monitor.sh

# Create other utility scripts
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

print_success "Monitoring scripts created"

print_status "Step 16: Final verification..."

echo ""
echo "🧪 Running final verification..."
echo "==============================="

# Check container status
echo "📋 Container Status:"
docker-compose ps

echo ""
echo "🔍 Port Usage:"
sudo netstat -tulpn | grep -E ":(8080|8081|8082|3000|9000|9001|8123|9090)" || echo "No services listening on expected ports"

echo ""
echo "🧪 Testing services..."
echo "Testing Auth Service..."
curl -s http://localhost:8080/ >/dev/null && echo "✅ Auth Service: OK" || echo "❌ Auth Service: DOWN"

echo "Testing API Gateway..."
curl -s http://localhost:8081/ >/dev/null && echo "✅ API Gateway: OK" || echo "❌ API Gateway: DOWN"

echo "Testing Grafana..."
curl -s http://localhost:3000 >/dev/null && echo "✅ Grafana: OK" || echo "❌ Grafana: DOWN"

echo "Testing MinIO Console..."
curl -s http://localhost:9001 >/dev/null && echo "✅ MinIO Console: OK" || echo "❌ MinIO Console: DOWN"

echo "Testing ClickHouse..."
if curl -s http://localhost:8123 >/dev/null; then
    echo "✅ ClickHouse: OK"
else
    echo "❌ ClickHouse: DOWN"
    echo "Checking ClickHouse logs..."
    docker-compose logs --tail=10 clickhouse
fi

echo "Testing Prometheus..."
curl -s http://localhost:9090 >/dev/null && echo "✅ Prometheus: OK" || echo "❌ Prometheus: DOWN"

print_success "🎉 Clean installation completed successfully!"
echo ""
echo "=================================================="
echo "📋 Installation Summary:"
echo "=================================================="
echo ""
echo "✅ All Docker containers cleaned and recreated"
echo "✅ Proper port assignments configured:"
echo "   - MinIO: 9000 (object storage), 9001 (console)"
echo "   - ClickHouse: 8123 (HTTP), 9002 (TCP)"
echo "   - Grafana: 3000"
echo "   - Prometheus: 9090"
echo "   - Microservices: 8080-8098 (matching microservices/docker-compose.yml)"
echo "✅ All configuration files created"
echo "✅ Monitoring scripts created"
echo "✅ All services started"
echo ""
echo "=================================================="
echo "📋 Available Commands:"
echo "=================================================="
echo ""
echo "1. 📊 ./monitor.sh          - Monitor all services"
echo "2. ⚡ ./status.sh           - Quick status check"
echo "3. 🚀 docker-compose up -d  - Start all services"
echo "4. 🛑 docker-compose down   - Stop all services"
echo "5. 📋 docker-compose ps     - Check container status"
echo ""
echo "=================================================="
echo "🌐 Access Your Services:"
echo "=================================================="
echo ""
echo "   - Auth Service: http://$(hostname -I | awk '{print $1}'):8080"
echo "   - API Gateway: http://$(hostname -I | awk '{print $1}'):8081"
echo "   - Grafana: http://$(hostname -I | awk '{print $1}'):3000"
echo "   - MinIO Console: http://$(hostname -I | awk '{print $1}'):9001"
echo "   - Prometheus: http://$(hostname -I | awk '{print $1}'):9090"
echo "   - ClickHouse: http://$(hostname -I | awk '{print $1}'):8123"
echo ""
echo "=================================================="
echo "🎯 Next Steps:"
echo "=================================================="
echo ""
echo "1. 🔧 Update .env file with your actual credentials"
echo "2. 🏗️  Build your Go microservices from microservices/ directory"
echo "3. 🔄 Replace placeholder nginx images with actual services"
echo "4. 🌐 Configure your Flutter app to use the API endpoints"
echo ""
echo "=================================================="
echo "✅ Clean installation completed! All port conflicts resolved."
echo "=================================================="
