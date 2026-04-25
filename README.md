# Claroline Connect v15 — Instalación y configuración de página de inicio pública

Guía completa para instalar Claroline Connect desde cero y configurar la página de inicio pública con lista de workspaces para usuarios anónimos.

**Versión:** Claroline Connect 15.0.15  
**Stack:** PHP 8.2 · nginx 1.24 · MariaDB 10.11 · Node.js 18 · Ubuntu 24.04 LTS

---

## ¿Cuál es tu punto de partida?

```
¿Ya tienes Claroline instalado?
│
├── NO — servidor vacío → sigue la Ruta A (instalación completa)
│
└── SÍ — ya está instalado pero la página de inicio está en blanco
           → salta directo a la Ruta B (solo el fix)
```

---

## Ruta A — Instalación completa desde cero

### ¿En qué sistema puedo instalar Claroline?

| Sistema | ¿Soportado? | Notas |
|---------|-------------|-------|
| **Ubuntu 24.04 LTS** (servidor o escritorio) | Sí — recomendado | Esta guía está basada en Ubuntu 24.04 |
| **Ubuntu 22.04 LTS** | Sí | Usar mismos comandos |
| **Debian 12** | Sí | Usar mismos comandos |
| **macOS** | Parcial (desarrollo) | Solo con Docker o Homebrew, no para producción |
| **Windows** | No nativo | Requiere WSL2 (Ubuntu dentro de Windows) |

> **Windows:** Claroline Connect es una aplicación PHP/Linux. **No corre nativamente en Windows.** Si estás en Windows, debes instalar WSL2 primero (ver más abajo) y luego seguir la guía de Ubuntu dentro de WSL2.

---

### A1 — Instalar en Ubuntu 24.04 (servidor o escritorio)

#### Requisitos previos
- Ubuntu 24.04 LTS instalado (servidor limpio)
- Acceso root o usuario con sudo
- Un dominio apuntando a la IP del servidor (o usar la IP directamente para pruebas)
- Puertos 80 y 443 abiertos en el firewall

#### Instalación automática (1 comando)

```bash
# Descargar el repositorio
git clone https://github.com/alexandervi1/claroline-public-home-setup.git
cd claroline-public-home-setup
chmod +x install_server.sh

# Ejecutar el instalador (reemplaza los valores)
sudo ./install_server.sh \
  --domain claroline.tudominio.com \
  --db-pass "MiPasswordSegura123*" \
  --admin-email admin@tudominio.com \
  --admin-pass "AdminPassword123*"
```

El script hace todo automáticamente:
1. Instala PHP 8.2 + extensiones requeridas
2. Instala nginx y MariaDB 10.11
3. Instala Composer y Node.js 18
4. Descarga Claroline Connect v15 desde GitHub
5. Configura la base de datos y corre las migraciones
6. Compila los assets del frontend (webpack)
7. Configura el vhost de nginx
8. Aplica el fix de página de inicio pública

---

### A2 — Instalar en Windows (requiere WSL2)

Claroline no corre en Windows nativo. Necesitas instalar WSL2, que es una capa de Ubuntu dentro de Windows.

#### Paso 1 — Instalar WSL2 con Ubuntu

Abre **PowerShell como Administrador** y ejecuta:

```powershell
wsl --install
```

Reinicia el equipo cuando lo pida. Al reiniciar, Ubuntu se abre automáticamente y te pide crear un usuario y contraseña Unix (esto es separado de tu usuario de Windows).

#### Paso 2 — Abrir Ubuntu y seguir la guía

Abre la aplicación **Ubuntu** desde el menú Inicio y ejecuta exactamente los mismos comandos que en Ubuntu:

```bash
sudo apt update
git clone https://github.com/alexandervi1/claroline-public-home-setup.git
cd claroline-public-home-setup
chmod +x install_server.sh

sudo ./install_server.sh \
  --domain localhost \
  --db-pass "MiPasswordSegura123*" \
  --admin-email admin@tudominio.com \
  --admin-pass "AdminPassword123*"
```

> **Nota:** En WSL2 local usa `--domain localhost`. Accedes a Claroline desde tu navegador de Windows en `http://localhost`.

---

### A3 — Instalar en macOS (solo para desarrollo local)

macOS no usa `apt` ni los mismos paquetes que Ubuntu. Para desarrollo local en macOS la forma más práctica es Docker.

#### Con Docker (recomendado en macOS)

```bash
# Instalar Docker Desktop: https://www.docker.com/products/docker-desktop/

# Clonar el repo oficial de Claroline
git clone --branch 15.0 https://github.com/claroline/Claroline.git claroline
cd claroline

# Iniciar con Docker Compose (si Claroline incluye docker-compose.yml)
docker compose up -d

# Aplicar el fix de página de inicio
cd ../claroline-public-home-setup
# Seguir la sección "Ruta B — Instalación local con Docker"
```

---

### A4 — Instalación paso a paso manual (sin script)

Si prefieres hacer cada paso manualmente o estás en un sistema diferente, aquí están los comandos individuales para Ubuntu 24.04:

#### 1. Actualizar sistema e instalar dependencias base

```bash
sudo apt update && sudo apt upgrade -y
sudo apt install -y curl git unzip software-properties-common
```

#### 2. Instalar PHP 8.2 con todas las extensiones requeridas

```bash
sudo add-apt-repository ppa:ondrej/php -y
sudo apt update
sudo apt install -y \
    php8.2-fpm php8.2-cli \
    php8.2-mysql php8.2-xml php8.2-mbstring \
    php8.2-curl php8.2-zip php8.2-gd \
    php8.2-intl php8.2-opcache php8.2-bcmath \
    php8.2-tokenizer php8.2-fileinfo \
    php8.2-iconv php8.2-simplexml \
    php8.2-sockets php8.2-exif php8.2-xsl
```

Ajustar límites en `/etc/php/8.2/fpm/php.ini`:

```ini
upload_max_filesize = 100M
post_max_size = 100M
memory_limit = 512M
max_execution_time = 300
date.timezone = America/Bogota
```

```bash
sudo systemctl restart php8.2-fpm
```

#### 3. Instalar nginx

```bash
sudo apt install -y nginx
sudo systemctl enable nginx
```

#### 4. Instalar MariaDB 10.11

```bash
sudo apt install -y mariadb-server mariadb-client
sudo systemctl enable mariadb
sudo systemctl start mariadb

# Crear base de datos y usuario
sudo mysql -e "CREATE DATABASE claroline_db CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
sudo mysql -e "CREATE USER 'claroline_user'@'localhost' IDENTIFIED BY 'TuPassword';"
sudo mysql -e "GRANT ALL PRIVILEGES ON claroline_db.* TO 'claroline_user'@'localhost';"
sudo mysql -e "FLUSH PRIVILEGES;"
```

#### 5. Instalar Composer y Node.js 18

```bash
# Composer
curl -sS https://getcomposer.org/installer | sudo php -- --install-dir=/usr/local/bin --filename=composer

# Node.js 18
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo bash -
sudo apt install -y nodejs
```

#### 6. Descargar Claroline Connect v15

```bash
sudo git clone \
    --branch 15.0 \
    --depth 1 \
    https://github.com/claroline/Claroline.git \
    /var/www/claroline

cd /var/www/claroline
sudo chown -R www-data:www-data /var/www/claroline
```

#### 7. Instalar dependencias PHP

```bash
cd /var/www/claroline
sudo -u www-data composer install --no-dev --optimize-autoloader --no-interaction
```

#### 8. Crear el archivo de configuración .env.local

```bash
sudo -u www-data tee /var/www/claroline/.env.local > /dev/null <<EOF
APP_ENV=prod
APP_SECRET=$(openssl rand -hex 32)
DATABASE_URL="mysql://claroline_user:TuPassword@127.0.0.1:3306/claroline_db?serverVersion=mariadb-10.11.16&charset=utf8mb4"
MAILER_DSN=null://null
EOF
```

#### 9. Instalar Claroline (migrar BD y cargar datos iniciales)

```bash
cd /var/www/claroline
sudo -u www-data php bin/console claroline:install --no-interaction
```

#### 10. Compilar assets del frontend

```bash
cd /var/www/claroline
sudo npm ci
sudo npm run webpack
sudo chown -R www-data:www-data /var/www/claroline/public
```

#### 11. Configurar nginx

Crear el archivo `/etc/nginx/sites-available/claroline`:

```nginx
server {
    listen 80;
    server_name claroline.tudominio.com;

    root /var/www/claroline/public;
    index index.php;

    client_max_body_size 100M;
    access_log /var/log/nginx/claroline_access.log;
    error_log  /var/log/nginx/claroline_error.log;

    location / {
        try_files $uri /index.php$is_args$args;
    }

    location ~ ^/index\.php(/|$) {
        fastcgi_pass unix:/run/php/php8.2-fpm.sock;
        fastcgi_split_path_info ^(.+\.php)(/.*)$;
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME $realpath_root$fastcgi_script_name;
        fastcgi_param DOCUMENT_ROOT $realpath_root;
        fastcgi_read_timeout 300;
        internal;
    }

    location ~ \.php$ {
        return 404;
    }
}
```

```bash
sudo ln -s /etc/nginx/sites-available/claroline /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default
sudo nginx -t && sudo systemctl reload nginx
```

#### 12. Aplicar el fix de página de inicio pública

```bash
# Continúa con la Ruta B — Fix de página de inicio
```

---

## Ruta B — Fix de página de inicio pública (Claroline ya instalado)

Esta sección aplica tanto si acabas de instalar Claroline con la Ruta A como si ya tenías una instalación existente.

### ¿Cuál es el problema que corrige?

En una instalación por defecto, los usuarios anónimos ven una **página en blanco** al visitar la plataforma. Este fix configura una página de inicio con la lista de workspaces públicos.

### ¿Desde dónde corres el fix?

| Tu situación | Sección a seguir |
|---|---|
| Claroline en servidor remoto, tú en Ubuntu o macOS | B1 — Script automático vía SSH |
| Claroline en servidor remoto, tú en Windows | B2 — SSH desde Windows con WSL |
| Claroline instalado en tu misma máquina (Ubuntu/Debian) | B3 — Comandos directos locales |
| Claroline en WSL2 en tu Windows | B3 — Comandos directos locales (dentro de WSL) |
| Claroline en Docker | B4 — Comandos dentro del contenedor |

---

### B1 — Servidor remoto desde Ubuntu o macOS

```bash
sudo apt install sshpass git        # Ubuntu
# brew install hudochenkov/sshpass/sshpass  # macOS

git clone https://github.com/alexandervi1/claroline-public-home-setup.git
cd claroline-public-home-setup
chmod +x setup.sh verify.sh

./setup.sh \
  --host IP_DEL_SERVIDOR \
  --ssh-user avpro2029 \
  --ssh-pass TuPasswordSSH \
  --db-user claroline_user \
  --db-pass "TuPasswordMySQL" \
  --db-name claroline_db \
  --domain claroline.tudominio.com

# Verificar
./verify.sh \
  --host IP_DEL_SERVIDOR \
  --ssh-user avpro2029 \
  --ssh-pass TuPasswordSSH \
  --db-user claroline_user \
  --db-pass "TuPasswordMySQL" \
  --db-name claroline_db \
  --domain claroline.tudominio.com
```

---

### B2 — Servidor remoto desde Windows (con WSL)

Instala WSL2 si no lo tienes (ver sección A2). Luego abre Ubuntu y ejecuta exactamente los mismos comandos del B1.

---

### B3 — Claroline instalado localmente (Ubuntu, Debian o WSL)

No necesitas SSH. Los comandos se corren directamente en la terminal:

```bash
git clone https://github.com/alexandervi1/claroline-public-home-setup.git
cd claroline-public-home-setup

# Paso 1: Parchear platform_options.json
sudo python3 -c "
import json
path = '/var/www/claroline/files/config/platform_options.json'
with open(path) as f: d = json.load(f)
d['home'] = {'type': 'tool', 'data': None}
with open(path, 'w') as f: json.dump(d, f, ensure_ascii=False, indent=4)
print('OK: platform_options.json actualizado')
"

# Paso 2: Ejecutar el SQL
mysql -u claroline_user -p claroline_db < sql/01_public_home_setup.sql

# Paso 3: Limpiar caché
cd /var/www/claroline
sudo -u www-data php bin/console cache:clear
sudo -u www-data php bin/console cache:warmup

echo "Listo. Abre tu navegador."
```

---

### B4 — Claroline en Docker

```bash
git clone https://github.com/alexandervi1/claroline-public-home-setup.git
cd claroline-public-home-setup

# Ver el nombre de tu contenedor PHP
docker ps

# Copiar el SQL al contenedor (reemplaza 'claroline_php' por tu nombre de contenedor)
docker cp sql/01_public_home_setup.sql claroline_php:/tmp/

# Ejecutar SQL dentro del contenedor
docker exec claroline_php bash -c \
  "mysql -u claroline_user -pTuPassword claroline_db < /tmp/01_public_home_setup.sql"

# Parchear platform_options.json
docker exec claroline_php python3 -c "
import json
path = '/var/www/claroline/files/config/platform_options.json'
with open(path) as f: d = json.load(f)
d['home'] = {'type': 'tool', 'data': None}
with open(path, 'w') as f: json.dump(d, f, ensure_ascii=False, indent=4)
print('OK')
"

# Limpiar caché
docker exec claroline_php bash -c \
  "cd /var/www/claroline && php bin/console cache:clear && php bin/console cache:warmup"
```

---

## Verificación final

Después de aplicar la Ruta B, abre un navegador en modo incógnito y visita la URL de tu plataforma. Debes ver la lista de workspaces públicos en la página de inicio.

Para verificar por terminal (correr en el servidor o dentro de WSL/Docker):

```bash
DOMAIN="claroline.tudominio.com"

# El home tool responde?
curl -s -o /dev/null -w 'HTTP: %{http_code}\n' \
  -H "Host: $DOMAIN" http://localhost/tool/open/home/public
# Esperado: HTTP: 200

# Devuelve workspaces?
curl -s -H "Host: $DOMAIN" http://localhost/data_source/workspaces/public | \
  python3 -c "import sys,json; d=json.load(sys.stdin); print('Workspaces públicos:', d['totalResults'])"
# Esperado: Workspaces públicos: 1 (o más)
```

Salida esperada de `verify.sh`:

```
=============================================
  Claroline — Verificacion Public Home
=============================================
  [OK]   platform_options.json home.type = tool
  [OK]   claro_home_tab context=public type=widgets
  [OK]   claro_home_tab.class contiene WidgetsTab
  [OK]   claro_widget_instance data_source=workspaces
  [OK]   claro__organization is_public=1
  [OK]   GET /tool/open/home/public -> 200
  [OK]   data_source workspaces devuelve 2 workspace(s)

  Resultado: 7 OK  /  0 FAIL
=============================================
```

---

## Activar workspaces como públicos

Para que un workspace aparezca en la página de inicio, debe marcarse como público:

**Desde la administración de Claroline:**
1. Ir a **Administración → Workspaces**
2. Editar el workspace
3. Marcar **Público**
4. Guardar

**O directamente en la BD:**
```sql
UPDATE claro_workspace SET is_public = 1 WHERE slug = 'nombre-del-workspace';
```

---

## Configurar HTTPS con SSL (recomendado para producción)

```bash
sudo apt install -y certbot python3-certbot-nginx
sudo certbot --nginx -d claroline.tudominio.com
# Certbot configura nginx automáticamente con renovación automática
```

---

## Problemas encontrados durante el diagnóstico

### Problema 1 — Página en blanco para usuarios anónimos

**Causa:** `platform_options.json` tenía `"home": {"type": "none"}`. El SPA no tenía contexto público configurado.  
**Fix:** Cambiar a `"home": {"type": "tool", "data": null}`.

> El código fuente de `PublicContext.php` verifica explícitamente `return 'tool' === $this->config->getParameter('home.type');`. Cualquier otro valor deja el contexto público desactivado.

---

### Problema 2 — curl de prueba devolvía HTML estático en vez de Claroline

**Causa:** El vhost de nginx está ligado a `server_name claroline.tudominio.com`. Las peticiones a `http://localhost` sin el header `Host:` correcto caían en el servidor por defecto de nginx y devolvían HTML estático.

**Fix:** Siempre incluir `-H 'Host: claroline.tudominio.com'` al hacer pruebas:

```bash
# MAL
curl http://localhost/tool/open/home/public

# BIEN
curl -H 'Host: claroline.tudominio.com' http://localhost/tool/open/home/public
```

---

### Problema 3 — El tab público no mostraba widgets

**Causa:** El campo `claro_home_tab.class` estaba en `NULL`. El serializador `HomeTabSerializer.php` solo carga los parámetros del widget cuando la clase es no-nula. Sin ella, el SPA muestra el tab vacío.

**Fix:** El campo `class` debe contener `Claroline\HomeBundle\Entity\Type\WidgetsTab`.

---

### Problema 4 — MySQL eliminaba las barras invertidas del campo class

**Causa:** MySQL en modo por defecto interpreta `\H`, `\E`, `\T` como secuencias de escape y las elimina. Al insertar `'Claroline\HomeBundle\...'`, MySQL guardaba `ClarolineHomeBundle...` (sin barras), rompiendo la carga de la clase PHP.

**Fix:** Usar `CHAR(92)` para el carácter backslash en el SQL:

```sql
-- MAL: MySQL elimina los backslashes
UPDATE claro_home_tab SET class = 'Claroline\HomeBundle\Entity\Type\WidgetsTab';

-- BIEN
UPDATE claro_home_tab SET class = CONCAT(
  'Claroline', CHAR(92), 'HomeBundle', CHAR(92),
  'Entity',    CHAR(92), 'Type',       CHAR(92), 'WidgetsTab'
);
```

---

### Problema 5 — El widget devolvía 0 workspaces

**Causa:** La query de `WorkspacesList.php` hace un JOIN con `claro__organization` y filtra `WHERE is_public = 1`. La organización por defecto tenía `is_public = 0`, devolviendo siempre `totalResults: 0`.

**Fix:**
```sql
UPDATE claro__organization SET is_public = 1 WHERE id = 1;
```

---

## Flujo de datos (referencia técnica)

```
Usuario anonimo visita https://claroline.tudominio.com/
  |
  +-> SPA carga -> GET /context/public
  |     PublicContext::isAvailable()  →  home.type debe ser "tool"
  |     Retorna: opening: { type: "tool", target: "home" }
  |
  +-> SPA navega al home -> GET /tool/open/home/public
  |     Busca claro_home_tab WHERE context_name='public'
  |     HomeTabSerializer carga WidgetsTabSerializer (requiere class != NULL)
  |     Retorna: tabs[0].parameters.widgets[0].source = "workspaces"
  |
  +-> Widget list -> GET /data_source/workspaces/public
        Filtra: public=true, model=false, personal=false
        JOIN claro__organization WHERE is_public = 1
        Retorna: { totalResults: N, data: [{name, slug, ...}] }
```

---

## Estructura del repositorio

```
claroline-public-home-setup/
├── README.md                      <- Esta guia
├── install_server.sh              <- Instalacion completa desde cero (Ubuntu 24.04)
├── setup.sh                       <- Fix de home publico via SSH (servidor remoto)
├── verify.sh                      <- Verificacion via SSH (servidor remoto)
├── sql/
│   └── 01_public_home_setup.sql   <- SQL portable (compatible con todas las rutas)
└── config/
    └── patch_platform_options.py  <- Script Python alternativo para parche via SSH
```
