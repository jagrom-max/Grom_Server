# Home Assistant externo e Grom_Security no HP EliteDesk

Esta readequacao separa automacao residencial/IoT de seguranca operacional. O
objetivo e evitar que integracoes de dispositivos, video, OCR e alertas
fiquem misturados com o `Grom.Seg` principal e impedir sobrecarga do HP
EliteDesk.

## Escopo atual deste documento

Este documento permanece no `Grom_Server` apenas para registrar a fronteira de
integracao entre `home-ops` e `Grom_Security`.

Detalhamento operacional da segunda maquina, incluindo implantacao, storage,
replica, restore e automacoes locais, pertence agora ao projeto `HA_Back`.

## Decisao arquitetural

Separar as cargas entre o HP EliteDesk atual e uma segunda maquina dedicada:

| Ambiente | Nome | IP sugerido | Funcao |
|---|---|---:|---|
| Segunda maquina dedicada | home-ops | 10.0.1.20 | Home Assistant OS, backups e automacoes |
| VM130 no HP EliteDesk | grom-security | 10.0.1.30 | Frigate, video, eventos, OCR, API e painel de seguranca |

Enquanto a segunda maquina nao estiver disponivel, o CT112 continua no HP e
grava na unidade USB de 1 TB como camada local temporaria.

Manter a infraestrutura base:

| ID | Nome | Funcao |
|---|---|---|
| VM100 | opnsense | Firewall |
| CT110 | grom-web | Grom.Seg |
| CT111 | grom-db | MySQL |
| CT112 | grom-backup | Backup |
| CT113 | grom-monitor | Monitoramento |
| CT114 | grom-vpn | WireGuard |

## Responsabilidades

### Segunda maquina dedicada

Executar:
- Home Assistant.
- backups nativos do Home Assistant.
- replica dos backups do HP.
- restauracoes de teste e retencao secundaria.
- Matter Server.
- integracao com Zemismart M6.
- dashboards.
- automacoes.
- Alarm Panel.
- Telegram/notificacoes.
- MQTT integration, se esse for o desenho final.

Regra: essa maquina concentra automacao e resiliencia. O Home Assistant controla
automacao e estados de dispositivos, mas nao deve armazenar evidencias
policiais principais nem ser o banco central de eventos sensiveis.

### VM Grom_Security

Executar:
- Docker Compose.
- Mosquitto MQTT, se ficar fora do Home Assistant.
- Frigate ou modulo proprio de video.
- OpenCV.
- OCR de placas.
- Banco de eventos.
- API do Grom_Security.
- Painel operacional.
- Motor de regras.
- Servidor de alertas.
- Snapshots e videos curtos.

Regra: Grom_Security concentra eventos de seguranca, video, OCR e evidencias tecnicas. O `Grom.Seg` consome eventos consolidados por API/banco, sem precisar executar processamento pesado.

## Cameras e DVR

Referencia operacional detalhada:

```text
docs/28-CAMERAS-DVR-VIDEO.md
```

Diretriz adotada:

| Equipamento | Integracao |
|---|---|
| DVR Intelbras iMHDX 3008 | RTSP/ONVIF para o Grom_Security |
| VHD 5240 / 3240 | Ligadas ao DVR; Grom_Security le canais do DVR |
| VIGI C330I | Direta no Grom_Security por RTSP/ONVIF; opcionalmente tambem no DVR |
| IM7 | Direta no Grom_Security por RTSP/ONVIF, como camera de contexto |
| Cameras internas garagem | Presenca de veiculo, lista branca e eventos de acesso |

O DVR permanece responsavel por gravacao continua propria. O `Grom_Security` deve iniciar com analise moderada, snapshots e videos curtos de eventos.

## Motor de regras

Referencia:

```text
docs/29-GROM-SECURITY-REGRAS.md
configs/grom-security/security-rules.example.yml
```

O `Grom_Security` deve correlacionar camera, sensor, estado do alarme e lista branca para gerar alertas de severidade baixa, media, alta, critica ou tecnica.

## MQTT

Decisao recomendada para baixa manutencao:

| Cenario | Recomendacao |
|---|---|
| Automacao simples e poucos dispositivos | Mosquitto no Home Assistant |
| Cameras, eventos, OCR e multiplos produtores | Mosquitto no Grom_Security |
| Necessidade de redundancia futura | Bridge MQTT entre Home Assistant e Grom_Security |

Para a primeira implantacao, preferir:

```text
Mosquitto no Grom_Security
Home Assistant conectado como cliente MQTT
Grom_Security como dono dos topicos de seguranca
```

Topicos sugeridos:

```text
grom/security/events
grom/security/plates
grom/security/alerts
homeassistant/status
homeassistant/alarm
```

## Alocacao de recursos

O HP EliteDesk possui 16 GB RAM e 6C/12T. A configuracao continua conservadora
porque o Frigate compartilha o host com firewall, banco, aplicacao e
monitoramento.

| Componente | RAM | vCPU | Disco | Observacao |
|---|---:|---:|---:|---|
| Proxmox host | 1.5-2 GB | - | 30 GB | Base |
| VM100 OPNsense | 2 GB | 2 | 20 GB | Firewall |
| Segunda maquina Home Assistant + backup | Fora do host | - | - | Automacao/IoT e resiliencia em outra maquina |
| VM130 Grom_Security | 4 GB | 4 | 100 GB | Frigate, video/eventos/OCR com OpenVINO |
| CT110 Grom.Seg | 2.5 GB | 3 | 60 GB | Aplicacao principal |
| CT111 MySQL | 2 GB | 2 | 100 GB | Banco |
| CT112 Backup | 512 MB | 1 | 16 GB | Borg/dumps; dados no USB de 1 TB |
| CT113 Monitor | 512 MB | 1 | 12 GB | Netdata/Uptime Kuma |
| CT114 VPN | 384 MB | 1 | 4 GB | WireGuard |

Observacao: Frigate com analise por CPU pode consumir bastante. Para o
i7-8700T, a estrategia preferencial e OpenVINO com GPU integrada Intel. Se a
iGPU nao ficar estavel no passthrough para a VM, usar OpenVINO em CPU como
fallback temporario, com poucos streams, baixa taxa de FPS, zonas bem
definidas e snapshots curtos.

## OpenVINO e Intel iGPU

Decisao recomendada:

```text
Frigate/OpenCV -> OpenVINO -> Intel iGPU do i7-8700T
Fallback -> OpenVINO CPU
Compra futura -> Coral somente se OpenVINO nao atender
```

Motivos:
- aproveita hardware ja existente;
- reduz carga de CPU em deteccao;
- evita compra imediata de acelerador externo;
- mantem o Frigate dentro da VM `Grom_Security`, preservando isolamento.

Requisitos de ativacao:
- virtualizacao Intel VT-x/VT-d habilitada na BIOS;
- IOMMU validado no Proxmox;
- dispositivo `/dev/dri/renderD128` visivel para a VM/container;
- Docker com acesso controlado ao device de GPU;
- ballooning desativado na VM `Grom_Security`;
- teste de estabilidade antes de producao.

Exemplo base:

```text
configs/grom-security/frigate.openvino.example.yml
```

## Rede e exposicao

| Servico | Publico? | Acesso |
|---|---|---|
| Home Assistant | Nao | VPN/LAN |
| Grom_Security painel | Nao por padrao | VPN/LAN |
| MQTT | Nao | LAN interna, usuario/senha e ACL |
| API Grom_Security | Nao por padrao | Grom.Seg/VPN/LAN |
| Frigate UI | Nao | VPN/LAN |
| Snapshots/videos | Nao direto | Via Grom_Security/Grom.Seg |

Portas publicas continuam restritas a:
- TCP 80/443 para `Grom.Seg`;
- UDP 51820 para WireGuard.

## Fluxo logico

```mermaid
flowchart LR
    HA[Home Assistant externo futuro]
    SEC[VM130 Grom_Security\n10.0.1.30]
    MQTT[MQTT broker]
    CAM[Cameras / sensores]
    SEG[CT110 Grom.Seg\n10.0.1.10]
    DB[CT111 MySQL\n10.0.1.11]
    ALERT[Telegram / alertas]

    CAM --> SEC
    HA --> MQTT
    SEC --> MQTT
    MQTT --> HA
    SEC --> SEG
    SEC --> DB
    HA --> ALERT
    SEC --> ALERT
```

## Retencao de midia

Como o SSD e de 500 GB e atende todo o host, usar retencao conservadora:

| Tipo de gravacao | Local |
|---|---|
| Gravacao continua | DVR Intelbras |
| Eventos relevantes | Grom_Security |
| Snapshots de alerta | Grom_Security + backup |
| Videos curtos de intrusao | Grom_Security |
| Evidencias importantes | Backup externo criptografado |

| Tipo | Retencao inicial |
|---|---|
| Eventos sem relevancia | 24-72h |
| Snapshots de eventos | 7-30 dias |
| Videos curtos de eventos | 7-15 dias |
| Eventos marcados/relevantes | Politica definida no Grom.Seg |

Videos longos e gravacao continua nao sao recomendados nesta fase sem storage dedicado.

## Backup

Backup obrigatorio no HP:
- compose/env do Grom_Security;
- banco de eventos;
- snapshots relevantes;
- configuracao MQTT.

Quando a segunda maquina estiver disponivel, incluir:
- backups nativos do Home Assistant;
- replica dos backups do HP;
- restore recorrente dessa replica.

Backup cauteloso:
- videos curtos somente se forem evidencia ou evento marcado.

Com a unidade externa de 1 TB:
- manter backups operacionais diarios do HP;
- guardar snapshots relevantes e evidencias importantes;
- nao usar a unidade para gravacao continua de video;
- replicar para o futuro servidor de backup quando ele estiver disponivel.

Nao fazer backup integral de cache de video sem necessidade.

## Dependencias futuras recomendadas

| Item | Prioridade | Motivo |
|---|---|---|
| Segunda maquina Home Assistant + backup | Alta | Segunda copia, separacao fisica e alivio do HP |
| Storage dedicado 2 TB+ | Media | Apenas se houver necessidade de ampliar retencao de eventos |
| Nobreak | Alta | Evita corrupcao em banco/video |
| Acelerador Coral USB/M.2 | Baixa/Media | Avaliar somente se OpenVINO na iGPU nao atender |
| Switch gerenciavel/VLAN | Media | Separar IoT/cameras/servidores/admin |

## Criterio para ativar em producao

Antes de uso real:
- Quando instalada, a segunda maquina deve ficar acessivel somente via VPN/LAN.
- Grom_Security acessivel somente via VPN/LAN.
- MQTT com usuario/senha.
- Cameras/sensores sem acesso direto a rede administrativa.
- Retencao de video definida.
- Backup de configuracoes testado.
- Alertas Telegram testados sem dados sensiveis em claro.
