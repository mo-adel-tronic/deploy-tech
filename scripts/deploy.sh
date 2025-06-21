#!/bin/bash

# Main Deployment Script for Next.js 15 with Docker Compose
# This script handles the complete deployment process

set -e

# Colors for output
RED=\033[0;31m
GREEN=\033[0;32m
YELLOW=\033[1;33m
BLUE=\033[0;34m
NC=\033[0m # No Color

# Configuration
DOMAIN=""
EMAIL=""
APP_NAME="nextjs-docker-app"

# Functions
print_header() {
    echo -e "\n${GREEN}=== $1 ===${NC}"
}

print_step() {
    echo -e "${YELLOW}→ $1${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ $1${NC}"
}

# Check if running as root
check_root() {
    if [ "$EUID" -eq 0 ]; then
        print_error "Please do not run this script as root"
        exit 1
    fi
}

# Check system requirements
check_requirements() {
    print_header "Checking System Requirements"
    
    # Check if Docker is installed
    if ! command -v docker &> /dev/null; then
        print_error "Docker is not installed"
        print_info "Please install Docker first: https://docs.docker.com/engine/install/"
        exit 1
    fi
    print_success "Docker is installed"
    
    # Check if Docker Compose is installed
    if ! command -v docker-compose &> /dev/null; then
        print_error "Docker Compose is not installed"
        print_info "Please install Docker Compose first"
        exit 1
    fi
    print_success "Docker Compose is installed"
    
    # Check if user is in docker group
    if ! groups $USER | grep &> /dev/null \'\\bdocker\\b\'; then
        print_error "User $USER is not in docker group"
        print_info "Add user to docker group: sudo usermod -aG docker $USER"
        print_info "Then logout and login again"
        exit 1
    fi
    print_success "User is in docker group"
    
    # Check if ports 80 and 443 are available
    if netstat -tuln | grep -q ":80 "; then
        print_error "Port 80 is already in use"
        print_info "Please stop the service using port 80"
        exit 1
    fi
    
    if netstat -tuln | grep -q ":443 "; then
        print_error "Port 443 is already in use"
        print_info "Please stop the service using port 443"
        exit 1
    fi
    print_success "Ports 80 and 443 are available"
}

# Get configuration from user
get_configuration() {
    print_header "Configuration Setup"
    
    if [ -z "$DOMAIN" ]; then
        read -p "Enter your domain name (e.g., example.com): " DOMAIN
        if [ -z "$DOMAIN" ]; then
            print_error "Domain name is required"
            exit 1
        fi
    fi
    
    if [ -z "$EMAIL" ]; then
        read -p "Enter your email for Let\'s Encrypt: " EMAIL
        if [ -z "$EMAIL" ]; then
            print_error "Email is required"
            exit 1
        fi
    fi
    
    print_info "Domain: $DOMAIN"
    print_info "Email: $EMAIL"
    
    read -p "Is this correct? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_error "Configuration cancelled"
        exit 1
    fi
}

# Update configuration files
update_configuration() {
    print_header "Updating Configuration Files"
    
    # Update nginx configuration
    print_step "Updating nginx configuration"
    sed -i "s/your-domain.com/$DOMAIN/g" nginx/conf.d/nextjs.conf
    
    # Update SSL setup script
    print_step "Updating SSL setup script"
    sed -i "s/DOMAIN=\"your-domain.com\"/DOMAIN=\"$DOMAIN\"/g" scripts/setup-ssl.sh
    sed -i "s/EMAIL=\"your-email@example.com\"/EMAIL=\"$EMAIL\"/g" scripts/setup-ssl.sh
    print_success "Configuration files updated"
}

# Build and start services
deploy_application() {
    print_header "Deploying Application"
    
    # Build the application
    print_step "Building Next.js application"
    docker-compose build --no-cache
    print_success "Application built successfully"
    
    # Start services without SSL first
    print_step "Starting services"
    docker-compose up -d nginx
    print_success "Services started"
    
    # Wait for services to be ready
    print_step "Waiting for services to be ready"
    sleep 10
    
    # Check if services are running
    if docker-compose ps | grep -q "Up"; then
        print_success "All services are running"
    else
        print_error "Some services failed to start"
        docker-compose logs
        exit 1
    fi
}

# Setup SSL certificates
setup_ssl() {
    print_header "Setting up SSL Certificates"
    
    print_step "Running SSL setup script"
    ./scripts/setup-ssl.sh
    
    print_success "SSL certificates configured"
}

# Verify deployment
verify_deployment() {
    print_header "Verifying Deployment"
    
    # Check if all containers are running
    print_step "Checking container status"
    if docker-compose ps | grep -q "Up"; then
        print_success "All containers are running"
        docker-compose ps
    else
        print_error "Some containers are not running"
        docker-compose ps
        return 1
    fi
    
    # Test HTTP redirect
    print_step "Testing HTTP to HTTPS redirect"
    if curl -s -I "http://$DOMAIN" | grep -q "301\|302"; then
        print_success "HTTP to HTTPS redirect working"
    else
        print_error "HTTP to HTTPS redirect not working"
    fi
    
    # Test HTTPS connection
    print_step "Testing HTTPS connection"
    if curl -s -I "https://$DOMAIN" | grep -q "200"; then
        print_success "HTTPS connection working"
    else
        print_error "HTTPS connection not working"
    fi
    
    print_success "Deployment verification completed"
}

# Show final information
show_final_info() {
    print_header "Deployment Complete!"
    
    echo -e "${GREEN}Your Next.js application is now deployed and accessible at:${NC}"
    echo -e "${BLUE}🌐 https://$DOMAIN${NC}"
    echo -e "${BLUE}🌐 https://www.$DOMAIN${NC}"
    
    echo -e "\n${YELLOW}Useful commands:${NC}"
    echo -e "${BLUE}• Check status: ./scripts/check-ssl.sh${NC}"
    echo -e "${BLUE}• Renew SSL: ./scripts/renew-ssl.sh${NC}"
    echo -e "${BLUE}• View logs: docker-compose logs${NC}"
    echo -e "${BLUE}• Restart: docker-compose restart${NC}"
    echo -e "${BLUE}• Stop: docker-compose down${NC}"
    
    echo -e "\n${YELLOW}Important notes:${NC}"
    echo -e "${BLUE}• SSL certificates will auto-renew via cron job${NC}"
    echo -e "${BLUE}• Check certificate status regularly${NC}"
    echo -e "${BLUE}• Monitor application logs for issues${NC}"
    echo -e "${BLUE}• Keep your system and Docker updated${NC}"
}

# Main execution
main() {
    print_header "Next.js 15 Docker Deployment Script"
    
    check_root
    check_requirements
    get_configuration
    update_configuration
    deploy_application
    setup_ssl
    verify_deployment
    show_final_info
}

# Run main function
main "$@"


