#!/bin/bash

# Main installation script for a music store server
# Runs all setup scripts in the correct order

set -euo pipefail

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"
}

error() {
    echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')] ERROR:${NC} $1" >&2
}

warning() {
    echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')] WARNING:${NC} $1"
}

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    error "This script must be run as root (use sudo)"
    exit 1
fi

# Check if .env file exists
if [[ ! -f .env ]]; then
    error ".env file not found! Please create it with DOMAIN_NAME and EMAIL variables"
    echo "Example:"
    echo 'DOMAIN_NAME="your.domain.com"'
    echo 'EMAIL="admin@your.domain.com"'
    exit 1
fi

# Source environment variables or use parameters
if [[ -f .env ]]; then
    source .env
fi

# Allow overriding with environment variables
DOMAIN_NAME="${DOMAIN_NAME:-}"
EMAIL="${EMAIL:-}"

# If no domain provided, prompt for it
if [[ -z "$DOMAIN_NAME" ]]; then
    read -p "Enter your domain name: " DOMAIN_NAME
fi

if [[ -z "$EMAIL" ]]; then
    read -p "Enter your admin email: " EMAIL
fi
# Validate required variables
if [[ -z "${DOMAIN_NAME:-}" || -z "${EMAIL:-}" ]]; then
    error "DOMAIN_NAME and EMAIL must be set in .env file"
    exit 1
fi

log "Starting server setup for domain: $DOMAIN_NAME"
log "Admin email: $EMAIL"

# Function to run script with error handling
run_script() {
    local script_name=$1
    local description=$2
    
    log "Starting: $description"
    
    if [[ ! -f "$script_name" ]]; then
        error "Script $script_name not found!"
        exit 1
    fi
    
    if ! bash "$script_name"; then
        error "Script $script_name failed!"
        exit 1
    fi
    
    log "Completed: $description"
}

# Pre-flight checks
log "Running pre-flight checks..."

# Check if we have internet connectivity
if ! ping -c 1 google.com &> /dev/null; then
    error "No internet connectivity detected"
    exit 1
fi

# Check if SSH key authentication is working (since we're hardening SSH)
if [[ -z "${SSH_CLIENT:-}" && -z "${SSH_TTY:-}" ]]; then
    warning "Not running over SSH - make sure you have SSH key access before hardening"
    read -p "Continue anyway? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

log "Pre-flight checks passed"

# Run scripts in order
log "=== Starting server installation ==="

# Step 1: Security hardening (must be first)
run_script "harden.sh" "Security hardening (SSH, firewall, fail2ban)"

# Step 2: LEMP stack and WordPress installation
run_script "install-wordpress.sh" "LEMP stack and WordPress installation"

# Step 3: Music store plugins (depends on WordPress)
run_script "install-music-store-plugins.sh" "Music store plugins installation"

log "=== Installation completed successfully! ==="
log "Your music store server is now ready at: https://$DOMAIN_NAME"
log "WordPress admin: https://$DOMAIN_NAME/wp-admin"
log ""
log "Next steps:"
log "1. Configure your DNS to point $DOMAIN_NAME to this server"
log "2. Access WordPress admin to complete setup"
log "3. Install and configure your Bandfront theme"
log "4. Test audio file uploads and playback"
log ""
log "Server services status:"
systemctl status nginx --no-pager -l
systemctl status php8.3-fpm --no-pager -l
systemctl status mariadb --no-pager -l
systemctl status fail2ban --no-pager -l

