# Validacao pos-deploy

Este documento define a validacao automatica que deve ser feita depois de executar `deploy-all.sh`. A meta e confirmar que o servidor ficou operacional sem abrir portas indevidas.

## Quando executar

Executar sempre:
- Depois da primeira implantacao.
- Depois de mudancas no OPNsense.
- Depois de mudancas em DNS/NAT.
- Depois de alteracoes em containers, backup, VPN ou monitoramento.
- Antes de liberar uso com dados reais.

## Comando basico

No Proxmox host:

```bash
bash /root/grom-scripts/scripts/proxmox/post-deploy-validation.sh
```

O relatorio padrao fica em:

```text
/var/log/grom-post-deploy-validation.log
```

## Comando com alvo publico

Quando DNS/NAT ja estiverem configurados, testar a exposicao publica:

```bash
bash /root/grom-scripts/scripts/proxmox/post-deploy-validation.sh --public-target=grom.seg.br
```

Tambem pode ser usado o IP publico:

```bash
bash /root/grom-scripts/scripts/proxmox/post-deploy-validation.sh --public-target=SEU_IP_PUBLICO
```

## O que o script verifica

| Area | Verificacao |
|---|---|
| Host | Root, Proxmox, log do deploy, script de backup VM/LXC |
| VM/CT | VM100, CT110-CT114 e VMs opcionais VM120/VM130 quando criadas |
| Servicos | Nginx, PHP-FPM, MySQL, WireGuard e Netdata |
| Rede interna | Web -> MySQL, Backup -> MySQL, Monitor -> Web |
| Backup | Ambiente de backup, cron, diretorios, cron Proxmox |
| Seguranca | Fail2Ban presente nos containers |
| Publico opcional | HTTP/HTTPS abertos, VPN UDP sinalizada e Proxmox/MySQL/Monitor fechados |

## Criterios de aceite

Para liberar uso controlado:
- Zero falhas.
- Avisos compreendidos e aceitos.
- Portas publicas administrativas bloqueadas.
- Backup configurado.
- VPN ativa e testada com cliente externo quando possivel.
- Web e banco comunicando internamente.
- Relatorio salvo.

## Portas esperadas

| Porta | Publica? | Observacao |
|---:|---|---|
| 80/TCP | Sim, se web publico ativo | HTTP e validacao TLS |
| 443/TCP | Sim | HTTPS dos sistemas |
| 51820/UDP | Sim, se VPN ativa | WireGuard |
| 8006/TCP | Nao | Proxmox |
| 3306/TCP | Nao | MySQL |
| 19999/TCP | Nao | Netdata |
| 3001/TCP | Nao | Uptime Kuma |

## Tratamento de falhas

Se houver falha:

1. Nao inserir dados reais.
2. Nao liberar acesso externo adicional.
3. Corrigir a causa no OPNsense, container ou script.
4. Executar novamente a validacao.
5. Registrar a causa no changelog ou runbook, se for falha recorrente.

## Observacao sobre teste externo

O teste com `--public-target` mede a visao a partir do proprio servidor/rede. Em alguns provedores, NAT loopback pode distorcer o resultado. Para validacao final de exposicao publica, repetir a verificacao a partir de outra internet confiavel antes de liberar producao.
