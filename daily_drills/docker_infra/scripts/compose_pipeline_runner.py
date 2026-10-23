#!/usr/bin/env python3
"""
==============================================================================
Script: compose_pipeline_runner.py
Estudiante: Kevin Stick Arciniegas Marquez
Tema: Orquestación Multi-Contenedor (Docker Compose & Redes Virtuales)
==============================================================================
¿QUÉ PROBLEMA DE ARQUITECTURA RESUELVE ESTE SCRIPT?
En producción, un contenedor de pipeline no trabaja aislado con archivos locales;
se comunica a través de una red virtual privada con un motor de base de datos
(PostgreSQL / SQL Server / ClickHouse / Snowflake).

Este script demuestra:
1. Resolución DNS interna en Docker: Se conecta a 'postgres_db:5432' usando el nombre
   del servicio definido en docker-compose.yml en lugar de 'localhost'.
2. Creación DDL de esquemas y tablas relacionales transaccionales.
3. Ingesta masiva simulada (Batch Ingestion).
4. Consulta analítica SQL avanzada con Funciones de Ventana (DENSE_RANK).
5. Exportación de resultados persistentes hacia el volumen montado en el host.
==============================================================================
"""

import os
import sys
import csv
import time
import platform
from datetime import datetime
from pathlib import Path
import psycopg2
from psycopg2 import sql

def get_db_connection():
    """
    Establece la conexión a PostgreSQL utilizando variables de entorno inyectadas
    por Docker Compose a través de la red virtual privada (bridge network).
    """
    host = os.getenv("DB_HOST", "postgres_db")
    port = int(os.getenv("DB_PORT", "5432"))
    user = os.getenv("DB_USER", "postgres")
    password = os.getenv("DB_PASSWORD", "postgres")
    dbname = os.getenv("DB_NAME", "mastery_dw")

    print(f"[*] Intentando conectar a la base de datos...")
    print(f"    -> Host (DNS Docker): {host}")
    print(f"    -> Puerto           : {port}")
    print(f"    -> Base de Datos    : {dbname}")
    print(f"    -> Usuario          : {user}")

    # Mecanismo de reintento defensivo (Retry Pattern)
    max_retries = 5
    for attempt in range(1, max_retries + 1):
        try:
            conn = psycopg2.connect(
                host=host,
                port=port,
                user=user,
                password=password,
                dbname=dbname,
                connect_timeout=5
            )
            print(f"[+] [ÉXITO] Conexión establecida con PostgreSQL en el intento {attempt}.")
            return conn
        except psycopg2.OperationalError as e:
            print(f"[!] [ADVERTENCIA] Intento {attempt}/{max_retries} falló: {e}")
            if attempt < max_retries:
                time.sleep(2)
            else:
                raise e

def run_pipeline():
    timestamp_start = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    print("=" * 80)
    print(f"[{timestamp_start}] INICIANDO DATA PIPELINE MULTI-CONTENEDOR (DOCKER COMPOSE)")
    print("=" * 80)

    # 1. Auditar entorno
    print(f" -> SO del Contenedor : {platform.system()} {platform.release()}")
    print(f" -> Versión de Python : {sys.version.split()[0]}")
    print(f" -> Directorio Trabajo: {os.getcwd()}")

    # 2. Conectar a PostgreSQL
    conn = get_db_connection()
    cur = conn.cursor()

    try:
        # 3. Crear esquema y tablas analíticas (DDL)
        print("\n[*] Creando esquema y tablas analíticas...")
        cur.execute("""
        CREATE SCHEMA IF NOT EXISTS raw_staging;
        
        DROP TABLE IF EXISTS raw_staging.stg_transactions;
        CREATE TABLE raw_staging.stg_transactions (
            transaction_id SERIAL PRIMARY KEY,
            customer_name VARCHAR(100) NOT NULL,
            category VARCHAR(50) NOT NULL,
            amount NUMERIC(10, 2) NOT NULL,
            status VARCHAR(20) NOT NULL,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        );
        """)
        conn.commit()
        print("[+] Esquema y tabla 'raw_staging.stg_transactions' listos.")

        # 4. Ingesta de datos en lote (Simulación de Batch Ingestion)
        print("\n[*] Ingestando lote de transacciones en PostgreSQL...")
        sample_transactions = [
            ("Alpha Corp", "Cloud Computing", 4500.00, "COMPLETED"),
            ("Alpha Corp", "Cloud Computing", 1200.50, "COMPLETED"),
            ("Beta Retail", "Hardware", 850.00, "COMPLETED"),
            ("Beta Retail", "Hardware", 2300.00, "COMPLETED"),
            ("Gamma Logistics", "Logistics Software", 6100.00, "COMPLETED"),
            ("Delta Fin", "Financial API", 15400.00, "COMPLETED"),
            ("Delta Fin", "Financial API", 3200.00, "COMPLETED"),
            ("Epsilon Health", "Hardware", 4100.00, "COMPLETED"),
            ("Zeta Edu", "Cloud Computing", 950.00, "COMPLETED"),
            ("Omega Security", "Financial API", 7800.00, "COMPLETED"),
        ]

        insert_query = """
        INSERT INTO raw_staging.stg_transactions (customer_name, category, amount, status)
        VALUES (%s, %s, %s, %s);
        """
        cur.executemany(insert_query, sample_transactions)
        conn.commit()
        print(f"[+] {len(sample_transactions)} registros insertados exitosamente.")

        # 5. Ejecutar Consulta Analítica Avanzada con Window Functions
        print("\n[*] Ejecutando consulta analítica con Window Function DENSE_RANK()...")
        analytics_query = """
        WITH CategorySummary AS (
            SELECT 
                category,
                customer_name,
                COUNT(transaction_id) AS total_orders,
                ROUND(SUM(amount), 2) AS total_revenue
            FROM raw_staging.stg_transactions
            WHERE status = 'COMPLETED'
            GROUP BY category, customer_name
        ),
        RankedCustomers AS (
            SELECT 
                category,
                customer_name,
                total_orders,
                total_revenue,
                DENSE_RANK() OVER (
                    PARTITION BY category 
                    ORDER BY total_revenue DESC
                ) AS ranking_en_categoria
            FROM CategorySummary
        )
        SELECT 
            category,
            customer_name,
            total_orders,
            total_revenue,
            ranking_en_categoria
        FROM RankedCustomers
        ORDER BY category, ranking_en_categoria;
        """
        cur.execute(analytics_query)
        rows = cur.fetchall()
        headers = [desc[0] for desc in cur.description]

        print(f"[+] Consulta analítica completada. Filas calculadas: {len(rows)}")

        # 6. Exportar resultado al volumen persistente compartido con el host
        output_dir = Path("/app/data/output")
        output_dir.mkdir(parents=True, exist_ok=True)
        timestamp_file = datetime.now().strftime("%Y%m%d_%H%M%S")
        output_file = output_dir / f"compose_pipeline_analytics_{timestamp_file}.csv"

        print(f"\n[*] Escribiendo archivo persistente en: {output_file}")
        with open(output_file, mode="w", newline="", encoding="utf-8") as f:
            writer = csv.writer(f)
            writer.writerow(headers)
            writer.writerows(rows)

        print(f"[+] [PERSISTENCIA EXITOSA] Reporte exportado a CSV.")
        print(f"    Archivo: {output_file.name}")
        print(f"    Ubicación en host: daily_drills/docker_infra/data/output/{output_file.name}")

    finally:
        cur.close()
        conn.close()
        print("\n[*] Conexión a PostgreSQL cerrada limpiamente.")

    print("=" * 80)
    print(f"[{datetime.now().strftime('%Y-%m-%d %H:%M:%S')}] PIPELINE FINALIZADO CON ÉXITO")
    print("=" * 80)

if __name__ == "__main__":
    run_pipeline()
