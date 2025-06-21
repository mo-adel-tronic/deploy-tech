#!/bin/bash

# SSL Certificate Setup Script for Let\"s Encrypt
# This script initializes SSL certificates for your domain

set -e

# Configuration
DOMAIN=\"technotorial.com\"
EMAIL=\"dr.mohamed.adel@sedu.asu.edu.eg\"
STAGING=0  # Set to 1 for testing with staging environment

# Colors for output
RED=\'\\033[0;31m\'
GREEN=\'\\033[0;32m\'
YELLOW=\'\\033[1;33m\'
NC=\'\\033[0m\' # No Color

echo -e \"${GREEN}=== SSL Certificate Setup for $DOMAIN ===${NC}\"

# Check if domain and email are set
if [ \"$DOMAIN\" = \"technotorial.com\" ] || [ \"$EMAIL\" = \"dr.mohamed.adel@sedu.asu.edu.eg\" ]; then
    echo -e \"${RED}Error: Please update DOMAIN and EMAIL variables in this script${NC}\"
    echo \"Edit the script and set your actual domain and email address\"
    exit 1
fi

# Create necessary directories
echo -e \"${YELLOW}Creating SSL directories...${NC}\"
mkdir -p ssl/certbot/conf
mkdir -p ssl/certbot/www

# Check if certificates already exist
if [ -d \"ssl/certbot/conf/live/$DOMAIN\" ]; then
    echo -e \"${YELLOW}Certificates already exist for $DOMAIN${NC}\"
    read -p \"Do you want to renew them? (y/N): \" -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo \"Exiting...\"
        exit 0
    fi
fi

# Start nginx temporarily for certificate generation
echo -e \"${YELLOW}Starting temporary nginx for certificate generation...${NC}\"

# Create temporary nginx config for certificate generation
cat > nginx/conf.d/temp-ssl.conf << EOF
server {
    listen 80;
    server_name $DOMAIN www.$DOMAIN;

    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
    }

    location / {
        return 200 \'OK\';
        add_header Content-Type text/plain;
    }
}
EOF

# Start nginx container for certificate generation
docker-compose up -d nginx

# Wait for nginx to start
echo -e \"${YELLOW}Waiting for nginx to start...${NC}\"
sleep 10

# Generate certificate
echo -e \"${YELLOW}Generating SSL certificate...${NC}\"

if [ $STAGING = 1 ]; then
    echo -e \"${YELLOW}Using Let\"s Encrypt staging environment${NC}\"
    STAGING_FLAG=\"--staging\"
else
    STAGING_FLAG=\"\"
fi

docker-compose run --rm certbot certonly \
    --webroot \
    --webroot-path=/var/www/certbot \
    --email $EMAIL \
    --agree-tos \
    --no-eff-email \
    $STAGING_FLAG \
    -d $DOMAIN \
    -d www.$DOMAIN

# Check if certificate was generated successfully
if [ -d \"ssl/certbot/conf/live/$DOMAIN\" ]; then
    echo -e \"${GREEN}Certificate generated successfully!${NC}\"
    
    # Remove temporary config
    rm nginx/conf.d/temp-ssl.conf
    
    # Update the main nginx config with the correct domain
    sed -i \"s/your-domain.com/$DOMAIN/g\" nginx/conf.d/nextjs.conf
    
    # Restart services with SSL
    echo -e \"${YELLOW}Restarting services with SSL configuration...${NC}\"
    docker-compose down
    docker-compose up -d
    
    echo -e \"${GREEN}=== SSL Setup Complete! ===${NC}\"
    echo -e \"${GREEN}Your site should now be available at https://$DOMAIN${NC}\"
    
else
    echo -e \"${RED}Certificate generation failed!${NC}\"
    echo \"Please check the logs and try again\"
    exit 1
fi

# Set up automatic renewal
echo -e \"${YELLOW}Setting up automatic certificate renewal...${NC}\"
echo \"0 12 * * * cd $(pwd) && docker-compose run --rm certbot renew --quiet && docker-compose exec nginx nginx -s reload\" | crontab -

echo -e \"${GREEN}Automatic renewal has been set up!${NC}\"
echo \"Certificates will be checked for renewal daily at 12:00 PM\"


