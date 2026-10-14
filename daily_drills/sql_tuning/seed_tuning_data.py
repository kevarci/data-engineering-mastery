"""
Generador de datos masivos para el laboratorio de SQL Performance Tuning
Genera una base de datos local SQLite (tuning_lab.db) con 100,000+ registros
optimizada para abrir en DBeaver y experimentar con:
- Window Functions (DENSE_RANK, LAG/LEAD, Running Totals)
- Índices y planes de ejecución (EXPLAIN QUERY PLAN)
- Consultas masivas y agregaciones analíticas
"""

import sqlite3
import random
from datetime import datetime, timedelta
from pathlib import Path

DB_PATH = Path(__file__).parent / "tuning_lab.db"

def create_database():
    if DB_PATH.exists():
        DB_PATH.unlink()
        print(f"[*] Base de datos anterior eliminada: {DB_PATH}")

    print(f"[*] Creando nueva base de datos en: {DB_PATH}")
    conn = sqlite3.connect(DB_PATH)
    cur = conn.cursor()

    # Optimizar configuración SQLite para inserción masiva en memoria
    cur.execute("PRAGMA journal_mode = WAL;")
    cur.execute("PRAGMA synchronous = NORMAL;")

    # 1. Tabla de Clientes (DimCustomer)
    print("[*] Creando tabla DimCustomer (5,000 clientes)...")
    cur.execute("""
    CREATE TABLE DimCustomer (
        CustomerID INTEGER PRIMARY KEY,
        CustomerName TEXT NOT NULL,
        Segment TEXT NOT NULL,
        Country TEXT NOT NULL,
        CreatedAt DATE NOT NULL
    );
    """)

    segments = ['Enterprise', 'SMB', 'Retail', 'Government']
    countries = ['US', 'CO', 'ES', 'MX', 'BR', 'AR', 'CA']
    start_date = datetime(2023, 1, 1)

    customers = []
    for i in range(1, 5001):
        created = start_date + timedelta(days=random.randint(0, 365))
        customers.append((
            i,
            f"Customer_{i:04d}",
            random.choice(segments),
            random.choice(countries),
            created.strftime('%Y-%m-%d')
        ))
    cur.executemany("INSERT INTO DimCustomer VALUES (?, ?, ?, ?, ?)", customers)

    # 2. Tabla de Ventas Masivas (FactSales / Orders)
    print("[*] Creando tabla FactSales con 120,000 registros...")
    cur.execute("""
    CREATE TABLE FactSales (
        SaleID INTEGER PRIMARY KEY AUTOINCREMENT,
        CustomerID INTEGER NOT NULL,
        SaleDate TIMESTAMP NOT NULL,
        Category TEXT NOT NULL,
        Amount REAL NOT NULL,
        Status TEXT NOT NULL,
        RegionID INTEGER NOT NULL,
        FOREIGN KEY (CustomerID) REFERENCES DimCustomer (CustomerID)
    );
    """)

    categories = ['Electronics', 'Home & Kitchen', 'Books', 'Clothing', 'Cloud Services', 'Automotive']
    statuses = ['COMPLETED'] * 95 + ['PENDING'] * 3 + ['CANCELLED'] * 2  # 95% completados, 3% pendientes
    base_sale_date = datetime(2025, 1, 1)

    batch_size = 20000
    total_sales = 120000
    
    for batch_num in range(0, total_sales, batch_size):
        sales_batch = []
        for _ in range(batch_size):
            cust_id = random.randint(1, 5000)
            sale_date = base_sale_date + timedelta(
                days=random.randint(0, 650),
                hours=random.randint(0, 23),
                minutes=random.randint(0, 59)
            )
            cat = random.choice(categories)
            amt = round(random.uniform(15.0, 3500.0), 2)
            st = random.choice(statuses)
            reg = random.randint(1, 8)
            sales_batch.append((cust_id, sale_date.strftime('%Y-%m-%d %H:%M:%S'), cat, amt, st, reg))
        
        cur.executemany("""
        INSERT INTO FactSales (CustomerID, SaleDate, Category, Amount, Status, RegionID)
        VALUES (?, ?, ?, ?, ?, ?)
        """, sales_batch)
        print(f"    -> Insertadas {batch_num + batch_size:,} de {total_sales:,} filas...")

    # Crear vista 'orders' para compatibilidad directa con 01_window_functions.sql
    cur.execute("""
    CREATE VIEW orders AS
    SELECT 
        SaleID AS order_id,
        CustomerID AS customer_id,
        DATE(SaleDate) AS order_date,
        Category AS category,
        Amount AS amount
    FROM FactSales;
    """)

    conn.commit()
    conn.close()

    print(f"\n[OK] Base de datos creada con exito!")
    print(f"     Archivo: {DB_PATH.resolve()}")
    print(f"     Tamano aproximado: {DB_PATH.stat().st_size / (1024*1024):.2f} MB")

if __name__ == "__main__":
    create_database()
