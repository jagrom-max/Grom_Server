# Cameras, DVR e video analitico

Este documento define a organizacao inicial das cameras e do DVR dentro da estrutura `Home Assistant OS` + `Grom_Security`.

O principio e simples: o DVR continua sendo o concentrador de cameras analogicas/HD, enquanto o `Grom_Security` faz leitura controlada dos streams para eventos, OCR, alertas e evidencias tecnicas. O servidor nao deve substituir o DVR como gravador continuo nesta fase.

## Matriz de integracao

| Equipamento | Integracao ideal | Papel operacional |
|---|---|---|
| DVR Intelbras iMHDX 3008 | Stream RTSP/ONVIF para o Grom_Security | Concentrador dos canais VHD e fonte principal de streams |
| VHD 5240 / 3240 | Ligadas ao DVR; servidor le os canais pelo DVR | Cameras principais ligadas ao gravador |
| VIGI C330I | Direto no servidor por RTSP/ONVIF; opcionalmente tambem no DVR | Camera IP com melhor potencial para analise direta |
| IM7 | Direto no servidor por RTSP/ONVIF | Camera de contexto e confirmacao visual |
| Cameras internas garagem | DVR ou IP direto, conforme modelo | Presenca de veiculo, lista branca e eventos de acesso |

## Fluxo recomendado

```text
Cameras VHD -> DVR Intelbras -> RTSP/ONVIF -> Grom_Security
Cameras IP -> RTSP/ONVIF -> Grom_Security
Grom_Security -> MQTT/eventos/API -> Home Assistant e Grom.Seg
Grom_Security -> monitor TV -> mosaico + overlay + mapa operacional
```

O `Home Assistant` deve consumir estados, alertas e automacoes. O `Grom_Security` deve consumir video, executar analise e registrar eventos.

## Regras de seguranca

- DVR e cameras ficam sem acesso direto pela internet.
- Acesso administrativo ao DVR/cameras somente pela LAN administrativa ou VPN.
- Streams RTSP/ONVIF devem ser liberados apenas do DVR/cameras para a VM `10.0.1.30`.
- Usar usuario exclusivo de leitura para RTSP/ONVIF sempre que o equipamento permitir.
- Nao reutilizar senha administrativa do DVR no `Grom_Security`.
- Nao enviar imagens sensiveis em notificacoes externas sem regra especifica.

## Enderecamento sugerido

| Tipo | Faixa sugerida | Observacao |
|---|---|---|
| DVR | `10.0.1.40` | IP fixo ou reserva DHCP |
| Cameras IP | `10.0.1.41-10.0.1.59` | IP fixo/reserva por MAC |
| Home Assistant | `10.0.1.20` | VM120 |
| Grom_Security | `10.0.1.30` | VM130 |

Quando houver switch gerenciavel/VLAN, mover cameras e DVR para VLAN propria. Ate la, isolar por firewall, senhas fortes e acesso restrito.

## RTSP/ONVIF

Antes da ativacao em producao, registrar para cada camera:

| Campo | Exemplo |
|---|---|
| Nome logico | `garagem_entrada` |
| Origem | DVR canal 1, camera IP direta, etc. |
| IP origem | `10.0.1.40` |
| Protocolo | RTSP/ONVIF |
| Stream principal | alta resolucao, usado sob demanda |
| Substream | baixa resolucao, usado para deteccao |
| Zona | garagem, entrada, patio, contexto |
| Funcao | presenca, placa, contexto, evidencia |

Preferir substream de baixa resolucao para analise continua. Usar stream principal somente para snapshot, confirmacao ou video curto de evento.

## Monitor principal

O monitor em TV deve operar como tela passiva de situacao:

- mosaico permanente das cameras principais;
- destaque visual da camera/zona quando houver alerta;
- overlay temporario com evento, severidade, camera e zona;
- mapa operacional da residencia com local destacado;
- sem acesso publico e sem credenciais RTSP no navegador.

A exibicao real dos streams deve usar uma camada propria para navegador, como Frigate/go2rtc/WebRTC ou HLS local. O navegador da TV nao deve receber URL RTSP com usuario/senha. O endpoint `/monitor` do `Grom_Security` fica como tela operacional; `/monitor/state` fornece o estado protegido por token.

## Analise com OpenVINO

Para o Beelink i5-1035G7, a recomendacao passa a ser usar OpenVINO com a GPU integrada Intel para deteccao no Frigate ou em modulo proprio.

Ordem de preferencia:

| Opcao | Uso |
|---|---|
| OpenVINO GPU | Preferencial para deteccao de objetos |
| OpenVINO CPU | Fallback se passthrough da iGPU nao estiver estavel |
| Coral USB/M.2 | Compra futura, apenas se OpenVINO nao atender |

Modelo de configuracao:

```text
configs/grom-security/frigate.openvino.example.yml
```

Mesmo usando GPU, manter deteccao conservadora: substream, FPS baixo, zonas bem definidas e cameras ativadas gradualmente.

## Criterio por tipo de camera

| Tipo | Uso recomendado no Grom_Security |
|---|---|
| Canal do DVR | Deteccao leve, snapshots e clipes curtos |
| VIGI C330I | Analise direta, melhor candidata para OCR/presenca |
| IM7 | Contexto, confirmacao visual e automacoes simples |
| Garagem interna | Presenca de veiculo, lista branca, ausencia prolongada |

## Regras de alerta

O monitoramento deve evoluir para um motor de regras capaz de gerar alertas de comportamento suspeito, nao apenas visualizacao de imagens.

Referencia:

```text
docs/29-GROM-SECURITY-REGRAS.md
configs/grom-security/security-rules.example.yml
```

Regras iniciais:

| Regra | Evento |
|---|---|
| Rua | Veiculo passar 3 vezes em 20 minutos |
| Pedestre | Pessoa diante do imovel por mais de 90 segundos |
| Corredor lateral | Pessoa entre 22h e 6h |
| Fundos | Movimento/pessoa em modo armado |
| Garagem | Veiculo nao cadastrado |
| Sensor + camera | Sensor abre e camera confirma pessoa |
| Sabotagem | Camera critica offline ou obstruida |

## Retencao

## Politica de gravacao e guarda

| Tipo de gravacao | Local |
|---|---|
| Gravacao continua | DVR Intelbras |
| Eventos relevantes | Grom_Security |
| Snapshots de alerta | Grom_Security + backup |
| Videos curtos de intrusao | Grom_Security |
| Evidencias importantes | Backup externo criptografado |

Essa divisao evita sobrecarregar o SSD do servidor, reduz o volume de dados pessoais tratados pelo `Grom_Security` e preserva o DVR como camada propria de gravacao local.

Se houver segundo HD externo de 1 TB, usar prioritariamente para copia B/offline e evidencias importantes. Ele nao deve virar destino de gravacao continua, pois isso reduz vida util, aumenta exposicao de dados e consome espaco rapidamente.

| Conteudo | Retencao inicial |
|---|---:|
| Cache temporario de deteccao | 24-72h |
| Snapshot de evento comum | 7-15 dias |
| Video curto de evento comum | 3-7 dias |
| Evento marcado como relevante | Conforme politica do Grom.Seg |

Gravacao continua no servidor nao e recomendada nesta fase. O DVR deve continuar responsavel por gravacao local propria.

## Lista branca de veiculos

A lista branca deve ficar no `Grom.Seg` ou banco de eventos do `Grom_Security`, com sincronizacao controlada. Dados minimos:

| Campo | Observacao |
|---|---|
| Placa | Dado pessoal; proteger por perfil de acesso |
| Categoria | Morador, autorizado, servico, bloqueado |
| Validade | Prazo de autorizacao |
| Observacao | Evitar dados excessivos |
| Auditoria | Quem cadastrou, alterou e consultou |

Eventos de OCR devem registrar confianca da leitura, imagem associada, camera, horario e decisao do motor de regras.

## Inventario

Modelo inicial no repositorio:

```text
configs/grom-security/cameras.inventory.example.yml
```

Esse arquivo e exemplo. O inventario real deve ficar fora do repositorio publico quando contiver URLs, usuarios, senhas, placas, locais sensiveis ou IPs definitivos.
