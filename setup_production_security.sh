#!/bin/bash

# 🔒 Complete Production Security Setup Script for Shivish Platform
# This script sets up firewall, SSL certificates, and provides production URLs

set -e  # Exit on any error

echo "🔒 Starting Production Security Setup for Shivish Platform..."
echo "============================================================="

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
    print_error "Please run setup_production.sh first"
    exit 1
fi

# Change to target directory
print_status "Changing to target directory: $TARGET_DIR"
cd "$TARGET_DIR"

print_status "Step 1: Setting up Firewall Rules..."

# Install ufw if not present
if ! command -v ufw &> /dev/null; then
    print_status "Installing UFW firewall..."
    sudo apt update
    sudo apt install -y ufw
fi

# Reset firewall to default
print_status "Configuring UFW firewall..."
sudo ufw --force reset

# Set default policies
sudo ufw default deny incoming
sudo ufw default allow outgoing

# Allow SSH (important!)
sudo ufw allow ssh
sudo ufw allow 22/tcp

# Allow HTTP and HTTPS
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp

# Allow specific microservice ports (for direct access if needed)
sudo ufw allow 8080:8099/tcp

# Allow monitoring ports
sudo ufw allow 3000/tcp  # Grafana
sudo ufw allow 9090/tcp  # Prometheus
sudo ufw allow 9001/tcp  # MinIO Console
sudo ufw allow 8123/tcp  # ClickHouse

# Enable firewall
sudo ufw --force enable

print_success "Firewall configured successfully!"

print_status "Step 2: Installing Certbot for SSL certificates..."

# Install certbot
sudo apt update
sudo apt install -y certbot python3-certbot-nginx

print_success "Certbot installed successfully!"

print_status "Step 3: Getting External IP Address..."

# Get external IP
EXTERNAL_IP=$(curl -s ifconfig.me 2>/dev/null || curl -s ipinfo.io/ip 2>/dev/null || curl -s icanhazip.com 2>/dev/null)
INTERNAL_IP=$(hostname -I | awk '{print $1}')

if [ -z "$EXTERNAL_IP" ]; then
    print_error "Could not determine external IP address"
    print_error "Please manually find your VM's public IP address"
    exit 1
fi

print_success "External IP detected: $EXTERNAL_IP"
print_success "Internal IP: $INTERNAL_IP"

print_status "Step 4: Setting up SSL Certificate..."

# Create nginx configuration for SSL
print_status "Creating nginx SSL configuration..."

# Create SSL nginx config
cat > configs/nginx/nginx-ssl.conf << EOF
events {
    worker_connections 1024;
}

http {
    # Redirect HTTP to HTTPS
    server {
        listen 80;
        server_name $EXTERNAL_IP;
        return 301 https://\$server_name\$request_uri;
    }

    # HTTPS server
    server {
        listen 443 ssl http2;
        server_name $EXTERNAL_IP;

        # SSL Configuration
        ssl_certificate /etc/letsencrypt/live/$EXTERNAL_IP/fullchain.pem;
        ssl_certificate_key /etc/letsencrypt/live/$EXTERNAL_IP/privkey.pem;
        
        # SSL Security Settings
        ssl_protocols TLSv1.2 TLSv1.3;
        ssl_ciphers ECDHE-RSA-AES256-GCM-SHA512:DHE-RSA-AES256-GCM-SHA512:ECDHE-RSA-AES256-GCM-SHA384:DHE-RSA-AES256-GCM-SHA384;
        ssl_prefer_server_ciphers off;
        ssl_session_cache shared:SSL:10m;
        ssl_session_timeout 10m;

        # Security Headers
        add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
        add_header X-Frame-Options DENY always;
        add_header X-Content-Type-Options nosniff always;
        add_header X-XSS-Protection "1; mode=block" always;
        add_header Referrer-Policy "strict-origin-when-cross-origin" always;

        # Upstream definitions
        upstream api_gateway {
            server api-gateway:8080;
        }

        upstream auth_service {
            server auth-service:8080;
        }

        upstream user_service {
            server user-service:8098;
        }

        upstream ecommerce_service {
            server ecommerce-service:8081;
        }

        upstream payment_service {
            server payment-service:8091;
        }

        upstream notification_service {
            server notification-service:8092;
        }

        upstream content_service {
            server content-service:8093;
        }

        upstream analytics_service {
            server analytics-service:8094;
        }

        upstream verification_service {
            server verification-service:8095;
        }

        upstream emergency_service {
            server emergency-service:8096;
        }

        upstream temple_service {
            server temple-service:8097;
        }

        # API Gateway (main entry point)
        location /api/ {
            proxy_pass http://api_gateway/;
            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto \$scheme;
            proxy_set_header X-Forwarded-Host \$host;
            proxy_set_header X-Forwarded-Port \$server_port;
        }

        # Direct service access
        location /auth/ {
            proxy_pass http://auth_service/;
            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto \$scheme;
        }

        location /users/ {
            proxy_pass http://user_service/;
            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto \$scheme;
        }

        location /ecommerce/ {
            proxy_pass http://ecommerce_service/;
            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto \$scheme;
        }

        location /payments/ {
            proxy_pass http://payment_service/;
            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto \$scheme;
        }

        location /notifications/ {
            proxy_pass http://notification_service/;
            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto \$scheme;
        }

        location /content/ {
            proxy_pass http://content_service/;
            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto \$scheme;
        }

        location /analytics/ {
            proxy_pass http://analytics_service/;
            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto \$scheme;
        }

        location /verification/ {
            proxy_pass http://verification_service/;
            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto \$scheme;
        }

        location /emergency/ {
            proxy_pass http://emergency_service/;
            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto \$scheme;
        }

        location /temple/ {
            proxy_pass http://temple_service/;
            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto \$scheme;
        }

        # Admin interfaces
        location /grafana/ {
            proxy_pass http://grafana:3000/;
            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto \$scheme;
        }

        location /minio/ {
            proxy_pass http://minio:9001/;
            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto \$scheme;
        }

        location /prometheus/ {
            proxy_pass http://prometheus:9090/;
            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto \$scheme;
        }
    }
}
EOF

print_success "SSL nginx configuration created!"

print_status "Step 5: Obtaining SSL Certificate..."

# Stop nginx if running
sudo systemctl stop nginx 2>/dev/null || true

# Get SSL certificate
print_status "Requesting SSL certificate for $EXTERNAL_IP..."
if sudo certbot certonly --standalone --non-interactive --agree-tos --email admin@$EXTERNAL_IP -d $EXTERNAL_IP; then
    print_success "SSL certificate obtained successfully!"
else
    print_warning "SSL certificate request failed. This might be due to:"
    print_warning "1. Port 80 is not accessible from the internet"
    print_warning "2. Domain/IP is not properly configured"
    print_warning "3. Firewall blocking the request"
    print_warning "Continuing with HTTP-only setup..."
    SSL_AVAILABLE=false
fi

print_status "Step 6: Updating Docker Compose for SSL..."

# Update docker-compose to use SSL nginx config
if [ "$SSL_AVAILABLE" = "false" ]; then
    print_status "Using HTTP configuration (SSL not available)..."
    # Use the existing HTTP configuration
    cp configs/nginx/nginx-production.conf configs/nginx/nginx.conf
else
    print_status "Using SSL configuration..."
    cp configs/nginx/nginx-ssl.conf configs/nginx/nginx.conf
fi

print_status "Step 7: Restarting Services with SSL..."

# Restart services
docker-compose -f docker-compose-production.yml down
docker-compose -f docker-compose-production.yml up -d

print_status "Step 8: Setting up SSL Certificate Auto-Renewal..."

# Create renewal script
cat > /opt/shivish/renew_ssl.sh << 'EOF'
#!/bin/bash
# SSL Certificate Renewal Script

echo "🔄 Renewing SSL certificates..."

# Stop nginx
sudo systemctl stop nginx 2>/dev/null || true

# Renew certificate
sudo certbot renew --quiet

# Restart nginx
sudo systemctl start nginx 2>/dev/null || true

# Restart docker services
cd /opt/shivish
docker-compose -f docker-compose-production.yml restart nginx

echo "✅ SSL certificate renewal completed!"
EOF

chmod +x /opt/shivish/renew_ssl.sh

# Add to crontab for auto-renewal
(crontab -l 2>/dev/null; echo "0 2 * * * /opt/shivish/renew_ssl.sh") | crontab -

print_success "SSL auto-renewal configured!"

print_status "Step 9: Testing SSL Setup..."

# Wait for services to start
sleep 10

# Test HTTP redirect
print_status "Testing HTTP to HTTPS redirect..."
if curl -s -I http://$EXTERNAL_IP | grep -q "301\|302"; then
    print_success "HTTP redirect working!"
else
    print_warning "HTTP redirect not working"
fi

# Test HTTPS
if [ "$SSL_AVAILABLE" != "false" ]; then
    print_status "Testing HTTPS connection..."
    if curl -s -k https://$EXTERNAL_IP/api/ >/dev/null; then
        print_success "HTTPS connection working!"
    else
        print_warning "HTTPS connection not working"
    fi
fi

print_status "Step 10: Creating Production URLs Script..."

# Create production URLs script
cat > get_production_urls.sh << EOF
#!/bin/bash

echo "🌐 Shivish Platform Production URLs"
echo "==================================="

EXTERNAL_IP="$EXTERNAL_IP"
INTERNAL_IP="$INTERNAL_IP"

echo "📱 Internal IP (VM network): \$INTERNAL_IP"
echo "🌍 External IP (for your app): \$EXTERNAL_IP"
echo ""

if [ "$SSL_AVAILABLE" != "false" ]; then
    echo "🔒 HTTPS URLs (Secure - Use these in production):"
    echo "=================================================="
    echo ""
    echo "   Main API: https://\$EXTERNAL_IP/api/"
    echo "   Auth Service: https://\$EXTERNAL_IP/auth/"
    echo "   User Service: https://\$EXTERNAL_IP/users/"
    echo "   E-commerce Service: https://\$EXTERNAL_IP/ecommerce/"
    echo "   Payment Service: https://\$EXTERNAL_IP/payments/"
    echo "   Notification Service: https://\$EXTERNAL_IP/notifications/"
    echo "   Content Service: https://\$EXTERNAL_IP/content/"
    echo "   Analytics Service: https://\$EXTERNAL_IP/analytics/"
    echo "   Verification Service: https://\$EXTERNAL_IP/verification/"
    echo "   Emergency Service: https://\$EXTERNAL_IP/emergency/"
    echo "   Temple Service: https://\$EXTERNAL_IP/temple/"
    echo ""
    echo "   Admin URLs:"
    echo "   Grafana: https://\$EXTERNAL_IP/grafana/"
    echo "   MinIO Console: https://\$EXTERNAL_IP/minio/"
    echo "   Prometheus: https://\$EXTERNAL_IP/prometheus/"
    echo ""
    echo "📱 Flutter App Configuration:"
    echo "============================="
    echo "const String API_BASE_URL = 'https://\$EXTERNAL_IP/api/';"
else
    echo "⚠️  HTTP URLs (Development only - Not secure for production):"
    echo "============================================================="
    echo ""
    echo "   Main API: http://\$EXTERNAL_IP/api/"
    echo "   Auth Service: http://\$EXTERNAL_IP/auth/"
    echo "   User Service: http://\$EXTERNAL_IP/users/"
    echo "   E-commerce Service: http://\$EXTERNAL_IP/ecommerce/"
    echo "   Payment Service: http://\$EXTERNAL_IP/payments/"
    echo "   Notification Service: http://\$EXTERNAL_IP/notifications/"
    echo "   Content Service: http://\$EXTERNAL_IP/content/"
    echo "   Analytics Service: http://\$EXTERNAL_IP/analytics/"
    echo "   Verification Service: http://\$EXTERNAL_IP/verification/"
    echo "   Emergency Service: http://\$EXTERNAL_IP/emergency/"
    echo "   Temple Service: http://\$EXTERNAL_IP/temple/"
    echo ""
    echo "   Admin URLs:"
    echo "   Grafana: http://\$EXTERNAL_IP/grafana/"
    echo "   MinIO Console: http://\$EXTERNAL_IP/minio/"
    echo "   Prometheus: http://\$EXTERNAL_IP/prometheus/"
    echo ""
    echo "📱 Flutter App Configuration:"
    echo "============================="
    echo "const String API_BASE_URL = 'http://\$EXTERNAL_IP/api/';"
fi

echo ""
echo "🧪 Test Your Setup:"
echo "==================="
if [ "$SSL_AVAILABLE" != "false" ]; then
    echo "1. Test HTTPS: https://\$EXTERNAL_IP/api/"
    echo "2. Test HTTP redirect: http://\$EXTERNAL_IP/api/"
else
    echo "1. Test HTTP: http://\$EXTERNAL_IP/api/"
fi
echo "3. Check firewall: sudo ufw status"
echo "4. Check SSL cert: sudo certbot certificates"

echo ""
echo "🛡️  Security Status:"
echo "==================="
echo "✅ Firewall configured and enabled"
if [ "$SSL_AVAILABLE" != "false" ]; then
    echo "✅ SSL certificate installed"
    echo "✅ HTTPS redirect configured"
    echo "✅ Auto-renewal configured"
else
    echo "⚠️  SSL certificate not available"
    echo "⚠️  Using HTTP only (not secure for production)"
fi

echo ""
echo "✅ Your Shivish platform is ready for production use!"
EOF

chmod +x get_production_urls.sh

print_success "🎉 Production Security Setup Completed Successfully!"
echo ""
echo "=================================================="
echo "📋 Security Setup Summary:"
echo "=================================================="
echo ""
echo "✅ Firewall configured and enabled"
if [ "$SSL_AVAILABLE" != "false" ]; then
    echo "✅ SSL certificate installed and configured"
    echo "✅ HTTPS redirect configured"
    echo "✅ Auto-renewal configured"
    echo "✅ Security headers configured"
else
    echo "⚠️  SSL certificate not available (using HTTP)"
fi
echo "✅ Production URLs script created"
echo ""
echo "=================================================="
echo "🌐 Get Your Production URLs:"
echo "=================================================="
echo ""
echo "Run: ./get_production_urls.sh"
echo ""
echo "=================================================="
echo "🔧 Available Commands:"
echo "=================================================="
echo ""
echo "1. ./get_production_urls.sh    - Get production URLs"
echo "2. ./monitor_production.sh    - Monitor all services"
echo "3. ./status_production.sh     - Quick status check"
echo "4. sudo ufw status            - Check firewall status"
echo "5. sudo certbot certificates  - Check SSL certificates"
echo ""
echo "=================================================="
echo "✅ Your Shivish platform is now production-ready!"
echo "=================================================="
