#!/bin/bash

# SSL Certificate Renewal Script
# This script manually renews SSL certificates and reloads nginx

set -e

# Colors for output
RED=\'\\033[0;31m\'
GREEN=\'\\033[0;32m\'
YELLOW=\'\\033[1;33m\'
NC=\'\\033[0m\'

echo -e \"${GREEN}=== SSL Certificate Renewal ===${NC}\"

# Check if docker-compose is running
if ! docker-compose ps | grep -q \"Up\"; then
    echo -e \"${RED}Error: Docker containers are not running${NC}\"
    echo \"Please start the containers first with: docker-compose up -d\"
    exit 1
fi

# Check certificate expiration
echo -e \"${YELLOW}Checking certificate expiration...${NC}\"
docker-compose run --rm certbot certificates

# Renew certificates
echo -e \"${YELLOW}Attempting to renew certificates...${NC}\"
docker-compose run --rm certbot renew

# Reload nginx to use new certificates
echo -e \"${YELLOW}Reloading nginx configuration...${NC}\"
docker-compose exec nginx nginx -s reload

echo -e \"${GREEN}Certificate renewal process completed!${NC}\"

# Check certificate validity
echo -e \"${YELLOW}Verifying certificate validity...${NC}\"
DOMAIN=$(grep \"server_name\" nginx/conf.d/nextjs.conf | head -1 | awk \\\'{print $2}\\\' | sed \\\\\'s/;//\\\\\')

if [ ! -z \"$DOMAIN\" ] && [ \"$DOMAIN\" != \"your-domain.com\" ]; then
    echo \"Checking certificate for $DOMAIN...\"
    echo | openssl s_client -servername $DOMAIN -connect $DOMAIN:443 2>/dev/null | openssl x509 -noout -dates
else
    echo -e \"${YELLOW}Domain not configured or still using default. Please check nginx configuration.${NC}\"
fi

echo -e \"${GREEN}Renewal process completed successfully!${NC}\"


