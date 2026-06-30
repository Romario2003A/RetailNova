from datetime import datetime, timedelta, timezone

from pymongo import MongoClient


cliente = MongoClient("mongodb://localhost:27017", serverSelectionTimeoutMS=5000)
bd = cliente["retailnova_nosql"]
coleccion = bd["eventos_web"]

coleccion.drop()

campanias = ["CMP001", "CMP002", "CMP003", "CMP004", "CMP005", "CMP006", None]
tipos_evento = ["vista_pagina", "vista_producto", "agregado_carrito", "inicio_pago", "compra"]
regiones = ["Lima", "Arequipa", "La Libertad", "Junin", "Piura"]
categorias = ["Tecnologia", "Hogar", "Moda", "Belleza", "Deportes", "Juguetes"]
ahora = datetime.now(timezone.utc)

lote = []
for i in range(1, 25001):
    producto_id = (i % 300) + 1
    lote.append(
        {
            "sesion_id": f"SES-{i:06d}",
            "cliente_id": (i % 12000) + 1,
            "tipo_evento": tipos_evento[i % len(tipos_evento)],
            "fecha_evento": ahora - timedelta(minutes=i),
            "campania_id": campanias[i % len(campanias)],
            "dispositivo": {
                "tipo": "movil" if i % 2 == 0 else "escritorio",
                "sistema_operativo": "Android" if i % 3 == 0 else "Windows" if i % 3 == 1 else "iOS",
                "navegador": "Chrome" if i % 2 == 0 else "Edge",
            },
            "ubicacion": {"pais": "PE", "region": regiones[i % len(regiones)]},
            "producto": {
                "producto_id": producto_id,
                "sku": f"SKU-{producto_id:05d}",
                "categoria": categorias[i % len(categorias)],
            },
            "carrito": {
                "items": [
                    {"producto_id": producto_id, "cantidad": (i % 3) + 1, "precio": 50 + (i % 500)},
                    {"producto_id": ((i + 7) % 300) + 1, "cantidad": 1, "precio": 35 + (i % 200)},
                ],
                "cupones": ["HOTSALE"] if i % 5 == 0 else [],
            },
            "metadatos": {
                "origen": "app" if i % 2 == 0 else "web",
                "experimento": "landing_a" if i % 4 == 0 else "landing_b",
            },
        }
    )

    if len(lote) == 1000:
        coleccion.insert_many(lote)
        lote.clear()

if lote:
    coleccion.insert_many(lote)

coleccion.create_index([("fecha_evento", -1), ("tipo_evento", 1)])
coleccion.create_index([("cliente_id", 1), ("fecha_evento", -1)])
coleccion.create_index([("campania_id", 1), ("tipo_evento", 1)])

print("base=retailnova_nosql")
print("coleccion=eventos_web")
print("documentos=", coleccion.count_documents({}))

pipeline = [
    {"$match": {"campania_id": {"$ne": None}}},
    {
        "$group": {
            "_id": {"campania_id": "$campania_id", "tipo_evento": "$tipo_evento"},
            "eventos": {"$sum": 1},
            "sesiones": {"$addToSet": "$sesion_id"},
        }
    },
    {
        "$project": {
            "_id": 0,
            "campania_id": "$_id.campania_id",
            "tipo_evento": "$_id.tipo_evento",
            "eventos": 1,
            "cantidad_sesiones": {"$size": "$sesiones"},
        }
    },
    {"$sort": {"campania_id": 1, "tipo_evento": 1}},
    {"$limit": 10},
]

for fila in coleccion.aggregate(pipeline):
    print(fila)

