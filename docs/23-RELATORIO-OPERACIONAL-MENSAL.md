# Relatorio operacional mensal

O relatorio operacional mensal cria uma evidencia simples da saude do Grom Server. Ele nao substitui auditoria humana, mas reduz a chance de problemas silenciosos em backup, espaco, servicos e exposicao.

## Script

No Proxmox host:

```bash
/usr/local/sbin/grom-monthly-operational-report.sh
```

Arquivo original no pacote:

```text
/root/grom-scripts/scripts/proxmox/monthly-operational-report.sh
```

## Agendamento

O `deploy-all.sh` instala o script e cria:

```text
/etc/cron.d/grom-monthly-report
```

Agenda padrao:

```cron
15 7 1 * * root /usr/local/sbin/grom-monthly-operational-report.sh
```

Ou seja, todo dia 1 as 07:15.

## Saida

Os relatorios ficam em:

```text
/var/log/grom-reports/grom-operational-report-AAAA-MM.txt
```

Se `mail` estiver configurado pelo relay SMTP, o relatorio tambem e enviado para `GROM_ALERT_EMAIL`.

## Conteudo

| Area | Conteudo |
|---|---|
| Host | Proxmox, uptime, disco, memoria, carga e temperatura se disponivel |
| VM/LXC | Lista e status de VM100, CT110-CT114 e VMs adicionais |
| Servicos | Nginx, PHP-FPM, MySQL, Netdata e WireGuard |
| Backup | HD externo, CT112, cron host e cron backup |
| Logs | Deploy, validacao pos-deploy, backup Proxmox e backup CT112 |
| Seguranca | Listeners no host e Fail2Ban por container |
| Validacao | Chama o validador pos-deploy quando disponivel |
| Checklist | Itens humanos mensais que exigem decisao ou confirmacao |

## Como executar manualmente

```bash
/usr/local/sbin/grom-monthly-operational-report.sh
```

Para informar alvo publico usado pela validacao pos-deploy:

```bash
GROM_PUBLIC_TARGET=grom.seg.br /usr/local/sbin/grom-monthly-operational-report.sh
```

Para gerar sem enviar e-mail:

```bash
GROM_SEND_REPORT_EMAIL=0 /usr/local/sbin/grom-monthly-operational-report.sh
```

## Politica LGPD

O relatorio nao deve conter senhas, dumps, documentos, boletins ou dados pessoais. Ele registra estado operacional, logs tecnicos e checklist.

Se algum sistema passar a registrar dados sensiveis em logs, corrigir a aplicacao ou reduzir o nivel de log antes de manter envio automatico por e-mail.

## Uso na rotina mensal

1. Abrir o relatorio do mes.
2. Procurar `[FALHA]` e `[AVISO]`.
3. Conferir se o backup mais recente existe.
4. Executar restore de amostra.
5. Revisar usuarios e peers WireGuard.
6. Confirmar regras WAN do OPNsense.
7. Registrar pendencias e a data da correcao.
