#!/bin/bash
# WordPress NGINX installation script for Ubuntu 24.04 - High Performance 32GB RAM Version

# Exit on any error
set -e

# Function for error handling
handle_error() {
    echo "Error: $1"
    exit 1
}

# Function to verify directory and file existence
verify_files() {
    local required_files=(
        "nginx-wordpress.template"
        "wp-config.template.php"
        "mariadb/conf.d/60-optimizations.cnf"
        "php/8.3/fpm/php.ini.template"
        "php/8.3/fpm/pool.d/www.conf.template"
    )

    for file in "${required_files[@]}"; do
        if [ ! -f "$file" ]; then
            handle_error "Missing required file: $file"
        fi
    done
}

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    handle_error "Please run as root (use sudo)"
fi

# Verify all required files exist
verify_files

# Load environment variables from .env file
if [ -f .env ]; then
    export $(grep -v '^#' .env | xargs)
else
    handle_error ".env file not found"
fi

# Check for required env variables
if [ -z "$DOMAIN_NAME" ] || [ -z "$EMAIL" ]; then
    handle_error "DOMAIN_NAME and EMAIL must be set in .env file"
fi

echo "Installing WordPress with NGINX on Ubuntu 24.04 (32GB RAM High Performance Configuration)..."
echo "Domain: $DOMAIN_NAME"
echo "Email: $EMAIL"

# Generate random credentials
DB_NAME="wp$(date +%s)"
DB_USER="$DB_NAME"
MYSQL_ROOT_PASS=$(openssl rand -base64 12 | tr -d "=+/'\"")
DB_PASS=$(openssl rand -base64 12 | tr -d "=+/'\"")

# Update system
apt update && apt upgrade -y || handle_error "System update failed"

# Install LEMP stack with all required extensions
echo "Installing LEMP stack and required extensions..."
apt install -y nginx certbot python3-certbot-nginx mariadb-server \
    php8.3-fpm php8.3-mysql php8.3-curl php8.3-gd php8.3-mbstring \
    php8.3-xml php8.3-zip php8.3-imagick php8.3-intl php8.3-bcmath \
    php8.3-opcache sshfs || handle_error "Package installation failed"

# Start and enable services
echo "Enabling and starting services..."
systemctl enable nginx mariadb php8.3-fpm || handle_error "Service enablement failed"
systemctl start nginx mariadb php8.3-fpm || handle_error "Service start failed"

# Secure MariaDB installation
echo "Configuring MariaDB..."
mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED BY '$MYSQL_ROOT_PASS';" || handle_error "MariaDB root password setup failed"
mysql -u root -p"$MYSQL_ROOT_PASS" <<EOF || handle_error "MariaDB secure installation failed"
DELETE FROM mysql.user WHERE User='';
DROP DATABASE IF EXISTS test;
DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';
FLUSH PRIVILEGES;
EOF

# Create WordPress database and user
echo "Creating WordPress database..."
mysql -u root -p"$MYSQL_ROOT_PASS" <<EOF || handle_error "WordPress database creation failed"
CREATE DATABASE $DB_NAME DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASS';
GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'localhost';
FLUSH PRIVILEGES;
EOF

# Configure MariaDB for 32GB RAM server
echo "Applying MariaDB optimizations..."
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cp "$SCRIPT_DIR/mariadb/conf.d/60-optimizations.cnf" /etc/mysql/mariadb.conf.d/ || handle_error "MariaDB optimization failed"
systemctl restart mariadb || handle_error "MariaDB restart failed"

# Configure PHP-FPM and PHP.ini
echo "Configuring PHP..."
cp "$SCRIPT_DIR/php/8.3/fpm/php.ini.template" /etc/php/8.3/fpm/php.ini || handle_error "PHP.ini configuration failed"
cp "$SCRIPT_DIR/php/8.3/fpm/pool.d/www.conf.template" /etc/php/8.3/fpm/pool.d/www.conf || handle_error "PHP-FPM configuration failed"

# Verify PHP configurations
if ! php -v >/dev/null 2>&1; then
    handle_error "PHP configuration verification failed"
fi

# Download and install WordPress
echo "Installing WordPress..."
cd /var/www/html || handle_error "Cannot access web root"
wget https://wordpress.org/latest.tar.gz || handle_error "WordPress download failed"
tar xzf latest.tar.gz || handle_error "WordPress extraction failed"
mv wordpress/* . || handle_error "WordPress file movement failed"
mv wordpress/.* . 2>/dev/null || true
rmdir wordpress
rm -f latest.tar.gz index.nginx-debian.html

# Configure WordPress
echo "Configuring WordPress..."
curl -s https://api.wordpress.org/secret-key/1.1/salt/ > /tmp/wp-salts.txt || handle_error "WordPress salt generation failed"
cp "$SCRIPT_DIR/wp-config.template.php" wp-config.php || handle_error "wp-config.php creation failed"

# Replace configuration placeholders
sed -i "s/%%DB_NAME%%/$DB_NAME/g" wp-config.php || handle_error "Database name configuration failed"
sed -i "s/%%DB_USER%%/$DB_USER/g" wp-config.php || handle_error "Database user configuration failed"
sed -i "s/%%DB_PASSWORD%%/$DB_PASS/g" wp-config.php || handle_error "Database password configuration failed"
sed -i "s/%%DOMAIN_NAME%%/$DOMAIN_NAME/g" wp-config.php || handle_error "Domain configuration failed"
sed -i "/%%SALT_KEYS%%/r /tmp/wp-salts.txt" wp-config.php || handle_error "Salt key configuration failed"
sed -i "/%%SALT_KEYS%%/d" wp-config.php
rm /tmp/wp-salts.txt

# Set proper permissions
echo "Setting file permissions..."
chown -R www-data:www-data /var/www/html || handle_error "Permission setting failed"
find /var/www/html -type d -exec chmod 755 {} \;
find /var/www/html -type f -exec chmod 644 {} \;
chmod 640 /var/www/html/wp-config.php

# Configure Nginx
echo "Configuring Nginx..."
cp "$SCRIPT_DIR/nginx-wordpress.template" /etc/nginx/sites-available/default || handle_error "Nginx configuration failed"
sed -i "s/%%DOMAIN_NAME%%/$DOMAIN_NAME/g" /etc/nginx/sites-available/default || handle_error "Nginx domain configuration failed"

# Configure main nginx.conf
echo "Optimizing Nginx..."
sed -i 's/# server_names_hash_bucket_size/server_names_hash_bucket_size/' /etc/nginx/nginx.conf
sed -i '/http {/a \    client_max_body_size 2G;\n    proxy_read_timeout 3600;\n    proxy_connect_timeout 3600;\n    proxy_send_timeout 3600;' /etc/nginx/nginx.conf
sed -i 's/worker_processes auto;/worker_processes auto;\nworker_rlimit_nofile 65535;/' /etc/nginx/nginx.conf

# Update nginx events block
sed -i '/events {/,/}/ {
    /worker_connections/d
    /use epoll/d
    /multi_accept/d
}' /etc/nginx/nginx.conf
sed -i '/events {/a \    worker_connections 4096;\n    use epoll;\n    multi_accept on;' /etc/nginx/nginx.conf

# Verify configurations
echo "Verifying configurations..."
nginx -t || handle_error "Nginx configuration test failed"
php-fpm8.3 -t || handle_error "PHP-FPM configuration test failed"

# Restart services
echo "Restarting services..."
systemctl restart php8.3-fpm || handle_error "PHP-FPM restart failed"
systemctl restart nginx || handle_error "Nginx restart failed"

# Get SSL certificate
echo "Obtaining SSL certificate..."
certbot --nginx --non-interactive --agree-tos -m "$EMAIL" -d "$DOMAIN_NAME" || handle_error "SSL certificate acquisition failed"

# Install WP-CLI
echo "Installing WP-CLI..."
curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar || handle_error "WP-CLI download failed"
chmod +x wp-cli.phar
mv wp-cli.phar /usr/local/bin/wp

# Set up WordPress cron in system crontab
echo "Configuring system cron for WordPress..."
echo "*/5 * * * * www-data php /var/www/html/wp-cron.php > /dev/null 2>&1" > /etc/cron.d/wordpress

# Create uploads directory
mkdir -p /var/www/html/wp-content/uploads
chown -R www-data:www-data /var/www/html/wp-content/uploads
chmod -R 755 /var/www/html/wp-content/uploads

# Save credentials
echo "Saving credentials..."
cat > /root/wordpress-credentials.txt << EOF
=========================
WordPress High Performance Installation Details
=========================
Domain: $DOMAIN_NAME
Database Name: $DB_NAME
Database User: $DB_USER
Database Password: $DB_PASS
MySQL Root Password: $MYSQL_ROOT_PASS
=========================
Performance Configuration:
- PHP Memory: 8GB
- WP Memory: 512MB (regular), 8GB (admin)
- MariaDB Buffer: 20GB
- Max upload size: 2GB
- Extended execution time: 1 hour
=========================
EOF

chmod 600 /root/wordpress-credentials.txt

echo "=========================="
echo "WordPress Installation Complete!"
echo "Optimized for 32GB RAM Server"
echo "=========================="
echo "Installation Details:"
echo "Domain: $DOMAIN_NAME"
echo "Database Name: $DB_NAME"
echo "Database User: $DB_USER"
echo "Database Password: $DB_PASS"
echo "MySQL Root Password: $MYSQL_ROOT_PASS"
echo "=========================="
echo "Credentials saved to: /root/wordpress-credentials.txt"
echo "Visit https://$DOMAIN_NAME to complete setup"
echo ""
echo "Post-Installation Recommendations:"
echo "1. Install a caching plugin"
echo "2. Configure object caching (Redis recommended)"
echo "3. Set up a CDN for media delivery"
echo "4. Monitor PHP-FPM and MariaDB performance"
echo "5. Regular backup setup"
