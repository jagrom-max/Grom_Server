# 🆘 Plano de Recuperação de Desastres

## Cenários de Desastre

| Cenário | Gravidade | RTO* | RPO** |
|---|---|---|---|
| Container corrompido | Baixa | 30 min | 6 horas |
| SSD falha total | Alta | 4 horas | 6 horas |
| Queda de energia prolongada | Média | 15 min | 0 (se UPS) |
| Ataque/Ransomware | Crítica | 4 horas | 6 horas |
| Falha do Mini PC | Crítica | 1-3 dias | 6 horas |

*RTO = Recovery Time Objective (tempo para restaurar)
**RPO = Recovery Point Objective (máximo de dados perdidos)

---

## Procedimento 1: Restaurar Container LXC

```bash
# No Proxmox host
# 1. Listar backups disponíveis
ls /var/lib/vz/dump/

# 2. Restaurar container
pct restore <CTID> /var/lib/vz/dump/vzdump-lxc-<CTID>-<date>.tar.zst

# 3. Iniciar container
pct start <CTID>

# 4. Verificar serviços
pct exec <CTID> -- systemctl status <servico>
```

---

## Procedimento 2: Restaurar Banco de Dados

```bash
# 1. Localizar último dump
ls -la /mnt/backup/databases/

# 2. Restaurar do BorgBackup
borg extract /mnt/backup/databases::latest

# 3. Importar dump
mysql -u root -p grom_web < dump_grom_web.sql
mysql -u root -p grom_documental < dump_grom_documental.sql

# 4. Verificar integridade
mysqlcheck --check --all-databases -u root -p
```

---

## Procedimento 3: Reconstrução Total (SSD falha)

### Pré-requisitos:
- Novo SSD instalado
- ISO Proxmox em pendrive
- HD externo com backups

### Passos:
1. Instalar Proxmox VE (conforme doc 03)
2. Configurar rede (conforme doc 02)
3. Restaurar VM OPNsense do backup
4. Restaurar containers LXC dos backups
5. Restaurar dados do HD externo:
   ```bash
   # Montar HD externo
   mount /dev/sdX1 /mnt/backup-external
   # Restaurar BorgBackup
   borg extract /mnt/backup-external/databases::latest
   borg extract /mnt/backup-external/webfiles::latest
   ```
6. Importar bancos de dados
7. Verificar serviços
8. Testar acesso externo

### Tempo estimado: 4-6 horas

---

## Procedimento 4: Falha do Mini PC

Se o hardware falhar completamente:

1. **Adquirir novo hardware** (mesmo modelo ou superior)
2. Seguir Procedimento 3 (Reconstrução Total)
3. Todo o projeto está documentado neste repositório
4. Scripts automatizam a maior parte da configuração

---

## Contatos de Emergência

| Recurso | Contato/URL |
|---|---|
| ISP (internet) | Número do provedor |
| Proxmox docs | https://pve.proxmox.com/wiki |
| OPNsense docs | https://docs.opnsense.org |
| Status da rede | Uptime Kuma dashboard |

---

## Testes de DR (Disaster Recovery)

**Frequência**: Trimestral

### Teste de Restauração
1. Criar container temporário
2. Restaurar backup mais recente
3. Verificar integridade dos dados
4. Testar aplicações
5. Documentar resultado
6. Destruir container de teste

> ⚠️ **REGRA**: Um backup que nunca foi testado NÃO é um backup confiável.
