#!/bin/bash
# =============================================================================
# GROM SERVER - Build do pacote de release
# Gera dist/grom-scripts.zip ou dist/grom-scripts.tar.gz com manifesto e hashes.
# Nao inclui .git, downloads, dist, segredos locais ou residuos do workspace.
# =============================================================================

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="${ROOT_DIR}/dist"
STAGE_DIR="${DIST_DIR}/grom-scripts"
ZIP_FILE="${DIST_DIR}/grom-scripts.zip"
TAR_FILE="${DIST_DIR}/grom-scripts.tar.gz"
MANIFEST_FILE="${STAGE_DIR}/RELEASE-MANIFEST.txt"

log() { echo "[OK] $1"; }
info() { echo "[INFO] $1"; }
fail() { echo "[FALHA] $1" >&2; exit 1; }

require_cmd() {
    command -v "$1" >/dev/null 2>&1 || fail "Comando obrigatorio ausente: $1"
}

copy_path() {
    local path="$1"

    if [ -e "${ROOT_DIR}/${path}" ]; then
        mkdir -p "$(dirname "${STAGE_DIR}/${path}")"
        cp -a "${ROOT_DIR}/${path}" "${STAGE_DIR}/${path}"
        log "Incluido: ${path}"
    else
        fail "Caminho obrigatorio ausente: ${path}"
    fi
}

assert_safe_stage_path() {
    local resolved_dist
    local resolved_stage_parent

    mkdir -p "$DIST_DIR"
    resolved_dist="$(cd "$DIST_DIR" && pwd -P)"
    resolved_stage_parent="$(cd "$(dirname "$STAGE_DIR")" && pwd -P)"

    [ "$resolved_dist" = "$resolved_stage_parent" ] || fail "Stage fora de dist: ${STAGE_DIR}"
    case "$STAGE_DIR" in
        "$ROOT_DIR"/dist/grom-scripts) ;;
        *) fail "Stage inesperado: ${STAGE_DIR}" ;;
    esac
}

run_audit() {
    local audit_script="${ROOT_DIR}/scripts/proxmox/audit-repository.sh"

    if [ -f "$audit_script" ]; then
        info "Executando auditoria local antes do release..."
        bash "$audit_script" --root="$ROOT_DIR"
    else
        fail "Auditor local ausente: ${audit_script}"
    fi
}

write_manifest() {
    local commit="unknown"
    local branch="unknown"
    local dirty="unknown"
    local version="unreleased"

    if command -v git >/dev/null 2>&1 && git -C "$ROOT_DIR" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        commit="$(git -C "$ROOT_DIR" rev-parse --short HEAD 2>/dev/null || echo unknown)"
        branch="$(git -C "$ROOT_DIR" rev-parse --abbrev-ref HEAD 2>/dev/null || echo unknown)"
        if git -C "$ROOT_DIR" diff --quiet --ignore-submodules -- 2>/dev/null; then
            dirty="no"
        else
            dirty="yes"
        fi
    fi

    version="$(awk '/^## \[/ { gsub(/^## \[/, "", $0); gsub(/\].*$/, "", $0); print; exit }' "${ROOT_DIR}/CHANGELOG.md" 2>/dev/null || echo unreleased)"

    {
        echo "GROM SERVER - Release Manifest"
        echo "Build date: $(date -Is)"
        echo "Version: ${version}"
        echo "Git branch: ${branch}"
        echo "Git commit: ${commit}"
        echo "Working tree dirty: ${dirty}"
        echo ""
        echo "Conteudo:"
        find "$STAGE_DIR" -type f ! -name 'RELEASE-MANIFEST.txt' -print | sed "s#^${STAGE_DIR}/##" | sort
        echo ""
        echo "SHA256:"
        find "$STAGE_DIR" -type f ! -name 'RELEASE-MANIFEST.txt' -print0 \
            | sort -z \
            | while IFS= read -r -d '' file; do
                local_hash="$(sha256sum "$file" | awk '{print $1}')"
                local_path="${file#"$STAGE_DIR"/}"
                printf '%s  %s\n' "$local_hash" "$local_path"
            done
    } > "$MANIFEST_FILE"

    log "Manifesto gerado: ${MANIFEST_FILE#"$ROOT_DIR"/}"
}

build_archive() {
    rm -f "$ZIP_FILE" "$TAR_FILE" "${ZIP_FILE}.sha256" "${TAR_FILE}.sha256"

    if command -v zip >/dev/null 2>&1; then
        (cd "$DIST_DIR" && zip -qr "$(basename "$ZIP_FILE")" "$(basename "$STAGE_DIR")")
        (cd "$DIST_DIR" && sha256sum "$(basename "$ZIP_FILE")" > "$(basename "${ZIP_FILE}.sha256")")
        log "Pacote gerado: ${ZIP_FILE#"$ROOT_DIR"/}"
        log "Checksum: ${ZIP_FILE#"$ROOT_DIR"/}.sha256"
        return
    fi

    tar -C "$DIST_DIR" -czf "$TAR_FILE" "$(basename "$STAGE_DIR")"
    (cd "$DIST_DIR" && sha256sum "$(basename "$TAR_FILE")" > "$(basename "${TAR_FILE}.sha256")")
    log "Pacote gerado: ${TAR_FILE#"$ROOT_DIR"/}"
    log "Checksum: ${TAR_FILE#"$ROOT_DIR"/}.sha256"
}

require_cmd bash
require_cmd find
require_cmd sha256sum
require_cmd tar

assert_safe_stage_path
run_audit

info "Preparando staging limpo..."
rm -rf "$STAGE_DIR"
mkdir -p "$STAGE_DIR"

copy_path "README.md"
copy_path "CHANGELOG.md"
copy_path ".gitattributes"
copy_path ".gitignore"
copy_path "scripts"
copy_path "configs"
copy_path "docs"
copy_path "apps"
copy_path "assets"

find "$STAGE_DIR" -type d \( -name '.git' -o -name 'dist' -o -name 'downloads' -o -name '.pytest_cache' -o -name '.venv' \) -prune -exec rm -rf {} +
find "$STAGE_DIR" -type f \( -name '.env' -o -name '.env.*' -o -name '*.pem' -o -name '*.key' -o -name '*.secret' -o -name '*.credentials' -o -name '*.log' \) -delete

write_manifest
build_archive

echo ""
echo "Release pronto em: ${DIST_DIR}"
