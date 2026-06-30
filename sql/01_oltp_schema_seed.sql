SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET ANSI_PADDING ON;
SET ANSI_WARNINGS ON;
SET CONCAT_NULL_YIELDS_NULL ON;
SET ARITHABORT ON;
SET NUMERIC_ROUNDABORT OFF;
SET NOCOUNT ON;

IF DB_ID('RetailNova_OLTP') IS NULL CREATE DATABASE RetailNova_OLTP;
GO
USE RetailNova_OLTP;
GO

DROP TABLE IF EXISTS dbo.DetallePedido;
DROP TABLE IF EXISTS dbo.Pagos;
DROP TABLE IF EXISTS dbo.Pedidos;
DROP TABLE IF EXISTS dbo.MovimientosInventario;
DROP TABLE IF EXISTS dbo.Productos;
DROP TABLE IF EXISTS dbo.Clientes;
DROP TABLE IF EXISTS dbo.Tiendas;
DROP TABLE IF EXISTS dbo.Categorias;
GO

CREATE TABLE dbo.Categorias (
    categoria_id INT IDENTITY(1,1) CONSTRAINT PK_Categorias PRIMARY KEY,
    nombre_categoria VARCHAR(80) NOT NULL UNIQUE
);

CREATE TABLE dbo.Tiendas (
    tienda_id INT IDENTITY(1,1) CONSTRAINT PK_Tiendas PRIMARY KEY,
    nombre_tienda VARCHAR(120) NOT NULL,
    region VARCHAR(60) NOT NULL,
    canal VARCHAR(20) NOT NULL CHECK (canal IN ('Web','App','Tienda'))
);

CREATE TABLE dbo.Clientes (
    cliente_id INT IDENTITY(1,1) CONSTRAINT PK_Clientes PRIMARY KEY,
    numero_documento VARCHAR(12) MASKED WITH (FUNCTION = 'partial(2,"******",2)') NOT NULL,
    nombre_completo VARCHAR(140) NOT NULL,
    correo VARCHAR(160) MASKED WITH (FUNCTION = 'email()') NOT NULL,
    telefono VARCHAR(20) MASKED WITH (FUNCTION = 'partial(3,"****",2)') NULL,
    region VARCHAR(60) NOT NULL,
    segmento VARCHAR(20) NOT NULL CHECK (segmento IN ('Nuevo','Regular','VIP','Riesgo')),
    fecha_registro DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME()
);

CREATE TABLE dbo.Productos (
    producto_id INT IDENTITY(1,1) CONSTRAINT PK_Productos PRIMARY KEY,
    sku VARCHAR(30) NOT NULL UNIQUE,
    nombre_producto VARCHAR(160) NOT NULL,
    categoria_id INT NOT NULL CONSTRAINT FK_Productos_Categorias REFERENCES dbo.Categorias(categoria_id),
    costo_unitario DECIMAL(12,2) NOT NULL,
    precio_lista DECIMAL(12,2) NOT NULL,
    activo BIT NOT NULL DEFAULT 1
);

CREATE TABLE dbo.MovimientosInventario (
    movimiento_id BIGINT IDENTITY(1,1) CONSTRAINT PK_MovimientosInventario PRIMARY KEY,
    producto_id INT NOT NULL CONSTRAINT FK_Inventario_Productos REFERENCES dbo.Productos(producto_id),
    tienda_id INT NOT NULL CONSTRAINT FK_Inventario_Tiendas REFERENCES dbo.Tiendas(tienda_id),
    tipo_movimiento VARCHAR(20) NOT NULL CHECK (tipo_movimiento IN ('Entrada','Venta','Ajuste')),
    cantidad INT NOT NULL,
    fecha_movimiento DATETIME2 NOT NULL
);

CREATE TABLE dbo.Pedidos (
    pedido_id BIGINT IDENTITY(1,1) CONSTRAINT PK_Pedidos PRIMARY KEY,
    cliente_id INT NOT NULL CONSTRAINT FK_Pedidos_Clientes REFERENCES dbo.Clientes(cliente_id),
    tienda_id INT NOT NULL CONSTRAINT FK_Pedidos_Tiendas REFERENCES dbo.Tiendas(tienda_id),
    fecha_pedido DATETIME2 NOT NULL,
    estado VARCHAR(20) NOT NULL CHECK (estado IN ('Pagado','Enviado','Cancelado','Devuelto')),
    metodo_pago VARCHAR(30) NOT NULL,
    campania_id VARCHAR(20) NULL,
    monto_total DECIMAL(14,2) NOT NULL,
    monto_descuento DECIMAL(14,2) NOT NULL DEFAULT 0,
    monto_impuesto DECIMAL(14,2) NOT NULL DEFAULT 0
);

CREATE TABLE dbo.DetallePedido (
    detalle_id BIGINT IDENTITY(1,1) CONSTRAINT PK_DetallePedido PRIMARY KEY,
    pedido_id BIGINT NOT NULL CONSTRAINT FK_DetallePedido_Pedidos REFERENCES dbo.Pedidos(pedido_id),
    producto_id INT NOT NULL CONSTRAINT FK_DetallePedido_Productos REFERENCES dbo.Productos(producto_id),
    cantidad INT NOT NULL,
    precio_unitario DECIMAL(12,2) NOT NULL,
    costo_unitario DECIMAL(12,2) NOT NULL,
    total_linea AS (cantidad * precio_unitario) PERSISTED
);

CREATE TABLE dbo.Pagos (
    pago_id BIGINT IDENTITY(1,1) CONSTRAINT PK_Pagos PRIMARY KEY,
    pedido_id BIGINT NOT NULL CONSTRAINT FK_Pagos_Pedidos REFERENCES dbo.Pedidos(pedido_id),
    fecha_pago DATETIME2 NOT NULL,
    monto DECIMAL(14,2) NOT NULL,
    proveedor VARCHAR(40) NOT NULL,
    codigo_autorizacion VARCHAR(40) NULL,
    estado_pago VARCHAR(20) NOT NULL
);
GO

INSERT INTO dbo.Categorias(nombre_categoria)
VALUES ('Tecnologia'),('Hogar'),('Moda'),('Belleza'),('Deportes'),('Juguetes');

INSERT INTO dbo.Tiendas(nombre_tienda, region, canal)
VALUES
('RetailNova Web Lima','Lima','Web'),
('RetailNova App Lima','Lima','App'),
('RetailNova Web Norte','La Libertad','Web'),
('RetailNova App Sur','Arequipa','App'),
('RetailNova Tienda Centro','Junin','Tienda');

;WITH n AS (
    SELECT TOP (300) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS rn
    FROM sys.all_objects a CROSS JOIN sys.all_objects b
)
INSERT INTO dbo.Productos(sku, nombre_producto, categoria_id, costo_unitario, precio_lista)
SELECT CONCAT('SKU-',FORMAT(rn,'00000')), CONCAT('Producto RetailNova ',rn), ((rn - 1) % 6) + 1,
       CAST(20 + (rn % 150) * 1.7 AS DECIMAL(12,2)),
       CAST(35 + (rn % 150) * 2.6 AS DECIMAL(12,2))
FROM n;

;WITH n AS (
    SELECT TOP (12000) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS rn
    FROM sys.all_objects a CROSS JOIN sys.all_objects b
)
INSERT INTO dbo.Clientes(numero_documento, nombre_completo, correo, telefono, region, segmento, fecha_registro)
SELECT RIGHT(CONCAT('00000000', rn), 8), CONCAT('Cliente ', rn), CONCAT('cliente', rn, '@retailnova.test'),
       CONCAT('9', RIGHT(CONCAT('00000000', rn), 8)),
       CHOOSE((rn % 5) + 1, 'Lima','Arequipa','La Libertad','Junin','Piura'),
       CHOOSE((rn % 4) + 1, 'Nuevo','Regular','VIP','Riesgo'),
       DATEADD(DAY, -rn % 730, SYSUTCDATETIME())
FROM n;

;WITH n AS (
    SELECT TOP (120000) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS rn
    FROM sys.all_objects a CROSS JOIN sys.all_objects b CROSS JOIN sys.all_objects c
)
INSERT INTO dbo.Pedidos(cliente_id, tienda_id, fecha_pedido, estado, metodo_pago, campania_id, monto_total, monto_descuento, monto_impuesto)
SELECT ((rn - 1) % 12000) + 1, ((rn - 1) % 5) + 1,
       DATEADD(MINUTE, -rn * 7, SYSUTCDATETIME()),
       CASE WHEN rn % 31 = 0 THEN 'Cancelado' WHEN rn % 47 = 0 THEN 'Devuelto' WHEN rn % 3 = 0 THEN 'Enviado' ELSE 'Pagado' END,
       CHOOSE((rn % 4) + 1, 'Tarjeta','Yape','Plin','Transferencia'),
       CASE WHEN rn % 4 = 0 THEN CONCAT('CMP00', ((rn % 6) + 1)) ELSE NULL END,
       CAST(60 + (rn % 900) * 1.35 AS DECIMAL(14,2)),
       CAST(CASE WHEN rn % 5 = 0 THEN 10 + (rn % 80) ELSE 0 END AS DECIMAL(14,2)),
       CAST((60 + (rn % 900) * 1.35) * 0.18 AS DECIMAL(14,2))
FROM n;

;WITH n AS (
    SELECT TOP (240000) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS rn
    FROM sys.all_objects a CROSS JOIN sys.all_objects b CROSS JOIN sys.all_objects c
)
INSERT INTO dbo.DetallePedido(pedido_id, producto_id, cantidad, precio_unitario, costo_unitario)
SELECT ((rn - 1) % 120000) + 1, ((rn - 1) % 300) + 1, (rn % 4) + 1, p.precio_lista, p.costo_unitario
FROM n
JOIN dbo.Productos p ON p.producto_id = ((rn - 1) % 300) + 1;

INSERT INTO dbo.Pagos(pedido_id, fecha_pago, monto, proveedor, codigo_autorizacion, estado_pago)
SELECT pedido_id, DATEADD(MINUTE, 2, fecha_pedido), monto_total, metodo_pago, CONCAT('AUTH', pedido_id), 'Aprobado'
FROM dbo.Pedidos
WHERE estado IN ('Pagado','Enviado');

INSERT INTO dbo.MovimientosInventario(producto_id, tienda_id, tipo_movimiento, cantidad, fecha_movimiento)
SELECT TOP (50000)
    ((ROW_NUMBER() OVER (ORDER BY p.pedido_id) - 1) % 300) + 1,
    p.tienda_id,
    CASE WHEN ROW_NUMBER() OVER (ORDER BY p.pedido_id) % 3 = 0 THEN 'Entrada' ELSE 'Venta' END,
    CASE WHEN ROW_NUMBER() OVER (ORDER BY p.pedido_id) % 3 = 0 THEN 50 ELSE -1 * ((ROW_NUMBER() OVER (ORDER BY p.pedido_id) % 4) + 1) END,
    p.fecha_pedido
FROM dbo.Pedidos p;
GO

CREATE INDEX IX_Pedidos_Fecha ON dbo.Pedidos(fecha_pedido);
CREATE INDEX IX_Pedidos_Cliente_Fecha ON dbo.Pedidos(cliente_id, fecha_pedido DESC) INCLUDE(monto_total, estado);
CREATE INDEX IX_DetallePedido_Pedido_Producto ON dbo.DetallePedido(pedido_id, producto_id) INCLUDE(cantidad, precio_unitario, costo_unitario);
CREATE INDEX IX_Productos_Categoria ON dbo.Productos(categoria_id) INCLUDE(nombre_producto, precio_lista, costo_unitario);
GO

SELECT
    (SELECT COUNT(*) FROM dbo.Pedidos) AS cantidad_pedidos,
    (SELECT COUNT(*) FROM dbo.DetallePedido) AS cantidad_detalles,
    (SELECT COUNT(*) FROM dbo.Clientes) AS cantidad_clientes;
GO
