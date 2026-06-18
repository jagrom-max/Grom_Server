# Comunicacao oficial do ecossistema Grom

Este documento padroniza a identidade externa de comunicacao operacional dos sistemas Grom.

## Conta oficial

```text
grom.servidor@gmail.com
```

Esta conta e a identidade tecnica oficial para:

- Grom_Server;
- Grom_Security;
- Grom.Seg;
- monitoramento;
- alertas de backup;
- avisos de certificado;
- contatos tecnicos com provedores, DNS, dominio e servicos auxiliares.

## Padrao de variaveis

```bash
GROM_CONTACT_EMAIL=grom.servidor@gmail.com
GROM_ALERT_EMAIL=grom.servidor@gmail.com
GROM_SMTP_USER=grom.servidor@gmail.com
GROM_SMTP_FROM=grom.servidor@gmail.com

GROM_SECURITY_SMTP_HOST=smtp.gmail.com
GROM_SECURITY_SMTP_PORT=587
GROM_SECURITY_SMTP_USERNAME=grom.servidor@gmail.com
GROM_SECURITY_SMTP_FROM=grom.servidor@gmail.com
```

Segredos e destinatarios reais ficam somente no servidor ou cofre:

```bash
GROM_SMTP_APP_PASS={SENHA_DE_APP_LOCAL}
GROM_SECURITY_SMTP_PASSWORD={SENHA_DE_APP_LOCAL}
GROM_SECURITY_ALERT_EMAIL_TO={DESTINATARIO_AUTORIZADO}
```

## Regras de seguranca

- Ativar 2FA na conta.
- Usar senha de app exclusiva para SMTP.
- Nunca commitar senha, token, backup, `.env`, chaves privadas ou dumps.
- Nunca enviar documentos policiais, imagens sensiveis, placas, rostos ou bases de dados em claro por e-mail.
- E-mails externos devem conter apenas informacao minima: sistema, severidade, tipo, zona/camera quando aplicavel e ID do evento.
- Evidencias completas devem ser acessadas apenas pelo sistema autenticado em LAN/VPN.
- Revisar atividade da conta mensalmente.

## Escopo

A conta oficial padroniza comunicacao externa. Ela nao substitui:

- usuarios nominais internos;
- auditoria dos sistemas;
- backup criptografado;
- cofre de senhas;
- politicas de retencao e descarte.

## Futuro

Se o projeto migrar para Google Workspace ou provedor equivalente, a conta preferencial passa a ser algo como:

```text
infra@grom.seg.br
```

A migracao deve preservar historico, MFA, senha de app, contatos de recuperacao e documentacao operacional.
