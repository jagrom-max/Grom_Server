# Motor de regras do Grom_Security

Este documento define as primeiras regras operacionais para transformar cameras, sensores e lista branca em alertas acionaveis.

O objetivo nao e apenas monitorar imagens. O `Grom_Security` deve correlacionar eventos e avisar possiveis acoes suspeitas com nivel de severidade, snapshot, video curto e trilha de auditoria.

## Entradas do motor

| Entrada | Origem |
|---|---|
| Pessoa detectada | Frigate/OpenVINO, OpenCV ou modulo proprio |
| Veiculo detectado | Frigate/OpenVINO, OpenCV ou modulo proprio |
| Placa/OCR | Modulo OCR de placas |
| Sensor de abertura | Home Assistant/MQTT |
| Estado do alarme | Home Assistant Alarm Panel |
| Lista branca de veiculos | Grom.Seg ou banco de eventos do Grom_Security |
| Status da camera | RTSP/ONVIF/Frigate healthcheck |

## Niveis de alerta

| Nivel | Uso |
|---|---|
| Baixo | Registro operacional, sem urgencia |
| Medio | Situacao suspeita que exige ciencia |
| Alto | Possivel violacao ou acesso nao autorizado |
| Critico | Intrusao provavel, acao imediata |
| Tecnico | Falha, perda de sinal, obstrucao ou sabotagem |

## Regras iniciais

| Regra | Condicao | Severidade | Acao |
|---|---|---|---|
| REGRA 1 - Rua | Veiculo passar 3 vezes em 20 minutos | Medio | Registrar recorrencia e enviar alerta |
| REGRA 2 - Pedestre | Pessoa permanecer diante do imovel por mais de 90 segundos | Medio | Enviar alerta com imagem |
| REGRA 3 - Corredor lateral | Pessoa no corredor lateral entre 22h e 6h | Critico | Alerta critico + sirene/luz se configurado |
| REGRA 4 - Fundos | Movimento/pessoa no quintal dos fundos em modo armado | Critico | Alerta critico |
| REGRA 5 - Garagem | Veiculo nao cadastrado dentro da garagem | Alto | Alerta alto |
| REGRA 6 - Sensor + camera | Sensor de abertura dispara e camera confirma pessoa | Critico | Alerta critico |
| REGRA 7 - Sabotagem | Camera critica perde sinal ou e obstruida | Tecnico/Critico | Alerta tecnico, escalar se alarme armado |

## Arquivo de configuracao

Modelo inicial:

```text
configs/grom-security/security-rules.example.yml
```

O arquivo real deve ficar fora do repositorio publico quando houver nomes de cameras definitivos, placas, locais sensiveis, usuarios ou contatos de notificacao.

## Painel editavel

O painel interno do `Grom_Security` deve permitir edicao gradual e segura das regras.

Primeira fase implementada:

- alterar modo do alarme: Desarmado, Presente, Noturno, Ausente e Perimetral;
- listar regras;
- ativar/desativar regra;
- alterar severidade;
- consultar eventos recentes.
- simular eventos para testar comportamento das regras;
- consultar auditoria de alteracoes.

Edicao completa de condicoes, janelas de tempo, zonas, acoes e mensagens deve ser liberada apenas apos validacao forte, backup automatico do YAML e teste contra eventos simulados.

Toda alteracao operacional deve gerar trilha de auditoria com valor anterior, valor posterior, horario e origem da requisicao.

## Modos do alarme

| Modo | Aplicacao pratica |
|---|---|
| Desarmado (`disarmed`) | Uso normal, sem alarmes de intrusao; manter eventos e falhas tecnicas |
| Presente (`present`) | Pessoas no local; reduzir alertas internos e manter perimetro sensivel |
| Noturno (`night`) | Ocupado durante a noite; elevar corredor lateral, fundos e portas |
| Ausente (`away`) | Imovel vazio; regras de intrusao em severidade alta/critica |
| Perimetral (`perimeter`) | Uso interno liberado, perimetro externo armado |

Tablet fixo deve operar apenas na rede interna isolada. Celular deve operar somente por VPN, nunca por exposicao publica direta do painel/API.

## Acionamentos

| Acao | Regra |
|---|---|
| `register_event` | Sempre registrar no banco de eventos |
| `create_snapshot` | Gerar imagem associada ao evento |
| `create_short_clip` | Gerar video curto quando houver intrusao ou confirmacao |
| `send_alert` | Notificar painel/Telegram conforme severidade |
| `send_critical_alert` | Notificacao prioritaria |
| `trigger_siren_light_if_configured` | Acionar sirene/luz apenas se configurado e permitido |
| `escalate_if_alarm_armed` | Elevar severidade quando o sistema estiver armado |

## LGPD e prova digital

- Enviar para Telegram apenas o minimo necessario.
- Preferir imagem reduzida ou mascarada em alerta externo.
- Exigir perfil autorizado para visualizar placa, rosto ou evidencia completa.
- Registrar quem visualizou, exportou ou marcou evidencia.
- Evitar retencao longa automatica sem marcacao manual ou regra formal.
- Diferenciar alerta operacional de evidencia relevante.

## Notificacoes externas

Os alertas devem poder sair por Telegram, WhatsApp, SMS e e-mail conforme criticidade e viabilidade tecnica.

Diretrizes:

- Telegram e e-mail sao os primeiros canais recomendados.
- WhatsApp somente via WhatsApp Business API/provedor formal.
- SMS apenas para contingencia ou alerta critico, por custo e dependencia externa.
- Conteudo externo deve ser minimo: severidade, tipo, zona, camera e ID do evento.
- Imagens, placas, rostos ou evidencias completas devem exigir acesso autenticado no ambiente interno/VPN.
- Toda tentativa de notificacao deve ser registrada em outbox/auditoria.

## Implantacao gradual

1. Ativar somente registro e snapshots.
2. Testar falsos positivos por pelo menos 7 dias.
3. Ativar alertas medios.
4. Ativar alertas criticos sem sirene.
5. Ativar sirene/luz apenas apos validacao presencial.
6. Revisar regras mensalmente.
