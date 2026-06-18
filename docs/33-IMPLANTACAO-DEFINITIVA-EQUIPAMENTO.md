# Implantacao definitiva no equipamento

Este documento resume o caminho operacional para levar o Grom Server ao mini PC definitivo com menor risco de erro humano.

## Estado atual do pacote

O Server esta pronto para instalacao controlada quando estes gates locais passam:

- `scripts/lab/prepare-local-release.ps1`
- auditoria local com zero falhas;
- validacao pre-deploy de laboratorio com zero falhas;
- simulacao de deploy com zero falhas;
- build de release com manifesto e checksum;
- dashboard local respondendo em `http://127.0.0.1:8090/server/`.

Isso nao significa producao plena. Producao plena depende dos testes no hardware final.

## Exportar para midia

No Windows de desenvolvimento:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/lab/prepare-local-release.ps1
powershell -ExecutionPolicy Bypass -File scripts/lab/export-release-usb.ps1 -Destination E:\TRANSFERENCIA
```

Troque `E:\TRANSFERENCIA` pela letra do pendrive, HD externo ou pasta de rede controlada.

O exportador cria:

```text
grom-server-release/
  grom-scripts.tar.gz
  grom-scripts.tar.gz.sha256
  LEIA-ME-IMPLANTACAO.txt
```

## Sequencia no Proxmox

Copiar os arquivos para `/root` e executar:

```bash
cd /root
sha256sum -c grom-scripts.tar.gz.sha256
tar -xzf grom-scripts.tar.gz -C /root
```

Criar o env real:

```bash
mkdir -p /etc/grom
chmod 700 /etc/grom
nano /etc/grom/grom.env
chmod 600 /etc/grom/grom.env
```

Ensaiar sem deploy:

```bash
bash /root/grom-scripts/scripts/proxmox/final-local-deploy.sh --skip-deploy
```

Executar deploy apenas depois do ensaio aprovado:

```bash
bash /root/grom-scripts/scripts/proxmox/final-local-deploy.sh --confirm-final-deploy --public-target=grom.seg.br
```

## Pontos de parada obrigatoria

Parar e corrigir antes de continuar se ocorrer qualquer item:

- checksum falha;
- `/etc/grom/grom.env` ausente ou permissivo demais;
- Proxmox nao detectado;
- menos de duas interfaces de rede;
- virtualizacao desabilitada;
- OPNsense nao assumiu caminho WAN/LAN;
- `validate-deploy-config.sh --strict` aponta variavel ausente;
- backup externo esperado nao montado;
- porta administrativa aparece publica;
- restore ainda nao foi testado.

## Percentual esperado por fase

| Fase | Meta de maturidade |
|---|---:|
| Pacote local auditado | 98% |
| Ensaio no host com `--skip-deploy` | 93% |
| Deploy concluido sem falhas | 90% |
| Backup e restore comprovados | 85% |
| VPN, DNS, TLS e alertas reais validados | 82% |
| Go/No-Go com evidencias completas | 95% para uso controlado |

## Proximo trabalho apos Server

Quando o Server passar pelo primeiro deploy real e pelos validadores, o caminho natural e iniciar o Grom Security em dry-run:

1. subir VM130;
2. validar rede e storage;
3. integrar MQTT/Home Assistant sem notificacoes reais;
4. testar cameras e regras com eventos simulados;
5. so depois ativar alertas reais e retencao definitiva.
