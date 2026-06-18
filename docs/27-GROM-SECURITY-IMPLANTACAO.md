# Implantacao do Grom_Security

O `Grom_Security` sera implantado em VM dedicada para separar video, OCR, eventos, MQTT e alertas do `Grom.Seg` principal.

## VM

| Item | Valor inicial |
|---|---|
| VM ID | 130 |
| Hostname | `grom-security` |
| IP | `10.0.1.30` |
| RAM | 4 GB |
| vCPU | 2-4 |
| Disco | 160 GB |
| Sistema sugerido | Ubuntu Server LTS |

## Diretorios

```bash
mkdir -p /opt/grom-security
mkdir -p /opt/grom-security/{api,media,mosquitto/config,mosquitto/data,mosquitto/log}
```

## Docker Compose

Arquivo base no repositorio:

```text
configs/docker/grom-security-compose.yml
```

No servidor:

```bash
cd /root/grom-scripts/Grom_Security
sudo scripts/install-vm-dependencies.sh
sudo scripts/deploy-local.sh
```

Pelo Proxmox host, apos a VM estar acessivel por SSH em `10.0.1.30`:

```bash
cd /root/grom-scripts
bash scripts/proxmox/deploy-grom-security.sh
```

API interna inicial:

```text
GET  http://10.0.1.30:8080/health
GET  http://10.0.1.30:8080/rules
POST http://10.0.1.30:8080/events/evaluate
GET  http://10.0.1.30:8080/panel
```

Swagger/OpenAPI ficam desativados por padrao.

Seguranca da API:

- `/health` fica disponivel para healthcheck local.
- Demais endpoints aceitam `X-Grom-Token` quando `GROM_SECURITY_API_TOKEN` estiver definido.
- Em producao, definir token em `.env` local/seguro, fora do Git.
- Nao publicar porta `8080` na internet; acesso apenas LAN/VPN/Grom.Seg.
- O painel `/panel` edita inicialmente apenas ativacao/desativacao e severidade das regras.

## Mosquitto

Criar configuracao minima:

```text
listener 1883
allow_anonymous false
password_file /mosquitto/config/passwords
persistence true
persistence_location /mosquitto/data/
log_dest file /mosquitto/log/mosquitto.log
```

Criar usuario:

```bash
cd /opt/grom-security
export GROM_MQTT_PASSWORD='senha-forte-local'
sudo -E scripts/create-mqtt-password.sh
```

## Frigate/OpenCV/OCR

Nao ativar processamento pesado antes de definir:
- cameras;
- resolucao;
- FPS;
- zonas de deteccao;
- retencao;
- storage;
- validacao do OpenVINO na GPU integrada Intel.

Estrategia recomendada para o Beelink i5-1035G7:

```text
1. OpenVINO com Intel iGPU
2. OpenVINO CPU como fallback
3. Coral USB/M.2 somente se necessario
```

Exemplo base:

```text
configs/grom-security/frigate.openvino.example.yml
```

Para Docker/Frigate com Intel GPU, validar a existencia do device antes de ativar:

```bash
ls -l /dev/dri
```

O container Frigate deve receber acesso controlado ao render device, normalmente:

```yaml
devices:
  - /dev/dri/renderD128:/dev/dri/renderD128
```

No Frigate, usar detector OpenVINO:

```yaml
detectors:
  ov:
    type: openvino
    device: GPU
```

Se a GPU nao for reconhecida de forma estavel, trocar temporariamente para:

```yaml
detectors:
  ov:
    type: openvino
    device: CPU
```

Mesmo com OpenVINO, iniciar com:
- poucos streams;
- substream de baixa resolucao;
- FPS reduzido;
- snapshots/eventos curtos;
- sem gravacao continua como padrao.

No Proxmox, passthrough de iGPU deve ser feito somente apos validar IOMMU/grupos PCI. Nao automatizar essa etapa sem teste local, pois uma configuracao incorreta pode afetar video do host ou estabilidade da VM.

## Cameras e DVR

Matriz completa:

```text
docs/28-CAMERAS-DVR-VIDEO.md
```

Inventario exemplo:

```text
configs/grom-security/cameras.inventory.example.yml
```

Exemplo Frigate/OpenVINO:

```text
configs/grom-security/frigate.openvino.example.yml
```

Regras de alerta:

```text
docs/29-GROM-SECURITY-REGRAS.md
configs/grom-security/security-rules.example.yml
```

Na primeira ativacao:

- DVR Intelbras iMHDX 3008 em IP fixo/reserva, preferencialmente `10.0.1.40`.
- Canais VHD 5240 / 3240 lidos pelo DVR, sem acessar cada camera individualmente.
- VIGI C330I e IM7 integradas diretamente ao `Grom_Security` por RTSP/ONVIF quando viavel.
- Usuario RTSP/ONVIF exclusivo de leitura, sem senha administrativa.
- Substream para deteccao; stream principal somente para snapshot ou video curto.

## Integracao com Home Assistant

Home Assistant deve conectar no MQTT do `Grom_Security` quando esta for a decisao operacional:

```text
host: 10.0.1.30
port: 1883
usuario: grom_mqtt
```

Topicos:

```text
grom/security/events
grom/security/plates
grom/security/alerts
homeassistant/alarm
```

## Integracao com Grom.Seg

O `Grom.Seg` deve consumir eventos consolidados por API ou banco. Evitar leitura direta de arquivos de video.

Fluxo recomendado:

```text
camera/sensor -> Grom_Security -> evento consolidado -> Grom.Seg
```

O motor de regras deve publicar eventos consolidados com:
- tipo de evento;
- camera/zona;
- nivel de severidade;
- snapshot/video curto associado;
- decisao tomada;
- origem da regra;
- trilha de auditoria.

## Seguranca

- Painel Grom_Security apenas VPN/LAN.
- MQTT apenas LAN.
- Senhas em arquivo `.env` local, fora do repositorio.
- Sem portas publicas novas.
- Logs sem dados pessoais desnecessarios.

## Backup

Politica de guarda:

| Tipo | Local |
|---|---|
| Gravacao continua | DVR Intelbras |
| Eventos relevantes | Grom_Security |
| Snapshots de alerta | Grom_Security + backup |
| Videos curtos de intrusao | Grom_Security |
| Evidencias importantes | Backup externo criptografado |

Backup obrigatorio:
- `/opt/grom-security/docker-compose.yml`;
- `/opt/grom-security/mosquitto/config`;
- banco de eventos;
- snapshots marcados como relevantes.

Backup seletivo:
- videos curtos de eventos.

Nao fazer backup de cache temporario de video.
