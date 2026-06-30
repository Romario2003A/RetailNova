"""
ETL multi-fuente RetailNova.

Fuentes:
- SQL Server OLTP: RetailNova_OLTP
- MongoDB: retailnova_nosql.eventos_web
- CSV: data/campanias_marketing.csv

Destino:
- SQL Server DWH: RetailNova_DWH
"""

from pathlib import Path

import pandas as pd
import pyodbc
from pymongo import MongoClient


RAIZ = Path(__file__).resolve().parents[1]
RUTA_CSV = RAIZ / "data" / "campanias_marketing.csv"

CONEXION_SQL = (
    "DRIVER={ODBC Driver 18 for SQL Server};"
    "SERVER=localhost;"
    "Trusted_Connection=yes;"
    "TrustServerCertificate=yes;"
)

URI_MONGO = "mongodb://localhost:27017"


def cargar_campanias_csv(cursor):
    campanias = pd.read_csv(RUTA_CSV)
    for fila in campanias.itertuples(index=False):
        cursor.execute(
            """
            IF NOT EXISTS (SELECT 1 FROM RetailNova_DWH.dbo.DimCampania WHERE campania_id = ?)
            INSERT INTO RetailNova_DWH.dbo.DimCampania(campania_id, nombre_campania, canal, objetivo, presupuesto)
            VALUES (?, ?, ?, ?, ?)
            """,
            fila.campania_id,
            fila.campania_id,
            fila.nombre_campania,
            fila.canal,
            fila.objetivo,
            float(fila.presupuesto),
        )


def cargar_eventos_mongodb(cursor):
    mongo = MongoClient(URI_MONGO)
    coleccion = mongo.retailnova_nosql.eventos_web

    pipeline = [
        {
            "$group": {
                "_id": {
                    "fecha": {"$dateToString": {"format": "%Y%m%d", "date": "$fecha_evento"}},
                    "campania_id": "$campania_id",
                    "producto_id": "$producto.producto_id",
                    "tipo_evento": "$tipo_evento",
                },
                "sesiones": {"$addToSet": "$sesion_id"},
                "eventos": {"$sum": 1},
                "carritos": {"$sum": {"$cond": [{"$eq": ["$tipo_evento", "agregado_carrito"]}, 1, 0]}},
                "compras": {"$sum": {"$cond": [{"$eq": ["$tipo_evento", "compra"]}, 1, 0]}},
            }
        }
    ]

    cursor.execute("TRUNCATE TABLE RetailNova_DWH.dbo.HechoEventosDigitalesDiarios;")

    for doc in coleccion.aggregate(pipeline, allowDiskUse=True):
        grupo = doc["_id"]
        campania_id = grupo.get("campania_id")
        producto_id = grupo.get("producto_id")

        cursor.execute(
            """
            SELECT campania_key
            FROM RetailNova_DWH.dbo.DimCampania
            WHERE campania_id = ?
            """,
            campania_id,
        )
        fila_campania = cursor.fetchone()

        cursor.execute(
            """
            SELECT producto_key
            FROM RetailNova_DWH.dbo.DimProducto
            WHERE producto_id = ?
            """,
            producto_id,
        )
        fila_producto = cursor.fetchone()

        cursor.execute(
            """
            INSERT INTO RetailNova_DWH.dbo.HechoEventosDigitalesDiarios
            (fecha_evento_key, campania_key, producto_key, tipo_evento, cantidad_sesiones, cantidad_eventos, cantidad_carritos, cantidad_compras)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            """,
            int(grupo["fecha"]),
            fila_campania.campania_key if fila_campania else None,
            fila_producto.producto_key if fila_producto else None,
            grupo["tipo_evento"],
            len(doc["sesiones"]),
            int(doc["eventos"]),
            int(doc["carritos"]),
            int(doc["compras"]),
        )


def main():
    with pyodbc.connect(CONEXION_SQL, autocommit=False) as conexion:
        cursor = conexion.cursor()
        cargar_campanias_csv(cursor)
        cargar_eventos_mongodb(cursor)
        conexion.commit()


if __name__ == "__main__":
    main()
