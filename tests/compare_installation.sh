#!/bin/bash

# Compare installed configurations with expected configs

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"
}

error() {
    echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')] ERROR:${NC} $1"
}

warning() {
    echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')] WARNING:${NC} $1"
}

log "Comparing installed configurations..."

# Function to compare config files
compare_config() {
    local expected_file="$1"
    local actual_file="$2"
    local description="$3"
    
    if [[ ! -f "$expected_file" ]]; then
        error "Expected config file not found: $expected_file"
        return 1
    fi
    
    if [[ ! -f "$actual_file" ]]; then
        error "Actual config file not found: $actual_file"
        return 1
    fi
    
    echo "=== $description ==="
    if diff -u "$expected_file" "$actual_file"; then
        log "$description: MATCH"
    else
        warning "$description: DIFFERENCES FOUND"
    fi
    echo
}

# Compare key configuration files
compare_config "configs/nginx/nginx.conf" "/etc/nginx/nginx.conf" "Nginx main config"
compare_config "configs/php/php.ini" "/etc/php/8.3/fpm/php.ini" "PHP configuration"
compare_config "configs/php/www.conf" "/etc/php/8.3/fpm/pool.d/www.conf" "PHP-FPM pool config"
compare_config "configs/mariadb/60-optimizations.cnf" "/etc/mysql/mariadb.conf.d/60-optimizations.cnf" "MariaDB optimizations"

# Check if services are running
log "Checking service status..."
services=("nginx" "mariadb" "php8.3-fpm" "fail2ban")
for service in "${services[@]}"; do
    if systemctl is-active --quiet "$service"; then
        log "$service: RUNNING"
    else
        error "$service: NOT RUNNING"
    fi
done

log "Configuration comparison complete!"
