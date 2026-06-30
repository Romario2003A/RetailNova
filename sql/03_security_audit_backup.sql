USE RetailNova_OLTP;
GO

IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'rol_operador_ventas') CREATE ROLE rol_operador_ventas;
IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'rol_analista_bi') CREATE ROLE rol_analista_bi;
IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'rol_auditor_seguridad') CREATE ROLE rol_auditor_seguridad;
GO

GRANT SELECT, INSERT, UPDATE ON dbo.Pedidos TO rol_operador_ventas;
GRANT SELECT, INSERT ON dbo.DetallePedido TO rol_operador_ventas;
GRANT SELECT ON dbo.Productos TO rol_operador_ventas;

GRANT SELECT ON dbo.Pedidos TO rol_analista_bi;
GRANT SELECT ON dbo.DetallePedido TO rol_analista_bi;
GRANT SELECT ON dbo.Productos TO rol_analista_bi;
GRANT SELECT ON dbo.Categorias TO rol_analista_bi;
GRANT SELECT ON dbo.Tiendas TO rol_analista_bi;
DENY SELECT ON dbo.Clientes(numero_documento, correo, telefono) TO rol_analista_bi;

GRANT SELECT TO rol_auditor_seguridad;
GO

IF SCHEMA_ID('Seguridad') IS NULL EXEC('CREATE SCHEMA Seguridad');
GO

CREATE OR ALTER FUNCTION Seguridad.fn_filtro_region(@region AS VARCHAR(60))
RETURNS TABLE
WITH SCHEMABINDING
AS
RETURN SELECT 1 AS resultado_filtro_seguridad
WHERE @region = CAST(SESSION_CONTEXT(N'region_usuario') AS VARCHAR(60))
   OR IS_ROLEMEMBER('db_owner') = 1;
GO

IF EXISTS (SELECT 1 FROM sys.security_policies WHERE name = 'Politica_Clientes_PorRegion')
    DROP SECURITY POLICY Seguridad.Politica_Clientes_PorRegion;
GO

CREATE SECURITY POLICY Seguridad.Politica_Clientes_PorRegion
ADD FILTER PREDICATE Seguridad.fn_filtro_region(region) ON dbo.Clientes
WITH (STATE = ON);
GO

DROP TABLE IF EXISTS dbo.AuditoriaPedidos;
GO
CREATE TABLE dbo.AuditoriaPedidos (
    auditoria_id BIGINT IDENTITY(1,1) PRIMARY KEY,
    pedido_id BIGINT NOT NULL,
    tipo_accion VARCHAR(10) NOT NULL,
    usuario_cambio SYSNAME NOT NULL DEFAULT SUSER_SNAME(),
    fecha_cambio DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
    estado_anterior VARCHAR(20) NULL,
    estado_nuevo VARCHAR(20) NULL,
    monto_anterior DECIMAL(14,2) NULL,
    monto_nuevo DECIMAL(14,2) NULL
);
GO

CREATE OR ALTER TRIGGER dbo.trg_AuditoriaPedidos
ON dbo.Pedidos
AFTER UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO dbo.AuditoriaPedidos(pedido_id, tipo_accion, estado_anterior, estado_nuevo, monto_anterior, monto_nuevo)
    SELECT COALESCE(i.pedido_id, d.pedido_id),
           CASE WHEN i.pedido_id IS NULL THEN 'DELETE' ELSE 'UPDATE' END,
           d.estado, i.estado, d.monto_total, i.monto_total
    FROM inserted i
    FULL JOIN deleted d ON d.pedido_id = i.pedido_id;
END;
GO

-- Prueba rapida de auditoria.
UPDATE TOP (1) dbo.Pedidos
SET estado = estado
WHERE estado = 'Pagado';

SELECT TOP (5) * FROM dbo.AuditoriaPedidos ORDER BY auditoria_id DESC;
GO

/*
Plan de contingencia:
- Backup completo diario a las 23:00.
- Backup diferencial cada 6 horas.
- Backup del log cada 15 minutos.
- RPO: 15 minutos.
- RTO: 60 minutos.
- Recuperacion: restaurar completo, diferencial y logs hasta el punto requerido; validar con DBCC CHECKDB y pruebas de humo.
*/
