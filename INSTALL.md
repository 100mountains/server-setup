# CONFIG DESCRIPTIONS

## MariaDB Configuration Settings

Current MariaDB configuration from `configs/mariadb/conf.d/60-optimizations.cnf`:

| Setting | Value |
|---------|-------|
| innodb_buffer_pool_size | 20G |
| innodb_file_per_table | ON |
| innodb_flush_method | O_DIRECT |
| innodb_flush_log_at_trx_commit | 2 |
| innodb_log_buffer_size | 64M |
| innodb_log_file_size | 512M |
| max_connections | 500 |
| thread_cache_size | 200 |
| thread_stack | 256K |
| query_cache_type | OFF |
| table_open_cache | 4000 |
| table_definition_cache | 2048 |
| max_allowed_packet | 256M |
| tmp_table_size | 256M |
| max_heap_table_size | 256M |
| sort_buffer_size | 4M |
| read_buffer_size | 3M |
| read_rnd_buffer_size | 4M |
| join_buffer_size | 4M |
| performance_schema | ON |

Configuration File Location: `configs/mariadb/conf.d/60-optimizations.cnf`






Wordpress Child Theme Installation

installs https://github.com/100mountains/bandfront


Wordpress Plugin Installation

install_plugin "WooCommerce" "woocommerce"
install_plugin "WooCommerce PayPal Payments" "woocommerce-paypal-payments"  
install_plugin "Theme My Login" "theme-my-login"
install_plugin "WP Armour - Honeypot Anti Spam" "wp-armour-extended"
install_plugin "WooCommerce Tax" "woocommerce-tax"