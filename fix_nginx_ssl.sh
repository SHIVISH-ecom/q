#!/bin/bash

echo "🔧 Fixing Nginx SSL Configuration..."
echo "===================================="

# Change to project directory
cd /opt/shivish

# Get external IP
EXTERNAL_IP=$(curl -s ifconfig.me 2>/dev/null || curl -s ipinfo.io/ip 2>/dev/null || curl -s icanhazip.com 2>/dev/null)

echo "🌐 External IP: $EXTERNAL_IP"

# Step 1: Stop nginx container
echo "🛑 Stopping nginx container..."
docker-compose -f docker-compose-production.yml stop nginx

# Step 2: Update nginx configuration
echo "📝 Updating nginx configuration..."
cat > configs/nginx/nginx.conf << EOF
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

        # SSL Configuration (Self-signed certificate)
        ssl_certificate /etc/ssl/shivish/fullchain.pem;
        ssl_certificate_key /etc/ssl/shivish/privkey.pem;
        
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

# Step 3: Start nginx container
echo "🚀 Starting nginx container..."
docker-compose -f docker-compose-production.yml up -d nginx

# Wait for nginx to start
echo "⏳ Waiting for nginx to start..."
sleep 10

# Step 4: Test connections
echo "🧪 Testing connections..."
echo "Testing HTTP redirect..."
if curl -s -I http://$EXTERNAL_IP | grep -q "301\|302"; then
    echo "✅ HTTP to HTTPS redirect working!"
else
    echo "❌ HTTP redirect not working"
fi

echo "Testing HTTPS connection..."
if curl -s -k https://$EXTERNAL_IP/api/ >/dev/null; then
    echo "✅ HTTPS connection working!"
else
    echo "❌ HTTPS connection not working"
fi

echo "Testing HTTP connection..."
if curl -s http://$EXTERNAL_IP/api/ >/dev/null; then
    echo "✅ HTTP connection working!"
else
    echo "❌ HTTP connection not working"
fi

echo ""
echo "✅ Nginx SSL configuration fixed!"
echo "🌐 Your production URLs:"
echo "   HTTP: http://$EXTERNAL_IP/api/"
echo "   HTTPS: https://$EXTERNAL_IP/api/"
