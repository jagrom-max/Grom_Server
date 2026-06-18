# Arquitetura segura e compromisso LGPD

Este projeto hospedara sistemas com dados pessoais e possivelmente dados pessoais sensiveis ou de alto impacto operacional, incluindo boletins de ocorrencia, dados de terceiros, documentos e estatisticas. Por isso, a decisao padrao do Grom Server e: expor o minimo possivel, registrar o necessario, criptografar backups e manter administracao acessivel apenas por VPN.

O principio economico do projeto e baixo custo com seguranca preservada: usar o hardware disponivel sempre que ele atender aos requisitos, e comprar apenas quando houver reducao clara de risco, ganho de confiabilidade ou necessidade comprovada. Ver `docs/15-PRINCIPIOS-BAIXO-CUSTO.md`.

## Decisoes obrigatorias

1. Apenas `grom.seg.br` deve ser a entrada publica principal da aplicacao. `web.grom.seg.br` e `docs.grom.seg.br` podem existir apenas durante transicao controlada.
2. Proxmox, OPNsense, Netdata, Uptime Kuma, MySQL, SSH e paineis administrativos ficam acessiveis somente pela LAN segura ou pela VPN WireGuard.
3. `monitor.grom.seg.br` nao deve existir como servico publico. Se for criado no DNS, deve apontar apenas para uso interno ou ser bloqueado no firewall.
4. O acesso remoto administrativo deve passar por WireGuard com chaves individuais por pessoa/dispositivo, preshared key e revogacao imediata em caso de perda.
5. O MySQL deve aceitar conexoes apenas dos hosts autorizados e exigir TLS (`require_secure_transport = ON`).
6. Backups devem usar BorgBackup com criptografia e chaves guardadas fora do servidor.
7. Nenhuma senha, chave, dump, arquivo `.env`, certificado privado ou base de dados deve entrar no reposititorio.
8. Atualizacoes automaticas ficam restritas a seguranca; atualizacoes maiores exigem janela de manutencao e backup antes.
9. Logs devem existir para auditoria, mas sem registrar conteudo de documentos, senhas, tokens, CPF completo ou dados sensiveis desnecessarios.
10. Todo restore deve ser testado no minimo trimestralmente.

## Exposicao publica recomendada

| Servico | Externo | Caminho |
|---|---:|---|
| Grom.Seg | Sim | HTTPS 443 para `10.0.1.10` |
| Grom_web/Grom Documental legados | Temporario | HTTPS 443 para `10.0.1.10`, somente durante migracao |
| WireGuard | Sim | UDP 51820 para `10.0.1.14` |
| Proxmox | Nao | VPN/LAN apenas |
| OPNsense WebGUI | Nao | VPN/LAN apenas |
| MySQL | Nao | Rede interna apenas |
| Netdata/Uptime Kuma | Nao | VPN/LAN apenas |
| SSH | Nao | VPN/LAN apenas |

## LGPD na pratica

- Base legal e finalidade: documentar quais sistemas tratam quais dados, por qual finalidade e quem pode acessar.
- Minimizacao: coletar e armazenar somente o necessario para a atividade.
- Segregacao de acesso: perfis por funcao; conta nominal; proibido usuario compartilhado.
- Rastreabilidade: logs de login, falhas, alteracoes relevantes, exportacoes e acessos administrativos.
- Retencao: definir prazo de guarda por tipo de documento e rotina de descarte seguro.
- Criptografia: HTTPS externo, TLS no banco, backups Borg criptografados e HD externo protegido fisicamente.
- Incidentes: manter runbook com responsaveis, evidencias a preservar, acao de contencao e comunicacao.
- Revisao periodica: auditoria mensal de usuarios, VPN peers, regras de firewall, logs criticos e backups.

## Rede atual aprovada

Com o equipamento disponivel hoje, a arquitetura aprovada e:

```text
Internet/ONT
  -> Mini PC porta onboard (WAN)
  -> OPNsense no Proxmox
  -> Mini PC adaptador Ugreen USB 2.5G (LAN)
  -> Switch TP-Link TL-SG108 nao gerenciavel
  -> Rede interna restrita 10.0.1.0/24
  -> VPN 10.0.10.0/24
```

Esta fase ja separa fisicamente WAN e LAN. A ausencia de VLAN no switch atual nao impede a implantacao inicial, desde que a LAN do servidor seja tratada como zona restrita e receba apenas equipamentos confiaveis.

## Rede futura com VLAN

Quando houver switch gerenciavel, separar em VLANs:

| VLAN | Rede | Uso |
|---|---|---|
| 10 | 10.0.1.0/24 | Servidores |
| 20 | 10.0.2.0/24 | Administracao local |
| 30 | 10.0.3.0/24 | Visitantes/isolados, se existir |
| 40 | 10.0.10.0/24 | VPN |

Com o switch atual nao gerenciavel, a separacao por VLAN fisica nao existe. A compensacao e manter poucos dispositivos cabeados nessa rede, evitar rede de visitantes nesse switch e tratar a LAN do servidor como zona restrita.

## Compras prioritarias

1. Nobreak senoidal ou line-interactive de boa qualidade, minimo 600VA, ideal 1000VA, com USB para desligamento ordenado.
2. Segundo HD externo de 2TB ou maior para rotacao de backup offline.
3. Switch gerenciavel 8 portas com VLAN, substituindo o TL-SG108 comum quando a rede definitiva for instalada.
4. Opcional: SSD externo ou NAS simples para copia local adicional, sem substituir o HD offline.
5. Opcional futuro: mini appliance dedicado para firewall, se a disponibilidade passar a ser critica.

## Cloudflare e dominio

Cloudflare pode ser usado para DNS, WAF e protecao basica. Para dados policiais, avaliar cuidadosamente o uso de proxy laranja, pois ele termina TLS na Cloudflare. Se a politica exigir que terceiros nao terminem conexoes, usar Cloudflare apenas como DNS ou usar VPN para acessos sensiveis.

## Padrao operacional

- Mudancas passam por commit no repositorio.
- A comunicacao externa oficial usa `grom.servidor@gmail.com`, conforme `docs/30-COMUNICACAO-OFICIAL.md`.
- Antes de aplicar em producao: backup, janela de manutencao, plano de rollback.
- Depois de aplicar: teste de login, teste de upload/consulta, teste de backup, leitura dos logs.
- Qualquer novo servico nasce privado por padrao e so vira publico mediante justificativa.
