// Ejecutar en mongosh:
// mongosh retailnova_nosql mongodb/01_retailnova_events.js

db.eventos_web.drop();

const campanias = ["CMP001", "CMP002", "CMP003", "CMP004", "CMP005", "CMP006", null];
const tiposEvento = ["vista_pagina", "vista_producto", "agregado_carrito", "inicio_pago", "compra"];
const regiones = ["Lima", "Arequipa", "La Libertad", "Junin", "Piura"];
const categorias = ["Tecnologia", "Hogar", "Moda", "Belleza", "Deportes", "Juguetes"];

const documentos = [];
for (let i = 1; i <= 25000; i++) {
  const productoId = (i % 300) + 1;
  documentos.push({
    sesion_id: `SES-${i.toString().padStart(6, "0")}`,
    cliente_id: (i % 12000) + 1,
    tipo_evento: tiposEvento[i % tiposEvento.length],
    fecha_evento: new Date(Date.now() - i * 60000),
    campania_id: campanias[i % campanias.length],
    dispositivo: {
      tipo: i % 2 === 0 ? "movil" : "escritorio",
      sistema_operativo: i % 3 === 0 ? "Android" : i % 3 === 1 ? "Windows" : "iOS",
      navegador: i % 2 === 0 ? "Chrome" : "Edge"
    },
    ubicacion: {
      pais: "PE",
      region: regiones[i % regiones.length]
    },
    producto: {
      producto_id: productoId,
      sku: `SKU-${productoId.toString().padStart(5, "0")}`,
      categoria: categorias[i % categorias.length]
    },
    carrito: {
      items: [
        { producto_id: productoId, cantidad: (i % 3) + 1, precio: 50 + (i % 500) },
        { producto_id: ((i + 7) % 300) + 1, cantidad: 1, precio: 35 + (i % 200) }
      ],
      cupones: i % 5 === 0 ? ["HOTSALE"] : []
    },
    metadatos: {
      origen: i % 2 === 0 ? "app" : "web",
      experimento: i % 4 === 0 ? "landing_a" : "landing_b"
    }
  });
}

db.eventos_web.insertMany(documentos);
db.eventos_web.createIndex({ fecha_evento: -1, tipo_evento: 1 });
db.eventos_web.createIndex({ cliente_id: 1, fecha_evento: -1 });
db.eventos_web.createIndex({ campania_id: 1, tipo_evento: 1 });

db.eventos_web.aggregate([
  { $match: { campania_id: { $ne: null } } },
  { $group: { _id: { campania_id: "$campania_id", tipo_evento: "$tipo_evento" }, eventos: { $sum: 1 }, sesiones: { $addToSet: "$sesion_id" } } },
  { $project: { campania_id: "$_id.campania_id", tipo_evento: "$_id.tipo_evento", eventos: 1, cantidad_sesiones: { $size: "$sesiones" }, _id: 0 } },
  { $sort: { campania_id: 1, tipo_evento: 1 } }
]);

