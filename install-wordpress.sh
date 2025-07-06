#!/bin/bash
# WordPress NGINX installation script for Ubuntu 24.04 - Audio/Large File Version

# Check if running as root
# Get script directory for relative paths
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
if [ "$EUID" -ne 0 ]; then
   echo "Please run as root (use sudo)"
   exit 1
fi

# Check if we're in the right directory with our templates
if [ ! -f "configs/nginx/nginx-wordpress.template" ] || [ ! -f "configs/wordpress/wp-config.template.php" ]; then
    echo "Error: Missing template files. Make sure you're running this from the server-setup directory."
    exit 1
fi

# Load environment variables from .env file
if [ -f .env ]; then
  set -a  # automatically export all variables
  source .env
  set +a  # disable automatic export
fi

# Check for required env variables
if [ -z "$DOMAIN_NAME" ] || [ -z "$EMAIL" ]; then
    echo "Error: DOMAIN_NAME and EMAIL must be set in .env file"
    exit 1
fi

echo "Installing WordPress with NGINX on Ubuntu 24.04 (Audio Site Configuration)..."
echo "Domain: $DOMAIN_NAME"
echo "Email: $EMAIL"

# Generate random credentials
DB_NAME="wp$(date +%s)"
DB_USER="$DB_NAME"
MYSQL_ROOT_PASS=$(openssl rand -base64 12 | tr -d "=+/'\"")
DB_PASS=$(openssl rand -base64 12 | tr -d "=+/'\"")

# Update system
apt update && apt upgrade -y

# Install LEMP stack with all PHP extensions
apt install -y nginx certbot python3-certbot-nginx mariadb-server php8.3-fpm php8.3-mysql php8.3-curl php8.3-gd php8.3-mbstring php8.3-xml php8.3-zip php8.3-imagick php8.3-intl php8.3-bcmath

# install optional software
apt install -y sshfs

# Start and enable services
systemctl enable nginx mariadb php8.3-fpm
systemctl start nginx mariadb php8.3-fpm

# Configure systemd service dependencies for proper boot order
echo "Configuring systemd service dependencies..."
mkdir -p /etc/systemd/system/nginx.service.d
mkdir -p /etc/systemd/system/php8.3-fpm.service.d
cp "$SCRIPT_DIR/configs/systemd/overrides/nginx-mariadb-dependency.conf" /etc/systemd/system/nginx.service.d/mariadb-dependency.conf
cp "$SCRIPT_DIR/configs/systemd/overrides/php-fpm-mariadb-dependency.conf" /etc/systemd/system/php8.3-fpm.service.d/mariadb-dependency.conf
systemctl daemon-reload

# Secure MySQL and set root password
mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED BY '$MYSQL_ROOT_PASS';"
mysql -u root -p"$MYSQL_ROOT_PASS" -e "DELETE FROM mysql.user WHERE User='';"
mysql -u root -p"$MYSQL_ROOT_PASS" -e "DROP DATABASE IF EXISTS test;"
mysql -u root -p"$MYSQL_ROOT_PASS" -e "DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';"
mysql -u root -p"$MYSQL_ROOT_PASS" -e "FLUSH PRIVILEGES;"

# Lockdown MariaDB (MySQL) - No Remote Access
echo "Configuring MariaDB to allow only local connections..."
sed -i 's/^bind-address.*/bind-address = 127.0.0.1/' /etc/mysql/mariadb.conf.d/50-server.cnf

# Create WordPress database and user
mysql -u root -p"$MYSQL_ROOT_PASS" -e "CREATE DATABASE $DB_NAME DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
mysql -u root -p"$MYSQL_ROOT_PASS" -e "CREATE USER '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASS';"
mysql -u root -p"$MYSQL_ROOT_PASS" -e "GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'localhost';"
mysql -u root -p"$MYSQL_ROOT_PASS" -e "FLUSH PRIVILEGES;"

# Download and extract WordPress
cd /var/www/html || exit
wget https://wordpress.org/latest.tar.gz
tar xzf latest.tar.gz
mv wordpress/* .
mv wordpress/.* . 2>/dev/null || true
rmdir wordpress
rm -f latest.tar.gz index.nginx-debian.html

# Get WordPress salts and save to temp file
echo "Fetching WordPress salts..."
curl -s https://api.wordpress.org/secret-key/1.1/salt/ > /tmp/wp-salts.txt

# Setup wp-config.php from template
cp "$SCRIPT_DIR/configs/wordpress/wp-config.template.php" /var/www/html/wp-config.php

# Replace placeholders in wp-config.php
sed -i "s/%%DB_NAME%%/$DB_NAME/g" /var/www/html/wp-config.php
sed -i "s/%%DB_USER%%/$DB_USER/g" /var/www/html/wp-config.php
sed -i "s/%%DB_PASSWORD%%/$DB_PASS/g" /var/www/html/wp-config.php
sed -i "s/%%DOMAIN_NAME%%/$DOMAIN_NAME/g" /var/www/html/wp-config.php

# Insert salts (this is the tricky bit - we read them in without fucking up special chars)
sed -i "/%%SALT_KEYS%%/r /tmp/wp-salts.txt" /var/www/html/wp-config.php
sed -i "/%%SALT_KEYS%%/d" /var/www/html/wp-config.php

# Setup PHP configuration from templates
echo "Configuring PHP from templates..."
cp "$SCRIPT_DIR/configs/php/8.3/fpm/php.ini.template" /etc/php/8.3/fpm/php.ini
cp "$SCRIPT_DIR/configs/php/8.3/fpm/pool.d/www.conf.template" /etc/php/8.3/fpm/pool.d/www.conf

# Restart PHP-FPM to apply new configuration
systemctl restart php8.3-fpm

# Clean up
rm /tmp/wp-salts.txt

# Set proper permissions
chown -R www-data:www-data /var/www/html
find /var/www/html -type d -exec chmod 755 {} \;
find /var/www/html -type f -exec chmod 644 {} \;
chmod 640 /var/www/html/wp-config.php

# Setup nginx from template
echo "Configuring Nginx..."
cp "$SCRIPT_DIR/configs/nginx/nginx-wordpress.template" /etc/nginx/sites-available/default

# Configure main nginx.conf from template
cp "$SCRIPT_DIR/configs/nginx/nginx.conf.template" /etc/nginx/nginx.conf
sed -i "s/%%DOMAIN_NAME%%/$DOMAIN_NAME/g" /etc/nginx/sites-available/default


# Test nginx config and restart services
nginx -t && systemctl restart nginx php8.3-fpm

# Get SSL cert
echo "Getting SSL certificate..."
certbot --nginx --non-interactive --agree-tos -m "$EMAIL" -d "$DOMAIN_NAME"

# Install WP-CLI
curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
chmod +x wp-cli.phar
mv wp-cli.phar /usr/local/bin/wp

# Complete WordPress core installation
echo "Completing WordPress core installation..."
WP_ADMIN_PASSWORD=$(openssl rand -base64 12)
sudo -u www-data wp --path=/var/www/html core install \
    --url="https://$DOMAIN_NAME" \
    --title="$DOMAIN_NAME" \
    --admin_user="admin" \
    --admin_password="$WP_ADMIN_PASSWORD" \
    --admin_email="$EMAIL" \
    --skip-email

echo "WordPress core installation complete!"
echo "Admin credentials generated successfully"

# Set up real cron for WordPress

# Set up real cron for WordPress
echo "*/5 * * * * www-data php /var/www/html/wp-cron.php > /dev/null 2>&1" > /etc/cron.d/wordpress

# Create uploads directory
mkdir -p /var/www/html/wp-content/uploads
chown -R www-data:www-data /var/www/html/wp-content/uploads
chmod -R 755 /var/www/html/wp-content/uploads



# Apply MariaDB configuration template
echo "Applying MariaDB configuration template..."
cp "$SCRIPT_DIR/configs/mariadb/conf.d/60-optimizations.cnf" /etc/mysql/mariadb.conf.d/
systemctl restart mariadb

# Save credentials
cat > /root/wordpress-credentials.txt << EOF
WP_ADMIN_USER="admin"
WP_ADMIN_PASSWORD="$WP_ADMIN_PASSWORD"
DOMAIN_URL="https://$DOMAIN_NAME/wp-admin"
DOMAIN="$DOMAIN_NAME"
EMAIL="$EMAIL"
DB_NAME="$DB_NAME"
DB_USER="$DB_USER"
DB_PASS="$DB_PASS"
MYSQL_ROOT_PASS="$MYSQL_ROOT_PASS"
EOF

chmod 600 /root/wordpress-credentials.txt

# Display completion message
echo "=========================="
echo "WordPress NGINX Installation Complete!"
echo "Optimized for 32GB RAM Server"
echo "=========================="
echo "WordPress Admin User: admin"
echo "WordPress Admin Password: $WP_ADMIN_PASSWORD"
echo "WordPress Admin URL: https://$DOMAIN_NAME/wp-admin"
echo "Database Name: $DB_NAME"
echo "Database User: $DB_USER"
echo "Database Password: $DB_PASS"
echo "MySQL Root Password: $MYSQL_ROOT_PASS"
echo "=========================="
echo "Credentials saved to: /root/wordpress-credentials.txt"
echo "Visit https://$DOMAIN_NAME to complete setup"
echo ""
echo "Theme: Bandfront child theme activated"
echo ""

# Install and activate the Bandfront child theme
echo "Installing Bandfront child theme..."

# Copy the Bandfront theme to WordPress themes directory
cp -r "$SCRIPT_DIR/themes/bandfront" /var/www/html/wp-content/themes/

# Set proper permissions for the theme
chown -R www-data:www-data /var/www/html/wp-content/themes/bandfront
find /var/www/html/wp-content/themes/bandfront -type d -exec chmod 755 {} \;
find /var/www/html/wp-content/themes/bandfront -type f -exec chmod 644 {} \;

# Install parent theme (Storefront) via WP-CLI
echo "Installing Storefront parent theme..."
sudo -u www-data wp --path=/var/www/html theme install storefront --activate

# Activate the Bandfront child theme
echo "Activating Bandfront child theme..."
sudo -u www-data wp --path=/var/www/html theme activate bandfront

echo "Bandfront child theme installation complete!"
