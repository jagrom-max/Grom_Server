# Diagramas e matrizes operacionais

Este documento consolida a topologia, os fluxos e as matrizes que devem orientar a implantacao do Grom Server. A regra central e simples: somente HTTP/HTTPS e VPN podem atravessar a borda publica; todo o resto fica em LAN restrita ou VPN.

## Topologia fisica - Fase 1

```mermaid
flowchart TD
    Internet[Internet fibra 650 Mbps]
    Router[Mercusys MR80X / AX3000]
    WanNic[Mini PC - porta onboard - WAN]
    Proxmox[Proxmox VE]
    OPN[VM100 OPNsense]
    LanNic[Adaptador Ugreen USB 2.5G - LAN]
    Switch[Switch TP-Link TL-SG108 - LAN restrita]
    Hd[HD externo Toshiba 1 TB]

    Internet --> Router
    Router --> WanNic
    WanNic --> Proxmox
    Proxmox --> OPN
    OPN --> LanNic
    LanNic --> Switch
    Proxmox --> Hd
```

Observacoes:
- O roteador Mercusys deve encaminhar apenas as portas aprovadas para o OPNsense.
- O switch atual nao faz VLAN; por isso, a rede fisica ligada nele deve ser tratada como zona restrita.
- Equipamentos de visitantes, IoT, cameras e dispositivos desconhecidos nao devem entrar nesse switch.

## Topologia logica

```mermaid
flowchart LR
    WAN[WAN / Internet]
    OPN[VM100 OPNsense\n10.0.1.1]
    WEB[CT110 Web\n10.0.1.10\nNginx, PHP, Python]
    DB[CT111 Database\n10.0.1.11\nMySQL]
    BAK[CT112 Backup\n10.0.1.12\nBorg, rclone]
    MON[CT113 Monitor\n10.0.1.13\nNetdata, Uptime Kuma]
    VPN[CT114 VPN\n10.0.1.14\nWireGuard]
    HA[VM120 Home Assistant OS\n10.0.1.20]
    SEC[VM130 Grom_Security\n10.0.1.30]

    WAN --> OPN
    OPN --> WEB
    OPN --> VPN
    WEB --> DB
    BAK --> DB
    MON --> WEB
    MON --> DB
    MON --> VPN
    HA --> SEC
    SEC --> WEB
    SEC --> DB
    VPN --> OPN
```

## Fluxo publico HTTPS

```mermaid
sequenceDiagram
    participant User as Usuario autorizado
    participant DNS as DNS grom.seg.br
    participant Router as Mercusys
    participant FW as OPNsense
    participant Web as CT110 Web
    participant DB as CT111 MySQL

    User->>DNS: Resolve grom.seg.br
    DNS-->>User: IP publico
    User->>Router: HTTPS TCP/443
    Router->>FW: Port forward TCP/443
    FW->>Web: Permite somente para CT110
    Web->>DB: Consulta MySQL com TLS interno
    DB-->>Web: Resposta
    Web-->>User: Resposta HTTPS
```

Controles obrigatorios:
- TLS valido via Let's Encrypt.
- Headers de seguranca no Nginx.
- Logs de acesso sem gravar conteudo sensivel.
- Banco acessivel somente por IPs internos autorizados.

## Fluxo administrativo por VPN

```mermaid
sequenceDiagram
    participant Admin as Administrador
    participant FW as OPNsense
    participant VPN as CT114 WireGuard
    participant PVE as Proxmox
    participant OPN as OPNsense WebGUI
    participant MON as CT113 Monitoramento

    Admin->>FW: UDP/51820
    FW->>VPN: Encaminha WireGuard
    VPN-->>Admin: Tunel ativo
    Admin->>PVE: Acesso 10.0.1.x somente via VPN/LAN
    Admin->>OPN: WebGUI somente via VPN/LAN
    Admin->>MON: Netdata/Uptime Kuma somente via VPN/LAN
```

Controles obrigatorios:
- Um peer WireGuard por pessoa/dispositivo.
- Revogacao imediata ao trocar aparelho, desligar colaborador ou suspeitar vazamento.
- Proxmox, OPNsense, SSH, MySQL e monitoramento nunca publicados na internet.

## Fluxo de backup

```mermaid
flowchart TD
    DB[CT111 MySQL]
    WEB[CT110 Web]
    PVE[Proxmox host]
    BAK[CT112 Backup]
    Borg[Borg repos criptografados]
    HD[HD externo A local]
    HD2[HD externo B opcional/offline]
    Drive[Google Drive via rclone crypt - opcional]

    DB -->|mysqldump TLS a cada 6h| BAK
    WEB -->|fontes montadas se existirem| BAK
    PVE -->|vzdump diario VM/LXC| HD
    BAK --> Borg
    Borg --> HD
    Borg -->|segunda copia/rotacao| HD2
    HD -->|copia criptografada| Drive
    HD2 -->|evidencias importantes| Drive
```

Regras:
- Google Drive e apenas copia externa criptografada, nunca backup principal.
- Segundo HD de 1 TB, se disponivel, deve ser usado como copia B/offline ou evidencias, nao como gravacao continua.
- O primeiro restore deve ser testado antes de inserir dados reais.
- Chaves Borg, senha Borg e senha do rclone crypt ficam fora do repositorio.

## Sequencia de implantacao

```mermaid
flowchart TD
    A[Preparar kit offline e senhas]
    B[Instalar Proxmox no mini PC]
    C[Configurar bridges vmbr0 WAN e vmbr1 LAN]
    D[Executar verify-host-readiness]
    E[Criar VM100 OPNsense]
    F[Configurar OPNsense e regras minimas]
    G[Criar containers CT110-CT114]
    H[Criar VMs Home Assistant e Grom_Security]
    I[Executar deploy-all]
    J[Testar HTTPS, VPN, backup, alertas]
    K[Liberar uso controlado]

    A --> B --> C --> D --> E --> F --> G --> H --> I --> J --> K
```

## Matriz de hosts

| ID | Nome | IP | Exposicao | Funcao | Acesso administrativo |
|---|---|---:|---|---|---|
| Host | Proxmox | LAN/host | Nao publico | Hypervisor | VPN/LAN |
| VM100 | opnsense | 10.0.1.1 | 80/443/51820 via NAT conforme regra | Firewall, DNS, DHCP | VPN/LAN |
| CT110 | grom-web | 10.0.1.10 | 80/443 via OPNsense | Nginx, PHP, Python, Grom.Seg | VPN/LAN/SSH restrito |
| CT111 | grom-db | 10.0.1.11 | Nao publico | MySQL | VPN/LAN/SSH restrito |
| CT112 | grom-backup | 10.0.1.12 | Nao publico | Borg, dumps, rclone | VPN/LAN/SSH restrito |
| CT113 | grom-monitor | 10.0.1.13 | Nao publico | Netdata, Uptime Kuma | VPN/LAN |
| CT114 | grom-vpn | 10.0.1.14 | UDP/51820 | WireGuard | VPN/LAN/SSH restrito |
| VM120 | home-assistant | 10.0.1.20 | Nao publico | Home Assistant OS, Matter, automacoes, alarm panel | VPN/LAN |
| VM130 | grom-security | 10.0.1.30 | Nao publico | MQTT, video, OCR, eventos, alertas | VPN/LAN |

## Matriz de portas

| Origem | Destino | Porta | Protocolo | Acao | Motivo |
|---|---|---:|---|---|---|
| Internet | OPNsense WAN | 80 | TCP | Permitir se web publico ativo | Emissao TLS e redirecionamento HTTP |
| Internet | OPNsense WAN | 443 | TCP | Permitir | HTTPS publico dos sistemas |
| Internet | OPNsense WAN | 51820 | UDP | Permitir se VPN ativa | WireGuard |
| Internet | Proxmox | 8006 | TCP | Bloquear | Administracao nao publica |
| Internet | OPNsense WebGUI | 443 | TCP | Bloquear | Administracao nao publica |
| Internet | CT111 MySQL | 3306 | TCP | Bloquear | Banco interno |
| Internet | CT113 Monitor | 19999/3001 | TCP | Bloquear | Monitoramento interno |
| CT110 Web | CT111 DB | 3306 | TCP | Permitir com TLS | Aplicacoes acessam banco |
| CT112 Backup | CT111 DB | 3306 | TCP | Permitir com TLS | Backup logico |
| CT113 Monitor | CT110/CT111/CT114 | portas de servico | TCP/ICMP | Permitir minimo | Monitoramento interno |
| VM120 Home Assistant | VM130 Grom_Security | 1883/API conforme desenho | TCP | Permitir restrito | MQTT/eventos |
| VM130 Grom_Security | CT110/CT111 | 443/3306 conforme desenho | TCP | Permitir restrito | API/eventos/banco |
| VM130 Grom_Security | DVR/cameras | RTSP/ONVIF conforme equipamento | TCP/UDP | Permitir restrito | Streams de video e descoberta |
| Internet | DVR/cameras | Qualquer | TCP/UDP | Bloquear | Sem exposicao publica |
| VPN/LAN admin | Proxmox/OPNsense/containers | 22/443/8006 conforme host | TCP | Permitir restrito | Manutencao |

## Matriz de exposicao publica

| Servico | Publicar? | Condicao |
|---|---|---|
| `grom.seg.br` | Sim | Entrada principal do Grom.Seg, somente HTTPS e autenticacao da aplicacao |
| `web.grom.seg.br` | Temporario | Legado/transicao |
| `docs.grom.seg.br` | Temporario | Legado/transicao |
| `vpn.grom.seg.br` | Sim | Somente UDP/51820 |
| Proxmox | Nao | VPN/LAN apenas |
| OPNsense WebGUI | Nao | VPN/LAN apenas |
| MySQL | Nao | CT110/CT112 apenas |
| Netdata | Nao | VPN/LAN apenas |
| Uptime Kuma | Nao | VPN/LAN apenas |
| SSH | Nao | VPN/LAN apenas |

## Matriz LGPD

| Dado | Local previsto | Controle minimo |
|---|---|---|
| Dados pessoais de terceiros | MySQL e arquivos dos sistemas | Controle de acesso, TLS, backup criptografado |
| Boletins e documentos policiais | Grom.Seg / armazenamento da aplicacao | Perfil por usuario, trilha de auditoria, retencao definida |
| Logs de acesso | Web, OPNsense, monitoramento | Sem conteudo sensivel; retencao limitada |
| Backups | SSD, HD externo, Drive criptografado opcional | Borg/rclone crypt, teste de restore, guarda fisica |
| Segredos | `/etc/grom/grom.env`, cofres locais | Nunca commitar, nunca enviar por e-mail |

## Criterio para evoluir para VLAN

Migrar para switch gerenciavel quando pelo menos uma condicao ocorrer:
- Existirem estacoes comuns ou dispositivos de terceiros na mesma rede fisica do servidor.
- Houver necessidade de separar administracao, usuarios, servidores e visitantes.
- O ambiente passar a ter cameras, IoT, impressoras ou equipamentos sem controle de hardening.
- A auditoria exigir segregacao fisica/logica mais forte.

Enquanto isso nao ocorrer, o TL-SG108 atual permanece aceitavel para a Fase 1, desde que usado apenas como LAN restrita do servidor.
