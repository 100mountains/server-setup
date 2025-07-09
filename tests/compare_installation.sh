#!/bin/bash

# Comprehensive Server Installation Comparison and Monitoring Script
# Validates configurations, monitors system health, and checks WordPress functionality

set -uo pipefail  # Removed 'e' to allow script to continue on errors

# =============================================================================
# CONFIGURATION AND GLOBALS
# =============================================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Monitoring thresholds
CPU_THRESHOLD=80
MEMORY_THRESHOLD=85
DISK_THRESHOLD=85
LOAD_THRESHOLD=4.0

# Counters for summary
TOTAL_CHECKS=0
PASSED_CHECKS=0
FAILED_CHECKS=0
WARNING_CHECKS=0

# Paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_BASE_DIR="$(dirname "$SCRIPT_DIR")/configs"
LOG_FILE="./server-monitor.log"
WP_PATH="/var/www/html"
WP_CONFIG="$WP_PATH/wp-config.php"
UPLOAD_DIR="$WP_PATH/wp-content/uploads"
WOO_DIR="$WP_PATH/wp-content/uploads/woocommerce_uploads"

# =============================================================================
# LOGGING AND UTILITY FUNCTIONS
# =============================================================================

log_entry() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE" 2>/dev/null || true
}

log() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"
    log_entry "INFO: $1"
}

error() {
    echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')] ERROR:${NC} $1"
    log_entry "ERROR: $1"
    FAILED_CHECKS=$((FAILED_CHECKS + 1))
}

warning() {
    echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')] WARNING:${NC} $1"
    log_entry "WARNING: $1"
    WARNING_CHECKS=$((WARNING_CHECKS + 1))
}

success() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')] SUCCESS:${NC} $1"
    log_entry "SUCCESS: $1"
    PASSED_CHECKS=$((PASSED_CHECKS + 1))
}

info() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')] INFO:${NC} $1"
}

alert() {
    echo -e "${RED}🚨 ALERT: $1${NC}"
    log_entry "ALERT: $1"
}

# =============================================================================
# WORDPRESS DATABASE HELPER FUNCTIONS
# =============================================================================

get_wp_db_creds() {
    if [[ -f "$WP_CONFIG" ]]; then
        # More robust parsing using awk to handle both single and double quotes
        DB_NAME=$(awk -F"['\"]" '/define.*DB_NAME/{print $(NF-1)}' "$WP_CONFIG" 2>/dev/null || true)
        DB_USER=$(awk -F"['\"]" '/define.*DB_USER/{print $(NF-1)}' "$WP_CONFIG" 2>/dev/null || true)
        DB_PASS=$(awk -F"['\"]" '/define.*DB_PASSWORD/{print $(NF-1)}' "$WP_CONFIG" 2>/dev/null || true)
        DB_HOST=$(awk -F"['\"]" '/define.*DB_HOST/{print $(NF-1)}' "$WP_CONFIG" 2>/dev/null || true)
    fi
}

# =============================================================================
# CONFIGURATION COMPARISON FUNCTIONS
# =============================================================================

# Compare actual config files with expected templates
compare_config() {
    local expected_file="$1"
    local actual_file="$2"
    local description="$3"
    
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    echo "=== $description ==="
    
    if [[ ! -f "$expected_file" ]]; then
        error "Expected config file not found: $expected_file"
        return 1
    fi
    
    if [[ ! -f "$actual_file" ]]; then
        error "Actual config file not found: $actual_file"
        return 1
    fi
    
    if diff_output=$(diff -u "$expected_file" "$actual_file" 2>&1); then
        success "$description: MATCH"
    else
        warning "$description: DIFFERENCES FOUND"
        echo -e "${YELLOW}First 10 lines of differences:${NC}"
        echo "$diff_output" | head -10
        echo -e "${YELLOW}(Full diff: diff -u $expected_file $actual_file)${NC}"
    fi
    echo
}

# Check if template files were properly processed (no unreplaced placeholders)
compare_template() {
    local template_file="$1"
    local actual_file="$2"
    local description="$3"
    
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    echo "=== $description (Template Check) ==="
    
    if [[ ! -f "$template_file" ]]; then
        error "Template file not found: $template_file"
        return 1
    fi
    
    if [[ ! -f "$actual_file" ]]; then
        error "Actual config file not found: $actual_file"
        return 1
    fi
    
    local unreplaced_vars=$(grep -o "%%.*%%" "$actual_file" 2>/dev/null || true)
    if [[ -n "$unreplaced_vars" ]]; then
        warning "$description: Contains unreplaced template placeholders"
        echo -e "${YELLOW}Unreplaced variables:${NC}"
        echo "$unreplaced_vars" | head -3
    else
        success "$description: Template properly processed"
    fi
    echo
}

# Check file permissions and ownership
check_file_perms() {
    local file_path="$1"
    local expected_owner="$2"
    local expected_perms="$3"
    local description="$4"
    
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    
    if [[ ! -f "$file_path" && ! -d "$file_path" ]]; then
        error "$description: File/directory not found: $file_path"
        return 1
    fi
    
    local actual_owner=$(stat -c "%U:%G" "$file_path")
    local actual_perms=$(stat -c "%a" "$file_path")
    
    if [[ "$actual_owner" == "$expected_owner" && "$actual_perms" == "$expected_perms" ]]; then
        success "$description: Correct permissions ($actual_perms) and ownership ($actual_owner)"
    else
        warning "$description: Permissions/ownership mismatch"
        echo "  Expected: $expected_perms $expected_owner"
        echo "  Actual:   $actual_perms $actual_owner"
    fi
}

# =============================================================================
# SYSTEM RESOURCE MONITORING FUNCTIONS
# =============================================================================

check_system_resources() {
    echo -e "${CYAN}=== SYSTEM RESOURCES ===${NC}"
    
    # CPU usage
    CPU_USAGE=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | sed 's/%us,//' | sed 's/%//')
    echo "CPU Usage: ${CPU_USAGE}%"
    if (( $(echo "$CPU_USAGE > $CPU_THRESHOLD" | bc -l 2>/dev/null || echo "0") )); then
        alert "High CPU usage: ${CPU_USAGE}%"
    fi
    
    # Memory usage
    MEMORY_INFO=$(free | grep Mem)
    TOTAL_MEM=$(echo "$MEMORY_INFO" | awk '{print $2}')
    USED_MEM=$(echo "$MEMORY_INFO" | awk '{print $3}')
    MEMORY_PERCENT=$(( (USED_MEM * 100) / TOTAL_MEM ))
    echo "Memory Usage: ${USED_MEM}/${TOTAL_MEM} (${MEMORY_PERCENT}%)"
    if [[ $MEMORY_PERCENT -gt $MEMORY_THRESHOLD ]]; then
        alert "High memory usage: ${MEMORY_PERCENT}%"
    fi
    
    # Load average
    LOAD_AVG=$(uptime | awk '{print $(NF-2)}' | sed 's/,//')
    echo "Load Average (1min): $LOAD_AVG"
    if (( $(echo "$LOAD_AVG > $LOAD_THRESHOLD" | bc -l 2>/dev/null || echo "0") )); then
        alert "High system load: $LOAD_AVG"
    fi
    
    # Disk usage
    echo -e "${BLUE}Disk Usage:${NC}"
    df -h | grep -E "/$|/var|/tmp" | while read filesystem size used avail percent mount; do
        percent_num=$(echo "$percent" | sed 's/%//')
        echo "$mount: $used/$size ($percent)"
        if [[ $percent_num -gt $DISK_THRESHOLD ]]; then
            alert "High disk usage on $mount: $percent"
        fi
    done
    
    # Process count
    PROCESS_COUNT=$(ps aux | wc -l)
    echo "Running processes: $PROCESS_COUNT"
    echo
}

# =============================================================================
# SERVICE HEALTH AND FUNCTIONALITY TESTS
# =============================================================================

test_service_functionality() {
    local service_name="$1"
    local test_command="$2"
    local description="$3"
    
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    
    if systemctl is-active --quiet "$service_name"; then
        if eval "$test_command" >/dev/null 2>&1; then
            success "$description: Service running and functional"
        else
            warning "$description: Service running but test failed"
            info "Test command: $test_command"
        fi
    else
        error "$description: Service not running"
    fi
}

check_service_health() {
    echo -e "${CYAN}=== SERVICE HEALTH ===${NC}"
    
    services=("nginx" "mariadb" "php8.3-fpm" "fail2ban")
    
    for service in "${services[@]}"; do
        TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
        if systemctl is-active --quiet "$service" 2>/dev/null; then
            case $service in
                "nginx")
                    # Check both HTTP and HTTPS, accepting redirects as valid responses
                    if curl -s -o /dev/null -w "%{http_code}" "http://localhost" 2>/dev/null | grep -q "200\|301\|302\|303\|307\|308"; then
                        success "$service: Running and responsive"
                    elif curl -s -o /dev/null -w "%{http_code}" "https://localhost" -k 2>/dev/null | grep -q "200\|301\|302"; then
                        success "$service: Running and responsive (HTTPS only)"
                    else
                        warning "$service: Running but not responding to HTTP/HTTPS requests"
                    fi
                    ;;
                "mariadb")
                    # Try to get WordPress database credentials for testing
                    get_wp_db_creds
                    
                    # Try multiple connection methods
                    if [[ -n "${DB_USER:-}" && -n "${DB_PASS:-}" ]] && mysql -h"${DB_HOST:-localhost}" -u"$DB_USER" -p"$DB_PASS" -e "SELECT 1;" >/dev/null 2>&1; then
                        success "$service: Running and responsive (using WP credentials)"
                    elif mysqladmin ping -h localhost 2>/dev/null | grep -q "alive"; then
                        success "$service: Running and responsive"
                    elif mysql -e "SELECT 1;" >/dev/null 2>&1; then
                        success "$service: Running and responsive"
                    elif sudo mysql -e "SELECT 1;" >/dev/null 2>&1; then
                        success "$service: Running and responsive (requires sudo)"
                    else
                        warning "$service: Running but not accepting connections"
                    fi
                    ;;
                "php8.3-fpm")
                    PHP_WORKERS=$(pgrep -f "php-fpm" | wc -l)
                    if [[ $PHP_WORKERS -gt 0 ]]; then
                        success "$service: Running with $PHP_WORKERS worker processes"
                    else
                        warning "$service: Running but no worker processes found"
                    fi
                    ;;
                "fail2ban")
                    if fail2ban-client status >/dev/null 2>&1; then
                        JAIL_COUNT=$(fail2ban-client status 2>/dev/null | grep "Jail list" | cut -d: -f2 | tr ',' '\n' | wc -l)
                        success "$service: Running with $JAIL_COUNT active jails"
                    else
                        warning "$service: Running but not responsive"
                    fi
                    ;;
            esac
        else
            # Check for alternative service names
            if [[ "$service" == "mariadb" ]] && systemctl is-active --quiet "mysql" 2>/dev/null; then
                warning "$service: Service is running as 'mysql'"
                # Still try to connect
                get_wp_db_creds
                if [[ -n "${DB_USER:-}" && -n "${DB_PASS:-}" ]] && mysql -h"${DB_HOST:-localhost}" -u"$DB_USER" -p"$DB_PASS" -e "SELECT 1;" >/dev/null 2>&1; then
                    success "mysql: Running and responsive (using WP credentials)"
                elif mysqladmin ping -h localhost 2>/dev/null | grep -q "alive"; then
                    success "mysql: Running and responsive"
                fi
            else
                error "$service: NOT RUNNING"
            fi
        fi
    done
    echo
}

# =============================================================================
# SECURITY MONITORING FUNCTIONS
# =============================================================================

check_security_status() {
    echo -e "${CYAN}=== SECURITY STATUS ===${NC}"
    
    # Fail2ban status and recent bans
    if systemctl is-active --quiet fail2ban 2>/dev/null; then
        echo -e "${BLUE}Fail2ban Status:${NC}"
        fail2ban-client status 2>/dev/null | head -5 || true
        
        # Recent bans - this is fail2ban working correctly
        RECENT_BANS=$(grep "$(date '+%Y-%m-%d')" /var/log/fail2ban.log 2>/dev/null | grep "Ban " | wc -l | tr -d '\n' | tr -d ' ' || echo "0")
        if [[ $RECENT_BANS -gt 0 ]]; then
            success "Fail2ban active: $RECENT_BANS IPs banned today (protection working)"
            echo -e "${BLUE}Recent bans:${NC}"
            # Only show actual ban notices, not email errors
            grep "$(date '+%Y-%m-%d')" /var/log/fail2ban.log 2>/dev/null | grep "NOTICE.*Ban" | tail -3 | sed 's/^/  /' || true
        else
            info "No IPs banned today (normal for new installations)"
        fi
        
        # Only check for real jail failures, not email notification failures
        JAIL_ERRORS=$(grep "$(date '+%Y-%m-%d')" /var/log/fail2ban.log 2>/dev/null | grep -E "ERROR|CRITICAL" | grep -v -E "sendmail|mail|smtp|printf|exec:|returned 127|fail2ban.actions|fail2ban.utils" | wc -l | tr -d '\n' | tr -d ' ' || echo "0")
        if [[ $JAIL_ERRORS -gt 0 ]]; then
            warning "Fail2ban jail errors detected: $JAIL_ERRORS"
            echo -e "${YELLOW}Recent jail errors:${NC}"
            grep "$(date '+%Y-%m-%d')" /var/log/fail2ban.log 2>/dev/null | grep -E "ERROR|CRITICAL" | grep -v -E "sendmail|mail|smtp|printf|exec:|returned 127|fail2ban.actions|fail2ban.utils" | tail -2 | sed 's/^/  /' || true
        fi
    else
        error "Fail2ban: NOT RUNNING"
    fi
    
    # SSH login attempts - fix date format for auth.log
    # auth.log uses format like "Jan  9" with two spaces for single digit days
    CURRENT_DATE=$(date '+%b %e' | sed 's/  */ /g')
    FAILED_SSH=$(grep "$CURRENT_DATE" /var/log/auth.log 2>/dev/null | grep -i -E "Failed password|Invalid user" | wc -l | tr -d '\n' | tr -d ' ' || echo "0")
    
    echo "Failed SSH attempts today: $FAILED_SSH"
    if [[ $FAILED_SSH -gt 10 ]]; then
        if [[ $RECENT_BANS -gt 0 ]]; then
            success "High SSH attempts ($FAILED_SSH) but fail2ban is blocking them"
        else
            warning "High failed SSH attempts today: $FAILED_SSH (consider checking fail2ban)"
        fi
    elif [[ $FAILED_SSH -eq 0 ]]; then
        info "No failed SSH attempts (typical for new servers)"
    fi
    
    # UFW firewall status
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    if command -v ufw >/dev/null 2>&1; then
        if ufw status 2>/dev/null | grep -q "Status: active"; then
            success "UFW: ACTIVE"
            
            # Check for required ports
            TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
            if ufw status numbered 2>/dev/null | grep -E "(22|80|443)" >/dev/null; then
                success "UFW: Standard ports configured"
            else
                warning "UFW: Standard ports (22,80,443) not found in rules"
            fi
        else
            error "UFW: INACTIVE"
        fi
    else
        warning "UFW: NOT INSTALLED"
    fi
    echo
}

# =============================================================================
# SSL CERTIFICATE MONITORING FUNCTIONS
# =============================================================================

check_ssl_certificates() {
    echo -e "${CYAN}=== SSL CERTIFICATES ===${NC}"
    
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    if [[ -d "/etc/letsencrypt/live" ]]; then
        CERT_COUNT=$(find /etc/letsencrypt/live -name "cert.pem" 2>/dev/null | wc -l || echo "0")
        if [[ $CERT_COUNT -gt 0 ]]; then
            success "SSL certificates: $CERT_COUNT found"
            
            for cert_dir in /etc/letsencrypt/live/*/; do
                if [[ -d "$cert_dir" && -f "$cert_dir/cert.pem" ]]; then
                    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
                    domain=$(basename "$cert_dir")
                    
                    if openssl x509 -in "$cert_dir/cert.pem" -noout -checkend 2592000 >/dev/null 2>&1; then
                        EXPIRE_DATE=$(openssl x509 -in "$cert_dir/cert.pem" -noout -enddate | cut -d= -f2)
                        success "SSL for $domain: Valid (expires: $EXPIRE_DATE)"
                    else
                        DAYS_LEFT=$(( ($(date -d "$(openssl x509 -in "$cert_dir/cert.pem" -noout -enddate | cut -d= -f2)" +%s) - $(date +%s)) / 86400 ))
                        if [[ $DAYS_LEFT -lt 7 ]]; then
                            alert "SSL for $domain: Certificate expires in $DAYS_LEFT days!"
                        else
                            warning "SSL for $domain: Certificate expires in $DAYS_LEFT days"
                        fi
                    fi
                fi
            done
        else
            warning "SSL certificates: NONE FOUND"
        fi
    else
        warning "Let's Encrypt directory: NOT FOUND"
    fi
    echo
}

# =============================================================================
# WORDPRESS MONITORING FUNCTIONS
# =============================================================================

check_wordpress_status() {
    echo -e "${CYAN}=== WORDPRESS STATUS ===${NC}"
    
    # WordPress configuration test
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    if [[ -f "$WP_CONFIG" ]]; then
        if php -f "$WP_CONFIG" >/dev/null 2>&1; then
            success "WordPress configuration: Syntax valid"
        else
            error "WordPress configuration: PHP syntax error"
        fi
        
        # WordPress version
        if [[ -f "$WP_PATH/wp-includes/version.php" ]]; then
            WP_VERSION=$(grep '$wp_version' "$WP_PATH/wp-includes/version.php" | cut -d "'" -f 2 || echo "Unknown")
            echo "WordPress version: $WP_VERSION"
        fi
        
        # Active plugins count
        PLUGIN_COUNT=$(find "$WP_PATH/wp-content/plugins" -maxdepth 1 -type d 2>/dev/null | wc -l || echo "0")
        echo "Installed plugins: $((PLUGIN_COUNT-1))"
        
        # Active theme
        ACTIVE_THEME=$(wp --path="$WP_PATH" theme list --status=active --field=name 2>/dev/null || echo "Unknown")
        echo "Active theme: $ACTIVE_THEME"
        
        # WordPress errors (last hour) - removed duplicate check
        if [[ -f "$WP_PATH/wp-content/debug.log" ]]; then
            WP_ERRORS=$(grep "$(date '+%Y-%m-%d %H')" "$WP_PATH/wp-content/debug.log" 2>/dev/null | wc -l || echo "0")
            if [[ $WP_ERRORS -gt 0 ]]; then
                warning "Recent WP errors: $WP_ERRORS"
                tail -3 "$WP_PATH/wp-content/debug.log" 2>/dev/null || true
            else
                success "No recent WordPress errors"
            fi
        fi
    else
        error "WordPress configuration: File not found"
    fi
    echo
}

check_wordpress_database() {
    echo -e "${CYAN}=== WORDPRESS DATABASE ===${NC}"
    
    get_wp_db_creds
    
    if [[ -n "${DB_NAME:-}" && -n "${DB_USER:-}" && -n "${DB_PASS:-}" ]]; then
        if mysql -h"${DB_HOST:-localhost}" -u"$DB_USER" -p"$DB_PASS" "$DB_NAME" -e "SELECT 1;" >/dev/null 2>&1; then
            success "WordPress Database: Accessible"
            
            # WordPress-specific DB stats
            POST_COUNT=$(mysql -h"${DB_HOST:-localhost}" -u"$DB_USER" -p"$DB_PASS" "$DB_NAME" -e "SELECT COUNT(*) FROM wp_posts WHERE post_status='publish' AND post_type='post';" -s 2>/dev/null || echo "0")
            PAGE_COUNT=$(mysql -h"${DB_HOST:-localhost}" -u"$DB_USER" -p"$DB_PASS" "$DB_NAME" -e "SELECT COUNT(*) FROM wp_posts WHERE post_status='publish' AND post_type='page';" -s 2>/dev/null || echo "0")
            PRODUCT_COUNT=$(mysql -h"${DB_HOST:-localhost}" -u"$DB_USER" -p"$DB_PASS" "$DB_NAME" -e "SELECT COUNT(*) FROM wp_posts WHERE post_status='publish' AND post_type='product';" -s 2>/dev/null || echo "0")
            USER_COUNT=$(mysql -h"${DB_HOST:-localhost}" -u"$DB_USER" -p"$DB_PASS" "$DB_NAME" -e "SELECT COUNT(*) FROM wp_users;" -s 2>/dev/null || echo "0")
            ORDER_COUNT=$(mysql -h"${DB_HOST:-localhost}" -u"$DB_USER" -p"$DB_PASS" "$DB_NAME" -e "SELECT COUNT(*) FROM wp_posts WHERE post_type='shop_order';" -s 2>/dev/null || echo "0")
            
            echo "Posts: $POST_COUNT | Pages: $PAGE_COUNT | Products: $PRODUCT_COUNT"
            echo "Users: $USER_COUNT | Orders: $ORDER_COUNT"
            
            # DB size
            DB_SIZE=$(mysql -h"${DB_HOST:-localhost}" -u"$DB_USER" -p"$DB_PASS" "$DB_NAME" -e "SELECT ROUND(SUM(data_length + index_length) / 1024 / 1024, 1) AS 'DB Size in MB' FROM information_schema.tables WHERE table_schema='$DB_NAME';" -s 2>/dev/null || echo "N/A")
            echo "Database size: ${DB_SIZE} MB"
        else
            error "WordPress Database: Connection failed"
        fi
    else
        error "WordPress Database: Credentials not found"
    fi
    echo
}

check_upload_status() {
    echo -e "${CYAN}=== UPLOAD DIAGNOSTICS ===${NC}"
    
    # PHP upload settings - check PHP-FPM config, not CLI
    echo -e "${BLUE}PHP Upload Limits (PHP-FPM):${NC}"
    
    # Check the actual PHP-FPM pool configuration
    if [[ -f "/etc/php/8.3/fpm/pool.d/www.conf" ]]; then
        echo "From PHP-FPM pool config:"
        grep -E "php_admin_value\[(upload_max_filesize|post_max_size|max_execution_time|memory_limit|max_file_uploads)\]" /etc/php/8.3/fpm/pool.d/www.conf 2>/dev/null | sed 's/php_admin_value\[/  /' | sed 's/\]//' | sed 's/ = /: /' || true
        
        # Also check PHP-FPM php.ini
        echo -e "\nFrom PHP-FPM php.ini:"
        if [[ -f "/etc/php/8.3/fpm/php.ini" ]]; then
            for setting in "upload_max_filesize" "post_max_size" "max_execution_time" "memory_limit" "max_file_uploads"; do
                value=$(grep "^${setting} = " /etc/php/8.3/fpm/php.ini 2>/dev/null | cut -d= -f2 | tr -d ' ' || echo "not set")
                echo "  ${setting}: ${value}"
            done
        fi
        
        # Compare with expected values
        TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
        EXPECTED_UPLOAD_SIZE=$(grep "upload_max_filesize" /etc/php/8.3/fpm/pool.d/www.conf 2>/dev/null | grep -o "[0-9]*[GM]" || echo "")
        if [[ "$EXPECTED_UPLOAD_SIZE" == "2G" ]]; then
            success "PHP-FPM upload_max_filesize: Correctly set to 2G"
        else
            error "PHP-FPM upload_max_filesize: Not set to 2G (found: ${EXPECTED_UPLOAD_SIZE:-not set})"
        fi
        
        # Create a test PHP file to check actual runtime values
        if [[ -d "/var/www/html" ]]; then
            echo '<?php phpinfo(); ?>' > /var/www/html/phpinfo_test.php
            chown www-data:www-data /var/www/html/phpinfo_test.php
            
            # Use curl to check actual PHP-FPM values
            echo -e "\nActual PHP-FPM runtime values:"
            curl -s "http://localhost/phpinfo_test.php" 2>/dev/null | grep -A1 -E "(upload_max_filesize|post_max_size|max_execution_time|memory_limit|max_file_uploads)" | grep -E "<td|<th" | sed 's/<[^>]*>//g' | paste - - | while read name value; do
                echo "  $name $value"
            done || true
            
            # Clean up test file
            rm -f /var/www/html/phpinfo_test.php 2>/dev/null
        fi
    else
        error "PHP-FPM pool config not found at /etc/php/8.3/fpm/pool.d/www.conf"
    fi
    
    if [[ -d "$UPLOAD_DIR" ]]; then
        # Upload directory permissions
        UPLOAD_PERMS=$(stat -c "%a" "$UPLOAD_DIR" 2>/dev/null || echo "N/A")
        UPLOAD_OWNER=$(stat -c "%U:%G" "$UPLOAD_DIR" 2>/dev/null || echo "N/A")
        echo -e "\nUpload dir permissions: $UPLOAD_PERMS ($UPLOAD_OWNER)"
        
        # Disk space and sizes
        UPLOAD_SIZE=$(du -sh "$UPLOAD_DIR" 2>/dev/null | cut -f1 || echo "N/A")
        echo "Uploads directory size: $UPLOAD_SIZE"
        
        # Recent upload activity
        RECENT_UPLOADS=$(find "$UPLOAD_DIR" -type f -mmin -60 2>/dev/null | wc -l || echo "0")
        echo "Files uploaded in last hour: $RECENT_UPLOADS"
        
        # Large files check
        echo -e "${BLUE}Large Files (>100MB):${NC}"
        LARGE_FILES=$(find "$UPLOAD_DIR" -type f -size +100M 2>/dev/null | wc -l || echo "0")
        if [[ $LARGE_FILES -gt 0 ]]; then
            find "$UPLOAD_DIR" -type f -size +100M -exec ls -lh {} \; 2>/dev/null | head -5 | awk '{print $5 "\t" $9}' || true
        else
            echo "No files >100MB found"
        fi
        
        # Recent failed uploads (look for temp files)
        TEMP_FILES=$(find "$UPLOAD_DIR" -name "*.tmp" -mtime -1 2>/dev/null | wc -l || echo "0")
        if [[ $TEMP_FILES -gt 0 ]]; then
            warning "Recent temp files (failed uploads): $TEMP_FILES"
            find "$UPLOAD_DIR" -name "*.tmp" -mtime -1 2>/dev/null | head -3 || true
        else
            success "No recent failed uploads detected"
        fi
    else
        error "Upload directory not found: $UPLOAD_DIR"
    fi
    echo
}

check_woocommerce_status() {
    echo -e "${CYAN}=== WOOCOMMERCE STATUS ===${NC}"
    
    if [[ -d "$WP_PATH/wp-content/plugins/woocommerce" ]]; then
        success "WooCommerce: Installed"
        
        get_wp_db_creds
        if [[ -n "${DB_NAME:-}" && -n "${DB_USER:-}" && -n "${DB_PASS:-}" ]]; then
            # Recent orders
            RECENT_ORDERS=$(mysql -h"${DB_HOST:-localhost}" -u"$DB_USER" -p"$DB_PASS" "$DB_NAME" -e "SELECT COUNT(*) FROM wp_posts WHERE post_type='shop_order' AND post_date > DATE_SUB(NOW(), INTERVAL 24 HOUR);" -s 2>/dev/null || echo "0")
            echo "Orders (24h): $RECENT_ORDERS"
            
            # Download attempts (check logs)
            DOWNLOAD_LOGS=$(grep -i "download" /var/log/nginx/access.log 2>/dev/null | grep "$(date '+%d/%b/%Y')" | wc -l || echo "0")
            echo "Download attempts today: $DOWNLOAD_LOGS"
            
            # WooCommerce uploads protection
            if [[ -f "$WOO_DIR/.htaccess" ]]; then
                success "Downloads protected"
            else
                warning "Downloads not protected"
            fi
            
            # Check WooCommerce uploads permissions
            if [[ -d "$WOO_DIR" ]]; then
                check_file_perms "$WOO_DIR" "www-data:www-data" "755" "WooCommerce uploads directory"
            fi
        fi
    else
        warning "WooCommerce: Not installed"
    fi
    echo
}

# =============================================================================
# WEB CONNECTIVITY AND PERFORMANCE TESTS
# =============================================================================

check_web_connectivity() {
    echo -e "${CYAN}=== WEB CONNECTIVITY ===${NC}"
    
    if command -v curl >/dev/null 2>&1; then
        if [[ -f "/root/wordpress-credentials.txt" ]]; then
            source /root/wordpress-credentials.txt 2>/dev/null || true
            if [[ -n "${DOMAIN_NAME:-}" ]]; then
                TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
                if curl -s -o /dev/null -w "%{http_code}" "https://$DOMAIN_NAME" 2>/dev/null | grep -q "200\|301\|302"; then
                    success "Website accessibility: HTTPS response received"
                else
                    warning "Website accessibility: No valid HTTPS response"
                fi
            fi
        fi
        
        # Local connectivity tests - check both HTTP and HTTPS
        TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
        HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost" 2>/dev/null || echo "000")
        HTTPS_CODE=$(curl -s -o /dev/null -w "%{http_code}" "https://localhost" -k 2>/dev/null || echo "000")
        
        if [[ "$HTTP_CODE" =~ ^(200|301|302|303|307|308)$ ]]; then
            success "Local HTTP: Responsive (${HTTP_CODE})"
        elif [[ "$HTTPS_CODE" =~ ^(200|301|302)$ ]]; then
            success "Local HTTPS: Responsive (${HTTPS_CODE})"
        else
            warning "Local HTTP/HTTPS: Not responding (HTTP: ${HTTP_CODE}, HTTPS: ${HTTPS_CODE})"
        fi
    fi
    
    # Nginx connections and performance
    if command -v ss >/dev/null 2>&1; then
        NGINX_CONNECTIONS=$(ss -tuln | grep -E ":80 |:443 " | wc -l)
        echo "Nginx listening ports: $NGINX_CONNECTIONS"
        
        ACTIVE_CONNECTIONS=$(ss -tu | grep -E ":80|:443" | wc -l)
        echo "Active HTTP(S) connections: $ACTIVE_CONNECTIONS"
    fi
    echo
}

# =============================================================================
# MAIN EXECUTION FLOW
# =============================================================================

main() {
    # Check if running as root
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}ERROR: This script must be run as root (use sudo)${NC}"
        echo "Many operations require root privileges:"
        echo "  - Reading system logs"
        echo "  - Checking service status"
        echo "  - Accessing SSL certificates"
        echo "  - Testing server configurations"
        exit 1
    fi
    
    log "Starting comprehensive server monitoring and configuration comparison..."
    log "Config base directory: $CONFIG_BASE_DIR"
    log_entry "Comprehensive monitoring started"
    
    # Validate environment
    if [[ ! -d "$CONFIG_BASE_DIR" ]]; then
        error "Config directory not found: $CONFIG_BASE_DIR"
        exit 1
    fi
    
    # System resource monitoring
    check_system_resources
    
    # Service health checks
    check_service_health
    
    # Security monitoring
    check_security_status
    
    # SSL certificate monitoring
    check_ssl_certificates
    
    # Configuration comparisons
    info "=== CONFIGURATION VALIDATION ==="
    
    # NGINX configuration validation
    compare_template "$CONFIG_BASE_DIR/nginx/nginx.conf.template" "/etc/nginx/nginx.conf" "Nginx main config"
    compare_template "$CONFIG_BASE_DIR/nginx/nginx-wordpress.template" "/etc/nginx/sites-available/default" "Nginx WordPress site config"
    
    # Check nginx config syntax
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    if nginx -t >/dev/null 2>&1; then
        success "Nginx configuration syntax: VALID"
    else
        error "Nginx configuration syntax: INVALID"
        nginx -t 2>&1 | head -3
    fi
    
    # PHP configuration validation
    compare_template "$CONFIG_BASE_DIR/php/8.3/fpm/php.ini.template" "/etc/php/8.3/fpm/php.ini" "PHP configuration"
    compare_template "$CONFIG_BASE_DIR/php/8.3/fpm/pool.d/www.conf.template" "/etc/php/8.3/fpm/pool.d/www.conf" "PHP-FPM pool config"
    
    # MariaDB configuration validation
    for config_file in "$CONFIG_BASE_DIR"/mariadb/conf.d/*.cnf; do
        if [[ -f "$config_file" ]]; then
            filename=$(basename "$config_file")
            compare_config "$config_file" "/etc/mysql/mariadb.conf.d/$filename" "MariaDB $filename"
        fi
    done
    
    if [[ -f "$CONFIG_BASE_DIR/mariadb-conf/debian.cnf" ]]; then
        compare_config "$CONFIG_BASE_DIR/mariadb-conf/debian.cnf" "/etc/mysql/debian.cnf" "MariaDB debian config"
        check_file_perms "/etc/mysql/debian.cnf" "root:root" "600" "MariaDB debian.cnf permissions"
    fi
    
    # Fail2ban configuration validation
    if [[ -f "$CONFIG_BASE_DIR/fail2ban/jail.local" ]]; then
        compare_config "$CONFIG_BASE_DIR/fail2ban/jail.local" "/etc/fail2ban/jail.local" "Fail2ban jail config"
    fi
    
    if [[ -f "$CONFIG_BASE_DIR/fail2ban/sshd.local" ]]; then
        compare_config "$CONFIG_BASE_DIR/fail2ban/sshd.local" "/etc/fail2ban/jail.d/sshd.local" "Fail2ban SSH jail"
    fi
    
    # WordPress and application monitoring
    check_wordpress_status
    check_wordpress_database
    check_upload_status
    check_woocommerce_status
    
    # Web connectivity tests
    check_web_connectivity
    
    # Theme installation check
    THEME_DIR="$(dirname "$SCRIPT_DIR")/themes/bandfront"
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    if [[ -d "$THEME_DIR" ]]; then
        if [[ -d "/var/www/html/wp-content/themes/bandfront" ]]; then
            success "Bandfront theme: INSTALLED"
            check_file_perms "/var/www/html/wp-content/themes/bandfront" "www-data:www-data" "755" "Theme directory permissions"
        else
            error "Bandfront theme: NOT INSTALLED in WordPress"
        fi
    else
        warning "Bandfront theme source: NOT FOUND (submodule not initialized?)"
    fi
    
    # Generate comprehensive summary
    echo
    echo "==============================================="
    echo -e "${BLUE}COMPREHENSIVE MONITORING SUMMARY${NC}"
    echo "==============================================="
    echo -e "Total checks performed: ${BLUE}$TOTAL_CHECKS${NC}"
    echo -e "Passed: ${GREEN}$PASSED_CHECKS${NC}"
    echo -e "Warnings: ${YELLOW}$WARNING_CHECKS${NC}"
    echo -e "Failures: ${RED}$FAILED_CHECKS${NC}"
    echo
    
    # Calculate success rate
    if [[ $TOTAL_CHECKS -gt 0 ]]; then
        SUCCESS_RATE=$(( (PASSED_CHECKS * 100) / TOTAL_CHECKS ))
        if [[ $SUCCESS_RATE -ge 90 ]]; then
            echo -e "Overall status: ${GREEN}EXCELLENT${NC} (${SUCCESS_RATE}%)"
        elif [[ $SUCCESS_RATE -ge 75 ]]; then
            echo -e "Overall status: ${YELLOW}GOOD${NC} (${SUCCESS_RATE}%)"
        elif [[ $SUCCESS_RATE -ge 50 ]]; then
            echo -e "Overall status: ${YELLOW}NEEDS ATTENTION${NC} (${SUCCESS_RATE}%)"
        else
            echo -e "Overall status: ${RED}CRITICAL ISSUES${NC} (${SUCCESS_RATE}%)"
        fi
    fi
    
    echo "==============================================="
    log_entry "Comprehensive monitoring completed"
    
    # Set exit code based on results
    if [[ $FAILED_CHECKS -gt 0 ]]; then
        error "Monitoring completed with failures"
        exit 1
    elif [[ $WARNING_CHECKS -gt 0 ]]; then
        warning "Monitoring completed with warnings"
        exit 2
    else
        success "Monitoring completed successfully"
        exit 0
    fi
}

# Run main function
main "$@"
