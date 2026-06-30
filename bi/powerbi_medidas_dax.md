# Power BI - Medidas DAX

Conectar Power BI a `RetailNova_DWH`.

Tablas principales:

- `HechoVentas`
- `HechoEventosDigitalesDiarios`
- `DimFecha`
- `DimCliente`
- `DimProducto`
- `DimTienda`
- `DimCampania`
- `vw_ventas_diarias_categoria`

## Medidas

```DAX
Ventas Brutas = SUM(HechoVentas[venta_bruta])
```

```DAX
Descuentos = SUM(HechoVentas[descuento])
```

```DAX
Ventas Netas = [Ventas Brutas] - [Descuentos]
```

```DAX
Costo = SUM(HechoVentas[costo])
```

```DAX
Margen = [Ventas Netas] - [Costo]
```

```DAX
% Margen = DIVIDE([Margen], [Ventas Netas])
```

```DAX
Unidades Vendidas = SUM(HechoVentas[cantidad])
```

```DAX
Ticket Promedio = DIVIDE([Ventas Netas], DISTINCTCOUNT(HechoVentas[pedido_id]))
```

```DAX
Eventos Digitales = SUM(HechoEventosDigitalesDiarios[cantidad_eventos])
```

```DAX
Compras Digitales = SUM(HechoEventosDigitalesDiarios[cantidad_compras])
```

## Visuales recomendados

- Tarjetas: ventas netas, margen, porcentaje de margen, unidades vendidas, ticket promedio.
- Linea temporal: ventas netas por fecha.
- Barras: ventas y margen por categoria.
- Barras: ventas por region.
- Matriz: campania, canal, ventas, margen y ticket promedio.
- Grafico de embudo: vista de pagina, vista de producto, agregado al carrito, inicio de pago y compra.
- Segmentadores: fecha, canal, categoria, region y segmento.

## Relato para el tablero

1. La gerencia identifica categorias rentables y canales de mayor crecimiento.
2. Marketing compara campanias por ventas y margen, no solo por clics.
3. Operaciones anticipa quiebres de stock cruzando ventas e inventario.
4. La empresa puede evolucionar hacia nube, gobierno de datos e inteligencia artificial.

