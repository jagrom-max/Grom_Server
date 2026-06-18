# Implantacao em bancada antes da rede destinataria

Este roteiro cobre o que pode ser feito no equipamento definitivo antes de levar o servidor para a rede destinataria. O objetivo e chegar ao local final com Proxmox, pacote, containers, dashboard, backup basico e validadores ja exercitados.

## O que pode ser feito em bancada

- Instalar Proxmox no mini PC definitivo.
- Validar CPU, virtualizacao, RAM, disco e interfaces de rede.
- Copiar e conferir o pacote `grom-scripts.tar.gz`.
- Criar `/etc/grom/grom.env` com segredos reais guardados no cofre.
- Rodar o orquestrador em modo ensaio.
- Executar deploy em rede isolada, sem `--public-target`.
- Validar containers, servicos internos, dashboard e conectividade interna.
- Testar backup em HD externo.
- Executar restore drill.
- Gerar relatorios locais em `/var/log/grom-*.log`.

## O que nao fecha em bancada

- DNS real de `grom.seg.br`.
- TLS real com Let's Encrypt se o dominio nao apontar para o IP final.
- NAT/port forward definitivo.
- Scanner externo de portas publicas.
- VPN externa pelo IP definitivo.
- Regras finais do OPNsense integradas a rede destinataria.
- Go/No-Go de producao com todas as evidencias.

## Preparar midia no Windows

No workspace:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/lab/prepare-local-release.ps1
powershell -ExecutionPolicy Bypass -File scripts/lab/export-release-usb.ps1 -Destination X:\CAMINHO
```

Troque `X:\CAMINHO` pelo pendrive, HD externo ou pasta de transferencia.

## Sequencia no Proxmox em bancada

Copiar `grom-scripts.tar.gz` e `grom-scripts.tar.gz.sha256` para `/root`.

```bash
cd /root
sha256sum -c grom-scripts.tar.gz.sha256
tar -xzf grom-scripts.tar.gz -C /root
```

Criar env real:

```bash
mkdir -p /etc/grom
chmod 700 /etc/grom
nano /etc/grom/grom.env
chmod 600 /etc/grom/grom.env
```

Ensaio sem deploy:

```bash
bash /root/grom-scripts/scripts/proxmox/final-local-deploy.sh --skip-deploy
```

Se o ensaio passar, executar deploy de bancada:

```bash
bash /root/grom-scripts/scripts/proxmox/final-local-deploy.sh --confirm-final-deploy
```

## Validacoes em bancada

```bash
bash /root/grom-scripts/scripts/proxmox/post-deploy-validation.sh
bash /root/grom-scripts/scripts/proxmox/operational-health-check.sh
bash /root/grom-scripts/scripts/proxmox/restore-drill.sh
```

Depois de revisar e aceitar o restore:

```bash
bash /root/grom-scripts/scripts/proxmox/restore-drill.sh --mark-ready
```

## Acesso ao dashboard em bancada

Usar acesso por IP/LAN interna. O caminho publicado pelo Nginx sera:

```text
http://IP_DO_CT110/server/
```

Na rede definitiva, o alvo esperado sera:

```text
https://grom.seg.br/server/
```

## Criterios para levar ao local final

- `final-local-deploy.sh --skip-deploy` passou sem falhas criticas.
- Deploy de bancada concluiu.
- CT110-CT114 sobem.
- Dashboard abre por LAN.
- Backup no HD externo foi criado.
- Restore drill foi executado.
- Nenhuma porta administrativa foi exposta na bancada.
- Logs principais foram revisados.
- Pendencias foram anotadas antes da mudanca de rede.

## Ao chegar na rede destinataria

Revisar WAN/LAN, OPNsense, DNS/NAT e repetir:

```bash
bash /root/grom-scripts/scripts/proxmox/final-local-deploy.sh --skip-deploy --public-target=grom.seg.br
bash /root/grom-scripts/scripts/proxmox/post-deploy-validation.sh --public-target=grom.seg.br
bash /root/grom-scripts/scripts/proxmox/operational-health-check.sh --public-target=grom.seg.br
bash /root/grom-scripts/scripts/proxmox/production-readiness-check.sh --public-target=grom.seg.br
```

So liberar uso real depois dos marcadores de evidencia em `/etc/grom/production-readiness.d/`.
