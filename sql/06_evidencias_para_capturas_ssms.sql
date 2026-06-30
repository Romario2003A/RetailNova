/*
RetailNova - Script para tomar evidencias en SSMS

Instrucciones:
1. Abrir este archivo en SQL Server Management Studio.
2. Ejecutar un bloque por vez.
3. Tomar captura de pantalla donde se vea:
   - el codigo ejecutado,
   - el resultado,
   - y, si aplica, STATISTICS IO/TIME o el plan de ejecucion.

Antes de iniciar:
- En SSMS activar: Query > Include Actual Execution Plan.
- Para las evidencias de rendimiento, dejar visible la pestana Messages.
*/

/* ============================================================
EVIDENCIA 1 - Bases creadas
Objetivo: demostrar que existen la base transaccional y el DWH.
Captura: resultado con RetailNova_OLTP y RetailNova_DWH.
============================================================ */
SELECT name AS base_de_datos
FROM sys.databases
WHERE name IN ('RetailNova_OLTP', 'RetailNova_DWH')
ORDER BY name;
GO


/* ============================================================
EVIDENCIA 2 - Tablas OLTP en espanol
Objetivo: demostrar el modelo transaccional.
Captura: lista de tablas Clientes, Pedidos, DetallePedido, etc.
============================================================ */
USE RetailNova_OLTP;
GO
SELECT name AS tabla_oltp
FROM sys.tables
ORDER BY name;
GO


/* ============================================================
EVIDENCIA 3 - Volumen de datos
Objetivo: demostrar que hay datos suficientes para rendimiento.
Captura esperada:
- 12000 clientes
- 120000 pedidos
- 240000 detalle_pedidos
- 300 productos
============================================================ */
SELECT
    (SELECT COUNT(*) FROM dbo.Clientes) AS clientes,
    (SELECT COUNT(*) FROM dbo.Pedidos) AS pedidos,
    (SELECT COUNT(*) FROM dbo.DetallePedido) AS detalle_pedidos,
    (SELECT COUNT(*) FROM dbo.Productos) AS productos;
GO


/* ============================================================
EVIDENCIA 4 - Modelo relacional con JOIN
Objetivo: demostrar que las tablas estan relacionadas.
Captura: pedidos unidos con cliente, tienda, producto y detalle.
============================================================ */
SELECT TOP (10)
    p.pedido_id,
    p.fecha_pedido,
    c.nombre_completo,
    t.nombre_tienda,
    pr.nombre_producto,
    dp.cantidad,
    dp.precio_unitario,
    dp.total_linea
FROM dbo.Pedidos p
JOIN dbo.Clientes c ON c.cliente_id = p.cliente_id
JOIN dbo.Tiendas t ON t.tienda_id = p.tienda_id
JOIN dbo.DetallePedido dp ON dp.pedido_id = p.pedido_id
JOIN dbo.Productos pr ON pr.producto_id = dp.producto_id
ORDER BY p.fecha_pedido DESC;
GO


/* ============================================================
EVIDENCIA 5 - Consulta lenta ANTES
Objetivo: mostrar consulta no SARGable.
Captura:
- codigo con YEAR(fecha_pedido)
- resultado
- pestana Messages con logical reads / elapsed time
- plan de ejecucion si esta activado
============================================================ */
SET STATISTICS IO ON;
SET STATISTICS TIME ON;
GO
SELECT COUNT(*) AS pedidos_2026_no_sargable
FROM dbo.Pedidos
WHERE YEAR(fecha_pedido) = 2026;
GO
SET STATISTICS IO OFF;
SET STATISTICS TIME OFF;
GO


/* ============================================================
EVIDENCIA 6 - Consulta optimizada DESPUES
Objetivo: mostrar consulta SARGable por rango de fechas.
Captura:
- codigo con rango de fechas
- resultado
- Messages con menos lecturas logicas que la evidencia anterior
============================================================ */
SET STATISTICS IO ON;
SET STATISTICS TIME ON;
GO
SELECT COUNT(*) AS pedidos_2026_sargable
FROM dbo.Pedidos
WHERE fecha_pedido >= '20260101'
  AND fecha_pedido < '20270101';
GO
SET STATISTICS IO OFF;
SET STATISTICS TIME OFF;
GO


/* ============================================================
EVIDENCIA 7 - Indices implementados
Objetivo: demostrar estrategia de indices.
Captura: nombres de indices sobre Pedidos.
============================================================ */
SELECT
    i.name AS indice,
    COL_NAME(ic.object_id, ic.column_id) AS columna,
    ic.key_ordinal,
    ic.is_included_column
FROM sys.indexes i
JOIN sys.index_columns ic
    ON ic.object_id = i.object_id
   AND ic.index_id = i.index_id
WHERE i.object_id = OBJECT_ID('dbo.Pedidos')
ORDER BY i.name, ic.key_ordinal, ic.index_column_id;
GO


/* ============================================================
EVIDENCIA 8 - Query Store y monitoreo
Objetivo: demostrar plan de monitoreo.
Captura: estado de Query Store y DMV con consultas costosas.
============================================================ */
SELECT
    actual_state_desc AS estado_query_store,
    desired_state_desc AS estado_deseado
FROM sys.database_query_store_options;
GO

SELECT TOP (10)
    qs.total_elapsed_time / NULLIF(qs.execution_count,0) AS tiempo_promedio,
    qs.total_logical_reads / NULLIF(qs.execution_count,0) AS lecturas_logicas_promedio,
    qs.execution_count AS cantidad_ejecuciones,
    LEFT(REPLACE(REPLACE(st.text, CHAR(13), ' '), CHAR(10), ' '), 180) AS consulta
FROM sys.dm_exec_query_stats qs
CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) st
ORDER BY lecturas_logicas_promedio DESC;
GO


/* ============================================================
EVIDENCIA 9 - Roles y permisos
Objetivo: demostrar RBAC y minimo privilegio.
Captura: roles creados y permisos/denegaciones.
============================================================ */
SELECT name AS rol
FROM sys.database_principals
WHERE type = 'R'
  AND name LIKE 'rol_%'
ORDER BY name;
GO

SELECT
    USER_NAME(grantee_principal_id) AS rol,
    permission_name AS permiso,
    state_desc AS estado,
    OBJECT_NAME(major_id) AS objeto
FROM sys.database_permissions
WHERE USER_NAME(grantee_principal_id) LIKE 'rol_%'
ORDER BY rol, objeto, permiso;
GO


/* ============================================================
EVIDENCIA 10 - Enmascaramiento de datos sensibles
Objetivo: demostrar Dynamic Data Masking.
Captura: columnas numero_documento, correo y telefono.
============================================================ */
SELECT
    OBJECT_NAME(object_id) AS tabla,
    name AS columna_enmascarada,
    masking_function
FROM sys.masked_columns
WHERE object_id = OBJECT_ID('dbo.Clientes');
GO


/* ============================================================
EVIDENCIA 11 - Row-Level Security
Objetivo: demostrar que existe politica de filtro por region.
Captura: Politica_Clientes_PorRegion y funcion fn_filtro_region.
============================================================ */
SELECT
    name AS politica_seguridad,
    is_enabled
FROM sys.security_policies;
GO

SELECT
    OBJECT_SCHEMA_NAME(object_id) AS esquema,
    name AS funcion_seguridad
FROM sys.objects
WHERE name = 'fn_filtro_region';
GO


/* ============================================================
EVIDENCIA 12 - Auditoria
Objetivo: demostrar registro de cambios en pedidos.
Captura: UPDATE ejecutado y tabla AuditoriaPedidos con registros.
============================================================ */
UPDATE TOP (1) dbo.Pedidos
SET estado = estado
WHERE estado = 'Pagado';
GO

SELECT TOP (10)
    auditoria_id,
    pedido_id,
    tipo_accion,
    usuario_cambio,
    fecha_cambio,
    estado_anterior,
    estado_nuevo,
    monto_anterior,
    monto_nuevo
FROM dbo.AuditoriaPedidos
ORDER BY auditoria_id DESC;
GO


/* ============================================================
EVIDENCIA 13 - Tablas del Data Warehouse
Objetivo: demostrar modelo dimensional.
Captura: dimensiones y hechos del DWH.
============================================================ */
USE RetailNova_DWH;
GO
SELECT name AS tabla_dwh
FROM sys.tables
ORDER BY name;
GO


/* ============================================================
EVIDENCIA 14 - Conteos del DWH
Objetivo: demostrar carga del DWH.
Captura esperada:
- 227318 filas en HechoVentas
- 25000 filas en HechoEventosDigitalesDiarios
============================================================ */
SELECT
    (SELECT COUNT(*) FROM dbo.DimFecha) AS fechas,
    (SELECT COUNT(*) FROM dbo.DimCliente) AS clientes,
    (SELECT COUNT(*) FROM dbo.DimProducto) AS productos,
    (SELECT COUNT(*) FROM dbo.DimTienda) AS tiendas,
    (SELECT COUNT(*) FROM dbo.DimCampania) AS campanias,
    (SELECT COUNT(*) FROM dbo.HechoVentas) AS hecho_ventas,
    (SELECT COUNT(*) FROM dbo.HechoEventosDigitalesDiarios) AS hecho_eventos;
GO


/* ============================================================
EVIDENCIA 15 - Vista agregada para BI
Objetivo: demostrar datos listos para Power BI.
Captura: ventas por fecha, categoria y canal.
============================================================ */
SELECT TOP (15)
    fecha,
    nombre_categoria,
    canal,
    unidades_vendidas,
    venta_bruta,
    descuentos,
    costos,
    margen
FROM dbo.vw_ventas_diarias_categoria
ORDER BY fecha DESC, venta_bruta DESC;
GO


/* ============================================================
EVIDENCIA 16 - Eventos digitales integrados desde MongoDB
Objetivo: demostrar que MongoDB alimento el DWH.
Captura: tipos de evento con 5000 registros cada uno.
============================================================ */
SELECT
    tipo_evento,
    SUM(cantidad_eventos) AS cantidad_eventos,
    SUM(cantidad_sesiones) AS cantidad_sesiones,
    SUM(cantidad_carritos) AS cantidad_carritos,
    SUM(cantidad_compras) AS cantidad_compras
FROM dbo.HechoEventosDigitalesDiarios
GROUP BY tipo_evento
ORDER BY tipo_evento;
GO


/* ============================================================
EVIDENCIA 17 - Indice columnstore analitico
Objetivo: demostrar optimizacion del DWH.
Captura: NCCI_HechoVentas_Analitico.
============================================================ */
SELECT
    i.name AS indice,
    i.type_desc AS tipo_indice,
    OBJECT_NAME(i.object_id) AS tabla
FROM sys.indexes i
WHERE i.object_id = OBJECT_ID('dbo.HechoVentas')
ORDER BY i.name;
GO

