/*
Demo corta para exposicion.
Usar este archivo en SSMS para mostrar evidencias sin abrir scripts largos.
*/

-- 1. Volumen OLTP y tablas principales
USE RetailNova_OLTP;
GO
SELECT
    (SELECT COUNT(*) FROM dbo.Clientes) AS clientes,
    (SELECT COUNT(*) FROM dbo.Pedidos) AS pedidos,
    (SELECT COUNT(*) FROM dbo.DetallePedido) AS detalle_pedidos,
    (SELECT COUNT(*) FROM dbo.Productos) AS productos;
GO

-- 2. Ejemplo de modelo relacional: pedidos conectados con cliente, tienda y producto.
-- Un pedido puede aparecer mas de una vez porque tiene varios productos en DetallePedido.
SELECT TOP (8)
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

-- 3. Optimizacion: antes y despues de una consulta no SARGable
SET STATISTICS IO ON;
SET STATISTICS TIME ON;

SELECT COUNT(*) AS pedidos_2026_no_sargable
FROM dbo.Pedidos
WHERE YEAR(fecha_pedido) = 2026;

SELECT COUNT(*) AS pedidos_2026_sargable
FROM dbo.Pedidos
WHERE fecha_pedido >= '20260101' AND fecha_pedido < '20270101';

SET STATISTICS IO OFF;
SET STATISTICS TIME OFF;
GO

-- 4. Indices creados sobre Pedidos
SELECT
    i.name AS indice,
    COL_NAME(ic.object_id, ic.column_id) AS columna,
    ic.key_ordinal,
    ic.is_included_column
FROM sys.indexes i
JOIN sys.index_columns ic ON ic.object_id = i.object_id AND ic.index_id = i.index_id
WHERE i.object_id = OBJECT_ID('dbo.Pedidos')
ORDER BY i.name, ic.key_ordinal, ic.index_column_id;
GO

-- 5. Seguridad: roles, enmascaramiento y auditoria
SELECT name AS rol
FROM sys.database_principals
WHERE type = 'R' AND name LIKE 'rol_%';

SELECT name AS columna_enmascarada, masking_function
FROM sys.masked_columns
WHERE object_id = OBJECT_ID('dbo.Clientes');

UPDATE TOP (1) dbo.Pedidos
SET estado = estado
WHERE estado = 'Pagado';

SELECT TOP (5)
    auditoria_id,
    pedido_id,
    tipo_accion,
    usuario_cambio,
    fecha_cambio,
    estado_anterior,
    estado_nuevo
FROM dbo.AuditoriaPedidos
ORDER BY auditoria_id DESC;
GO

-- 6. DWH: modelo dimensional y hechos
USE RetailNova_DWH;
GO
SELECT
    (SELECT COUNT(*) FROM dbo.DimFecha) AS fechas,
    (SELECT COUNT(*) FROM dbo.DimCliente) AS clientes,
    (SELECT COUNT(*) FROM dbo.DimProducto) AS productos,
    (SELECT COUNT(*) FROM dbo.DimTienda) AS tiendas,
    (SELECT COUNT(*) FROM dbo.DimCampania) AS campanias,
    (SELECT COUNT(*) FROM dbo.HechoVentas) AS hechos_ventas,
    (SELECT COUNT(*) FROM dbo.HechoEventosDigitalesDiarios) AS hechos_eventos;
GO

-- 7. Vista agregada para BI
SELECT TOP (10)
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

-- 8. Eventos digitales cargados desde MongoDB
SELECT
    tipo_evento,
    SUM(cantidad_eventos) AS cantidad_eventos,
    SUM(cantidad_sesiones) AS cantidad_sesiones
FROM dbo.HechoEventosDigitalesDiarios
GROUP BY tipo_evento
ORDER BY cantidad_eventos DESC;
GO
