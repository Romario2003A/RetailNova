USE RetailNova_OLTP;
GO
SET STATISTICS IO ON;
SET STATISTICS TIME ON;
GO

-- Consulta 1 antes: filtro no SARGable por fecha.
SELECT COUNT(*) AS pedidos_2026
FROM dbo.Pedidos
WHERE YEAR(fecha_pedido) = 2026;

-- Consulta 1 despues: rango SARGable.
SELECT COUNT(*) AS pedidos_2026
FROM dbo.Pedidos
WHERE fecha_pedido >= '20260101' AND fecha_pedido < '20270101';

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Pedidos_Fecha_Estado_Cubriente' AND object_id = OBJECT_ID('dbo.Pedidos'))
    CREATE INDEX IX_Pedidos_Fecha_Estado_Cubriente
    ON dbo.Pedidos(fecha_pedido, estado)
    INCLUDE(monto_total, cliente_id, tienda_id);
GO

-- Consulta 2 antes: agregacion amplia para clientes con compras.
SELECT TOP (50) c.cliente_id, c.nombre_completo, SUM(p.monto_total) AS venta_total
FROM dbo.Clientes c
JOIN dbo.Pedidos p ON p.cliente_id = c.cliente_id
WHERE c.cliente_id IN (
    SELECT cliente_id FROM dbo.Pedidos WHERE estado IN ('Pagado','Enviado')
)
GROUP BY c.cliente_id, c.nombre_completo
ORDER BY venta_total DESC;

-- Consulta 2 despues: filtro temprano, TOP y EXISTS.
SELECT TOP (50) c.cliente_id, c.nombre_completo, SUM(p.monto_total) AS venta_total
FROM dbo.Clientes c
JOIN dbo.Pedidos p ON p.cliente_id = c.cliente_id
WHERE p.estado IN ('Pagado','Enviado')
  AND EXISTS (
      SELECT 1
      FROM dbo.Pedidos px
      WHERE px.cliente_id = c.cliente_id
        AND px.estado IN ('Pagado','Enviado')
  )
GROUP BY c.cliente_id, c.nombre_completo
ORDER BY venta_total DESC;
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Pedidos_Estado_Cliente' AND object_id = OBJECT_ID('dbo.Pedidos'))
    CREATE INDEX IX_Pedidos_Estado_Cliente
    ON dbo.Pedidos(estado, cliente_id)
    INCLUDE(monto_total, fecha_pedido);
GO

-- Consulta 3 antes: paginacion profunda con OFFSET.
SELECT pedido_id, fecha_pedido, cliente_id, estado, monto_total
FROM dbo.Pedidos
ORDER BY fecha_pedido DESC, pedido_id DESC
OFFSET 80000 ROWS FETCH NEXT 50 ROWS ONLY;

-- Consulta 3 despues: keyset pagination.
DECLARE @ultima_fecha_pedido DATETIME2 = (
    SELECT MIN(fecha_pedido)
    FROM (
        SELECT TOP (80000) fecha_pedido
        FROM dbo.Pedidos
        ORDER BY fecha_pedido DESC
    ) q
);

SELECT TOP (50) pedido_id, fecha_pedido, cliente_id, estado, monto_total
FROM dbo.Pedidos
WHERE fecha_pedido < @ultima_fecha_pedido
ORDER BY fecha_pedido DESC, pedido_id DESC;
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Pedidos_Fecha_Pedido' AND object_id = OBJECT_ID('dbo.Pedidos'))
    CREATE INDEX IX_Pedidos_Fecha_Pedido
    ON dbo.Pedidos(fecha_pedido DESC, pedido_id DESC)
    INCLUDE(cliente_id, estado, monto_total);
GO

-- Plan de monitoreo: Query Store y DMV.
ALTER DATABASE RetailNova_OLTP SET QUERY_STORE = ON;
GO

SELECT TOP (20)
    qs.total_elapsed_time / NULLIF(qs.execution_count,0) AS tiempo_promedio,
    qs.total_logical_reads / NULLIF(qs.execution_count,0) AS lecturas_logicas_promedio,
    qs.execution_count AS cantidad_ejecuciones,
    SUBSTRING(st.text, (qs.statement_start_offset/2)+1,
        ((CASE qs.statement_end_offset WHEN -1 THEN DATALENGTH(st.text) ELSE qs.statement_end_offset END
        - qs.statement_start_offset)/2)+1) AS consulta
FROM sys.dm_exec_query_stats qs
CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) st
ORDER BY lecturas_logicas_promedio DESC;
GO

SET STATISTICS IO OFF;
SET STATISTICS TIME OFF;
GO
