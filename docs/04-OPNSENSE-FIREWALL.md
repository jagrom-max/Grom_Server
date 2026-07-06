# 🛡️ Configuração do OPNsense Firewall

## Visão Geral

O OPNsense será o firewall/roteador principal, rodando como VM no Proxmox com duas interfaces de rede (WAN e LAN).

---

## Instalação na VM Proxmox

### Download
- URL: https://opnsense.org/download/
- Arquitetura: amd64, tipo: dvd
- Mirror: mais próximo do Brasil

### Instalação
1. Iniciar VM 100 no Proxmox
2. Boot pela ISO
3. Login: `installer` / `opnsense`
4. Seguir wizard de instalação
5. Filesystem: UFS
6. Reiniciar e remover ISO

### Configuração Inicial via Console
```
Assign interfaces:
  vtnet0 → WAN (vmbr0 - internet)
  vtnet1 → LAN (vmbr1 - rede interna)

Set interface IP:
  WAN: DHCP
  LAN: 10.0.1.1/24
  DHCP Server LAN: 10.0.1.50 - 10.0.1.200
```

---

## Acesso WebGUI

- URL: `https://10.0.1.1`
- Usuário: `root`
- Senha: `opnsense` (alterar imediatamente!)

---

## Configuração de Segurança

### 1. Conta Admin
- Criar usuário admin dedicado
- Desabilitar login root na WebGUI
- Habilitar 2FA (TOTP)

### 2. Regras de Firewall - WAN

```
# DEFAULT: Block All Incoming (já padrão)

# Permitir resposta a conexões estabelecidas
PASS | WAN | * | * | * | * | State: established/related

# VPN WireGuard (quando configurado)
PASS | WAN | UDP | * | WAN addr | 51820 | WireGuard VPN

# HTTP/HTTPS (apenas se hospedar sites públicos)
PASS | WAN | TCP | * | WAN addr | 80,443 | Web Services
```

### 3. Regras de Firewall - LAN

```
# Permitir LAN acessar internet
PASS | LAN | * | LAN net | * | * | LAN to Internet

# Bloquear acesso à interface de gerenciamento de outros hosts
BLOCK | LAN | * | !LAN addr | * | 443 | Block Mgmt Access

# Permitir DNS
PASS | LAN | UDP/TCP | LAN net | LAN addr | 53 | DNS
```

### 4. IDS/IPS (Suricata)

1. **Services** → **Intrusion Detection** → **Administration**
2. Habilitar IDS
3. Download rulesets: ET Open
4. Interfaces: WAN
5. Modo: IPS (prevenção ativa)
6. Padrão: Default drop action

### 5. DNS sobre TLS (DoT)

1. **Services** → **Unbound DNS**
2. Habilitar DNS over TLS
3. Forwarders:
   - `1.1.1.1` (Cloudflare)
   - `9.9.9.9` (Quad9)
4. Habilitar DNSSEC

### 6. Aliases (Organização)

```
Alias: SERVERS
  10.0.1.10  # Web Server
  10.0.1.11  # MySQL
  10.0.1.12  # Backup
  10.0.1.13  # Monitoring
  10.0.1.14  # WireGuard
  10.0.1.20  # Reserva futura para Home Assistant externo
  10.0.1.30  # Grom_Security

Alias: WEB_PORTS
  80, 443

Alias: ADMIN_PORTS
  22, 8006
```

---

## DHCP Server

- Interface: LAN
- Range: 10.0.1.50 - 10.0.1.200
- DNS: 10.0.1.1 (OPNsense - Unbound)
- Gateway: 10.0.1.1
- Lease time: 86400 (24h)

### Reservas Estáticas (Static Leases)
Configurar MAC → IP fixo para cada container (opcional, pois LXC já tem IP estático).

---

## NAT / Port Forwarding

Para serviços acessíveis externamente:

| Porta WAN | Protocolo | Destino LAN | Porta | Serviço |
|---|---|---|---|---|
| 80 | TCP | 10.0.1.10 | 80 | HTTP |
| 443 | TCP | 10.0.1.10 | 443 | HTTPS |
| 51820 | UDP | 10.0.1.14 | 51820 | WireGuard |

Nao criar NAT publico para:
- Home Assistant externo futuro `10.0.1.20`, se esta reserva for adotada;
- Grom_Security `10.0.1.30`;
- MQTT `1883`;
- Frigate/painel de video;
- APIs internas de eventos.

## Cameras, DVR e RTSP/ONVIF

Quando DVR/cameras forem ativados, aplicar regra conservadora:

| Origem | Destino | Portas | Acao | Motivo |
|---|---|---:|---|---|
| VM130 Grom_Security | DVR/cameras | RTSP/ONVIF conforme equipamento | Permitir restrito | Leitura de streams e descoberta controlada |
| DVR/cameras | Internet | Qualquer | Bloquear | Impedir acesso remoto direto e telemetria desnecessaria |
| Internet | DVR/cameras | Qualquer | Bloquear | Nunca expor painel, RTSP ou ONVIF publicamente |
| LAN administrativa/VPN | DVR/cameras | HTTPS/porta admin conforme equipamento | Permitir restrito | Administracao tecnica |

Referencia: `docs/28-CAMERAS-DVR-VIDEO.md`.

---

## Backup da Configuração

```
System → Configuration → Backups
- Fazer download manual do XML após mudanças relevantes
- Guardar cópia criptografada no cofre/HD externo offline
- Não salvar XML completo no repositório, pois pode conter segredos
```

---

## Atualizações

- Verificar atualizações semanalmente
- **System** → **Firmware** → **Check for Updates**
- Agendar janela de manutenção
- Sempre fazer backup ANTES de atualizar
