-- =============================================================================
-- Claroline Connect v15 — Configuración de página de inicio pública
-- con lista de workspaces visibles para usuarios anónimos
-- =============================================================================
-- Ejecutar como: mysql -u <usuario> -p<contraseña> <base_de_datos> < 01_public_home_setup.sql
-- =============================================================================

-- Detectar el ID del widget "list" dinámicamente (portable entre instalaciones)
SET @widget_list_id = (SELECT id FROM claro_widget WHERE name = 'list' LIMIT 1);

-- UUIDs fijos para el tab y sus componentes (puedes cambiarlos si lo prefieres)
SET @tab_uuid        = 'b117a911-d7e3-4462-8fe4-23d45d3be90e';
SET @container_uuid  = 'ebe8e281-5ca9-4a8c-a868-aac7bf09a745';
SET @instance_uuid   = '6726e628-b610-4ef5-9beb-67fe94ddfe9d';

-- -----------------------------------------------------------------------------
-- 1. Tab principal del contexto público
--    context_name='public' + type='widgets' activa el home con widgets
-- -----------------------------------------------------------------------------
INSERT INTO claro_home_tab
    (parent_id, context_name, type, class, name, longTitle,
     uuid, entity_order, poster, icon, hidden,
     accessible_from, accessible_until, access_code, context_id, views)
VALUES
    (NULL, 'public', 'widgets',
     CONCAT('Claroline',CHAR(92),'HomeBundle',CHAR(92),'Entity',CHAR(92),'Type',CHAR(92),'WidgetsTab'),
     'Inicio', '',
     @tab_uuid, 0, NULL, NULL, 0,
     NULL, NULL, NULL, NULL, 0);

SET @tab_id = LAST_INSERT_ID();

-- -----------------------------------------------------------------------------
-- 2. Registro WidgetsTab (tabla claro_home_tab_widgets)
-- -----------------------------------------------------------------------------
INSERT INTO claro_home_tab_widgets (tab_id)
VALUES (@tab_id);

SET @widgets_tab_id = LAST_INSERT_ID();

-- -----------------------------------------------------------------------------
-- 3. Contenedor de widget
-- -----------------------------------------------------------------------------
INSERT INTO claro_widget_container (uuid)
VALUES (@container_uuid);

SET @container_id = LAST_INSERT_ID();

-- -----------------------------------------------------------------------------
-- 4. Relación tab <-> contenedor (tabla pivote)
-- -----------------------------------------------------------------------------
INSERT INTO claro_home_tab_widgets_containers (tab_id, container_id)
VALUES (@widgets_tab_id, @container_id);

-- -----------------------------------------------------------------------------
-- 5. Instancia del widget (tipo "list" con fuente de datos "workspaces")
-- -----------------------------------------------------------------------------
INSERT INTO claro_widget_instance
    (widget_id, container_id, uuid, data_source_name)
VALUES
    (@widget_list_id, @container_id, @instance_uuid, 'workspaces');

SET @instance_id = LAST_INSERT_ID();

-- -----------------------------------------------------------------------------
-- 6. Configuración del widget list
-- -----------------------------------------------------------------------------
INSERT INTO claro_widget_list
    (widgetInstance_id, paginated, actions, pageSize,
     availablePageSizes, display, availableDisplays,
     filterable, sortable, columnsFilterable,
     count, all_contexts,
     filters, availableFilters, availableColumns,
     displayedColumns, availableSort, card)
VALUES
    (@instance_id,
     1, 1, 15,
     '[15, 30, 60, 120, -1]',
     'list', '["list"]',
     0, 0, 0,
     0, 0,
     '[]', '[]', '[]',
     '[]', '[]',
     '["icon","flags","subtitle","description","footer"]');

-- -----------------------------------------------------------------------------
-- 7. Organización default marcada como pública
--    REQUERIDO: la query de WorkspacesList hace JOIN con claro__organization
--    y filtra WHERE is_public = 1. Sin esto retorna 0 resultados.
-- -----------------------------------------------------------------------------
UPDATE claro__organization
SET is_public = 1
WHERE id = (SELECT MIN(id) FROM (SELECT id FROM claro__organization) AS t);

-- Verificación
SELECT 'claro_home_tab (public)' AS tabla, COUNT(*) AS ok FROM claro_home_tab WHERE context_name = 'public'
UNION ALL
SELECT 'claro_widget_instance (workspaces)', COUNT(*) FROM claro_widget_instance WHERE data_source_name = 'workspaces'
UNION ALL
SELECT 'claro__organization is_public=1', COUNT(*) FROM claro__organization WHERE is_public = 1;
