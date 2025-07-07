#!/bin/bash
# WordPress Music Store Plugins Installation Script
# Installs and configures essential plugins for a music/audio store

# Check if running as root
if [ "$EUID" -ne 0 ]; then
   echo "Please run as root (use sudo)"
   exit 1
fi

# Check if WordPress is installed
if [ ! -f "/var/www/html/wp-config.php" ]; then
    echo "Error: WordPress not found at /var/www/html/"
    echo "Please run install-wordpress.sh first"
    exit 1
fi

# Read WordPress credentials
if [ -f /root/wordpress-credentials.txt ]; then
    source /root/wordpress-credentials.txt
else
    echo "Error: WordPress credentials file not found"
    exit 1
fi

echo "Installing Music Store Plugins for WordPress..."
echo "Domain: $DOMAIN_NAME"
echo ""

# Function to check if WP-CLI is available
check_wp_cli() {
    if ! command -v wp &> /dev/null; then
        echo "Error: WP-CLI not found. Please install WP-CLI first."
        exit 1
    fi
}

# Function to install and activate a plugin
install_plugin() {
    local plugin_name="$1"
    local plugin_slug="$2"
    
    echo "Installing $plugin_name..."
    
    # Check if plugin is already installed
    if sudo -u www-data wp --path=/var/www/html plugin is-installed "$plugin_slug" 2>/dev/null; then
        echo "$plugin_name is already installed."
        # Activate if not active
        if ! sudo -u www-data wp --path=/var/www/html plugin is-active "$plugin_slug" 2>/dev/null; then
            echo "Activating $plugin_name..."
            sudo -u www-data wp --path=/var/www/html plugin activate "$plugin_slug"
        else
            echo "$plugin_name is already active."
        fi
    else
        # Install and activate plugin
        if sudo -u www-data wp --path=/var/www/html plugin install "$plugin_slug" --activate; then
            echo "$plugin_name installed and activated successfully!"
        else
            echo "Failed to install $plugin_name"
            return 1
        fi
    fi
    echo ""
}

# Check WP-CLI availability
check_wp_cli

echo "Starting plugin installation..."
echo "================================="

# Install WooCommerce (E-commerce platform)
install_plugin "WooCommerce" "woocommerce"

# Install WooCommerce PayPal Payments
install_plugin "WooCommerce PayPal Payments" "woocommerce-paypal-payments"

# Install Theme My Login (Custom login experience)
install_plugin "Theme My Login" "theme-my-login"

# Install WP Armour - Honeypot Anti Spam (correct slug)
install_plugin "WP Armour - Honeypot Anti Spam" "honeypot-anti-spam"

# Remove WooCommerce Tax - this is a premium plugin, not available in free repo
# install_plugin "WooCommerce Tax" "woocommerce-tax"

# Install List Category Posts (content organization)
install_plugin "List Category Posts" "list-category-posts"

# Install MailPoet (email marketing)
install_plugin "MailPoet" "mailpoet"

echo "================================="
echo "Configuring plugins..."
echo "================================="

# Configure WooCommerce basic settings
echo "Configuring WooCommerce basic settings..."
sudo -u www-data wp --path=/var/www/html option update woocommerce_store_address "Your Store Address"
sudo -u www-data wp --path=/var/www/html option update woocommerce_store_city "Your City"
sudo -u www-data wp --path=/var/www/html option update woocommerce_default_country "US:CA"
sudo -u www-data wp --path=/var/www/html option update woocommerce_store_postcode "12345"
sudo -u www-data wp --path=/var/www/html option update woocommerce_currency "USD"
sudo -u www-data wp --path=/var/www/html option update woocommerce_product_type "both"
sudo -u www-data wp --path=/var/www/html option update woocommerce_allow_tracking "no"

# Enable digital downloads (perfect for music)
sudo -u www-data wp --path=/var/www/html option update woocommerce_enable_guest_checkout "yes"
sudo -u www-data wp --path=/var/www/html option update woocommerce_enable_checkout_login_reminder "yes"
sudo -u www-data wp --path=/var/www/html option update woocommerce_enable_signup_and_login_from_checkout "yes"

# Configure for digital products (music)
echo "Configuring WooCommerce for digital music products..."
sudo -u www-data wp --path=/var/www/html option update woocommerce_downloads_require_login "yes"
sudo -u www-data wp --path=/var/www/html option update woocommerce_downloads_grant_access_after_payment "yes"

# Configure Theme My Login
echo "Configuring Theme My Login..."
sudo -u www-data wp --path=/var/www/html option update theme_my_login_enable "1"
sudo -u www-data wp --path=/var/www/html option update theme_my_login_redirect_to_referer "1"

# Configure MailPoet
echo "Configuring MailPoet..."
sudo -u www-data wp --path=/var/www/html option update mailpoet_analytics_enabled "0"
sudo -u www-data wp --path=/var/www/html option update mailpoet_premium_key ""

# Configure WP Armour Anti-Spam
echo "Configuring WP Armour Anti-Spam..."
sudo -u www-data wp --path=/var/www/html option update wp_armour_enable "1"
sudo -u www-data wp --path=/var/www/html option update wp_armour_honeypot_enable "1"

# Create necessary directories
echo "Creating necessary directories..."

# Create uploads directory for digital products
mkdir -p /var/www/html/wp-content/uploads/woocommerce_uploads
chown -R www-data:www-data /var/www/html/wp-content/uploads/woocommerce_uploads
chmod -R 755 /var/www/html/wp-content/uploads/woocommerce_uploads

# Set proper permissions for all plugins
echo "Setting proper permissions..."
chown -R www-data:www-data /var/www/html/wp-content/plugins/
find /var/www/html/wp-content/plugins/ -type d -exec chmod 755 {} \;
find /var/www/html/wp-content/plugins/ -type f -exec chmod 644 {} \;

echo "================================="
echo "Music Store Plugins Installation Complete!"
echo "================================="
echo "Installed Plugins:"
echo "- WooCommerce (E-commerce platform)"
echo "- WooCommerce PayPal Payments (Payment gateway)"
echo "- Theme My Login (Custom login experience)"
echo "- WP Armour - Honeypot Anti Spam (Security)"
echo "- List Category Posts (Content organization)"
echo "- MailPoet (Email marketing)"
echo ""
echo "Created Directories:"
echo "- /var/www/html/wp-content/uploads/woocommerce_uploads"
echo ""
echo "Next Steps:"
echo "1. Visit https://$DOMAIN_NAME/wp-admin to complete WordPress setup"
echo "2. Complete WooCommerce setup wizard"
echo "3. Configure PayPal payments in WooCommerce settings"
echo "4. Set up Theme My Login pages and styling"
echo "5. Configure tax settings for your location"
echo "6. Add your music products with downloadable files"
echo ""
