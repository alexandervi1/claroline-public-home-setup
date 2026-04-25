#!/usr/bin/env bash
# =============================================================================
# Claroline Connect v15.0.15 — Instalación completa desde cero
# Sistema operativo: Ubuntu 24.04 LTS (Noble)
# Stack: PHP 8.2 · nginx 1.24 · MariaDB 10.11 · Node.js 18 · Composer 2
# =============================================================================
# Uso:
#   chmod +x install_server.sh
#   sudo ./install_server.sh \
#     --domain claroline.tudominio.com \
#     --db-pass "MiPasswordSegura123*" \
#     --admin-email admin@tudominio.com \
#     --admin-pass "AdminPassword123*"
#
# IMPORTANTE: ejecutar como root o con sudo
# =============================================================================

set -euo pipefail

# ---------- Argumentos ----------
DOMAIN=""
DB_NAME="claroline_db"
DB_USER="claroline_user"
DB_PASS=""
ADMIN_EMAIL=""
ADMIN_PASS=""
CLAROLINE_PATH="/var/www/claroline"
CLAROLINE_VERSION="15.0"   # rama del repositorio

while [[ $# -gt 0 ]]; do
    case "$1" in
        --domain)       DOMAIN="$2";       shift 2 ;;
        --db-name)      DB_NAME="$2";      shift 2 ;;
        --db-user)      DB_USER="$2";      shift 2 ;;
        --db-pass)      DB_PASS="$2";      shift 2 ;;
        --admin-email)  ADMIN_EMAIL="$2";  shift 2 ;;
        --admin-pass)   ADMIN_PASS="$2";   shift 2 ;;
        --path)         CLAROLINE_PATH="$2"; shift 2 ;;
        *) echo "Parametro desconocido: $1"; exit 1 ;;
    esac
done

for var in DOMAIN DB_PASS ADMIN_EMAIL ADMIN_PASS; do
    if [[ -z "${!var}" ]]; then
        echo "ERROR: --$(echo $var | tr '[:upper:]' '[:lower:]' | tr '_' '-') es requerido"
        exit 1
    fi
done

echo "============================================="
echo "  Claroline Connect v15 — Instalacion"
echo "============================================="
echo "  Dominio       : $DOMAIN"
echo "  Ruta          : $CLAROLINE_PATH"
echo "  Base de datos : $DB_NAME (usuario: $DB_USER)"
echo "  Admin email   : $ADMIN_EMAIL"
echo "============================================="
echo ""

# ============================================================
# PASO 1: Actualizar el sistema
# ============================================================
echo "[1/9] Actualizando sistema..."
apt update -qq && apt upgrade -y -qq
apt install -y -qq curl git unzip software-properties-common

# ============================================================
# PASO 2: Instalar PHP 8.2 y extensiones requeridas
# ============================================================
echo "[2/9] Instalando PHP 8.2..."
add-apt-repository -y ppa:ondrej/php > /dev/null 2>&1
apt update -qq
apt install -y -qq \
    php8.2-fpm \
    php8.2-cli \
    php8.2-mysql \
    php8.2-pdo \
    php8.2-xml \
    php8.2-mbstring \
    php8.2-curl \
    php8.2-zip \
    php8.2-gd \
    php8.2-intl \
    php8.2-opcache \
    php8.2-bcmath \
    php8.2-tokenizer \
    php8.2-fileinfo \
    php8.2-iconv \
    php8.2-simplexml \
    php8.2-sockets \
    php8.2-exif \
    php8.2-xsl

# Ajustar php.ini para Claroline
PHP_INI="/etc/php/8.2/fpm/php.ini"
sed -i 's/^upload_max_filesize.*/upload_max_filesize = 100M/'  "$PHP_INI"
sed -i 's/^post_max_size.*/post_max_size = 100M/'             "$PHP_INI"
sed -i 's/^memory_limit.*/memory_limit = 512M/'               "$PHP_INI"
sed -i 's/^max_execution_time.*/max_execution_time = 300/'    "$PHP_INI"
sed -i 's/^;date.timezone.*/date.timezone = America\/Bogota/' "$PHP_INI"

systemctl restart php8.2-fpm
echo "  OK: PHP 8.2 instalado"

# ============================================================
# PASO 3: Instalar nginx
# ============================================================
echo "[3/9] Instalando nginx..."
apt install -y -qq nginx
systemctl enable nginx
echo "  OK: nginx instalado"

# ============================================================
# PASO 4: Instalar MariaDB 10.11
# ============================================================
echo "[4/9] Instalando MariaDB 10.11..."
apt install -y -qq mariadb-server mariadb-client

systemctl enable mariadb
systemctl start mariadb

# Seguridad básica de MariaDB
mysql -e "DELETE FROM mysql.user WHERE User='';"
mysql -e "DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost','127.0.0.1','::1');"
mysql -e "DROP DATABASE IF EXISTS test;"
mysql -e "FLUSH PRIVILEGES;"

# Crear base de datos y usuario
mysql -e "CREATE DATABASE IF NOT EXISTS \`$DB_NAME\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
mysql -e "CREATE USER IF NOT EXISTS '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASS';"
mysql -e "GRANT ALL PRIVILEGES ON \`$DB_NAME\`.* TO '$DB_USER'@'localhost';"
mysql -e "FLUSH PRIVILEGES;"
echo "  OK: MariaDB configurado — BD: $DB_NAME, usuario: $DB_USER"

# ============================================================
# PASO 5: Instalar Composer y Node.js 18
# ============================================================
echo "[5/9] Instalando Composer y Node.js..."

# Composer
if ! command -v composer &>/dev/null; then
    curl -sS https://getcomposer.org/installer -o /tmp/composer-setup.php
    php /tmp/composer-setup.php --install-dir=/usr/local/bin --filename=composer --quiet
fi

# Node.js 18 LTS
if ! command -v node &>/dev/null || [[ "$(node --version | cut -d. -f1)" != "v18" ]]; then
    curl -fsSL https://deb.nodesource.com/setup_18.x | bash - > /dev/null 2>&1
    apt install -y -qq nodejs
fi

echo "  OK: Composer $(composer --version --no-ansi 2>/dev/null | head -1)"
echo "  OK: Node.js $(node --version)"

# ============================================================
# PASO 6: Descargar e instalar Claroline Connect
# ============================================================
echo "[6/9] Descargando Claroline Connect v15..."

# Crear directorio y descargar
mkdir -p "$(dirname $CLAROLINE_PATH)"

if [[ -d "$CLAROLINE_PATH/.git" ]]; then
    echo "  Directorio ya existe, actualizando..."
    cd "$CLAROLINE_PATH"
    git pull origin "$CLAROLINE_VERSION" 2>/dev/null || true
else
    git clone \
        --branch "$CLAROLINE_VERSION" \
        --depth 1 \
        https://github.com/claroline/Claroline.git \
        "$CLAROLINE_PATH"
fi

cd "$CLAROLINE_PATH"

# Instalar dependencias PHP
echo "  Instalando dependencias PHP (composer install)..."
sudo -u www-data composer install \
    --no-dev \
    --optimize-autoloader \
    --no-interaction \
    --quiet

# Crear .env.local
MARIADB_VERSION=$(mariadb --version 2>/dev/null | grep -oP '\d+\.\d+\.\d+' | head -1)
cat > "$CLAROLINE_PATH/.env.local" <<ENVEOF
APP_ENV=prod
APP_SECRET=$(openssl rand -hex 32)
DATABASE_URL="mysql://${DB_USER}:${DB_PASS}@127.0.0.1:3306/${DB_NAME}?serverVersion=mariadb-${MARIADB_VERSION}&charset=utf8mb4"
MAILER_DSN=null://null
ENVEOF

chown www-data:www-data "$CLAROLINE_PATH/.env.local"
chmod 640 "$CLAROLINE_PATH/.env.local"

# Ejecutar instalador de Claroline
echo "  Ejecutando instalador de Claroline..."
sudo -u www-data php "$CLAROLINE_PATH/bin/console" claroline:install \
    --no-interaction 2>&1 | tail -5 || \
sudo -u www-data php "$CLAROLINE_PATH/bin/console" doctrine:migrations:migrate \
    --no-interaction --quiet 2>/dev/null || true

# Crear usuario administrador
echo "  Creando usuario administrador..."
sudo -u www-data php "$CLAROLINE_PATH/bin/console" \
    claroline:user:create \
    --admin \
    --email="$ADMIN_EMAIL" \
    --password="$ADMIN_PASS" \
    --no-interaction 2>/dev/null || \
echo "  (El admin puede crearse desde la interfaz web en el primer acceso)"

# Construir assets frontend
echo "  Compilando assets frontend (npm run webpack)..."
cd "$CLAROLINE_PATH"
npm ci --quiet 2>/dev/null
npm run webpack 2>/dev/null | tail -3

echo "  OK: Claroline instalado"

# ============================================================
# PASO 7: Permisos de archivos
# ============================================================
echo "[7/9] Configurando permisos..."
chown -R www-data:www-data "$CLAROLINE_PATH"
find "$CLAROLINE_PATH" -type d -exec chmod 755 {} \;
find "$CLAROLINE_PATH" -type f -exec chmod 644 {} \;
chmod -R ug+w "$CLAROLINE_PATH/var"
chmod -R ug+w "$CLAROLINE_PATH/files"
chmod -R ug+w "$CLAROLINE_PATH/public"
echo "  OK: permisos configurados"

# ============================================================
# PASO 8: Configurar nginx
# ============================================================
echo "[8/9] Configurando nginx..."

cat > "/etc/nginx/sites-available/claroline" <<NGINXEOF
server {
    listen 80;
    server_name $DOMAIN;

    root $CLAROLINE_PATH/public;
    index index.php;

    client_max_body_size 100M;
    access_log /var/log/nginx/claroline_access.log;
    error_log  /var/log/nginx/claroline_error.log;

    location / {
        try_files \$uri /index.php\$is_args\$args;
    }

    location ~ ^/index\\.php(/|$) {
        fastcgi_pass unix:/run/php/php8.2-fpm.sock;
        fastcgi_split_path_info ^(.+\\.php)(/.*)$;
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME \$realpath_root\$fastcgi_script_name;
        fastcgi_param DOCUMENT_ROOT \$realpath_root;
        fastcgi_read_timeout 300;
        internal;
    }

    location ~ \\.php$ {
        return 404;
    }
}
NGINXEOF

ln -sf /etc/nginx/sites-available/claroline /etc/nginx/sites-enabled/claroline
rm -f /etc/nginx/sites-enabled/default

nginx -t && systemctl reload nginx
echo "  OK: nginx configurado para $DOMAIN"

# ============================================================
# PASO 9: Aplicar fix de página de inicio pública
# ============================================================
echo "[9/9] Aplicando configuracion de pagina de inicio publica..."

# Parchear platform_options.json
PLATFORM_JSON="$CLAROLINE_PATH/files/config/platform_options.json"
if [[ -f "$PLATFORM_JSON" ]]; then
    sudo -u www-data python3 -c "
import json
with open('$PLATFORM_JSON') as f:
    d = json.load(f)
d['home'] = {'type': 'tool', 'data': None}
with open('$PLATFORM_JSON', 'w') as f:
    json.dump(d, f, ensure_ascii=False, indent=4)
print('  OK: platform_options.json actualizado')
"
fi

# Ejecutar SQL
SQL_FILE="$(dirname "$0")/sql/01_public_home_setup.sql"
if [[ -f "$SQL_FILE" ]]; then
    mysql -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" < "$SQL_FILE" 2>/dev/null
    echo "  OK: registros de home publico insertados"
fi

# Limpiar caché
sudo -u www-data php "$CLAROLINE_PATH/bin/console" cache:clear --no-warmup --no-debug -q 2>/dev/null
sudo -u www-data php "$CLAROLINE_PATH/bin/console" cache:warmup --no-debug -q 2>/dev/null
echo "  OK: cache regenerada"

# ============================================================
# RESUMEN FINAL
# ============================================================
echo ""
echo "============================================="
echo "  INSTALACION COMPLETADA"
echo "============================================="
echo "  URL          : http://$DOMAIN"
echo "  Admin email  : $ADMIN_EMAIL"
echo "  Admin pass   : $ADMIN_PASS"
echo ""
echo "  Proximos pasos:"
echo "  1. Apunta el DNS de $DOMAIN a la IP de este servidor"
echo "  2. Accede a http://$DOMAIN y verifica que carga"
echo "  3. (Opcional) Configura SSL con Certbot:"
echo "     apt install certbot python3-certbot-nginx"
echo "     certbot --nginx -d $DOMAIN"
echo "  4. Crea workspaces publicos en:"
echo "     http://$DOMAIN/#/administration/workspaces"
echo "============================================="
