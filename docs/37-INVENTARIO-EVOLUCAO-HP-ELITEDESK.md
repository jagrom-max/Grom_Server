# Inventario de evolucao - HP EliteDesk

Data de consolidacao: 2026-07-06

Este inventario registra a mudanca de plataforma do Grom Server e serve como
ponto de retomada antes da implantacao fisica.

## Linha de base anterior

| Item | Planejamento anterior |
|---|---|
| Host | Beelink Mini PC |
| CPU | Intel Core i5-1035G7, 4C/8T |
| RAM | 16 GB DDR4 |
| SSD | 1 TB |
| Home Assistant | VM120 no mesmo host |
| Grom_Security | VM130 com disco de 160 GB |
| Backup | CT112 e HD externo |

Commit-base anterior a esta evolucao:
`3d86338ac3fee072a88f5ac94c338a6e9a99dfed`.

## Plataforma atual aprovada

| Item | Definicao atual |
|---|---|
| Host | HP EliteDesk 800 G4 Mini |
| CPU | Intel Core i7-8700T, 6C/12T |
| RAM | 16 GB DDR4 |
| SSD original | 256 GB, retirar antes da implantacao |
| SSD definitivo | 500 GB |
| Rede adicional | Adaptador Ugreen USB 2.5GbE |
| Backup inicial | Unidade externa USB de 1 TB |
| Video continuo | DVR Intelbras iMHDX 3008 |
| Video analitico | Frigate/OpenVINO na VM130 |
| Home Assistant | Outra maquina, ainda futura |
| Backup definitivo | Outra maquina, ainda futura |

## Distribuicao no HP EliteDesk

| ID | Servico | RAM | vCPU | Disco |
|---|---|---:|---:|---:|
| Host | Proxmox | 2 GB | - | 30 GB |
| VM100 | OPNsense | 2 GB | 2 | 20 GB |
| CT110 | Grom.Seg/Web | 2,5 GB | 3 | 60 GB |
| CT111 | MySQL | 2 GB | 2 | 100 GB |
| CT112 | Orquestracao de backup | 512 MB | 1 | 16 GB |
| CT113 | Monitoramento | 512 MB | 1 | 12 GB |
| CT114 | WireGuard | 384 MB | 1 | 4 GB |
| VM130 | Grom_Security/Frigate | 4 GB | 4 | 100 GB |

Totais planejados:

- aproximadamente 14 GB de RAM, com margem operacional;
- 14 vCPU alocadas com overcommit controlado sobre 6C/12T;
- aproximadamente 342 GB de disco, deixando cerca de 120 GB de margem no
  planejamento nominal.

## Divisao de responsabilidades de video

### DVR Intelbras

- gravacao continua;
- retencao principal das cameras;
- concentracao dos canais analogicos/HD;
- origem RTSP/ONVIF com usuario exclusivo de leitura.

### Frigate/Grom_Security

- deteccao de objetos e eventos;
- snapshots e clips curtos;
- OCR e correlacao de regras;
- MQTT, API e painel operacional;
- OpenVINO na iGPU Intel, depois de validar IOMMU e passthrough.

O SSD interno e a unidade USB de backup nao devem receber gravacao continua
indiscriminada do Frigate.

## Estrategia de backup por fase

### Fase atual

- CT112 coordena Borg, dumps e rotinas de copia;
- unidade USB de 1 TB recebe `vzdump`, backups operacionais e evidencias
  selecionadas;
- restore deve ser testado antes de dados reais;
- copia externa criptografada continua opcional.

### Fase futura

- instalar Home Assistant e o servidor de backup em outra maquina;
- replicar os backups do HP para esse segundo host;
- manter temporariamente a unidade USB como copia adicional;
- validar restore nas duas copias antes de alterar a politica de retencao.

## Evolucoes implementadas no repositorio

- documentacao de hardware, rede, capacidade, backup e instalacao revisada;
- scripts de criacao dos CT110-CT114 redimensionados para o SSD de 500 GB;
- VM130 reduzida de 160 GB para 100 GB;
- criacao local do Home Assistant desativada por padrao;
- validadores deixaram de tratar VM120 como requisito do HP;
- changelog e versao do projeto atualizados para 1.2.0;
- referencias operacionais ao hardware Beelink removidas.

## Validacoes realizadas

- `git diff --check`: sem erros;
- auditoria local: zero falhas;
- sintaxe Bash: aprovada em todos os scripts alterados;
- busca por referencias operacionais antigas: nenhuma ocorrencia;
- aviso conhecido: diretorio residual vazio/bloqueado `Grom_Security`.

## Pendencias antes da implantacao

1. instalar fisicamente o SSD de 500 GB;
2. confirmar BIOS, VT-x, VT-d, Hyper-Threading e boot UEFI;
3. identificar interfaces onboard e Ugreen pelos nomes/MAC reais;
4. montar e testar a unidade USB de 1 TB;
5. regenerar release, checksum e midia de instalacao;
6. executar `final-local-deploy.sh --skip-deploy` no HP;
7. validar passthrough da iGPU antes de ativar OpenVINO GPU;
8. cadastrar o DVR com usuario RTSP/ONVIF somente leitura;
9. testar backup e restore;
10. executar o gate Go/No-Go antes de dados reais.

## Ponto seguro de retomada

Ao continuar o desenvolvimento, iniciar pela regeneracao da release e pelo
checklist fisico do HP EliteDesk. Nao executar o deploy confirmado antes de
concluir o ensaio `--skip-deploy`.
