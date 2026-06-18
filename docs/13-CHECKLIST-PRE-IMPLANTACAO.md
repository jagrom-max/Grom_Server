# Checklist pre-implantacao

Este checklist organiza o que deve ficar pronto antes da instalacao fisica do Grom Server.

## Preparar agora

- Revisar e commitar toda alteracao de infraestrutura.
- Gerar senhas no KeePassXC para:
  - `MYSQL_ROOT_PASS`
  - `GROM_SEG_PASS`
  - `GROM_WEB_PASS`
  - `GROM_DOC_PASS`
  - `GROM_BACKUP_PASS`
  - `BORG_PASSPHRASE`
  - `GROM_SMTP_APP_PASS`, se alertas por Gmail forem ativados
- Definir quem tera VPN e criar lista nominal de dispositivos.
- Confirmar se o provedor entrega IP publico real ou CGNAT.
- Confirmar controle DNS de `grom.seg.br`.
- Revisar `docs/25-DNS-REGISTRO-BR.md`.
- Conta Google dedicada `grom.servidor@gmail.com` criada e configurada conforme `docs/17-CONTA-GOOGLE-BACKUP.md`.
- Arquivo local `/etc/grom/grom.env` planejado, sem commitar senha de app.
- Separar pendrive de instalacao do Proxmox.
- Baixar ISOs e pacotes necessarios quando possivel.
- Gerar `downloads/manifest.json` com `scripts/downloads/prepare-offline-kit.ps1`.
- Gerar pacote de release com `bash scripts/build-release.sh`.
- No Windows de desenvolvimento, preferir `powershell -ExecutionPolicy Bypass -File scripts/lab/prepare-local-release.ps1` para validar laboratorio, dashboard e release em uma unica rotina.
- Conferir `dist/grom-scripts.zip.sha256` ou `dist/grom-scripts.tar.gz.sha256`, conforme o formato gerado.
- No Proxmox final, executar primeiro `bash /root/grom-scripts/scripts/proxmox/final-local-deploy.sh --skip-deploy`.
- Definir politica de retencao de documentos e logs.
- Definir responsavel LGPD/seguranca e contato de incidente.
- Confirmar que a Fase 1 usara o switch atual apenas como LAN restrita, sem VLAN.

## Comprar antes da instalacao

- Nobreak minimo 600VA, ideal 1000VA, com USB para desligamento ordenado.
- Segundo HD externo de 2TB ou maior para rotacao offline; se houver apenas 1TB extra, usar como copia B/offline e evidencias importantes.
- Cabos Cat6 curtos e identificados.
- Futuro/recomendado: switch gerenciavel com VLAN para a rede definitiva.

## Validar no dia da instalacao

- BIOS com VT-x, VT-d e Hyper-Threading habilitados.
- Proxmox instalado e atualizado.
- `scripts/proxmox/verify-host-readiness.sh` executado sem falhas.
- OPNsense como unico caminho entre WAN e LAN.
- VM100 OPNsense ativa antes dos containers.
- CT110 web, CT111 banco, CT112 backup, CT113 monitoramento, CT114 VPN.
- Dashboard `https://grom.seg.br/server/` publicado com logo e dados de `status.json`, acessivel apenas por LAN/VPN.
- Proxmox e OPNsense acessiveis apenas por LAN/VPN.
- VM120 Home Assistant OS planejada em `10.0.1.20`.
- VM130 Grom_Security planejada em `10.0.1.30`.
- Apenas portas externas 80/443 e 51820 liberadas, se realmente necessarias.
- Certificados TLS emitidos para `grom.seg.br` e, durante a transicao, `web.grom.seg.br` e `docs.grom.seg.br`.
- Teste de login, consulta, cadastro e upload nos sistemas.
- Primeiro backup completo executado.
- Se o segundo HD estiver disponivel, montar em `/mnt/backup-external-2` e validar bind mount `/mnt/external2` no CT112.
- Cron/timer do Proxmox host configurado para `scripts/proxmox/backup-containers.sh`.
- Restore de teste executado em ambiente temporario.
- Alertas de monitoramento funcionando.
- Conta `grom.servidor@gmail.com` recebendo alertas de teste, sem armazenar dados sensiveis em claro.

## Variaveis para deploy

Exemplo de execucao no Proxmox host, apos extrair o pacote em `/root`:

```bash
export MYSQL_ROOT_PASS='guardar-no-cofre'
export GROM_SEG_PASS='guardar-no-cofre'
export GROM_WEB_PASS='guardar-no-cofre'
export GROM_DOC_PASS='guardar-no-cofre'
export GROM_BACKUP_PASS='guardar-no-cofre'
export BORG_PASSPHRASE='guardar-no-cofre'

bash /root/grom-scripts/scripts/proxmox/final-local-deploy.sh --confirm-final-deploy --public-target=grom.seg.br
```

Nao registrar esses valores em terminal compartilhado, print, documento sem criptografia ou repositorio.

## Criterios de aceite

- Nenhum painel administrativo responde pela internet.
- Backup criptografado existe em SSD e HD externo.
- Uma restauracao de banco foi testada.
- Acesso remoto administrativo funciona por WireGuard.
- Logs registram eventos de seguranca sem gravar conteudo sensivel.
- Existe plano claro para revogar usuario, VPN peer e senha.
