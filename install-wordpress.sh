#!/bin/bash
# WordPress NGINX installation script for Ubuntu 24.04 - Audio/Large File Version
#

# Load environment variables from .env file
if [ -f .env ]; then
  export $(cat .env | xargs)
fi

# Check if running as root
if [ "$EUID" -ne 0 ]; then
   echo "Please run as root (use sudo)"
   exit 1
fi

echo "Installing WordPress with NGINX on Ubuntu 24.04 (Audio Site Configuration)..."

# Generate random credentials
DB_NAME="wp$(date +%s)"
DB_USER="$DB_NAME"
DB_PASS=$(openssl rand -base64 12)
MYSQL_ROOT_PASS=$(openssl rand -base64 12)

# Update system
apt update && apt upgrade -y

# Install LEMP stack with all PHP extensions
apt install -y nginx certbot python3-certbot-nginx mariadb-server php8.3-fpm php8.3-mysql php8.3-curl php8.3-gd php8.3-mbstring php8.3-xml php8.3-zip php8.3-imagick php8.3-intl php8.3-bcmath

# Start and enable services
systemctl enable nginx mariadb php8.3-fpm
systemctl start nginx mariadb php8.3-fpm

# Secure MySQL and set root password
mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '$MYSQL_ROOT_PASS';"
mysql -u root -p$MYSQL_ROOT_PASS -e "DELETE FROM mysql.user WHERE User='';"
mysql -u root -p$MYSQL_ROOT_PASS -e "DROP DATABASE IF EXISTS test;"
mysql -u root -p$MYSQL_ROOT_PASS -e "DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';"
mysql -u root -p$MYSQL_ROOT_PASS -e "FLUSH PRIVILEGES;"

# MariaDB hardening (non-interactive)
mysql -u root -p$MYSQL_ROOT_PASS -e "UPDATE mysql.user SET plugin='mysql_native_password' WHERE User='root';"
mysql -u root -p$MYSQL_ROOT_PASS -e "DELETE FROM mysql.db WHERE Db='information_schema' OR Db='performance_schema';"
mysql -u root -p$MYSQL_ROOT_PASS -e "FLUSH PRIVILEGES;"

# Create WordPress database and user
mysql -u root -p$MYSQL_ROOT_PASS -e "CREATE DATABASE $DB_NAME DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
mysql -u root -p$MYSQL_ROOT_PASS -e "CREATE USER '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASS';"
mysql -u root -p$MYSQL_ROOT_PASS -e "GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'localhost';"
mysql -u root -p$MYSQL_ROOT_PASS -e "FLUSH PRIVILEGES;"

# Download and extract WordPress
cd /var/www/html
wget https://wordpress.org/latest.tar.gz
tar xzf latest.tar.gz
mv wordpress/* .
mv wordpress/.* . 2>/dev/null || true
rmdir wordpress
rm -f latest.tar.gz index.nginx-debian.html

# Configure WordPress
cp wp-config-sample.php wp-config.php
sed -i "s/database_name_here/$DB_NAME/" wp-config.php
sed -i "s/username_here/$DB_USER/" wp-config.php
sed -i "s/password_here/$DB_PASS/" wp-config.php

# Add salts to wp-config.php
SALT_KEYS=$(curl -s https://api.wordpress.org/secret-key/1.1/salt/)
sed -i "/put your unique phrase here/d" wp-config.php
echo "$SALT_KEYS" >> wp-config.php

# Set proper permissions
chown -R www-data:www-data /var/www/html
find /var/www/html -type d -exec chmod 755 {} \;
find /var/www/html -type f -exec chmod 644 {} \;

# Configure PHP for massive file uploads with HIGH MEMORY (32GB server)
# PHP-FPM configuration
sed -i 's/memory_limit = 128M/memory_limit = 4G/' /etc/php/8.3/fpm/php.ini
sed -i 's/upload_max_filesize = 2M/upload_max_filesize = 2G/' /etc/php/8.3/fpm/php.ini
sed -i 's/post_max_size = 8M/post_max_size = 2G/' /etc/php/8.3/fpm/php.ini
sed -i 's/max_execution_time = 30/max_execution_time = 3600/' /etc/php/8.3/fpm/php.ini
sed -i 's/max_input_time = 60/max_input_time = 3600/' /etc/php/8.3/fpm/php.ini
sed -i 's/;max_input_vars = 1000/max_input_vars = 10000/' /etc/php/8.3/fpm/php.ini

# Configure PHP-FPM pool for better performance with high memory
echo 'pm.max_children = 100
pm.start_servers = 20
pm.min_spare_servers = 10
pm.max_spare_servers = 40
pm.max_requests = 1000' >> /etc/php/8.3/fpm/pool.d/www.conf

# Configure Nginx for WordPress with audio streaming optimizations
echo "server {
   listen 80 default_server;
   listen [::]:80 default_server;
   
   root /var/www/html;
   index index.php index.html index.htm;
   
   server_name $DOMAIN_NAME;
   
   # Massive file upload support
   client_max_body_size 2G;
   client_body_buffer_size 512K;
   client_body_timeout 3600;
   client_header_timeout 3600;
   keepalive_timeout 3600;
   send_timeout 3600;
   
   # Proxy timeouts for large uploads
   proxy_connect_timeout 3600;
   proxy_send_timeout 3600;
   proxy_read_timeout 3600;
   
   # FastCGI timeouts
   fastcgi_read_timeout 3600;
   fastcgi_send_timeout 3600;
   
   location / {
       try_files $uri $uri/ /index.php?$args;
   }
   
   location ~ \.php$ {
       include snippets/fastcgi-php.conf;
       fastcgi_pass unix:/var/run/php/php8.3-fpm.sock;
       fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
       include fastcgi_params;
       fastcgi_buffer_size 128k;
       fastcgi_buffers 256 16k;
       fastcgi_busy_buffers_size 256k;
       fastcgi_temp_file_write_size 256k;
   }
   
   # Audio file handling with proper headers
   location ~* \.(mp3|mp4|m4a|flac|wav|ogg|aac|wma|aiff|ape)$ {
       expires 30d;
       add_header Cache-Control "public, immutable";
       add_header X-Content-Type-Options "nosniff";
       
       # Enable range requests for audio streaming
       add_header Accept-Ranges bytes;
       
       # Disable access logging for audio files to save disk I/O
       access_log off;
   }
   
   location ~ /\.ht {
       deny all;
   }
   
   location = /favicon.ico {
       log_not_found off;
       access_log off;
   }
   
   location = /robots.txt {
       allow all;
       log_not_found off;
       access_log off;
   }
   
   location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg)$ {
       expires max;
       log_not_found off;
   }
}"  | envsubst '$SERVER_NAME' > /etc/nginx/sites-available/default

# Increase Nginx main configuration limits
sed -i 's/# server_names_hash_bucket_size/server_names_hash_bucket_size/' /etc/nginx/nginx.conf
sed -i '/http {/a \    client_max_body_size 2G;\n    proxy_read_timeout 3600;\n    proxy_connect_timeout 3600;\n    proxy_send_timeout 3600;' /etc/nginx/nginx.conf

# Optimize Nginx worker processes for high memory server
sed -i 's/worker_processes auto;/worker_processes auto;\nworker_rlimit_nofile 65535;/' /etc/nginx/nginx.conf

# Check if events block exists and update it properly
if grep -q "events {" /etc/nginx/nginx.conf; then
   # Backup original
   cp /etc/nginx/nginx.conf /etc/nginx/nginx.conf.bak
   
   # Update events block without creating duplicates
   sed -i '/events {/,/}/ {
       /worker_connections/d
       /use epoll/d
       /multi_accept/d
   }' /etc/nginx/nginx.conf
   
   sed -i '/events {/a \    worker_connections 4096;\n    use epoll;\n    multi_accept on;' /etc/nginx/nginx.conf
fi

# Test nginx config and restart services
nginx -t && systemctl restart nginx php8.3-fpm

# Install Certbot from Nginx config
certbot --nginx --non-interactive --agree-tos -m $EMAIL

# Install WP-CLI for easier management
curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
chmod +x wp-cli.phar
mv wp-cli.phar /usr/local/bin/wp

# Add WordPress configuration for large files with HIGH MEMORY
cd /var/www/html
echo "
// Increase WordPress memory limit (using 2GB for WP, 4GB for max)
define('WP_MEMORY_LIMIT', '2G');
define('WP_MAX_MEMORY_LIMIT', '4G');

// Increase upload size in WordPress
@ini_set('upload_max_size', '2048M');
@ini_set('post_max_size', '2048M');
@ini_set('max_execution_time', '3600');

// WooCommerce specific settings for digital downloads
define('WC_CHUNK_SIZE', 1024 * 1024); // 1MB chunks for downloads

// Disable WordPress cron for better performance (use real cron instead)
define('DISABLE_WP_CRON', true);" >> wp-config.php

# Set up real cron for WordPress (better for high traffic)
echo "*/5 * * * * www-data php /var/www/html/wp-cron.php > /dev/null 2>&1" > /etc/cron.d/wordpress

# Create uploads directory with proper permissions
mkdir -p /var/www/html/wp-content/uploads
chown -R www-data:www-data /var/www/html/wp-content/uploads
chmod -R 755 /var/www/html/wp-content/uploads

# Configure MariaDB for better performance with high memory
echo "[mysqld]
innodb_buffer_pool_size = 8G
innodb_log_file_size = 1G
innodb_flush_log_at_trx_commit = 2
innodb_flush_method = O_DIRECT
query_cache_type = 1
query_cache_size = 256M
tmp_table_size = 512M
max_heap_table_size = 512M" > /etc/mysql/conf.d/wordpress.cnf

systemctl restart mariadb

# Save credentials to file
echo "=========================" > /root/wordpress-credentials.txt
echo "WordPress Audio Site Installation Details" >> /root/wordpress-credentials.txt
echo "=========================" >> /root/wordpress-credentials.txt
echo "Database Name: $DB_NAME" >> /root/wordpress-credentials.txt
echo "Database User: $DB_USER" >> /root/wordpress-credentials.txt
echo "Database Password: $DB_PASS" >> /root/wordpress-credentials.txt
echo "MySQL Root Password: $MYSQL_ROOT_PASS" >> /root/wordpress-credentials.txt
echo "=========================" >> /root/wordpress-credentials.txt
echo "Performance Configuration:" >> /root/wordpress-credentials.txt
echo "- PHP Memory: 4GB" >> /root/wordpress-credentials.txt
echo "- WP Memory: 2GB (max 4GB)" >> /root/wordpress-credentials.txt
echo "- MariaDB Buffer: 8GB" >> /root/wordpress-credentials.txt
echo "- Max upload size: 2GB" >> /root/wordpress-credentials.txt
echo "- Execution time: 1 hour" >> /root/wordpress-credentials.txt
echo "=========================" >> /root/wordpress-credentials.txt

# Display completion message
echo "=========================="
echo "WordPress NGINX Installation Complete!"
echo "Optimized for 32GB RAM Server"
echo "=========================="
echo "Database Name: $DB_NAME"
echo "Database User: $DB_USER"
echo "Database Password: $DB_PASS"
echo "MySQL Root Password: $MYSQL_ROOT_PASS"
echo "=========================="
echo "Performance Configuration:"
echo "- PHP Memory: 4GB"
echo "- WP Memory: 2GB (max 4GB)"
echo "- MariaDB Buffer: 8GB"
echo "- Max upload: 2GB"
echo "- Timeout: 1 hour"
echo "=========================="
echo "Credentials saved to: /root/wordpress-credentials.txt"
echo "Visit http://$(hostname -I | awk '{print $1}') to complete setup"
echo ""
echo "For SSL/HTTPS (REQUIRED for large uploads), run:"
echo "apt install certbot python3-certbot-nginx && certbot --nginx"
echo ""
echo "Consider installing these plugins for audio handling:"
echo "- WooCommerce (for selling)"
echo "- WP Offload Media (for S3/CDN storage)" 
echo "- Seriously Simple Podcasting (for streaming)"
