# 🗄️ Configuração do Banco de Dados MySQL

## Container LXC: CT101 - MySQL Server

| Parâmetro | Valor |
|---|---|
| **ID** | 101 |
| **Hostname** | grom-db |
| **SO** | Ubuntu 24.04 LTS |
| **RAM** | 3GB |
| **vCPU** | 2 |
| **Disco** | 200GB |
| **IP** | 10.0.1.11/24 |
| **Gateway** | 10.0.1.1 |

---

## Instalação MySQL 8.0

```bash
apt update && apt upgrade -y
apt install mysql-server mysql-client -y
systemctl enable mysql
systemctl start mysql
```

## Hardening Inicial

```bash
mysql_secure_installation
# - Set root password: YES (senha forte)
# - Remove anonymous users: YES
# - Disallow root login remotely: YES
# - Remove test database: YES
# - Reload privilege tables: YES
```

---

## Bancos de Dados e Usuários

```sql
-- Criar bancos
CREATE DATABASE grom_web CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE DATABASE grom_documental CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- Usuário para Grom_web (acesso apenas do web server)
CREATE USER 'grom_web_user'@'10.0.1.10' IDENTIFIED BY '<SENHA_FORTE>';
GRANT SELECT, INSERT, UPDATE, DELETE, CREATE, ALTER, INDEX, DROP
  ON grom_web.* TO 'grom_web_user'@'10.0.1.10';

-- Usuário para Grom Documental
CREATE USER 'grom_doc_user'@'10.0.1.10' IDENTIFIED BY '<SENHA_FORTE>';
GRANT SELECT, INSERT, UPDATE, DELETE, CREATE, ALTER, INDEX, DROP
  ON grom_documental.* TO 'grom_doc_user'@'10.0.1.10';

-- Usuário de backup (somente leitura + LOCK)
CREATE USER 'grom_backup'@'10.0.1.12' IDENTIFIED BY '<SENHA_FORTE>';
GRANT SELECT, LOCK TABLES, SHOW VIEW, EVENT, TRIGGER, RELOAD
  ON *.* TO 'grom_backup'@'10.0.1.12';

FLUSH PRIVILEGES;
```

---

## Configuração Otimizada (`/etc/mysql/mysql.conf.d/mysqld.cnf`)

Ver arquivo: `configs/mysql/my.cnf`

### Parâmetros-chave para 3GB RAM:
```ini
[mysqld]
# Rede - aceitar apenas do web server
bind-address = 10.0.1.11
port = 3306

# InnoDB otimizado para 3GB RAM
innodb_buffer_pool_size = 1536M      # ~50% da RAM
innodb_log_file_size = 256M
innodb_flush_log_at_trx_commit = 2   # Balance perf/safety
innodb_flush_method = O_DIRECT

# Conexões (máximo 10 simultâneos)
max_connections = 30
max_connect_errors = 10

# Query cache e performance
join_buffer_size = 256K
sort_buffer_size = 256K
tmp_table_size = 64M
max_heap_table_size = 64M

# Segurança
local_infile = 0
symbolic-links = 0
sql_mode = STRICT_TRANS_TABLES,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION

# Logs
slow_query_log = 1
slow_query_log_file = /var/log/mysql/slow.log
long_query_time = 2
log_error = /var/log/mysql/error.log

# Character set
character-set-server = utf8mb4
collation-server = utf8mb4_unicode_ci
```

---

## Segurança Adicional

### Firewall (no container)
```bash
ufw default deny incoming
ufw allow from 10.0.1.10 to any port 3306  # Web server
ufw allow from 10.0.1.12 to any port 3306  # Backup server
ufw allow from 10.0.1.13 to any port 3306  # Monitoring
ufw enable
```

### SSL/TLS para conexões MySQL
```bash
# MySQL 8 já gera certificados automaticamente
# Verificar status:
mysql -e "SHOW VARIABLES LIKE '%ssl%';"
```

---

## Manutenção

### Otimizar tabelas (mensal)
```bash
mysqlcheck --optimize --all-databases -u root -p
```

### Verificar integridade
```bash
mysqlcheck --check --all-databases -u root -p
```
