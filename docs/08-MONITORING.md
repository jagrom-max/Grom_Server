# 📊 Monitoramento e Alertas

## Container LXC: CT113 - Monitoring

| Parâmetro | Valor |
|---|---|
| **ID** | 113 |
| **Hostname** | grom-monitor |
| **SO** | Ubuntu 24.04 LTS |
| **RAM** | 1GB |
| **vCPU** | 1 |
| **Disco** | 20GB |
| **IP** | 10.0.1.13/24 |

---

## Ferramentas de Monitoramento

### 0. Grom Server Dashboard
- Painel operacional simples e visual em `https://grom.seg.br/server/`
- Acesso permitido apenas pela LAN `10.0.1.0/24` ou VPN `10.0.10.0/24`
- Mostra estado geral, CPU, memoria, disco, backup, VMs/containers, servicos e exposicao administrativa
- Dados atualizados pelo `grom-operational-health-check.sh`

### 1. Netdata (Métricas em Tempo Real)
- Dashboard web interativo
- Métricas de CPU, RAM, disco, rede
- Alertas configuráveis
- Agente leve em cada container
- URL: `http://10.0.1.13:19999` apenas via LAN/VPN

### 2. Uptime Kuma (Monitoramento de Uptime)
- Monitoramento HTTP/HTTPS, TCP, DNS, ping
- Dashboard de status
- Alertas por email, Telegram, Discord
- URL: `http://10.0.1.13:3001` apenas via LAN/VPN

---

## Instalação Netdata

### No servidor de monitoring (central)
```bash
wget -O /tmp/netdata-kickstart.sh https://get.netdata.cloud/kickstart.sh
sh /tmp/netdata-kickstart.sh --stable-channel
```

### Agente em cada container
```bash
# Instalar agente Netdata em CT110, CT111, CT112, CT114
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
| Grom.Seg | HTTP | https://grom.seg.br | 60s |
| Grom Web legado | HTTP | https://web.grom.seg.br | 60s |
| Grom Documental legado | HTTP | https://docs.grom.seg.br | 60s |
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
