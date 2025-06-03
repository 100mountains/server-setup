#!/bin/bash
# /root/monitor-wordpress.sh

LOG_FILE="/var/log/wordpress-monitor.log"
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

WP_PATH="/var/www/html"
WP_CONFIG="$WP_PATH/wp-config.php"

log_entry() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a $LOG_FILE 2>/dev/null
}

get_wp_db_creds() {
    DB_NAME=$(grep "DB_NAME" $WP_CONFIG | cut -d "'" -f 4)
    DB_USER=$(grep "DB_USER" $WP_CONFIG | cut -d "'" -f 4)
    DB_PASS=$(grep "DB_PASSWORD" $WP_CONFIG | cut -d "'" -f 4)
    DB_HOST=$(grep "DB_HOST" $WP_CONFIG | cut -d "'" -f 4)
}

check_mysql() {
    echo -e "${YELLOW}=== MARIADB & WORDPRESS DB ===${NC}"
    if systemctl is-active --quiet mariadb; then
        echo -e "${GREEN}✓ MariaDB: Running${NC}"
        
        get_wp_db_creds
        
        # Test WordPress DB connection
        if mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASS" "$DB_NAME" -e "SELECT 1;" >/dev/null 2>&1; then
            echo -e "${GREEN}✓ WordPress Database: Accessible${NC}"
            
            # WordPress-specific DB stats
            POST_COUNT=$(mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASS" "$DB_NAME" -e "SELECT COUNT(*) FROM wp_posts WHERE post_status='publish' AND post_type='post';" -s)
            PAGE_COUNT=$(mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASS" "$DB_NAME" -e "SELECT COUNT(*) FROM wp_posts WHERE post_status='publish' AND post_type='page';" -s)
            PRODUCT_COUNT=$(mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASS" "$DB_NAME" -e "SELECT COUNT(*) FROM wp_posts WHERE post_status='publish' AND post_type='product';" -s 2>/dev/null || echo "0")
            USER_COUNT=$(mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASS" "$DB_NAME" -e "SELECT COUNT(*) FROM wp_users;" -s)
            ORDER_COUNT=$(mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASS" "$DB_NAME" -e "SELECT COUNT(*) FROM wp_posts WHERE post_type='shop_order';" -s 2>/dev/null || echo "0")
            
            echo "Posts: $POST_COUNT | Pages: $PAGE_COUNT | Products: $PRODUCT_COUNT"
            echo "Users: $USER_COUNT | Orders: $ORDER_COUNT"
            
            # DB size
            DB_SIZE=$(mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASS" "$DB_NAME" -e "SELECT ROUND(SUM(data_length + index_length) / 1024 / 1024, 1) AS 'DB Size in MB' FROM information_schema.tables WHERE table_schema='$DB_NAME';" -s)
            echo "Database size: ${DB_SIZE} MB"
            
        else
            echo -e "${RED}✗ WordPress Database: Connection failed${NC}"
        fi
    else
        echo -e "${RED}✗ MariaDB: Stopped${NC}"
    fi
    echo
}

check_wordpress() {
    echo -e "${YELLOW}=== WORDPRESS STATUS ===${NC}"
    
    # WordPress version
    if [ -f "$WP_PATH/wp-includes/version.php" ]; then
        WP_VERSION=$(grep '$wp_version' $WP_PATH/wp-includes/version.php | cut -d "'" -f 2)
        echo "WordPress version: $WP_VERSION"
    fi
    
    # Active plugins count
    PLUGIN_COUNT=$(find $WP_PATH/wp-content/plugins -maxdepth 1 -type d | wc -l)
    echo "Installed plugins: $((PLUGIN_COUNT-1))"
    
    # Active theme
    ACTIVE_THEME=$(wp --path="$WP_PATH" theme list --status=active --field=name 2>/dev/null || echo "Unknown")
    echo "Active theme: $ACTIVE_THEME"
    
    # WordPress errors (last hour)
    WP_ERRORS=$(grep "$(date '+%Y-%m-%d %H')" $WP_PATH/wp-content/debug.log 2>/dev/null | wc -l)
    if [ $WP_ERRORS -gt 0 ]; then
        echo -e "${RED}Recent WP errors: $WP_ERRORS${NC}"
        tail -3 $WP_PATH/wp-content/debug.log 2>/dev/null
    else
        echo -e "${GREEN}✓ No recent WordPress errors${NC}"
    fi
    echo
}

check_upload_issues() {
    echo -e "${YELLOW}=== UPLOAD DIAGNOSTICS ===${NC}"
    
    # PHP upload settings
    echo -e "${BLUE}PHP Upload Limits:${NC}"
    php -r "
    echo 'upload_max_filesize: ' . ini_get('upload_max_filesize') . PHP_EOL;
    echo 'post_max_size: ' . ini_get('post_max_size') . PHP_EOL;
    echo 'max_execution_time: ' . ini_get('max_execution_time') . 's' . PHP_EOL;
    echo 'memory_limit: ' . ini_get('memory_limit') . PHP_EOL;
    echo 'max_file_uploads: ' . ini_get('max_file_uploads') . PHP_EOL;
    "
    
    # WordPress upload dir permissions
    UPLOAD_DIR="$WP_PATH/wp-content/uploads"
    UPLOAD_PERMS=$(stat -c "%a" "$UPLOAD_DIR" 2>/dev/null)
    UPLOAD_OWNER=$(stat -c "%U:%G" "$UPLOAD_DIR" 2>/dev/null)
    echo "Upload dir permissions: $UPLOAD_PERMS ($UPLOAD_OWNER)"
    
    # Recent failed uploads (look for tmp files)
    TEMP_FILES=$(find "$UPLOAD_DIR" -name "*.tmp" -mtime -1 2>/dev/null | wc -l)
    if [ $TEMP_FILES -gt 0 ]; then
        echo -e "${RED}Recent temp files (failed uploads): $TEMP_FILES${NC}"
        find "$UPLOAD_DIR" -name "*.tmp" -mtime -1 2>/dev/null | head -3
    else
        echo -e "${GREEN}✓ No recent failed uploads${NC}"
    fi
    
    # Check disk space in uploads
    UPLOAD_SIZE=$(du -sh "$UPLOAD_DIR" 2>/dev/null | cut -f1)
    echo "Uploads directory size: $UPLOAD_SIZE"
    
    # Recent upload activity
    RECENT_UPLOADS=$(find "$UPLOAD_DIR" -type f -mmin -60 2>/dev/null | wc -l)
    echo "Files uploaded in last hour: $RECENT_UPLOADS"
    
    echo
}

check_woocommerce() {
    echo -e "${YELLOW}=== WOOCOMMERCE STATUS ===${NC}"
    
    get_wp_db_creds
    
    # Check if WooCommerce is active
    if [ -d "$WP_PATH/wp-content/plugins/woocommerce" ]; then
        echo -e "${GREEN}✓ WooCommerce: Installed${NC}"
        
        # Recent orders
        RECENT_ORDERS=$(mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASS" "$DB_NAME" -e "SELECT COUNT(*) FROM wp_posts WHERE post_type='shop_order' AND post_date > DATE_SUB(NOW(), INTERVAL 24 HOUR);" -s 2>/dev/null || echo "0")
        echo "Orders (24h): $RECENT_ORDERS"
        
        # Download attempts (check logs)
        DOWNLOAD_LOGS=$(grep -i "download" /var/log/nginx/access.log | grep "$(date '+%d/%b/%Y')" | wc -l 2>/dev/null || echo "0")
        echo "Download attempts today: $DOWNLOAD_LOGS"
        
        # WooCommerce uploads protection
        if [ -f "$WP_PATH/wp-content/uploads/woocommerce_uploads/.htaccess" ]; then
            echo -e "${GREEN}✓ Downloads protected${NC}"
        else
            echo -e "${RED}✗ Downloads not protected${NC}"
        fi
    else
        echo -e "${RED}✗ WooCommerce: Not installed${NC}"
    fi
    echo
}

# Main execution
echo -e "${GREEN}=== WORDPRESS MONITOR - $(date) ===${NC}"
log_entry "WordPress monitor started"

# System basics
echo -e "${YELLOW}=== SYSTEM LOAD ===${NC}"
uptime | awk '{print "Load average: " $(NF-2) " " $(NF-1) " " $NF}'
free -h | grep Mem | awk '{print "Memory: " $3 "/" $2 " (" int($3/$2*100) "%)"}'
echo

check_mysql
check_wordpress
check_upload_issues
check_woocommerce

log_entry "WordPress monitor completed"
echo -e "${GREEN}=== END WORDPRESS MONITOR ===${NC}"
