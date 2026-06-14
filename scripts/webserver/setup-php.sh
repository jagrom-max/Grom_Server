#!/bin/bash
# =============================================================================
# GROM SERVER - Setup PHP 8.3-FPM
# Executar DENTRO do container CT100 (grom-web)
# TOTALMENTE AUTOMATIZADO
# =============================================================================

set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

log() { echo -e "\033[0;32m[✓]\033[0m $1"; }
info() { echo -e "\033[0;34m[i]\033[0m $1"; }

echo "============================================"
echo "  GROM SERVER - Setup PHP 8.3-FPM"
echo "============================================"

# 1. Instalar PHP 8.3 e extensões
info "Instalando PHP 8.3-FPM e extensões..."
apt-get install -y -qq \
    php8.3-fpm \
    php8.3-mysql \
    php8.3-mbstring \
    php8.3-xml \
    php8.3-gd \
    php8.3-curl \
    php8.3-zip \
    php8.3-intl \
    php8.3-bcmath \
    php8.3-opcache \
    php8.3-readline \
    php8.3-cli
log "PHP 8.3-FPM instalado"

# 2. Configuração de produção
info "Aplicando configuração de produção..."
PHP_INI="/etc/php/8.3/fpm/php.ini"

sed -i 's/^display_errors = .*/display_errors = Off/' "$PHP_INI"
sed -i 's/^display_startup_errors = .*/display_startup_errors = Off/' "$PHP_INI"
sed -i 's/^log_errors = .*/log_errors = On/' "$PHP_INI"
sed -i 's/^error_reporting = .*/error_reporting = E_ALL \& ~E_DEPRECATED \& ~E_STRICT/' "$PHP_INI"
sed -i 's/^upload_max_filesize = .*/upload_max_filesize = 50M/' "$PHP_INI"
sed -i 's/^post_max_size = .*/post_max_size = 50M/' "$PHP_INI"
sed -i 's/^memory_limit = .*/memory_limit = 256M/' "$PHP_INI"
sed -i 's/^max_execution_time = .*/max_execution_time = 60/' "$PHP_INI"
sed -i 's/^max_input_time = .*/max_input_time = 60/' "$PHP_INI"
sed -i 's/^;date.timezone =.*/date.timezone = America\/Sao_Paulo/' "$PHP_INI"
sed -i 's/^expose_php = .*/expose_php = Off/' "$PHP_INI"
sed -i 's/^session.cookie_httponly =.*/session.cookie_httponly = 1/' "$PHP_INI"
sed -i 's/^session.cookie_secure =.*/session.cookie_secure = 1/' "$PHP_INI"
sed -i 's/^session.use_strict_mode =.*/session.use_strict_mode = 1/' "$PHP_INI"

# OPcache otimizado
sed -i 's/^;opcache.enable=.*/opcache.enable=1/' "$PHP_INI"
sed -i 's/^;opcache.memory_consumption=.*/opcache.memory_consumption=128/' "$PHP_INI"
sed -i 's/^;opcache.max_accelerated_files=.*/opcache.max_accelerated_files=10000/' "$PHP_INI"
sed -i 's/^;opcache.validate_timestamps=.*/opcache.validate_timestamps=0/' "$PHP_INI"

log "PHP configurado para produção"

# 3. Configurar PHP-FPM pool
info "Configurando PHP-FPM pool..."
cat > /etc/php/8.3/fpm/pool.d/www.conf << 'POOLEOF'
[www]
user = www-data
group = www-data
listen = /run/php/php8.3-fpm.sock
listen.owner = www-data
listen.group = www-data
listen.mode = 0660

; Otimizado para máximo 10 acessos simultâneos
pm = dynamic
pm.max_children = 10
pm.start_servers = 3
pm.min_spare_servers = 2
pm.max_spare_servers = 5
pm.max_requests = 1000
pm.process_idle_timeout = 10s

; Logs
php_admin_value[error_log] = /var/log/php8.3-fpm.log
php_admin_flag[log_errors] = on

; Segurança
php_admin_value[open_basedir] = /var/www/:/tmp/:/usr/share/php/
php_admin_value[disable_functions] = exec,passthru,shell_exec,system,proc_open,popen
security.limit_extensions = .php
POOLEOF

# 4. Instalar Composer
info "Instalando Composer..."
curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer
log "Composer instalado"

# 5. Reiniciar PHP-FPM
systemctl enable php8.3-fpm
systemctl restart php8.3-fpm
log "PHP-FPM rodando"

echo ""
echo "  ✅ PHP 8.3-FPM configurado para produção!"
