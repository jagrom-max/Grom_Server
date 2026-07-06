# Implantacao definitiva no equipamento

Este documento resume o caminho operacional para levar o Grom Server ao HP EliteDesk 800 G4 Mini definitivo com menor risco de erro humano.

Hardware alvo:

- Intel Core i7-8700T, 16 GB DDR4;
- SSD de 500 GB instalado no lugar da unidade original de 256 GB;
- unidade externa USB de 1 TB para backup;
- adaptador Ugreen USB 2.5GbE como segunda interface;
- DVR Intelbras iMHDX 3008 integrado ao Frigate, mas responsavel pela gravacao continua.

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

Para executar primeiro em bancada, antes da rede destinataria, siga tambem `docs/34-IMPLANTACAO-EM-BANCADA.md`.

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
- SSD de 500 GB nao instalado ou unidade de 256 GB selecionada por engano;
- Frigate configurado para gravacao continua indiscriminada no SSD interno;
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

1. subir VM130 no HP EliteDesk;
2. validar rede e storage;
3. integrar MQTT/Home Assistant sem notificacoes reais;
4. testar cameras e regras com eventos simulados;
5. so depois ativar alertas reais e retencao definitiva.

O Home Assistant nao deve ser criado neste host. Sua integracao sera feita
posteriormente, a partir de outra maquina. O servidor de backup dedicado tambem
sera externo; ate sua chegada, manter CT112 e a unidade USB de 1 TB.
