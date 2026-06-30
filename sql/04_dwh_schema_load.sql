SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET ANSI_PADDING ON;
SET ANSI_WARNINGS ON;
SET CONCAT_NULL_YIELDS_NULL ON;
SET ARITHABORT ON;
SET NUMERIC_ROUNDABORT OFF;
SET NOCOUNT ON;

IF DB_ID('RetailNova_DWH') IS NULL CREATE DATABASE RetailNova_DWH;
GO
USE RetailNova_DWH;
GO

DROP TABLE IF EXISTS dbo.HechoVentas;
DROP TABLE IF EXISTS dbo.HechoEventosDigitalesDiarios;
DROP TABLE IF EXISTS dbo.DimCampania;
DROP TABLE IF EXISTS dbo.DimCliente;
DROP TABLE IF EXISTS dbo.DimProducto;
DROP TABLE IF EXISTS dbo.DimTienda;
DROP TABLE IF EXISTS dbo.DimFecha;
GO

CREATE TABLE dbo.DimFecha (
    fecha_key INT NOT NULL PRIMARY KEY,
    fecha DATE NOT NULL UNIQUE,
    anio INT NOT NULL,
    mes INT NOT NULL,
    dia INT NOT NULL,
    nombre_mes VARCHAR(20) NOT NULL
);

CREATE TABLE dbo.DimCliente (
    cliente_key INT IDENTITY(1,1) PRIMARY KEY,
    cliente_id INT NOT NULL,
    region VARCHAR(60) NOT NULL,
    segmento VARCHAR(20) NOT NULL
);

CREATE TABLE dbo.DimProducto (
    producto_key INT IDENTITY(1,1) PRIMARY KEY,
    producto_id INT NOT NULL,
    sku VARCHAR(30) NOT NULL,
    nombre_producto VARCHAR(160) NOT NULL,
    nombre_categoria VARCHAR(80) NOT NULL
);

CREATE TABLE dbo.DimTienda (
    tienda_key INT IDENTITY(1,1) PRIMARY KEY,
    tienda_id INT NOT NULL,
    nombre_tienda VARCHAR(120) NOT NULL,
    region VARCHAR(60) NOT NULL,
    canal VARCHAR(20) NOT NULL
);

CREATE TABLE dbo.DimCampania (
    campania_key INT IDENTITY(1,1) PRIMARY KEY,
    campania_id VARCHAR(20) NOT NULL UNIQUE,
    nombre_campania VARCHAR(120) NOT NULL,
    canal VARCHAR(40) NOT NULL,
    objetivo VARCHAR(40) NOT NULL,
    presupuesto DECIMAL(14,2) NOT NULL
);

CREATE TABLE dbo.HechoVentas (
    venta_key BIGINT IDENTITY(1,1) NOT NULL,
    fecha_key INT NOT NULL,
    cliente_key INT NOT NULL,
    producto_key INT NOT NULL,
    tienda_key INT NOT NULL,
    campania_key INT NULL,
    pedido_id BIGINT NOT NULL,
    cantidad INT NOT NULL,
    venta_bruta DECIMAL(14,2) NOT NULL,
    descuento DECIMAL(14,2) NOT NULL,
    costo DECIMAL(14,2) NOT NULL,
    margen AS (venta_bruta - descuento - costo) PERSISTED,
    CONSTRAINT PK_HechoVentas PRIMARY KEY NONCLUSTERED (venta_key)
);

CREATE TABLE dbo.HechoEventosDigitalesDiarios (
    fecha_evento_key INT NOT NULL,
    campania_key INT NULL,
    producto_key INT NULL,
    tipo_evento VARCHAR(40) NOT NULL,
    cantidad_sesiones INT NOT NULL,
    cantidad_eventos INT NOT NULL,
    cantidad_carritos INT NOT NULL,
    cantidad_compras INT NOT NULL
);
GO

INSERT INTO dbo.DimFecha(fecha_key, fecha, anio, mes, dia, nombre_mes)
SELECT DISTINCT
    CONVERT(INT, FORMAT(CAST(p.fecha_pedido AS DATE), 'yyyyMMdd')),
    CAST(p.fecha_pedido AS DATE),
    YEAR(p.fecha_pedido),
    MONTH(p.fecha_pedido),
    DAY(p.fecha_pedido),
    DATENAME(MONTH, p.fecha_pedido)
FROM RetailNova_OLTP.dbo.Pedidos p;

INSERT INTO dbo.DimCliente(cliente_id, region, segmento)
SELECT cliente_id, region, segmento
FROM RetailNova_OLTP.dbo.Clientes;

INSERT INTO dbo.DimProducto(producto_id, sku, nombre_producto, nombre_categoria)
SELECT p.producto_id, p.sku, p.nombre_producto, c.nombre_categoria
FROM RetailNova_OLTP.dbo.Productos p
JOIN RetailNova_OLTP.dbo.Categorias c ON c.categoria_id = p.categoria_id;

INSERT INTO dbo.DimTienda(tienda_id, nombre_tienda, region, canal)
SELECT tienda_id, nombre_tienda, region, canal
FROM RetailNova_OLTP.dbo.Tiendas;

INSERT INTO dbo.DimCampania(campania_id, nombre_campania, canal, objetivo, presupuesto)
VALUES
('CMP001','Hot Sale Peru','Email','Conversion',8500),
('CMP002','Tech Week','Social Ads','Ventas',12000),
('CMP003','Hogar Inteligente','Search Ads','Conversion',9500),
('CMP004','Clientes VIP','Push','Retencion',3500),
('CMP005','Renueva tu laptop','Social Ads','Ventas',11000),
('CMP006','Moda Express','Email','Conversion',6000);

INSERT INTO dbo.HechoVentas(fecha_key, cliente_key, producto_key, tienda_key, campania_key, pedido_id, cantidad, venta_bruta, descuento, costo)
SELECT
    CONVERT(INT, FORMAT(CAST(p.fecha_pedido AS DATE), 'yyyyMMdd')),
    dc.cliente_key,
    dp.producto_key,
    dt.tienda_key,
    dca.campania_key,
    p.pedido_id,
    dped.cantidad,
    dped.cantidad * dped.precio_unitario,
    CASE WHEN p.monto_total = 0 THEN 0 ELSE p.monto_descuento * ((dped.cantidad * dped.precio_unitario) / NULLIF(p.monto_total,0)) END,
    dped.cantidad * dped.costo_unitario
FROM RetailNova_OLTP.dbo.Pedidos p
JOIN RetailNova_OLTP.dbo.DetallePedido dped ON dped.pedido_id = p.pedido_id
JOIN dbo.DimCliente dc ON dc.cliente_id = p.cliente_id
JOIN dbo.DimProducto dp ON dp.producto_id = dped.producto_id
JOIN dbo.DimTienda dt ON dt.tienda_id = p.tienda_id
LEFT JOIN dbo.DimCampania dca ON dca.campania_id = p.campania_id
WHERE p.estado IN ('Pagado','Enviado');
GO

CREATE NONCLUSTERED COLUMNSTORE INDEX NCCI_HechoVentas_Analitico
ON dbo.HechoVentas(fecha_key, cliente_key, producto_key, tienda_key, campania_key, cantidad, venta_bruta, descuento, costo);

CREATE INDEX IX_HechoEventos_Fecha_Tipo ON dbo.HechoEventosDigitalesDiarios(fecha_evento_key, tipo_evento);
GO

CREATE OR ALTER VIEW dbo.vw_ventas_diarias_categoria
AS
SELECT f.fecha, p.nombre_categoria, t.canal,
       SUM(h.cantidad) AS unidades_vendidas,
       SUM(h.venta_bruta) AS venta_bruta,
       SUM(h.descuento) AS descuentos,
       SUM(h.costo) AS costos,
       SUM(h.margen) AS margen
FROM dbo.HechoVentas h
JOIN dbo.DimFecha f ON f.fecha_key = h.fecha_key
JOIN dbo.DimProducto p ON p.producto_key = h.producto_key
JOIN dbo.DimTienda t ON t.tienda_key = h.tienda_key
GROUP BY f.fecha, p.nombre_categoria, t.canal;
GO

SELECT COUNT(*) AS filas_hecho_ventas FROM dbo.HechoVentas;
GO
