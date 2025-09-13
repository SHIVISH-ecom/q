#!/bin/bash

echo "🔍 Checking VirtualBox Network Configuration..."
echo "=============================================="

# Get network information
INTERNAL_IP=$(hostname -I | awk '{print $1}')
EXTERNAL_IP=$(curl -s ifconfig.me 2>/dev/null || curl -s ipinfo.io/ip 2>/dev/null || curl -s icanhazip.com 2>/dev/null)

echo "🏠 Internal IP (VM): $INTERNAL_IP"
echo "🌍 External IP (Internet): $EXTERNAL_IP"
echo ""

# Check if we're in VirtualBox
if [ -d "/proc/vz" ] && [ ! -d "/proc/bc" ]; then
    echo "☁️  Detected: Cloud VM (not VirtualBox)"
    echo "✅ Cloud VMs usually have external access configured automatically"
    echo "✅ Your external IP ($EXTERNAL_IP) should work from other devices"
elif [ -f "/sys/class/dmi/id/product_name" ] && grep -q "VirtualBox" /sys/class/dmi/id/product_name 2>/dev/null; then
    echo "🖥️  Detected: VirtualBox VM"
    echo "⚠️  VirtualBox needs port forwarding configuration"
    echo ""
    echo "🔧 VirtualBox Configuration Required:"
    echo "====================================="
    echo ""
    echo "1. Open VirtualBox Manager"
    echo "2. Select your Ubuntu VM"
    echo "3. Go to Settings → Network"
    echo "4. Select 'Adapter 1' (NAT)"
    echo "5. Click 'Advanced' → 'Port Forwarding'"
    echo "6. Add these rules:"
    echo ""
    echo "   Name: HTTP"
    echo "   Protocol: TCP"
    echo "   Host Port: 80"
    echo "   Guest Port: 80"
    echo ""
    echo "   Name: HTTPS"
    echo "   Protocol: TCP"
    echo "   Host Port: 443"
    echo "   Guest Port: 443"
    echo ""
    echo "   Name: SSH"
    echo "   Protocol: TCP"
    echo "   Host Port: 22"
    echo "   Guest Port: 22"
    echo ""
    echo "7. Click OK and restart your VM"
else
    echo "🖥️  Detected: Physical machine or other virtualization"
    echo "✅ External access should work directly"
fi

echo ""
echo "🧪 Testing Current Configuration:"
echo "================================"

# Test if external IP is accessible
if [ "$INTERNAL_IP" = "$EXTERNAL_IP" ]; then
    echo "✅ VM has direct external access"
    echo "✅ No VirtualBox port forwarding needed"
else
    echo "⚠️  VM has private IP, needs port forwarding"
    echo "⚠️  External devices cannot access $INTERNAL_IP"
fi

echo ""
echo "🌐 Test URLs:"
echo "============="
echo "From VM: http://$INTERNAL_IP/api/"
echo "From external: http://$EXTERNAL_IP/api/"
echo ""
echo "📱 Test from your mobile:"
echo "1. Open browser"
echo "2. Go to: http://$EXTERNAL_IP/api/"
echo "3. If it works, VirtualBox is configured correctly"
echo "4. If it doesn't work, you need to configure port forwarding"
echo ""
echo "🔧 Quick Fix:"
echo "============="
echo "1. Configure VirtualBox port forwarding (see above)"
echo "2. Restart your VM"
echo "3. Run: ./fix_firewall.sh"
echo "4. Test from mobile: http://$EXTERNAL_IP/api/"
