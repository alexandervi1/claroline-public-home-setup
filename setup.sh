#!/usr/bin/env bash
# =============================================================================
# Claroline Connect v15 — Setup de página de inicio pública con workspaces
# =============================================================================
# Uso:
#   chmod +x setup.sh
#   ./setup.sh --host 192.168.1.10 --ssh-user avpro2029 --ssh-pass nuevo2029 \
#              --db-user claroline_user --db-pass "Nuevo2029*" --db-name claroline_db \
#              --domain claroline.miempresa.com
# =============================================================================

set -euo pipefail

HOST=""
SSH_USER=""
SSH_PASS=""
DB_USER="claroline_user"
DB_PASS=""
DB_NAME="claroline_db"
DB_HOST="localhost"
DOMAIN=""
CLAROLINE_PATH="/var/www/claroline"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --host)       HOST="$2";           shift 2 ;;
        --ssh-user)   SSH_USER="$2";       shift 2 ;;
        --ssh-pass)   SSH_PASS="$2";       shift 2 ;;
        --db-user)    DB_USER="$2";        shift 2 ;;
        --db-pass)    DB_PASS="$2";        shift 2 ;;
        --db-name)    DB_NAME="$2";        shift 2 ;;
        --db-host)    DB_HOST="$2";        shift 2 ;;
        --domain)     DOMAIN="$2";         shift 2 ;;
        --path)       CLAROLINE_PATH="$2"; shift 2 ;;
        *) echo "Parametro desconocido: $1"; exit 1 ;;
    esac
done

for var in HOST SSH_USER SSH_PASS DB_USER DB_PASS DB_NAME DOMAIN; do
    if [[ -z "${!var}" ]]; then
        echo "ERROR: --$(echo $var | tr '[:upper:]' '[:lower:]' | tr '_' '-') es requerido"
        exit 1
    fi
done

echo "============================================="
echo "  Claroline Connect — Public Home Setup"
echo "============================================="
echo "  Servidor : $HOST"
echo "  Dominio  : $DOMAIN"
echo "  DB       : $DB_NAME @ $DB_HOST"
echo "  Ruta     : $CLAROLINE_PATH"
echo "============================================="
echo ""

if ! command -v sshpass &>/dev/null; then
    echo "ERROR: instala sshpass primero"
    echo "  Ubuntu/Debian : apt install sshpass"
    echo "  macOS         : brew install hudochenkov/sshpass/sshpass"
    exit 1
fi

ssh_cmd() {
    sshpass -p "$SSH_PASS" ssh -o StrictHostKeyChecking=no "$SSH_USER@$HOST" "$@"
}

# ---------- Paso 1: Parche de platform_options.json ----------
echo "[1/4] Parcheando platform_options.json (home.type = tool)..."
PLATFORM_JSON="$CLAROLINE_PATH/files/config/platform_options.json"

ssh_cmd bash -s <<ENDSSH
set -e
SUDO="echo $SSH_PASS | sudo -S"
CURRENT=\$(\$SUDO cat $PLATFORM_JSON 2>/dev/null)
echo "\$CURRENT" | python3 -c "
import sys, json
d = json.load(sys.stdin)
d['home'] = {'type': 'tool', 'data': None}
print(json.dumps(d, ensure_ascii=False, indent=4))
" > /tmp/platform_options_patched.json
\$SUDO cp /tmp/platform_options_patched.json $PLATFORM_JSON
\$SUDO chown www-data:www-data $PLATFORM_JSON
echo "  OK: home.type = tool"
ENDSSH

# ---------- Paso 2: Insertar registros en la base de datos ----------
echo "[2/4] Configurando base de datos..."
sshpass -p "$SSH_PASS" scp -o StrictHostKeyChecking=no \
    "$(dirname "$0")/sql/01_public_home_setup.sql" \
    "$SSH_USER@$HOST:/tmp/claroline_public_home.sql"

ssh_cmd bash -c "mysql -u '$DB_USER' -p'$DB_PASS' -h '$DB_HOST' '$DB_NAME' < /tmp/claroline_public_home.sql 2>/dev/null"
echo "  OK: registros insertados"

# ---------- Paso 3: Limpiar caché de Symfony ----------
echo "[3/4] Limpiando cache de Symfony..."
ssh_cmd bash -s <<ENDSSH
set -e
SUDO="echo $SSH_PASS | sudo -S"
cd $CLAROLINE_PATH
\$SUDO -u www-data php bin/console cache:clear --no-warmup --no-debug -q 2>/dev/null
\$SUDO -u www-data php bin/console cache:warmup --no-debug -q 2>/dev/null
echo "  OK: cache regenerada"
ENDSSH

# ---------- Verificación final ----------
echo "[4/4] Verificando..."
echo ""

HOME_STATUS=$(ssh_cmd curl -s -o /dev/null -w '%{http_code}' \
    -H "Host: $DOMAIN" http://localhost/tool/open/home/public)

WS_RESULT=$(ssh_cmd curl -s -H "Host: $DOMAIN" http://localhost/data_source/workspaces/public | \
    python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('totalResults',0))" 2>/dev/null || echo "?")

echo "  /tool/open/home/public   -> HTTP $HOME_STATUS"
echo "  /data_source/workspaces  -> $WS_RESULT workspace(s) publicos"

if [[ "$HOME_STATUS" == "200" ]]; then
    echo ""
    echo "  LISTO. Visita https://$DOMAIN/ como usuario anonimo."
    echo "  Deben aparecer los workspaces publicos en la pagina de inicio."
else
    echo ""
    echo "  ADVERTENCIA: endpoint retorno HTTP $HOME_STATUS"
    echo "  Revisa: tail -100 /var/log/nginx/error.log"
fi
echo "============================================="
