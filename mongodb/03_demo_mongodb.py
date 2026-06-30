from pprint import pprint

from pymongo import MongoClient


cliente = MongoClient("mongodb://localhost:27017", serverSelectionTimeoutMS=5000)
coleccion = cliente.retailnova_nosql.eventos_web

print("Cantidad de documentos:", coleccion.count_documents({}))
print("\nDocumento de ejemplo:")
pprint(coleccion.find_one({}, {"_id": 0}))

print("\nEmbudo por campania y tipo de evento:")
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
    pprint(fila)

