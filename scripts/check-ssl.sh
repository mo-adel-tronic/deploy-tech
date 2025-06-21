#!/bin/bash

# SSL Certificate Status Check Script
# This script checks the status and expiration of SSL certificates

set -e

# Colors for output
RED=\'\\033[0;31m\'
GREEN=\'\\033[0;32m\'
YELLOW=\'\\033[1;33m\'
BLUE=\'\\033[0;34m\'
NC=\'\\033[0m\'

echo -e \"${GREEN}=== SSL Certificate Status Check ===${NC}\"

# Get domain from nginx config
DOMAIN=$(grep \"server_name\" nginx/conf.d/nextjs.conf | head -1 | awk \\\'{print $2}\\\' | sed \\\\\\'s/;//\\\\\\')

if [ -z \"$DOMAIN\" ] || [ \"$DOMAIN\" = \"technotorial.com\" ]; then
    echo -e \"${RED}Error: Domain not configured in nginx config${NC}\"
    echo \"Please update nginx/conf.d/nextjs.conf with your actual domain\"
    exit 1
fi

echo -e \"${BLUE}Domain: $DOMAIN${NC}\"

# Check if certificates exist locally
CERT_PATH=\"ssl/certbot/conf/live/$DOMAIN\"
if [ -d \"$CERT_PATH\" ]; then
    echo -e \"${GREEN}✓ Local certificates found${NC}\"
    
    # Check certificate expiration
    echo -e \"${YELLOW}Certificate expiration info:${NC}\"
    openssl x509 -in \"$CERT_PATH/fullchain.pem\" -noout -dates
    
    # Calculate days until expiration
    EXPIRY_DATE=$(openssl x509 -in \"$CERT_PATH/fullchain.pem\" -noout -enddate | cut -d= -f2)
    EXPIRY_EPOCH=$(date -d \"$EXPIRY_DATE\" +%s)
    CURRENT_EPOCH=$(date +%s)
    DAYS_UNTIL_EXPIRY=$(( (EXPIRY_EPOCH - CURRENT_EPOCH) / 86400 ))
    
    echo -e \"${BLUE}Days until expiration: $DAYS_UNTIL_EXPIRY${NC}\"
    
    if [ $DAYS_UNTIL_EXPIRY -lt 30 ]; then
        echo -e \"${RED}⚠️  Certificate expires in less than 30 days!${NC}\"
        echo -e \"${YELLOW}Consider running: ./scripts/renew-ssl.sh${NC}\"
    elif [ $DAYS_UNTIL_EXPIRY -lt 7 ]; then
        echo -e \"${RED}🚨 Certificate expires in less than 7 days!${NC}\"
        echo -e \"${RED}Run renewal immediately: ./scripts/renew-ssl.sh${NC}\"
    else
        echo -e \"${GREEN}✓ Certificate is valid for $DAYS_UNTIL_EXPIRY more days${NC}\"
    fi
    
else
    echo -e \"${RED}✗ No local certificates found${NC}\"
    echo -e \"${YELLOW}Run: ./scripts/setup-ssl.sh to generate certificates${NC}\"
fi

# Check if containers are running
echo -e \"\n${YELLOW}Container status:${NC}\"
if docker-compose ps | grep -q \"Up\"; then
    docker-compose ps
    
    # Test HTTPS connection if containers are running
    echo -e \"\n${YELLOW}Testing HTTPS connection...${NC}\"
    if command -v curl >/dev/null 2>&1; then
        if curl -s -I \"https://$DOMAIN\" >/dev/null 2>&1; then
            echo -e \"${GREEN}✓ HTTPS connection successful${NC}\"
            
            # Get certificate info from live site
            echo -e \"\n${YELLOW}Live certificate info:${NC}\"
            echo | openssl s_client -servername \"$DOMAIN\" -connect \"$DOMAIN:443\" 2>/dev/null | openssl x509 -noout -subject -issuer -dates
        else
            echo -e \"${RED}✗ HTTPS connection failed${NC}\"
            echo -e \"${YELLOW}Check if domain DNS is pointing to this server${NC}\"
        fi
    else
        echo -e \"${YELLOW}curl not available, skipping connection test${NC}\"
    fi
else
    echo -e \"${RED}✗ Containers are not running${NC}\"
    echo -e \"${YELLOW}Start with: docker-compose up -d${NC}\"
fi

# Check certbot container logs if available
if docker-compose ps certbot >/dev/null 2>&1; then
    echo -e \"\n${YELLOW}Recent certbot logs:${NC}\"
    docker-compose logs --tail=10 certbot 2>/dev/null || echo \"No certbot logs available\"
fi

echo -e \"\n${GREEN}Status check completed!${NC}\"


