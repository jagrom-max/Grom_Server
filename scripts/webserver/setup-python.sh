#!/bin/bash
# =============================================================================
# GROM SERVER - Setup Python Environment
# Executar DENTRO do container CT100 (grom-web)
# TOTALMENTE AUTOMATIZADO
# =============================================================================

set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

DOMAIN="grom.seg.br"
DOCS_DIR="/var/www/docs.${DOMAIN}"

log() { echo -e "\033[0;32m[✓]\033[0m $1"; }
info() { echo -e "\033[0;34m[i]\033[0m $1"; }

echo "============================================"
echo "  GROM SERVER - Setup Python Environment"
echo "============================================"

# 1. Instalar Python 3.12 e dependências
info "Instalando Python 3.12..."
apt-get install -y -qq \
    python3 \
    python3-pip \
    python3-venv \
    python3-dev \
    build-essential \
    libmysqlclient-dev
log "Python 3 instalado"

# 2. Criar estrutura do projeto
info "Criando estrutura do Grom Documental..."
mkdir -p ${DOCS_DIR}/app/{routes,models,templates,static/{css,js,img}}

# 3. Criar ambiente virtual
info "Criando ambiente virtual..."
python3 -m venv ${DOCS_DIR}/venv
source ${DOCS_DIR}/venv/bin/activate

# 4. Instalar dependências
cat > ${DOCS_DIR}/requirements.txt << 'REQEOF'
# Web Framework
fastapi==0.115.0
uvicorn[standard]==0.30.0
gunicorn==22.0.0

# Database
mysqlclient==2.2.4
SQLAlchemy==2.0.35
alembic==1.13.2

# Templates
jinja2==3.1.4

# Segurança
python-jose[cryptography]==3.3.0
passlib[bcrypt]==1.7.4
python-multipart==0.0.9

# Utilitários
python-dotenv==1.0.1
pydantic==2.9.2
pydantic-settings==2.5.2
httpx==0.27.2
REQEOF

pip install -r ${DOCS_DIR}/requirements.txt -q
log "Dependências Python instaladas"

# 5. Criar aplicação base
cat > ${DOCS_DIR}/app/main.py << 'APPEOF'
"""
Grom Documental - Sistema de Gestão Documental
Aplicação FastAPI principal
"""
from fastapi import FastAPI
from fastapi.staticfiles import StaticFiles
from fastapi.templating import Jinja2Templates
from datetime import datetime
import os

app = FastAPI(
    title="Grom Documental",
    description="Sistema de Gestão Documental - grom.seg.br",
    version="1.0.0",
    docs_url="/api/docs",
    redoc_url="/api/redoc"
)

# Static files e templates
app.mount("/static", StaticFiles(directory="app/static"), name="static")
templates = Jinja2Templates(directory="app/templates")

@app.get("/")
async def root():
    return {
        "service": "Grom Documental",
        "version": "1.0.0",
        "status": "operational",
        "timestamp": datetime.now().isoformat()
    }

@app.get("/health")
async def health_check():
    return {"status": "healthy", "timestamp": datetime.now().isoformat()}
APPEOF

# 6. Config Gunicorn
cat > ${DOCS_DIR}/gunicorn.conf.py << 'GUNIEOF'
"""Gunicorn configuration for Grom Documental"""
import multiprocessing

# Binding
bind = "unix:/run/grom-documental.sock"
backlog = 64

# Workers - otimizado para max 10 conexões simultâneas
workers = 2
worker_class = "uvicorn.workers.UvicornWorker"
worker_connections = 50
timeout = 120
keepalive = 5

# Logging
accesslog = "/var/log/grom-documental/access.log"
errorlog = "/var/log/grom-documental/error.log"
loglevel = "warning"

# Process naming
proc_name = "grom-documental"

# Security
limit_request_line = 4094
limit_request_fields = 100
limit_request_field_size = 8190
GUNIEOF

# 7. Criar diretório de logs
mkdir -p /var/log/grom-documental

# 8. Systemd service
cat > /etc/systemd/system/grom-documental.service << 'SVCEOF'
[Unit]
Description=Grom Documental - Sistema de Gestão Documental
After=network.target
Wants=network.target

[Service]
Type=notify
User=www-data
Group=www-data
WorkingDirectory=/var/www/docs.grom.seg.br
Environment="PATH=/var/www/docs.grom.seg.br/venv/bin:/usr/bin"
ExecStart=/var/www/docs.grom.seg.br/venv/bin/gunicorn \
    --config gunicorn.conf.py \
    app.main:app
ExecReload=/bin/kill -HUP $MAINPID
Restart=always
RestartSec=5
StandardOutput=append:/var/log/grom-documental/stdout.log
StandardError=append:/var/log/grom-documental/stderr.log

[Install]
WantedBy=multi-user.target
SVCEOF

# 9. Permissões
chown -R www-data:www-data ${DOCS_DIR}
chown -R www-data:www-data /var/log/grom-documental
chmod -R 750 ${DOCS_DIR}

# 10. Habilitar e iniciar
systemctl daemon-reload
systemctl enable grom-documental
systemctl start grom-documental
log "Grom Documental rodando como serviço"

echo ""
echo "  ✅ Python environment configurado!"
echo "  App: ${DOCS_DIR}"
echo "  Service: grom-documental.service"
