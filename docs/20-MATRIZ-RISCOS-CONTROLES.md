# Matriz de riscos e controles

Esta matriz e o compromisso pratico do Grom Server com seguranca, LGPD, robustez e baixa manutencao. Ela deve ser revisada antes da implantacao e depois mensalmente nos primeiros tres meses.

## Escala

| Nivel | Significado |
|---|---|
| Baixo | Impacto limitado e recuperacao simples |
| Medio | Pode afetar disponibilidade, confidencialidade ou trabalho operacional |
| Alto | Pode expor dados pessoais, interromper servicos ou gerar incidente relevante |
| Critico | Pode comprometer dados policiais, cadeia de custodia operacional ou continuidade |

## Riscos principais

| Risco | Nivel | Controle atual | Dono | Frequencia |
|---|---|---|---|---|
| Exposicao indevida de painel administrativo | Critico | Proxmox, OPNsense, SSH e monitoramento somente por VPN/LAN | Admin infra | Mensal e a cada mudanca |
| Vazamento de dados pessoais em backup | Critico | Borg/rclone crypt; proibido backup em claro no Drive | Admin infra | Mensal |
| Perda de dados por backup nao testado | Alto | Teste de restore obrigatorio antes de dados reais | Admin infra | Mensal |
| Falha do unico SSD interno | Alto | Backup VM/LXC no HD externo e copia externa criptografada opcional | Admin infra | Semanal |
| Falha do HD externo | Alto | Recomendado segundo HD para rotacao offline | Gestao | Mensal |
| CGNAT impedindo acesso remoto | Medio | Confirmar IP publico; alternativa futura tunnel/VPN reversa controlada | Admin rede | Antes da implantacao |
| Comprometimento de senha Gmail | Alto | 2FA, senha de app, permissao minima, nao usar para dados em claro | Admin conta | Mensal |
| Uso indevido de conta compartilhada | Alto | Usuarios nominais nas aplicacoes e VPN por dispositivo | Gestao sistema | Mensal |
| Dispositivo desconhecido na LAN restrita | Alto | TL-SG108 usado apenas para equipamentos confiaveis | Admin rede | Permanente |
| Falta de VLAN na Fase 1 | Medio | Compensacao por rede fisica restrita; evolucao planejada para switch gerenciavel | Admin rede | Revisao trimestral |
| Ataque de forca bruta HTTP/SSH | Alto | Nginx, Fail2Ban, OPNsense, SSH nao publico | Admin infra | Mensal |
| Aplicacao com falha de autenticacao | Critico | Revisao de app, logs, menor privilegio no banco, HTTPS | Dev responsavel | A cada release |
| Banco exposto indevidamente | Critico | MySQL bind interno, usuarios por app, REQUIRE SSL, firewall | Admin infra | Mensal |
| Logs contendo dados sensiveis | Alto | Politica de log minimo e retencao limitada | Dev/Admin | A cada release |
| Atualizacao quebrando servico | Medio | Backup antes, janela de manutencao, rollback | Admin infra | A cada atualizacao |
| Queda de energia | Alto | Nobreak recomendado; desligamento ordenado futuro via USB | Gestao | Antes da producao |
| Superaquecimento/poeira | Medio | Local ventilado, monitoramento de temperatura | Admin local | Mensal |
| Perda de chaves Borg/rclone | Critico | Guardar chaves e passphrases em cofre offline | Gestao/Admin | A cada mudanca |
| Acesso de ex-colaborador | Alto | Revogar usuario, senha, VPN peer e sessoes | Gestao/Admin | Imediato |
| Dominio/DNS alterado indevidamente | Alto | 2FA no provedor DNS, usuarios restritos | Admin DNS | Mensal |

## Controles minimos por area

### Rede

- OPNsense como unico ponto de passagem entre WAN e LAN.
- Portas publicas limitadas a TCP/80, TCP/443 e UDP/51820 quando necessario.
- Administracao somente por VPN/LAN.
- Switch atual tratado como LAN restrita.
- VLAN futura quando houver rede de usuarios, visitantes, IoT ou equipamentos nao confiaveis.

### Servidores

- Proxmox atualizado e sem painel publico.
- Containers separados por funcao.
- SSH restrito e com chave quando possivel.
- Servicos internos com bind em IP interno.
- Reinicio automatico de servicos essenciais quando apropriado.

### Aplicacoes

- Autenticacao obrigatoria.
- Perfis de acesso por necessidade.
- Sessao com timeout.
- Registro de login, falha de login, alteracoes relevantes, exportacoes e operacoes administrativas.
- Validacao de upload e limite de tamanho.

### Banco de dados

- MySQL nao publico.
- Usuario separado por aplicacao.
- Usuario de backup somente leitura.
- TLS interno exigido.
- Rotina de backup logico a cada 6 horas.

### Backup

- Backup local criptografado.
- Copia em HD externo.
- Copia externa criptografada opcional no Google Drive.
- Teste de restore antes da producao.
- Retencao documentada.
- Segredos fora do repositorio.

### LGPD

- Minimizar coleta e armazenamento.
- Definir base legal e finalidade de cada modulo.
- Manter trilha de auditoria sem expor conteudo sensivel nos logs.
- Definir retencao e descarte.
- Controlar acesso nominal.
- Registrar incidentes e resposta adotada.

## Rotina mensal de auditoria

1. Revisar usuarios ativos das aplicacoes.
2. Revisar peers WireGuard.
3. Revisar regras WAN do OPNsense.
4. Verificar se Proxmox/OPNsense/monitoramento continuam nao publicos.
5. Validar ultimo backup de banco.
6. Executar restore de amostra.
7. Conferir espaco em SSD e HD externo.
8. Conferir alertas recebidos em `grom.servidor@gmail.com`.
9. Revisar logs de falhas de login e eventos administrativos.
10. Registrar pendencias e correcao aplicada.

## Gatilhos de incidente

Tratar como incidente de seguranca:
- Login administrativo desconhecido.
- Porta administrativa exposta na internet.
- Perda ou roubo de dispositivo com VPN.
- Suspeita de vazamento de backup, senha ou chave.
- Alteracao DNS nao reconhecida.
- Upload de arquivo malicioso.
- Falha de integridade no banco ou nos documentos.

## Primeiras acoes em incidente

1. Isolar exposicao publica removendo port forwards desnecessarios.
2. Revogar VPN peers suspeitos.
3. Trocar senhas afetadas.
4. Preservar logs.
5. Criar backup forense se houver risco de perda de evidencia.
6. Avaliar impacto LGPD e necessidade de comunicacao formal.
7. Registrar linha do tempo, causa provavel, contencao e medidas corretivas.

## Pendencias estrategicas

| Item | Prioridade | Motivo |
|---|---|---|
| Nobreak 600VA/1000VA | Alta | Reduz corrupcao de dados e indisponibilidade |
| Segundo HD externo 2TB+ | Alta | Permite rotacao offline e reduz risco de perda |
| Switch gerenciavel com VLAN | Media | Aumenta segregacao quando houver rede definitiva |
| Teste de restore trimestral documentado | Alta | Confirma recuperabilidade real |
| Inventario de usuarios e dispositivos | Alta | Facilita revogacao e auditoria |
