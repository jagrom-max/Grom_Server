# Go/No-Go de producao

Este documento e o portao final antes de liberar o Grom Server para uso real com dados sensiveis, Grom_SigePol, Grom_Security e automacoes residenciais.

O objetivo nao e prometer risco zero. O objetivo e impedir liberacao por intuicao, exigindo evidencias minimas de seguranca, recuperacao e operacao.

## Decisao atual

Status recomendado ate validacao no hardware final:

```text
NO-GO para producao plena
GO apenas para homologacao, implantacao controlada e testes sem dados reais
```

Motivos:

- O deploy ainda precisa ser executado e validado no Proxmox definitivo.
- Backup e restore precisam ser provados, nao apenas configurados.
- Exposicao publica precisa ser testada a partir de internet externa.
- Alertas reais precisam ser recebidos.
- Grom_SigePol e Grom_Security precisam de planos de deploy separados e versionados.

## Percentual de maturidade

Estimativa operacional nesta fase:

| Area | Maturidade |
|---|---:|
| Arquitetura do Server | 85% |
| Documentacao e runbooks | 90% |
| Automacao de infraestrutura | 80% |
| Hardening planejado | 75% |
| Evidencia real de seguranca em producao | 50% |
| Backup configurado | 75% |
| Restore comprovado | 0% ate teste real |
| Monitoramento e alertas | 70% planejado, pendente validacao real |
| Prontidao para hospedar sistemas | 70% para infraestrutura, pendente apps reais |

## Gate automatizado

Antes de copiar o pacote para o Proxmox, gerar uma release limpa:

```bash
bash scripts/build-release.sh
```

Levar para o host final o arquivo gerado em `dist/` e conferir o `.sha256` antes de extrair.

Depois do deploy, executar no Proxmox host:

```bash
bash /root/grom-scripts/scripts/proxmox/capacity-baseline.sh
bash /root/grom-scripts/scripts/proxmox/post-deploy-validation.sh --public-target=grom.seg.br
bash /root/grom-scripts/scripts/proxmox/restore-drill.sh
bash /root/grom-scripts/scripts/proxmox/operational-health-check.sh --public-target=grom.seg.br
bash /root/grom-scripts/scripts/proxmox/production-readiness-check.sh --public-target=grom.seg.br
```

O relatorio do gate fica em:

```text
/var/log/grom-production-readiness.log
```

## Evidencias obrigatorias

O gate exige marcadores em:

```text
/etc/grom/production-readiness.d/
```

Criar cada marcador somente depois de executar e registrar o teste correspondente.

| Marcador | Evidencia exigida |
|---|---|
| `restore-tested` | Restore de banco, arquivos e ao menos uma VM/LXC testado |
| `external-scan-ok` | Scanner externo confirmou Proxmox/MySQL/monitoramento fechados |
| `vpn-tested` | Cliente WireGuard externo conectou e acessou recurso interno permitido |
| `alert-email-ok` | Alerta operacional recebido em `grom.servidor@gmail.com` |
| `secrets-in-vault` | Senhas, chaves Borg/rclone, tokens e recovery codes guardados fora do Git |
| `dns-tls-ok` | DNS e TLS validos para os dominios publicos |

Exemplo de registro:

```bash
mkdir -p /etc/grom/production-readiness.d
printf '%s\n' "2026-06-17 restore testado por NOME" > /etc/grom/production-readiness.d/restore-tested
chmod 600 /etc/grom/production-readiness.d/restore-tested
```

## Criterios de GO

Liberar uso controlado somente com:

- `post-deploy-validation.sh` com zero falhas.
- `capacity-baseline.sh` com zero falhas e avisos aceitos.
- `restore-drill.sh` com zero falhas; usar `--mark-ready` somente depois de revisar o relatorio.
- `operational-health-check.sh` com zero falhas em execucao manual e cron instalado.
- `production-readiness-check.sh` com zero falhas.
- Dashboard `https://grom.seg.br/server/` acessivel por LAN/VPN e bloqueado publicamente.
- Portas publicas administrativas fechadas.
- Restore testado.
- VPN testada.
- Alertas testados.
- Segredos fora do repositorio.
- DNS e TLS corretos.
- Plano de rollback conhecido.

## Criterios de NO-GO

Nao liberar producao se qualquer item abaixo ocorrer:

- Proxmox, OPNsense, MySQL, Netdata ou Uptime Kuma exposto publicamente.
- Backup existe, mas restore nunca foi testado.
- Senhas reais aparecem em repositorio, documentacao ou logs.
- `/etc/grom/grom.env` esta ausente ou permissivo demais.
- VPN nao foi testada por cliente externo.
- DNS/TLS esta instavel.
- Falhas de deploy foram ignoradas.
- Grom_SigePol ou Grom_Security forem publicados sem autenticacao, logs e plano de rollback.

## Hospedagem dos sistemas

### Grom_SigePol

O Grom_SigePol deve unificar Grom_Web e Grom_Documental como aplicacao principal de gestao. Antes de producao, definir:

- stack oficial;
- modelo de banco;
- usuarios e perfis;
- uploads e limites;
- auditoria de login, alteracoes, exportacoes e documentos;
- estrategia de migrations;
- estrategia de rollback;
- jobs/filas, se houver OCR ou processamento pesado;
- politica de retencao de documentos.

### Grom_Security

O Grom_Security deve operar como sistema separado para alarme, monitoramento e automacao residencial. Antes de producao, definir:

- VM/host final;
- integracao MQTT/Home Assistant;
- zonas, cameras, sensores e regras;
- retencao de eventos e evidencias;
- modo dry-run antes de notificacoes reais;
- autenticacao do painel/API;
- limites de CPU/GPU/storage;
- resposta quando camera, sensor ou rede falhar.

## Amadurecimento recomendado

Ordem de trabalho:

1. Implantar Server em homologacao no hardware final.
2. Executar validadores e corrigir falhas.
3. Provar backup e restore.
4. Validar portas publicas por internet externa.
5. Ativar alertas e relatorio mensal.
6. Medir baseline de CPU/RAM/disco/rede.
7. Implantar Grom_SigePol em ambiente interno.
8. Implantar Grom_Security em dry-run.
9. Rodar 7 dias de observacao sem dados criticos.
10. Liberar producao controlada.

## Verdade operacional

O servidor pode ser robusto, mas nunca invulneravel. A confianca vem de camadas:

- firewall e menor exposicao;
- segmentacao por VM/container;
- senhas e chaves fora do Git;
- backup criptografado;
- restore testado;
- logs e alertas;
- atualizacoes controladas;
- rollback praticavel;
- revisao periodica.
