# Transicao para Grom.Seg

O projeto passa a considerar `Grom.Seg` como sistema principal e unificado. Os nomes `Grom_web`, `Grom Documental` e `Grom_OCR` devem ser tratados como modulos legados ou componentes internos durante a migracao gradual.

## Decisao arquitetural

Centralizar funcionalidades em um unico sistema:

```text
Grom.Seg
  - gestao operacional
  - gestao documental
  - OCR
  - consultas
  - estatisticas
  - administracao
  - auditoria
```

Beneficios:
- Menos dispersao de dados.
- Menos superficies administrativas.
- Auditoria mais simples.
- Menos subdominios publicos.
- Backup e restore mais objetivos.
- Controle de acesso unificado.
- Melhor experiencia para usuarios.

## Entrada publica preferencial

| Nome | Status | Uso |
|---|---|---|
| `grom.seg.br` | Principal | `Grom.Seg` unificado |
| `web.grom.seg.br` | Legado/transicao | Compatibilidade com antigo Grom_web |
| `docs.grom.seg.br` | Legado/transicao | Compatibilidade com antigo Grom Documental |
| `vpn.grom.seg.br` | Mantido | WireGuard |

Novas funcionalidades devem nascer em `grom.seg.br`, nao em novos subdominios.

## Banco de dados

O banco principal passa a ser:

```text
grom_seg
```

Usuario principal:

```text
grom_seg_user@10.0.1.10
```

Bancos legados mantidos durante migracao:

```text
grom_web
grom_documental
```

Regra: nao migrar dados sensiveis sem backup e plano de rollback.

## Estrutura de aplicacao

Diretorio principal no repositorio:

```text
apps/grom-seg/
```

Diretorio esperado no servidor:

```text
/var/www/grom.seg.br/
```

Diretorios legados podem existir enquanto houver dependencia:

```text
/var/www/web.grom.seg.br/
/var/www/docs.grom.seg.br/
```

## Estrategia de migracao

1. Publicar `Grom.Seg` como entrada principal.
2. Manter `web.grom.seg.br` e `docs.grom.seg.br` funcionando para compatibilidade.
3. Migrar funcionalidades uma por uma para rotas do `Grom.Seg`.
4. Consolidar autenticacao e perfis.
5. Consolidar logs de auditoria.
6. Migrar dados para `grom_seg` com scripts testados.
7. Testar backup e restore.
8. Desativar subdominios legados somente quando nao houver dependencia.

## Rotas sugeridas

| Funcao | Rota sugerida |
|---|---|
| Painel | `/` |
| Login | `/login` |
| Administracao | `/admin` |
| Documentos | `/documentos` |
| OCR | `/ocr` |
| Estatisticas | `/estatisticas` |
| Auditoria | `/auditoria` |
| API | `/api` |

## LGPD e seguranca

A unificacao nao deve reduzir controles. O minimo esperado:
- usuarios nominais;
- perfis por necessidade;
- logs de acesso e operacoes relevantes;
- trilha para exportacoes e alteracoes administrativas;
- segregacao logica de permissoes;
- backup criptografado;
- restore testado antes de dados reais;
- nenhuma area administrativa publica sem VPN/autenticacao forte.

## Criterio de conclusao

A transicao para `Grom.Seg` estara concluida quando:
- `grom.seg.br` for a unica entrada publica de aplicacao;
- `web.grom.seg.br` e `docs.grom.seg.br` puderem ser removidos ou redirecionados;
- banco `grom_seg` concentrar os dados ativos;
- backup/restore contemplar o sistema unificado;
- auditoria e perfis estiverem consolidados.
