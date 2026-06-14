# 🌐 Configuração do Servidor Web

## Container LXC: CT100 - Web Server

| Parâmetro | Valor |
|---|---|
| **ID** | 100 |
| **Hostname** | grom-web |
| **SO** | Ubuntu 24.04 LTS |
| **RAM** | 4GB |
| **vCPU** | 4 |
| **Disco** | 100GB |
| **IP** | 10.0.1.10/24 |
| **Gateway** | 10.0.1.1 |

---

## Stack do Servidor Web

### Nginx (Reverse Proxy + Web Server)
- Serve conteúdo estático
- Proxy reverso para PHP-FPM e Python (Gunicorn)
- Terminação SSL/TLS
- Rate limiting e proteção DDoS básica

### PHP 8.3-FPM
- Para aplicação Grom_web
- Extensões: mysql, mbstring, xml, gd, curl, opcache, zip

### Python 3.12+
- Para Grom Documental
- Framework: FastAPI ou Flask
- ASGI/WSGI: Gunicorn + Uvicorn workers
- Ambiente virtual isolado (venv)

---

## Configuração Nginx

### Config Principal (`/etc/nginx/nginx.conf`)
Ver arquivo: `configs/nginx/nginx.conf`

### Grom_web VHost (`/etc/nginx/sites-available/grom-web.conf`)
Ver arquivo: `configs/nginx/grom-web.conf`

### Grom Documental VHost (`/etc/nginx/sites-available/grom-documental.conf`)
Ver arquivo: `configs/nginx/grom-documental.conf`

### Headers de Segurança
Ver arquivo: `configs/nginx/security-headers.conf`

---

## SSL/TLS com Let's Encrypt

### Instalação Certbot
```bash
apt install certbot python3-certbot-nginx -y
```

### Obter Certificados
```bash
# Para cada domínio
certbot --nginx -d gromweb.seudominio.com.br
certbot --nginx -d docs.seudominio.com.br
```

### Renovação Automática
```bash
# Já configurado automaticamente via systemd timer
systemctl status certbot.timer
```

---

## Estrutura de Diretórios

```
/var/www/
├── grom-web/              # Aplicação PHP
│   ├── public/            # Document root
│   │   ├── index.php
│   │   ├── css/
│   │   ├── js/
│   │   └── assets/
│   ├── src/               # Código fonte PHP
│   ├── config/            # Configurações
│   ├── vendor/            # Dependências (Composer)
│   └── .env               # Variáveis de ambiente
│
└── grom-documental/       # Aplicação Python
    ├── app/               # Código fonte
    │   ├── __init__.py
    │   ├── main.py
    │   ├── routes/
    │   ├── models/
    │   └── templates/
    ├── venv/              # Ambiente virtual
    ├── requirements.txt   # Dependências
    ├── gunicorn.conf.py   # Config Gunicorn
    └── .env               # Variáveis de ambiente
```

---

## Systemd Services

### Grom Documental (Python)
```ini
# /etc/systemd/system/grom-documental.service
[Unit]
Description=Grom Documental Application
After=network.target

[Service]
Type=notify
User=www-data
Group=www-data
WorkingDirectory=/var/www/grom-documental
Environment="PATH=/var/www/grom-documental/venv/bin"
ExecStart=/var/www/grom-documental/venv/bin/gunicorn \
    --workers 2 \
    --bind unix:/run/grom-documental.sock \
    --timeout 120 \
    app.main:app
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
```

---

## Permissões

```bash
chown -R www-data:www-data /var/www/grom-web
chown -R www-data:www-data /var/www/grom-documental
chmod -R 750 /var/www/grom-web
chmod -R 750 /var/www/grom-documental
```
