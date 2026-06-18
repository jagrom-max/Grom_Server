# Desenvolvimento seguro em laboratorio

Este documento define a fase atual do projeto: desenvolver, validar e endurecer o Grom Server em unidade separada, sem usar o hardware definitivo, a rede definitiva ou dados reais.

## Regra principal

Enquanto o sistema nao estiver maduro:

- nao executar `deploy-all.sh` no ambiente definitivo;
- nao copiar segredos reais para o repositorio;
- nao apontar validacoes de laboratorio para `grom.seg.br`;
- nao expor portas publicas;
- nao usar documentos, dumps, imagens de camera ou dados pessoais reais;
- nao misturar codigo do `Grom_Security` dentro do `Grom_Server`.

## Fluxo local recomendado

No Windows:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/lab/run-safe-lab-checks.ps1
```

Para tambem gerar pacote de release local:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/lab/run-safe-lab-checks.ps1 -BuildRelease
```

Para preparar um pacote candidato completo, com preview local do dashboard e release:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/lab/prepare-local-release.ps1
```

Para abrir apenas o dashboard operacional em preview HTTP local:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/lab/preview-dashboard.ps1
```

URL padrao:

```text
http://127.0.0.1:8090/server/
```

Para exportar o pacote candidato para pendrive, HD externo ou pasta de transferencia:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/lab/export-release-usb.ps1 -Destination X:\CAMINHO
```

Em Linux/Git Bash:

```bash
bash scripts/lab/run-safe-lab-checks.sh
bash scripts/lab/run-safe-lab-checks.sh --build-release
```

O fluxo cria arquivos somente em:

```text
.lab/
dist/
```

Esses diretorios sao artefatos locais e ficam fora do Git.

## O que o laboratorio valida

O script de laboratorio:

- cria `.lab/grom.env` com valores ficticios fortes;
- usa dominio `.invalid`, evitando alvo real por acidente;
- executa `scripts/proxmox/audit-repository.sh`;
- executa `scripts/proxmox/validate-deploy-config.sh --strict` apontando para o workspace local;
- executa `scripts/lab/simulate-deploy-plan.sh` para gerar o plano seguro que seria seguido no Proxmox definitivo;
- opcionalmente executa `scripts/build-release.sh`;
- grava relatorios em `.lab/reports/`.
- mantem o dashboard e seus assets dentro de `apps/grom-seg/public/server/`, garantindo que o pacote de deploy leve logo, CSS, JS e `status.json`.

Ele nao executa:

- `deploy-all.sh`;
- `pct`;
- `qm`;
- `vzdump`;
- `systemctl`;
- comandos de firewall;
- escrita em `/etc/grom`;
- alteracoes de rede.

## Simulacao do deploy

Para gerar somente o plano simulado:

```bash
bash scripts/lab/simulate-deploy-plan.sh
```

Relatorio gerado:

```text
.lab/reports/deploy-plan.log
```

A simulacao valida artefatos, variaveis ficticias, IDs esperados de VM/CT e a ordem operacional que sera usada no hardware final. Ela nao interpreta nem executa o `deploy-all.sh`; o objetivo e transformar a implantacao futura em checklist auditavel.

## Criterios para continuar desenvolvendo

Antes de qualquer novo commit relevante:

```bash
bash scripts/lab/run-safe-lab-checks.sh
```

Antes de considerar um pacote candidato:

```bash
bash scripts/lab/run-safe-lab-checks.sh --build-release
```

O pacote candidato so deve ser considerado se:

- auditoria local terminar com zero falhas;
- validacao pre-deploy de laboratorio terminar com zero falhas;
- simulacao de deploy terminar com zero falhas;
- release for gerado com manifesto e checksum;
- `git diff --check` nao apontar problemas;
- nao houver segredos reais em arquivos rastreados.
- o dashboard local responder via `scripts/lab/preview-dashboard.ps1`.
- o orquestrador `scripts/proxmox/final-local-deploy.sh` estiver presente no pacote.

## Escada de maturidade

| Nivel | Ambiente | Objetivo | Permissao |
|---|---|---|---|
| L0 | Workspace local | Edicao, auditoria, release local | Sem Proxmox |
| L1 | VM descartavel/local | Testar sintaxe e partes nao destrutivas | Sem rede publica |
| L2 | Proxmox de homologacao | Testar containers/VMs com dados ficticios | LAN isolada |
| L3 | Hardware final em janela controlada | Validar host, rede, backup e restore | Sem dados reais |
| L4 | Producao controlada | Uso real com monitoramento e rollback | Somente apos Go/No-Go |

No L3, o primeiro comando no host final deve ser:

```bash
bash /root/grom-scripts/scripts/proxmox/final-local-deploy.sh --skip-deploy
```

Somente apos revisar o ensaio e confirmar janela:

```bash
bash /root/grom-scripts/scripts/proxmox/final-local-deploy.sh --confirm-final-deploy --public-target=grom.seg.br
```

## Promocao para implantacao definitiva

So avancar para o hardware definitivo quando:

- `docs/31-GO-NOGO-PRODUCAO.md` estiver sem pendencias criticas;
- os scripts de laboratorio passarem repetidamente;
- backup e restore tiverem plano testavel;
- Grom_SigePol e Grom_Security tiverem deploys separados;
- houver decisao documentada de janela, rollback e responsavel.

## Verdade operacional

O objetivo desta fase e reduzir surpresa. O destino definitivo deve receber um pacote que ja foi auditado, empacotado, documentado e testado em modo seguro muitas vezes.
