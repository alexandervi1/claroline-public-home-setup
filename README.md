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

## Uso rápido (script automático)

### Requisitos

```bash
# Ubuntu/Debian
apt install sshpass

# macOS
brew install hudochenkov/sshpass/sshpass
```

### Instalar

```bash
git clone https://github.com/alexandervi1/claroline-public-home-setup.git
cd claroline-public-home-setup
chmod +x setup.sh verify.sh

./setup.sh \
  --host 192.168.1.10 \
  --ssh-user avpro2029 \
  --ssh-pass TuPasswordSSH \
  --db-user claroline_user \
  --db-pass "TuPasswordMySQL" \
  --db-name claroline_db \
  --domain claroline.tudominio.com
```

### Verificar

```bash
./verify.sh \
  --host 192.168.1.10 \
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

## Paso a paso manual

### 1. Modificar platform_options.json

Archivo: `/var/www/claroline/files/config/platform_options.json`

```json
// ANTES
"home": { "type": "none", "data": null }

// DESPUÉS
"home": { "type": "tool", "data": null }
```

O con el script Python incluido:

```bash
pip install paramiko
python3 config/patch_platform_options.py \
  --host 192.168.1.10 --user avpro2029 --password TuPassword
```

> **Por qué `"tool"` y no otro valor:** El código fuente de `PublicContext.php` tiene la verificación explícita `return 'tool' === $this->config->getParameter('home.type');`. Cualquier otro valor deja el contexto público desactivado.

### 2. Ejecutar el SQL

```bash
mysql -u claroline_user -p claroline_db < sql/01_public_home_setup.sql
```

El script crea estos registros:

```
claro_home_tab                    tab con context_name='public', type='widgets'
claro_home_tab_widgets            configuracion WidgetsTab vinculada al tab
claro_widget_container            contenedor columna para los widgets
claro_home_tab_widgets_containers relacion tab <-> contenedor (tabla pivote)
claro_widget_instance             widget tipo 'list' con fuente 'workspaces'
claro_widget_list                 opciones de visualizacion (paginado, 15/pag, etc.)
claro__organization               is_public=1 en la organizacion por defecto
```

### 3. Limpiar caché

```bash
cd /var/www/claroline
sudo -u www-data php bin/console cache:clear
sudo -u www-data php bin/console cache:warmup
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
├── setup.sh                        <- Script de instalacion automatica
├── verify.sh                       <- Script de verificacion post-instalacion
├── sql/
│   └── 01_public_home_setup.sql    <- SQL portable (widget ID dinamico)
└── config/
    └── patch_platform_options.py   <- Script Python para parche via SSH
```

---

## Prerequisitos del servidor destino

- Claroline Connect 15.x instalado y funcionando
- Usuario SSH con permisos `sudo`
- MySQL/MariaDB accesible desde el servidor
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
