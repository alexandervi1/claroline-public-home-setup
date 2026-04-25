# Claroline Connect v15 — Página de Inicio Pública con Lista de Workspaces

Guía y scripts para configurar que los usuarios anónimos vean una lista de workspaces públicos al acceder a la plataforma, en lugar de una página en blanco.

**Versión probada:** Claroline Connect 15.0.15  
**Stack:** PHP 8.2-FPM · Symfony · MySQL 8.0 / MariaDB 10.11 · nginx 1.24

---

## El problema

En una instalación por defecto de Claroline Connect, al visitar la URL raíz como usuario no autenticado, el SPA carga sin contexto y muestra una **página en blanco**. Esto ocurre porque la configuración por defecto tiene `home.type = "none"`, lo que deshabilita completamente el contexto público.

---

## La solución en 4 pasos

| # | Qué se cambia | Por qué es necesario |
|---|---------------|----------------------|
| 1 | `platform_options.json`: `home.type` → `"tool"` | Activa `PublicContext` en el SPA |
| 2 | INSERT en tablas de BD: tab + widget container + widget instance | Crea el tab de inicio con el widget de lista de workspaces |
| 3 | `claro__organization.is_public = 1` | Sin esto la query de WorkspacesList devuelve 0 resultados |
| 4 | Limpiar caché de Symfony | Aplica los cambios sin reiniciar PHP-FPM |

---

## ¿Cuál es tu escenario?

Antes de seguir la guía, identifica en cuál de estos dos casos estás:

| Escenario | Descripción |
|-----------|-------------|
| **A — Servidor remoto** | Claroline está instalado en un servidor Linux al que accedes por SSH (VPS, servidor propio, Hetzner, DigitalOcean, etc.) |
| **B — Instalación local** | Claroline está instalado en tu propia máquina (Ubuntu de escritorio, macOS, o Windows con WSL/Docker) |

---

## Escenario A — Servidor remoto (acceso por SSH)

Tú estás en tu computadora y Claroline corre en otro servidor. Los scripts usan SSH para conectarse y hacer los cambios.

### ¿Desde qué sistema puedo correr los scripts?

| Tu sistema operativo | ¿Puedes usar setup.sh? | Cómo |
|----------------------|------------------------|------|
| **Ubuntu / Debian** | Sí | Directo |
| **macOS** | Sí | Con Homebrew |
| **Windows** | Solo con WSL | Instalar WSL primero |

### Desde Ubuntu o Debian

```bash
sudo apt install sshpass git

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
```

### Desde macOS

```bash
# Instalar Homebrew si no lo tienes: https://brew.sh
brew install hudochenkov/sshpass/sshpass git

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
```

### Desde Windows (requiere WSL)

`setup.sh` no funciona nativo en Windows porque usa `bash` y `sshpass`. La solución es WSL (Windows Subsystem for Linux), que instala Ubuntu dentro de Windows.

**Paso 1 — Instalar WSL** (solo la primera vez, requiere reinicio):

```powershell
# Abrir PowerShell como Administrador y ejecutar:
wsl --install
# Reiniciar el equipo cuando lo pida
```

**Paso 2 — Abrir la terminal de Ubuntu** (aparece en el menú Inicio como "Ubuntu") y ejecutar:

```bash
sudo apt install sshpass git

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
```

> **Nota:** WSL solo es necesario para correr `setup.sh` y `verify.sh`. Los cambios se aplican en el servidor remoto, no en tu máquina local.

---

## Escenario B — Instalación local (Claroline en tu propia máquina)

Claroline corre en tu misma computadora. No necesitas SSH ni `sshpass`. Los comandos se corren directamente en la terminal.

> **Importante:** Claroline Connect requiere Linux o macOS para funcionar. **No corre nativamente en Windows.** En Windows debes usar WSL o Docker (ver más abajo).

### Ubuntu o Debian (local)

Abre una terminal y ejecuta los pasos directamente:

```bash
# Paso 1: Parchear platform_options.json
sudo python3 -c "
import json
path = '/var/www/claroline/files/config/platform_options.json'
with open(path) as f:
    d = json.load(f)
d['home'] = {'type': 'tool', 'data': None}
with open(path, 'w') as f:
    json.dump(d, f, indent=4)
print('OK: platform_options.json actualizado')
"

# Paso 2: Ejecutar el SQL
git clone https://github.com/alexandervi1/claroline-public-home-setup.git
mysql -u claroline_user -p claroline_db < claroline-public-home-setup/sql/01_public_home_setup.sql

# Paso 3: Limpiar caché de Symfony
cd /var/www/claroline
sudo -u www-data php bin/console cache:clear
sudo -u www-data php bin/console cache:warmup

echo "Listo. Abre http://localhost en tu navegador."
```

### macOS (local)

En macOS, Claroline generalmente corre via Docker o con PHP/nginx instalados con Homebrew. La ruta de instalación puede variar.

```bash
# Paso 1: Parchear platform_options.json
# Reemplaza la ruta si tu instalación está en otro directorio
PLATFORM_JSON="$HOME/claroline/files/config/platform_options.json"

python3 -c "
import json, os
path = os.environ['PLATFORM_JSON']  if 'PLATFORM_JSON' in os.environ else '/var/www/claroline/files/config/platform_options.json'
with open(path) as f:
    d = json.load(f)
d['home'] = {'type': 'tool', 'data': None}
with open(path, 'w') as f:
    json.dump(d, f, indent=4)
print('OK:', path)
" 

# Paso 2: Ejecutar el SQL
git clone https://github.com/alexandervi1/claroline-public-home-setup.git
mysql -u claroline_user -p claroline_db < claroline-public-home-setup/sql/01_public_home_setup.sql

# Paso 3: Limpiar caché
cd /ruta/a/tu/claroline
php bin/console cache:clear
php bin/console cache:warmup
```

### Windows con WSL (local)

Claroline no corre nativo en Windows. Si lo tienes instalado dentro de WSL (Ubuntu corriendo dentro de Windows), sigue los mismos pasos que Ubuntu local pero desde la terminal de WSL:

```bash
# Abrir terminal Ubuntu (WSL) y ejecutar exactamente igual que Ubuntu local
sudo python3 -c "
import json
path = '/var/www/claroline/files/config/platform_options.json'
with open(path) as f:
    d = json.load(f)
d['home'] = {'type': 'tool', 'data': None}
with open(path, 'w') as f:
    json.dump(d, f, indent=4)
print('OK')
"
mysql -u claroline_user -p claroline_db < claroline-public-home-setup/sql/01_public_home_setup.sql
cd /var/www/claroline
sudo -u www-data php bin/console cache:clear
sudo -u www-data php bin/console cache:warmup
```

### Windows con Docker (local)

Si tienes Claroline corriendo en Docker:

```bash
# Identificar el nombre del contenedor PHP
docker ps

# Copiar el SQL al contenedor y ejecutarlo
docker cp claroline-public-home-setup/sql/01_public_home_setup.sql claroline_php:/tmp/

# Ejecutar dentro del contenedor
docker exec claroline_php bash -c "
  mysql -u claroline_user -pTuPassword claroline_db < /tmp/01_public_home_setup.sql
"

# Parchear platform_options.json dentro del contenedor
docker exec claroline_php python3 -c "
import json
path = '/var/www/claroline/files/config/platform_options.json'
with open(path) as f:
    d = json.load(f)
d['home'] = {'type': 'tool', 'data': None}
with open(path, 'w') as f:
    json.dump(d, f, indent=4)
print('OK')
"

# Limpiar caché dentro del contenedor
docker exec claroline_php bash -c "
  cd /var/www/claroline &&
  php bin/console cache:clear &&
  php bin/console cache:warmup
"
```

> **Nota Docker:** Los nombres de contenedor (`claroline_php`, etc.) dependen de tu `docker-compose.yml`. Ajústalos según tu instalación.

---

## Verificar que funcionó

Después de aplicar los cambios, abre un navegador en modo incógnito y visita la URL de tu plataforma. Deberías ver la lista de workspaces públicos en la página de inicio.

También puedes verificar con estos comandos (correrlos **en el servidor** o **dentro de WSL/Docker** según tu caso):

```bash
# Reemplaza el dominio por el tuyo (o usa localhost si es local)
DOMAIN="claroline.tudominio.com"

# 1. ¿Responde el home tool?
curl -s -o /dev/null -w 'HTTP: %{http_code}\n' \
  -H "Host: $DOMAIN" http://localhost/tool/open/home/public
# Esperado: HTTP: 200

# 2. ¿Devuelve workspaces?
curl -s -H "Host: $DOMAIN" http://localhost/data_source/workspaces/public | \
  python3 -c "import sys,json; d=json.load(sys.stdin); print('Workspaces:', d['totalResults'])"
# Esperado: Workspaces: 1 (o más)
```

O usando el script incluido (solo Escenario A — servidor remoto):

```bash
./verify.sh \
  --host IP_DEL_SERVIDOR \
  --ssh-user avpro2029 \
  --ssh-pass TuPasswordSSH \
  --db-user claroline_user \
  --db-pass "TuPasswordMySQL" \
  --db-name claroline_db \
  --domain claroline.tudominio.com
```

Salida esperada:

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

## Problemas encontrados durante el diagnóstico

### Problema 1 — Página en blanco al visitar la plataforma

**Causa:** `platform_options.json` tenía `"home": {"type": "none"}`. El SPA no tenía contexto público configurado.  
**Fix:** Cambiar a `"home": {"type": "tool", "data": null}`.

---

### Problema 2 — Requests de prueba devolvían HTML estático (no Claroline)

**Causa:** El vhost de nginx está ligado a `server_name claroline.tudominio.com`. Las peticiones a `http://localhost` sin el header `Host:` correcto caían en el servidor por defecto de nginx y devolvían un archivo HTML estático. Esto hacía que los tests parecieran funcionar cuando en realidad no llegaban a Claroline.

**Fix:** Siempre incluir `-H 'Host: claroline.tudominio.com'` en los `curl` de prueba:

```bash
# MAL — no llega a Claroline
curl http://localhost/tool/open/home/public

# BIEN
curl -H 'Host: claroline.tudominio.com' http://localhost/tool/open/home/public
```

---

### Problema 3 — El tab público no mostraba widgets (`parameters` vacío en la API)

**Causa:** El campo `claro_home_tab.class` estaba en `NULL`. El serializador `HomeTabSerializer.php` solo carga los parámetros del widget cuando `$homeTab->getClass()` es no-nulo. Sin la clase, el API devolvía el tab sin ningún contenido de widgets y el SPA mostraba el tab vacío.

**Fix:** El campo `class` debe contener `Claroline\HomeBundle\Entity\Type\WidgetsTab`.

---

### Problema 4 — MySQL eliminaba las barras invertidas del campo `class`

**Causa:** MySQL en modo por defecto (`NO_BACKSLASH_ESCAPES=OFF`) interpreta `\H`, `\E`, `\T` como secuencias de escape y las elimina. Al insertar `'Claroline\HomeBundle\Entity\Type\WidgetsTab'`, MySQL guardaba `ClarolineHomeBundleEntityTypeWidgetsTab` (sin barras), rompiendo la carga de la clase PHP.

**Fix:** Usar `CHAR(92)` para el carácter backslash:

```sql
-- MAL: MySQL elimina los backslashes
UPDATE claro_home_tab SET class = 'Claroline\HomeBundle\Entity\Type\WidgetsTab';

-- BIEN: CHAR(92) = backslash, MySQL no lo puede escapar
UPDATE claro_home_tab SET class = CONCAT(
  'Claroline', CHAR(92), 'HomeBundle', CHAR(92),
  'Entity',    CHAR(92), 'Type',       CHAR(92), 'WidgetsTab'
);
```

---

### Problema 5 — El widget de workspaces devolvía 0 resultados

**Causa:** La query interna de `WorkspacesList.php` hace un JOIN con `claro__organization` y aplica `WHERE c1_.is_public = 1`. La organización por defecto tenía `is_public = 0`, lo que hacía que la query devolviera `totalResults: 0` aunque los workspaces individuales sí estuvieran marcados como públicos.

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
  |     PublicContext::isAvailable() verifica home.type = "tool"  <-- Paso 1
  |     Retorna: opening: { type: "tool", target: "home" }
  |
  +-> SPA navega al home tool -> GET /tool/open/home/public
  |     HomeTool::open() busca claro_home_tab WHERE context_name='public'
  |     HomeTabSerializer carga WidgetsTabSerializer (requiere class != NULL)  <-- Paso 2
  |     Retorna: tabs[0].parameters.widgets[0].source = "workspaces"
  |
  +-> Widget list -> GET /data_source/workspaces/public
        WorkspacesList::getData() filtra public=true, model=false, personal=false
        JOIN claro__organization WHERE is_public = 1  <-- Paso 3
        Retorna: { totalResults: 2, data: [{name: "Base de Datos I"}, ...] }
```

---

## Estructura del repositorio

```
claroline-public-home-setup/
├── README.md                       <- Esta guia
├── setup.sh                        <- Script automatico para servidor remoto (SSH)
├── verify.sh                       <- Verificacion para servidor remoto (SSH)
├── sql/
│   └── 01_public_home_setup.sql    <- SQL portable (funciona local y remoto)
└── config/
    └── patch_platform_options.py   <- Script Python para parche via SSH
```

---

## Prerequisitos

- Claroline Connect 15.x instalado y funcionando
- Usuario con permisos `sudo` (local) o acceso SSH con sudo (remoto)
- Acceso a MySQL/MariaDB con usuario que pueda hacer INSERT/UPDATE
- PHP 8.x con `bin/console` operativo
- Al menos un workspace con **Público = activado** en la administración de Claroline

### Activar un workspace como público

Desde la administración de Claroline:
1. **Administración → Workspaces**
2. Editar el workspace
3. Marcar la opción **Público**
4. Guardar

O directamente en la BD:

```sql
UPDATE claro_workspace SET is_public = 1 WHERE slug = 'nombre-del-workspace';
```
