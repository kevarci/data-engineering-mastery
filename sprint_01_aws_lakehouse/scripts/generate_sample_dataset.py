#!/usr/bin/env python3
"""Generador de Dataset Masivo Particionado para el Sprint 1 (Lakehouse en AWS / Databricks).

Genera 100,000 transacciones de e-commerce realistas y las guarda particionadas por
año, mes y día en formato Apache Parquet, listas para subir a Amazon S3.

Uso:
    python generate_sample_dataset.py
"""

import datetime
import os
import random
from pathlib import Path
import pandas as pd
import pyarrow as pa
import pyarrow.parquet as pq

# Semilla para reproducibilidad
random.seed(42)

OUTPUT_DIR = Path(__file__).resolve().parent.parent / "data" / "raw"
NUM_RECORDS = 100_000

CATEGORIES = ["Electronics", "Fashion", "Home & Garden", "Books", "Health & Sports", "Groceries"]
PAYMENT_METHODS = ["Credit Card", "Debit Card", "PayPal", "Crypto", "Wire Transfer"]
COUNTRIES = ["VE", "CO", "CL", "ES", "MX", "AR", "US"]
STATUSES = ["COMPLETED", "COMPLETED", "COMPLETED", "REFUNDED", "FAILED", "PENDING"]

print(f"[*] Generando {NUM_RECORDS:,} transacciones sintéticas...")

# Generar fechas a lo largo de los últimos 30 días
base_date = datetime.date(2026, 9, 15)
dates = [base_date + datetime.timedelta(days=random.randint(0, 28)) for _ in range(NUM_RECORDS)]

data = {
    "transaction_id": [f"TXN-{1000000 + i}" for i in range(NUM_RECORDS)],
    "customer_id": [f"CUST-{random.randint(1000, 9999)}" for _ in range(NUM_RECORDS)],
    "category": [random.choice(CATEGORIES) for _ in range(NUM_RECORDS)],
    "amount": [round(random.uniform(5.50, 850.00), 2) for _ in range(NUM_RECORDS)],
    "payment_method": [random.choice(PAYMENT_METHODS) for _ in range(NUM_RECORDS)],
    "country": [random.choice(COUNTRIES) for _ in range(NUM_RECORDS)],
    "status": [random.choice(STATUSES) for _ in range(NUM_RECORDS)],
    "created_at": [
        datetime.datetime.combine(d, datetime.time(random.randint(0, 23), random.randint(0, 59), random.randint(0, 59)))
        for d in dates
    ]
}

df = pd.DataFrame(data)

# Extraer columnas de partición
df["year"] = df["created_at"].dt.year
df["month"] = df["created_at"].dt.month
df["day"] = df["created_at"].dt.day

print(f"[*] Guardando datos particionados en formato Parquet en: {OUTPUT_DIR}")
OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

# Guardar con particionamiento de Apache Arrow
table = pa.Table.from_pandas(df)
pq.write_to_dataset(
    table,
    root_path=str(OUTPUT_DIR),
    partition_cols=["year", "month", "day"],
    compression="snappy"
)

print("[✓] ¡Dataset generado exitosamente!")
print(f"    Total filas: {len(df):,}")
print(f"    Estructura de partición: {OUTPUT_DIR}/year=YYYY/month=MM/day=DD/*.parquet")
print("    Listo para subir a tu bucket S3: `aws s3 cp data/raw/ s3://<tu-bucket>/bronze/ --recursive`")
