# 📊 Monitoramento e Alertas

## Container LXC: CT103 - Monitoring

| Parâmetro | Valor |
|---|---|
| **ID** | 103 |
| **Hostname** | grom-monitor |
| **SO** | Ubuntu 24.04 LTS |
| **RAM** | 1GB |
| **vCPU** | 1 |
| **Disco** | 20GB |
| **IP** | 10.0.1.13/24 |

---

## Ferramentas de Monitoramento

### 1. Netdata (Métricas em Tempo Real)
- Dashboard web interativo
- Métricas de CPU, RAM, disco, rede
- Alertas configuráveis
- Agente leve em cada container
- URL: `http://10.0.1.13:19999`

### 2. Uptime Kuma (Monitoramento de Uptime)
- Monitoramento HTTP/HTTPS, TCP, DNS, ping
- Dashboard de status
- Alertas por email, Telegram, Discord
- URL: `http://10.0.1.13:3001`

---

## Instalação Netdata

### No servidor de monitoring (central)
```bash
wget -O /tmp/netdata-kickstart.sh https://get.netdata.cloud/kickstart.sh
sh /tmp/netdata-kickstart.sh --stable-channel
```

### Agente em cada container
```bash
# Instalar agente Netdata em CT100, CT101, CT102, CT104
wget -O /tmp/netdata-kickstart.sh https://get.netdata.cloud/kickstart.sh
sh /tmp/netdata-kickstart.sh --stable-channel
```

---

## Instalação Uptime Kuma

```bash
# Via Docker (mais simples)
apt install docker.io -y
docker run -d --restart=always \
  -p 3001:3001 \
  -v uptime-kuma:/app/data \
  --name uptime-kuma \
  louislam/uptime-kuma:1
```

### Monitores a Configurar

| Serviço | Tipo | Alvo | Intervalo |
|---|---|---|---|
| Web Server | HTTP | https://gromweb.dominio | 60s |
| Grom Documental | HTTP | https://docs.dominio | 60s |
| MySQL | TCP | 10.0.1.11:3306 | 60s |
| OPNsense | Ping | 10.0.1.1 | 30s |
| WireGuard | Ping | 10.0.1.14 | 60s |
| Backup Server | Ping | 10.0.1.12 | 120s |
| Internet | HTTP | https://1.1.1.1 | 30s |

---

## Alertas

### Canais de Notificação
1. **Email** - Para alertas críticos
2. **Telegram Bot** - Notificações em tempo real (recomendado)

### Configurar Bot Telegram
1. Criar bot via @BotFather no Telegram
2. Obter token do bot
3. Obter chat_id
4. Configurar no Uptime Kuma e Netdata

---

## Métricas Monitoradas

- **CPU**: Uso, temperatura, load average
- **RAM**: Uso, swap, available
- **Disco**: Uso, I/O, health (SMART)
- **Rede**: Throughput, erros, conexões
- **Serviços**: Status, tempo de resposta, uptime
- **MySQL**: Queries/s, conexões, slow queries
- **Nginx**: Requests/s, códigos de resposta, conexões ativas
