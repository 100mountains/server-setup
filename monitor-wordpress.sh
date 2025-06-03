#!/bin/bash
# /root/monitor-uploads.sh

LOG_FILE="/var/log/upload-monitor.log"
UPLOAD_DIR="/var/www/html/wp-content/uploads"
WOO_DIR="/var/www/html/wp-content/uploads/woocommerce_uploads"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_entry() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a $LOG_FILE
}

check_disk_space() {
    echo -e "${YELLOW}=== DISK SPACE ===${NC}"
    df -h /var/www/html | tail -1 | awk '{print "Used: " $3 "/" $2 " (" $5 ")"}'
    echo
}

check_large_files() {
    echo -e "${YELLOW}=== LARGE FILES (>100MB) ===${NC}"
    find $UPLOAD_DIR -type f -size +100M -exec ls -lh {} \; | awk '{print $5 "\t" $9}'
    echo
}

check_recent_uploads() {
    echo -e "${YELLOW}=== RECENT UPLOADS (Last 24h) ===${NC}"
    find $UPLOAD_DIR -type f -mtime -1 -exec ls -lh {} \; | awk '{print $6 " " $7 " " $8 "\t" $5 "\t" $9}'
    echo
}

check_woo_permissions() {
    echo -e "${YELLOW}=== WOOCOMMERCE UPLOADS PERMISSIONS ===${NC}"
    ls -la $WOO_DIR | head -5
    
    # Check for wrong ownership
    WRONG_OWNER=$(find $WOO_DIR -type f ! -user www-data -o ! -group www-data 2>/dev/null | wc -l)
    if [ $WRONG_OWNER -gt 0 ]; then
        echo -e "${RED}Warning: $WRONG_OWNER files with wrong ownership${NC}"
        find $WOO_DIR -type f ! -user www-data -o ! -group www-data 2>/dev/null | head -5
    else
        echo -e "${GREEN}All files have correct ownership${NC}"
    fi
    echo
}

check_php_uploads() {
    echo -e "${YELLOW}=== PHP UPLOAD SETTINGS ===${NC}"
    php -r "
    echo 'upload_max_filesize: ' . ini_get('upload_max_filesize') . PHP_EOL;
    echo 'post_max_size: ' . ini_get('post_max_size') . PHP_EOL;
    echo 'max_execution_time: ' . ini_get('max_execution_time') . PHP_EOL;
    echo 'memory_limit: ' . ini_get('memory_limit') . PHP_EOL;
    "
    echo
}

check_nginx_status() {
    echo -e "${YELLOW}=== NGINX STATUS ===${NC}"
    if systemctl is-active --quiet nginx; then
        echo -e "${GREEN}NGINX: Running${NC}"
    else
        echo -e "${RED}NGINX: Not running${NC}"
    fi
    
    # Check for recent errors
    ERROR_COUNT=$(tail -100 /var/log/nginx/error.log | grep "$(date '+%Y/%m/%d')" | wc -l)
    if [ $ERROR_COUNT -gt 0 ]; then
        echo -e "${RED}Recent NGINX errors: $ERROR_COUNT${NC}"
        tail -5 /var/log/nginx/error.log
    else
        echo -e "${GREEN}No recent NGINX errors${NC}"
    fi
    echo
}

check_failed_uploads() {
    echo -e "${YELLOW}=== FAILED UPLOAD INDICATORS ===${NC}"
    
    # Look for temp files that might indicate failed uploads
    TEMP_FILES=$(find $UPLOAD_DIR -name "*.tmp" -o -name ".*" -type f | wc -l)
    if [ $TEMP_FILES -gt 0 ]; then
        echo -e "${RED}Temp files found: $TEMP_FILES${NC}"
        find $UPLOAD_DIR -name "*.tmp" -o -name ".*" -type f | head -5
    fi
    
    # Check for files stuck in regular uploads that should be in woocommerce_uploads
    STUCK_AUDIO=$(find $UPLOAD_DIR/2025 -name "*.wav" -o -name "*.mp3" -o -name "*.flac" 2>/dev/null | grep -v woocommerce_uploads | wc -l)
    if [ $STUCK_AUDIO -gt 0 ]; then
        echo -e "${YELLOW}Audio files in regular uploads (might need moving): $STUCK_AUDIO${NC}"
        find $UPLOAD_DIR/2025 -name "*.wav" -o -name "*.mp3" -o -name "*.flac" 2>/dev/null | grep -v woocommerce_uploads | head -3
    fi
    echo
}

# Main execution
echo -e "${GREEN}=== UPLOAD MONITOR - $(date) ===${NC}"
log_entry "Monitor started"

check_disk_space
check_php_uploads
check_nginx_status
check_recent_uploads
check_large_files
check_woo_permissions
check_failed_uploads

log_entry "Monitor completed"
echo -e "${GREEN}=== END MONITOR ===${NC}"
