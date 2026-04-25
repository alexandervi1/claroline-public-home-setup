#!/usr/bin/env bash
# =============================================================================
# Claroline Connect v15 — Verificación de página de inicio pública
# =============================================================================
# Uso:
#   chmod +x verify.sh
#   ./verify.sh --host 192.168.1.10 --ssh-user avpro2029 --ssh-pass nuevo2029 \
#               --db-user claroline_user --db-pass "Nuevo2029*" --db-name claroline_db \
#               --domain claroline.tudominio.com
# =============================================================================

set -euo pipefail

HOST=""; SSH_USER=""; SSH_PASS=""; DB_USER="claroline_user"
DB_PASS=""; DB_NAME="claroline_db"; DB_HOST="localhost"; DOMAIN=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --host)      HOST="$2";     shift 2 ;;
        --ssh-user)  SSH_USER="$2"; shift 2 ;;
        --ssh-pass)  SSH_PASS="$2"; shift 2 ;;
        --db-user)   DB_USER="$2";  shift 2 ;;
        --db-pass)   DB_PASS="$2";  shift 2 ;;
        --db-name)   DB_NAME="$2";  shift 2 ;;
        --db-host)   DB_HOST="$2";  shift 2 ;;
        --domain)    DOMAIN="$2";   shift 2 ;;
        *) echo "Parametro desconocido: $1"; exit 1 ;;
    esac
done

ssh_cmd() {
    sshpass -p "$SSH_PASS" ssh -o StrictHostKeyChecking=no "$SSH_USER@$HOST" "$@"
}

PASS=0; FAIL=0

check() {
    local label="$1"; local result="$2"; local expected="$3"
    if [[ "$result" == *"$expected"* ]]; then
        echo "  [OK]   $label"
        ((PASS++)) || true
    else
        echo "  [FAIL] $label"
        echo "         Esperado : $expected"
        echo "         Obtenido : $result"
        ((FAIL++)) || true
    fi
}

echo "============================================="
echo "  Claroline — Verificacion Public Home"
echo "============================================="

# 1. platform_options.json
OPTS=$(ssh_cmd bash -c "echo $SSH_PASS | sudo -S cat /var/www/claroline/files/config/platform_options.json 2>/dev/null | python3 -c \"import sys,json; d=json.load(sys.stdin); print(d.get('home',{}).get('type','?'))\"")
check "platform_options.json home.type = tool" "$OPTS" "tool"

# 2. claro_home_tab public
TAB=$(ssh_cmd mysql -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" \
    -se "SELECT COUNT(*) FROM claro_home_tab WHERE context_name='public' AND type='widgets'" 2>/dev/null)
check "claro_home_tab context=public type=widgets" "$TAB" "1"

# 3. class configurada
CLASS=$(ssh_cmd mysql -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" \
    -se "SELECT class FROM claro_home_tab WHERE context_name='public' LIMIT 1" 2>/dev/null)
check "claro_home_tab.class contiene WidgetsTab" "$CLASS" "WidgetsTab"

# 4. Widget instance workspaces
WI=$(ssh_cmd mysql -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" \
    -se "SELECT COUNT(*) FROM claro_widget_instance WHERE data_source_name='workspaces'" 2>/dev/null)
check "claro_widget_instance data_source=workspaces" "$WI" "1"

# 5. Organización pública
ORG=$(ssh_cmd mysql -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" \
    -se "SELECT COUNT(*) FROM claro__organization WHERE is_public=1" 2>/dev/null)
check "claro__organization is_public=1" "$ORG" "1"

# 6. API home
HOME_HTTP=$(ssh_cmd curl -s -o /dev/null -w '%{http_code}' \
    -H "Host: $DOMAIN" http://localhost/tool/open/home/public)
check "GET /tool/open/home/public -> 200" "$HOME_HTTP" "200"

# 7. Workspaces data source
WS_DATA=$(ssh_cmd curl -s -H "Host: $DOMAIN" http://localhost/data_source/workspaces/public)
WS_COUNT=$(echo "$WS_DATA" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('totalResults',0))" 2>/dev/null || echo "0")
if [[ "$WS_COUNT" -gt 0 ]]; then
    echo "  [OK]   data_source workspaces devuelve $WS_COUNT workspace(s)"
    ((PASS++)) || true
else
    echo "  [FAIL] data_source workspaces devuelve 0 resultados"
    echo "         Verifica: workspaces con is_public=true en la administracion"
    ((FAIL++)) || true
fi

echo ""
echo "  Resultado: $PASS OK  /  $FAIL FAIL"
echo "============================================="
[[ $FAIL -eq 0 ]] && exit 0 || exit 1
