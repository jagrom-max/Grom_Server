#!/bin/bash
# =============================================================================
# GROM SERVER - Setup Nginx (Web Server)
# Executar DENTRO do container CT100 (grom-web)
# TOTALMENTE AUTOMATIZADO
# =============================================================================

set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

DOMAIN="grom.seg.br"
WEB_DOMAIN="web.${DOMAIN}"
DOCS_DOMAIN="docs.${DOMAIN}"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
log() { echo -e "${GREEN}[✓]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }
info() { echo -e "${BLUE}[i]${NC} $1"; }

echo "============================================"
echo "  GROM SERVER - Setup Nginx Web Server"
echo "============================================"

# 1. Atualizar sistema
info "Atualizando sistema..."
apt-get update -qq && apt-get upgrade -y -qq
log "Sistema atualizado"

# 2. Instalar Nginx
info "Instalando Nginx..."
apt-get install -y -qq nginx
systemctl enable nginx
log "Nginx instalado"

# 3. Criar estrutura de diretórios
info "Criando estrutura de diretórios..."
mkdir -p /var/www/${WEB_DOMAIN}/public
mkdir -p /var/www/${DOCS_DOMAIN}/app
mkdir -p /var/log/nginx
mkdir -p /etc/nginx/snippets
log "Diretórios criados"

# 4. Config principal do Nginx
info "Configurando Nginx..."
cat > /etc/nginx/nginx.conf << 'NGINXEOF'
user www-data;
worker_processes auto;
pid /run/nginx.pid;
error_log /var/log/nginx/error.log warn;

events {
    worker_connections 512;
    multi_accept on;
    use epoll;
}

http {
    # Básico
    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    types_hash_max_size 2048;
    server_tokens off;
    client_max_body_size 50M;

    # MIME types
    include /etc/nginx/mime.types;
    default_type application/octet-stream;

    # Logging
    log_format main '$remote_addr - $remote_user [$time_local] "$request" '
                    '$status $body_bytes_sent "$http_referer" '
                    '"$http_user_agent" "$http_x_forwarded_for"';
    access_log /var/log/nginx/access.log main;

    # Gzip
    gzip on;
    gzip_vary on;
    gzip_proxied any;
    gzip_comp_level 6;
    gzip_types text/plain text/css application/json application/javascript
               text/xml application/xml application/xml+rss text/javascript
               image/svg+xml;

    # Rate limiting
    limit_req_zone $binary_remote_addr zone=general:10m rate=10r/s;
    limit_req_zone $binary_remote_addr zone=login:10m rate=3r/s;
    limit_conn_zone $binary_remote_addr zone=connlimit:10m;

    # Security headers (incluído em cada server block)
    include /etc/nginx/snippets/security-headers.conf;

    # Virtual Hosts
    include /etc/nginx/sites-enabled/*;
}
NGINXEOF

# 5. Security headers snippet
cat > /etc/nginx/snippets/security-headers.conf << 'SECEOF'
add_header X-Frame-Options "SAMEORIGIN" always;
add_header X-Content-Type-Options "nosniff" always;
add_header X-XSS-Protection "1; mode=block" always;
add_header Referrer-Policy "strict-origin-when-cross-origin" always;
add_header Permissions-Policy "camera=(), microphone=(), geolocation=()" always;
add_header Strict-Transport-Security "max-age=31536000; includeSubDomains; preload" always;
SECEOF

# 6. VHost - Grom_web (PHP)
cat > /etc/nginx/sites-available/${WEB_DOMAIN}.conf << VHOSTEOF
server {
    listen 80;
    server_name ${WEB_DOMAIN};

    root /var/www/${WEB_DOMAIN}/public;
    index index.php index.html;

    # Rate limiting
    limit_req zone=general burst=20 nodelay;
    limit_conn connlimit 10;

    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    location ~ \.php\$ {
        fastcgi_pass unix:/run/php/php8.3-fpm.sock;
        fastcgi_param SCRIPT_FILENAME \$realpath_root\$fastcgi_script_name;
        include fastcgi_params;
        fastcgi_intercept_errors on;
        fastcgi_buffer_size 16k;
        fastcgi_buffers 4 16k;
    }

    # Bloquear acesso a arquivos sensíveis
    location ~ /\.(ht|env|git) {
        deny all;
        return 404;
    }

    location ~ /\.(sql|bak|old|orig|swp) {
        deny all;
        return 404;
    }

    # Cache de assets estáticos
    location ~* \.(css|js|jpg|jpeg|png|gif|ico|svg|woff|woff2|ttf|eot)\$ {
        expires 30d;
        add_header Cache-Control "public, immutable";
    }

    access_log /var/log/nginx/${WEB_DOMAIN}.access.log main;
    error_log /var/log/nginx/${WEB_DOMAIN}.error.log;
}
VHOSTEOF

# 7. VHost - Grom Documental (Python/Gunicorn)
cat > /etc/nginx/sites-available/${DOCS_DOMAIN}.conf << VHOSTEOF
server {
    listen 80;
    server_name ${DOCS_DOMAIN};

    # Rate limiting
    limit_req zone=general burst=20 nodelay;
    limit_conn connlimit 10;

    location / {
        proxy_pass http://unix:/run/grom-documental.sock;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_connect_timeout 60s;
        proxy_read_timeout 120s;
    }

    location /static/ {
        alias /var/www/${DOCS_DOMAIN}/app/static/;
        expires 30d;
        add_header Cache-Control "public, immutable";
    }

    access_log /var/log/nginx/${DOCS_DOMAIN}.access.log main;
    error_log /var/log/nginx/${DOCS_DOMAIN}.error.log;
}
VHOSTEOF

# 8. Habilitar sites
rm -f /etc/nginx/sites-enabled/default
ln -sf /etc/nginx/sites-available/${WEB_DOMAIN}.conf /etc/nginx/sites-enabled/
ln -sf /etc/nginx/sites-available/${DOCS_DOMAIN}.conf /etc/nginx/sites-enabled/

# 9. Criar página inicial temporária
cat > /var/www/${WEB_DOMAIN}/public/index.php << 'PHPEOF'
<?php
echo "<h1>🖥️ Grom Server</h1>";
echo "<p>Servidor operacional - " . date('Y-m-d H:i:s') . "</p>";
echo "<p>PHP " . phpversion() . "</p>";
phpinfo();
PHPEOF

# 10. Permissões
chown -R www-data:www-data /var/www/
chmod -R 750 /var/www/

# 11. Testar e reiniciar
nginx -t && systemctl restart nginx
log "Nginx configurado e rodando"

# 12. Instalar UFW
info "Configurando firewall local..."
apt-get install -y -qq ufw
ufw default deny incoming
ufw default allow outgoing
ufw allow from 10.0.1.0/24 to any port 22
ufw allow 80/tcp
ufw allow 443/tcp
echo "y" | ufw enable
log "Firewall configurado"

# 13. Instalar Fail2Ban
info "Instalando Fail2Ban..."
apt-get install -y -qq fail2ban
systemctl enable fail2ban
log "Fail2Ban instalado"

# 14. Atualizações automáticas de segurança
info "Configurando atualizações automáticas..."
apt-get install -y -qq unattended-upgrades
echo 'Unattended-Upgrade::Automatic-Reboot "false";' > /etc/apt/apt.conf.d/51grom-auto
log "Atualizações automáticas configuradas"

echo ""
echo "============================================"
echo "  ✅ Nginx configurado!"
echo "  Domínios: ${WEB_DOMAIN} | ${DOCS_DOMAIN}"
echo "============================================"
