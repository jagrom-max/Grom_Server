#!/bin/bash
# =============================================================================
# GROM SERVER - Provisiona usuario restrito de replica no CT112
# Executar DENTRO do container CT112 (grom-backup)
# =============================================================================

set -euo pipefail

log() { echo "[OK] $*"; }
fail() { echo "[FALHA] $*"; exit 1; }

usage() {
    cat <<'EOF'
Uso:
  setup-replica-user.sh --public-key-file=/tmp/grom-ha-back.pub [--user=grom-replica] [--source-path=/mnt/backup] [--source-ip=10.0.1.20]

Descricao:
  Cria um usuario dedicado de replica somente leitura para a segunda maquina,
  publica a chave SSH e restringe o acesso ao IP e ao caminho de backup.
EOF
}

[ "$(id -u)" -eq 0 ] || fail "Execute como root no CT112"

REPLICA_USER="grom-replica"
SOURCE_PATH="/mnt/backup"
SOURCE_IP="10.0.1.20"
PUBLIC_KEY_FILE=""

for arg in "$@"; do
    case "$arg" in
        --public-key-file=*) PUBLIC_KEY_FILE="${arg#--public-key-file=}" ;;
        --user=*) REPLICA_USER="${arg#--user=}" ;;
        --source-path=*) SOURCE_PATH="${arg#--source-path=}" ;;
        --source-ip=*) SOURCE_IP="${arg#--source-ip=}" ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            fail "Argumento desconhecido: $arg"
            ;;
    esac
done

[ -n "$PUBLIC_KEY_FILE" ] || fail "Informe --public-key-file=/caminho/chave.pub"
[ -f "$PUBLIC_KEY_FILE" ] || fail "Chave publica nao encontrada: $PUBLIC_KEY_FILE"
[ -d "$SOURCE_PATH" ] || fail "Diretorio de origem nao encontrado: $SOURCE_PATH"

if ! id "$REPLICA_USER" >/dev/null 2>&1; then
    adduser --disabled-password --gecos "" "$REPLICA_USER"
    log "Usuario criado: $REPLICA_USER"
else
    log "Usuario ja existe: $REPLICA_USER"
fi

install -d -m 700 -o "$REPLICA_USER" -g "$REPLICA_USER" "/home/${REPLICA_USER}/.ssh"
touch "/home/${REPLICA_USER}/.ssh/authorized_keys"
chown "$REPLICA_USER:$REPLICA_USER" "/home/${REPLICA_USER}/.ssh/authorized_keys"
chmod 600 "/home/${REPLICA_USER}/.ssh/authorized_keys"

if command -v setfacl >/dev/null 2>&1; then
    setfacl -R -m "u:${REPLICA_USER}:rx" "$SOURCE_PATH"
    setfacl -R -d -m "u:${REPLICA_USER}:rx" "$SOURCE_PATH"
    log "ACL aplicada em ${SOURCE_PATH} para ${REPLICA_USER}"
else
    fail "setfacl nao encontrado. Instale o pacote acl ou ajuste permissoes manualmente."
fi

PUBKEY_CONTENT="$(cat "$PUBLIC_KEY_FILE")"
AUTH_LINE="from=\"${SOURCE_IP}\",no-agent-forwarding,no-port-forwarding,no-pty,no-user-rc,no-X11-forwarding ${PUBKEY_CONTENT}"

if ! grep -Fq "$PUBKEY_CONTENT" "/home/${REPLICA_USER}/.ssh/authorized_keys"; then
    printf '%s\n' "$AUTH_LINE" >> "/home/${REPLICA_USER}/.ssh/authorized_keys"
    log "Chave publicada para ${REPLICA_USER}"
else
    log "Chave ja estava publicada para ${REPLICA_USER}"
fi

log "Provisionamento do usuario de replica concluido"
log "Usuario: ${REPLICA_USER}"
log "IP permitido: ${SOURCE_IP}"
log "Caminho permitido: ${SOURCE_PATH}"
