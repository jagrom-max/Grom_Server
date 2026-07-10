# DNS do dominio grom.seg.br no Registro.br

O dominio `grom.seg.br` esta registrado no Registro.br/Dominios.br. A configuracao DNS deve ser feita com cautela, porque ela define o que ficara exposto publicamente.

Escopo atual:

- este documento trata apenas de DNS publico do `hp-core` e dos servicos
  publicados pelo `Grom_Server`;
- o `HA_Back` e um host externo de acesso restrito por VPN/LAN e nao deve
  receber DNS publico nesta fase.

## Decisao atual

Entrada publica principal:

```text
grom.seg.br -> Grom.Seg
```

Entradas temporarias durante transicao:

```text
web.grom.seg.br  -> legado Grom_web
docs.grom.seg.br -> legado Grom Documental
```

Entrada de VPN:

```text
vpn.grom.seg.br -> WireGuard
```

Nao criar entrada publica para monitoramento:

```text
monitor.grom.seg.br
```

## Registros planejados

Quando houver IP publico fixo ou dinamico conhecido:

| Nome | Tipo | Valor | Publicar? | Observacao |
|---|---|---|---|---|
| `grom.seg.br` | A | IP publico | Sim | Entrada principal Grom.Seg |
| `web.grom.seg.br` | A | IP publico | Temporario | Legado/transicao |
| `docs.grom.seg.br` | A | IP publico | Temporario | Legado/transicao |
| `vpn.grom.seg.br` | A | IP publico | Sim | WireGuard |
| `monitor.grom.seg.br` | - | - | Nao | Usar apenas VPN/LAN |

Se houver IPv6 publico estavel e firewall corretamente configurado, pode-se usar AAAA. Sem controle claro de firewall IPv6, nao criar AAAA.

## TTL recomendado

Durante implantacao e testes:

```text
300 segundos
```

Depois de estabilizar:

```text
3600 segundos ou mais
```

## IP publico real versus CGNAT

Antes de depender de acesso externo, confirmar se a internet entrega IP publico real.

Sinais de CGNAT:
- IP WAN do roteador diferente do IP visto em sites de "meu IP".
- WAN do roteador em faixas privadas ou compartilhadas, como `10.0.0.0/8`, `172.16.0.0/12`, `192.168.0.0/16` ou `100.64.0.0/10`.
- Port forward configurado, mas portas externas nunca respondem.

Se houver CGNAT:
- pedir IP publico ao provedor;
- avaliar plano com IP fixo;
- adiar exposicao publica;
- usar VPN/tunel reverso somente apos avaliacao de seguranca.

## NAT e firewall

DNS sozinho nao publica servico. Para funcionar, tambem precisa:

1. Roteador/ONT encaminhando portas para o OPNsense.
2. OPNsense encaminhando somente portas aprovadas.
3. CT110 respondendo HTTP/HTTPS.
4. CT114 respondendo WireGuard.

Portas publicas aprovadas:

| Porta | Protocolo | Destino interno | Uso |
|---:|---|---|---|
| 80 | TCP | CT110 `10.0.1.10` | HTTP/Let's Encrypt/redirecionamento |
| 443 | TCP | CT110 `10.0.1.10` | HTTPS Grom.Seg |
| 51820 | UDP | CT114 `10.0.1.14` | WireGuard |

Portas que devem ficar bloqueadas:

| Porta | Uso |
|---:|---|
| 22 | SSH |
| 3306 | MySQL |
| 8006 | Proxmox |
| 19999 | Netdata |
| 3001 | Uptime Kuma |
| 1883 | MQTT |
| 8123 | HA_Back / Home Assistant |
| 5000/8971 | Frigate/painel de video, se usado |

`HA_Back`/Home Assistant e `Grom_Security` nao devem receber registros DNS
publicos nesta fase.

## SSL/TLS

Emitir certificado somente depois de:
- DNS apontar corretamente;
- NAT/OPNsense liberarem HTTP/HTTPS;
- CT110 estar online;
- Nginx estar configurado.

Comando previsto:

```bash
pct exec 110 -- bash /tmp/setup-ssl.sh
```

O script inclui:

```text
grom.seg.br
web.grom.seg.br
docs.grom.seg.br
```

Durante a transicao, os legados podem permanecer. No futuro, quando `Grom.Seg` estiver consolidado, remover ou redirecionar os legados.

## Validacao

Depois de criar DNS e NAT:

```bash
dig grom.seg.br
dig web.grom.seg.br
dig docs.grom.seg.br
dig vpn.grom.seg.br
```

No Proxmox:

```bash
bash /root/grom-scripts/scripts/proxmox/post-deploy-validation.sh --public-target=grom.seg.br
```

De outra internet confiavel, confirmar:

```text
https://grom.seg.br
https://web.grom.seg.br
https://docs.grom.seg.br
```

E confirmar que nao respondem publicamente:

```text
https://grom.seg.br:8006
grom.seg.br:3306
grom.seg.br:19999
grom.seg.br:3001
```

## Politica de mudanca DNS

Toda mudanca DNS deve registrar:
- data;
- responsavel;
- registro alterado;
- valor antigo;
- valor novo;
- motivo;
- teste executado apos alteracao.

Mudancas DNS devem ser evitadas em horario critico, salvo correcao de incidente.
