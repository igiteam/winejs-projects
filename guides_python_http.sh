#!/bin/bash
# Complete Strategy Guides Server Setup
# Using nginx alias to serve files directly (no Python server needed)

# Get domain from user
echo "🚀 Strategy Guides HTTP Server Setup"
echo "===================================="
echo ""
read -p "Enter your domain (default: flipbook.gitgpt.chat): " DOMAIN_INPUT
DOMAIN="${DOMAIN_INPUT:-flipbook.gitgpt.chat}"

GUIDES_DIR="/mnt/data/Strategy_Guides/Strategy Guides"
PORT="8000"

echo ""
echo "📋 Configuration:"
echo "   Domain: $DOMAIN"
echo "   Path: $GUIDES_DIR"
echo ""

# Check if /guides/ already exists in config
NGINX_CONFIG="/etc/nginx/sites-available/$DOMAIN"

if [ ! -f "$NGINX_CONFIG" ]; then
    echo "⚠️ Nginx config for $DOMAIN not found!"
    echo "   Using default site config..."
    NGINX_CONFIG="/etc/nginx/sites-available/default"
fi

# Check if /guides/ already exists
if grep -q "location /guides/" "$NGINX_CONFIG" 2>/dev/null; then
    echo "✅ /guides/ location already exists in $NGINX_CONFIG"
else
    echo "📝 Adding /guides/ location to nginx config..."
    
    # Backup the config
    BACKUP_FILE="$NGINX_CONFIG.backup.$(date +%Y%m%d_%H%M%S)"
    cp "$NGINX_CONFIG" "$BACKUP_FILE"
    echo "✅ Backup created: $BACKUP_FILE"
    
    # Find the server block
    SERVER_START=$(grep -n "listen 443" "$NGINX_CONFIG" | head -1 | cut -d: -f1)
    
    if [ -z "$SERVER_START" ]; then
        SERVER_START=$(grep -n "listen 80" "$NGINX_CONFIG" | head -1 | cut -d: -f1)
    fi
    
    if [ -z "$SERVER_START" ]; then
        echo "❌ Could not find server block"
        exit 1
    fi
    
    # Find the closing brace
    BRACE_COUNT=0
    LINE_NUM=$SERVER_START
    TOTAL_LINES=$(wc -l < "$NGINX_CONFIG")
    SERVER_END=""
    
    while [ $LINE_NUM -le $TOTAL_LINES ]; do
        LINE=$(sed -n "${LINE_NUM}p" "$NGINX_CONFIG")
        for ((i=0; i<${#LINE}; i++)); do
            char="${LINE:$i:1}"
            if [ "$char" = "{" ]; then
                BRACE_COUNT=$((BRACE_COUNT + 1))
            elif [ "$char" = "}" ]; then
                BRACE_COUNT=$((BRACE_COUNT - 1))
            fi
        done
        if [ $BRACE_COUNT -eq 0 ]; then
            SERVER_END=$LINE_NUM
            break
        fi
        LINE_NUM=$((LINE_NUM + 1))
    done
    
    if [ -z "$SERVER_END" ]; then
        echo "❌ Could not find closing brace"
        exit 1
    fi
    
    # Insert the location block with alias
    sed -i "${SERVER_END}i\\
    # Strategy Guides - Python HTTP Server Proxy\n\
    location /guides/ {\n\
        alias \"${GUIDES_DIR}/\";\n\
        autoindex on;\n\
        autoindex_exact_size off;\n\
        autoindex_localtime on;\n\
    }\n" "$NGINX_CONFIG"
    
    echo "✅ Added /guides/ location to $NGINX_CONFIG"
fi

# Test and reload nginx
echo "🔄 Testing nginx configuration..."
if nginx -t 2>&1; then
    systemctl reload nginx
    echo "✅ Nginx reloaded successfully!"
else
    echo "❌ Nginx configuration error!"
    echo ""
    echo "🔄 Restoring backup..."
    LATEST_BACKUP=$(ls -t "$NGINX_CONFIG.backup."* 2>/dev/null | head -1)
    if [ -f "$LATEST_BACKUP" ]; then
        mv "$LATEST_BACKUP" "$NGINX_CONFIG"
        echo "✅ Restored from backup"
        nginx -t && systemctl reload nginx
    fi
    exit 1
fi

# 4. Show status
echo ""
echo "📊 STATUS:"
echo "   Server URL: https://$DOMAIN/guides/"
echo "   Local path: $GUIDES_DIR"
echo ""
echo "🌐 Open in browser: https://$DOMAIN/guides/"