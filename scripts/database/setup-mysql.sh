#!/bin/bash
# =============================================================================
# GROM SERVER - Setup MySQL 8.0
# Executar DENTRO do container CT111 (grom-db)
# TOTALMENTE AUTOMATIZADO
# =============================================================================

set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

# Senhas obrigatorias - gerar e guardar antes em KeePassXC ou cofre equivalente.
: "${MYSQL_ROOT_PASS:?Defina MYSQL_ROOT_PASS antes de executar}"
: "${GROM_SEG_PASS:?Defina GROM_SEG_PASS antes de executar}"
: "${GROM_WEB_PASS:?Defina GROM_WEB_PASS antes de executar}"
: "${GROM_DOC_PASS:?Defina GROM_DOC_PASS antes de executar}"
: "${GROM_BACKUP_PASS:?Defina GROM_BACKUP_PASS antes de executar}"

CREDENTIALS_FILE="/root/.grom_mysql_credentials"
umask 077

sql_escape() {
    local value=$1
    value=${value//\\/\\\\}
    value=${value//\'/\'\'}
    printf '%s' "$value"
}

MYSQL_ROOT_PASS_SQL=$(sql_escape "$MYSQL_ROOT_PASS")
GROM_SEG_PASS_SQL=$(sql_escape "$GROM_SEG_PASS")
GROM_WEB_PASS_SQL=$(sql_escape "$GROM_WEB_PASS")
GROM_DOC_PASS_SQL=$(sql_escape "$GROM_DOC_PASS")
GROM_BACKUP_PASS_SQL=$(sql_escape "$GROM_BACKUP_PASS")

log() { echo -e "\033[0;32m[✓]\033[0m $1"; }
info() { echo -e "\033[0;34m[i]\033[0m $1"; }
warn() { echo -e "\033[1;33m[!]\033[0m $1"; }

echo "============================================"
echo "  GROM SERVER - Setup MySQL 8.0"
echo "============================================"

# 1. Instalar MySQL
info "Instalando MySQL 8.0..."
apt-get update -qq
apt-get install -y -qq mysql-server mysql-client
systemctl enable mysql
systemctl start mysql
log "MySQL instalado"

# 2. Hardening automatizado
info "Aplicando hardening..."
mysql -u root << SQLEOF
-- Definir senha root
ALTER USER 'root'@'localhost' IDENTIFIED WITH caching_sha2_password BY '${MYSQL_ROOT_PASS_SQL}';

-- Remover usuários anônimos
DELETE FROM mysql.user WHERE User='';

-- Remover acesso root remoto
DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');

-- Remover banco test
DROP DATABASE IF EXISTS test;
DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';

-- Criar bancos de dados
CREATE DATABASE IF NOT EXISTS grom_seg
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_unicode_ci;

CREATE DATABASE IF NOT EXISTS grom_web
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_unicode_ci;

CREATE DATABASE IF NOT EXISTS grom_documental
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_unicode_ci;

-- Usuário Grom_web (acesso apenas do web server)
CREATE USER IF NOT EXISTS 'grom_seg_user'@'10.0.1.10'
    IDENTIFIED BY '${GROM_SEG_PASS_SQL}' REQUIRE SSL;
ALTER USER 'grom_seg_user'@'10.0.1.10'
    IDENTIFIED BY '${GROM_SEG_PASS_SQL}' REQUIRE SSL;
GRANT SELECT, INSERT, UPDATE, DELETE, CREATE, ALTER, INDEX, DROP, REFERENCES
    ON grom_seg.* TO 'grom_seg_user'@'10.0.1.10';

CREATE USER IF NOT EXISTS 'grom_web_user'@'10.0.1.10'
    IDENTIFIED BY '${GROM_WEB_PASS_SQL}' REQUIRE SSL;
ALTER USER 'grom_web_user'@'10.0.1.10'
    IDENTIFIED BY '${GROM_WEB_PASS_SQL}' REQUIRE SSL;
GRANT SELECT, INSERT, UPDATE, DELETE, CREATE, ALTER, INDEX, DROP, REFERENCES
    ON grom_web.* TO 'grom_web_user'@'10.0.1.10';

-- Usuário Grom Documental
CREATE USER IF NOT EXISTS 'grom_doc_user'@'10.0.1.10'
    IDENTIFIED BY '${GROM_DOC_PASS_SQL}' REQUIRE SSL;
ALTER USER 'grom_doc_user'@'10.0.1.10'
    IDENTIFIED BY '${GROM_DOC_PASS_SQL}' REQUIRE SSL;
GRANT SELECT, INSERT, UPDATE, DELETE, CREATE, ALTER, INDEX, DROP, REFERENCES
    ON grom_documental.* TO 'grom_doc_user'@'10.0.1.10';

-- Usuário de backup (somente leitura)
CREATE USER IF NOT EXISTS 'grom_backup'@'10.0.1.12'
    IDENTIFIED BY '${GROM_BACKUP_PASS_SQL}' REQUIRE SSL;
ALTER USER 'grom_backup'@'10.0.1.12'
    IDENTIFIED BY '${GROM_BACKUP_PASS_SQL}' REQUIRE SSL;
GRANT SELECT, LOCK TABLES, SHOW VIEW, EVENT, TRIGGER, RELOAD, PROCESS
    ON *.* TO 'grom_backup'@'10.0.1.12';

FLUSH PRIVILEGES;
SQLEOF
log "Hardening e usuários configurados"

# 3. Configuração otimizada
info "Aplicando configuração otimizada..."
cat > /etc/mysql/mysql.conf.d/99-grom.cnf << 'CNFEOF'
# =============================================================================
# GROM SERVER - MySQL 8.0 Configuration
# Otimizado para: 3GB RAM, max 10 conexões simultâneas, SSD
# =============================================================================

[mysqld]
# Rede
bind-address = 10.0.1.11
port = 3306
mysqlx = 0

# InnoDB - Otimizado para 3GB RAM
innodb_buffer_pool_size = 1536M
innodb_buffer_pool_instances = 2
innodb_log_file_size = 256M
innodb_flush_log_at_trx_commit = 2
innodb_flush_method = O_DIRECT
innodb_io_capacity = 2000
innodb_io_capacity_max = 4000
innodb_read_io_threads = 4
innodb_write_io_threads = 4
innodb_file_per_table = 1

# Conexões
max_connections = 30
max_connect_errors = 5
wait_timeout = 600
interactive_timeout = 600

# Buffers
join_buffer_size = 256K
sort_buffer_size = 256K
read_buffer_size = 256K
read_rnd_buffer_size = 512K
tmp_table_size = 64M
max_heap_table_size = 64M
key_buffer_size = 32M

# Query
max_allowed_packet = 64M

# Segurança
local_infile = 0
symbolic-links = 0
sql_mode = STRICT_TRANS_TABLES,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION
require_secure_transport = ON

# Logs
slow_query_log = 1
slow_query_log_file = /var/log/mysql/slow.log
long_query_time = 2
log_error = /var/log/mysql/error.log
log_error_verbosity = 2

# Performance Schema (mantém ligado para diagnóstico)
performance_schema = ON

# Character set
character-set-server = utf8mb4
collation-server = utf8mb4_unicode_ci

[client]
default-character-set = utf8mb4
CNFEOF

systemctl restart mysql
log "MySQL reiniciado com configuração otimizada"

# 4. Salvar credenciais em arquivo seguro
{
cat << CREDEOF
# =============================================================================
# GROM SERVER - MySQL Credentials
# GERADO AUTOMATICAMENTE em $(date)
# MOVER PARA LOCAL SEGURO E REMOVER DESTE SERVIDOR!
# =============================================================================
CREDEOF
printf 'ROOT_PASS=%q\n' "$MYSQL_ROOT_PASS"
cat << CREDEOF
GROM_SEG_USER=grom_seg_user@10.0.1.10
CREDEOF
printf 'GROM_SEG_PASS=%q\n' "$GROM_SEG_PASS"
cat << CREDEOF
GROM_WEB_USER=grom_web_user@10.0.1.10
CREDEOF
printf 'GROM_WEB_PASS=%q\n' "$GROM_WEB_PASS"
cat << CREDEOF
GROM_DOC_USER=grom_doc_user@10.0.1.10
CREDEOF
printf 'GROM_DOC_PASS=%q\n' "$GROM_DOC_PASS"
cat << CREDEOF
GROM_BACKUP_USER=grom_backup@10.0.1.12
CREDEOF
printf 'GROM_BACKUP_PASS=%q\n' "$GROM_BACKUP_PASS"
} > "$CREDENTIALS_FILE"
chmod 600 "$CREDENTIALS_FILE"
log "Credenciais salvas em ${CREDENTIALS_FILE}"

# 5. Firewall
info "Configurando firewall..."
apt-get install -y -qq ufw
ufw default deny incoming
ufw default allow outgoing
ufw allow from 10.0.1.10 to any port 3306
ufw allow from 10.0.1.12 to any port 3306
ufw allow from 10.0.1.13 to any port 3306
ufw allow from 10.0.1.0/24 to any port 22
echo "y" | ufw enable
log "Firewall configurado"

# 6. Atualizações automáticas
apt-get install -y -qq unattended-upgrades
log "Atualizações automáticas configuradas"

echo ""
echo "============================================"
echo "  ✅ MySQL 8.0 configurado!"
echo "  Bancos: grom_seg, grom_web, grom_documental"
echo ""
warn "IMPORTANTE: Salvar credenciais de ${CREDENTIALS_FILE}"
warn "e depois remover o arquivo do servidor!"
echo "============================================"
