<?php
/**
 * The base configuration for WordPress
 *
 * @link https://developer.wordpress.org/advanced-administration/wordpress/wp-config/
 *
 * @package WordPress
 */

// ** Database settings - You can get this info from your web host ** //
/** The name of the database for WordPress */
define( 'DB_NAME', '%%DB_NAME%%' );

/** Database username */
define( 'DB_USER', '%%DB_USER%%' );

/** Database password */
define( 'DB_PASSWORD', '%%DB_PASSWORD%%' );

/** Database hostname */
define( 'DB_HOST', 'localhost' );

/** Database charset to use in creating database tables. */
define( 'DB_CHARSET', 'utf8mb4' );

/** The database collate type. Don't change this if in doubt. */
define( 'DB_COLLATE', '' );

/**#@+
 * Authentication unique keys and salts.
 */
%%SALT_KEYS%%

/**#@-*/

$table_prefix = 'wp_';

// Debug settings
define( 'WP_DEBUG', false );
define( 'WP_DEBUG_LOG', false );
define( 'WP_DEBUG_DISPLAY', false );

// Force SSL configuration
if (isset($_SERVER['HTTP_X_FORWARDED_PROTO']) && $_SERVER['HTTP_X_FORWARDED_PROTO'] === 'https') {
    $_SERVER['HTTPS'] = 'on';
}
define('FORCE_SSL_ADMIN', true);
define('WP_HOME','https://%%DOMAIN_NAME%%');
define('WP_SITEURL','https://%%DOMAIN_NAME%%');

// Memory settings optimized for 32GB RAM server
define('WP_MEMORY_LIMIT', '512M');      // Regular operation limit
define('WP_MAX_MEMORY_LIMIT', '8G');    // Admin/upload operations limit

// PHP settings optimized for high-performance server
@ini_set('memory_limit', '8G');
@ini_set('upload_max_filesize', '2048M');
@ini_set('post_max_size', '2048M');
@ini_set('max_execution_time', '3600');
@ini_set('max_input_time', '3600');

// Performance optimizations
define('DISABLE_WP_CRON', true);        // Using server cron instead
define('WP_POST_REVISIONS', 20);        // Limit post revisions
define('EMPTY_TRASH_DAYS', 7);          // Empty trash after 7 days
define('WP_CACHE', false);              // Let plugins handle caching

// WooCommerce settings for digital downloads
define('WC_CHUNK_SIZE', 2 * 1024 * 1024); // 2MB chunks for better performance

/* That's all, stop editing! Happy publishing. */

/** Absolute path to the WordPress directory. */
if ( ! defined( 'ABSPATH' ) ) {
    define( 'ABSPATH', __DIR__ . '/' );
}

/** Sets up WordPress vars and included files. */
require_once ABSPATH . 'wp-settings.php';
