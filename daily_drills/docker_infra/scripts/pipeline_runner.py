#!/usr/bin/env python3
"""
Pipeline Runner en Contenedor Docker (DataOps Drill)
Estudiante: Kevin Stick Arciniegas Marquez

Objetivo:
Demostrar el aislamiento de ejecución dentro de Linux y la persistencia
de datos hacia la máquina host mediante un Docker Volume montado en /app/data.
"""

import os
import sys
import csv
import platform
from datetime import datetime
from pathlib import Path

def main():
    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    print("=" * 70)
    print(f"[{timestamp}] [INFO] INICIANDO PIPELINE DE DATOS EN CONTENEDOR DOCKER")
    print("=" * 70)
    
    # 1. Auditar el entorno de ejecución
    print(f" -> Sistema Operativo del Contenedor : {platform.system()} {platform.release()}")
    print(f" -> Versión de Python en Contenedor : {sys.version.split()[0]}")
    print(f" -> Directorio de Trabajo           : {os.getcwd()}")
    
    # 2. Rutas del volumen montado
    data_dir = Path("/app/data")
    output_dir = data_dir / "output"
    output_dir.mkdir(parents=True, exist_ok=True)
    
    output_file = output_dir / f"batch_processed_{datetime.now().strftime('%Y%m%d_%H%M%S')}.csv"
    
    # 3. Procesamiento y generación de datos transformados
    print(f"\n[{timestamp}] [INFO] Procesando lote de transacciones analíticas...")
    sample_records = [
        {"customer_id": 101, "name": "Alice Corp", "total_orders": 12, "spent_usd": 4820.50, "tier": "VIP"},
        {"customer_id": 102, "name": "Beta Tech",  "total_orders": 3,  "spent_usd": 450.00,  "tier": "Standard"},
        {"customer_id": 103, "name": "Gamma Labs", "total_orders": 28, "spent_usd": 12400.00, "tier": "VIP"},
        {"customer_id": 104, "name": "Delta Inc",  "total_orders": 7,  "spent_usd": 1890.30, "tier": "Medium"},
    ]
    
    # 4. Escribir datos en el volumen persistente
    fieldnames = ["customer_id", "name", "total_orders", "spent_usd", "tier", "processed_at"]
    with open(output_file, mode="w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        for row in sample_records:
            row["processed_at"] = datetime.now().isoformat()
            writer.writerow(row)
            
    print(f"[{timestamp}] [INFO] Archivo persistido con éxito en:")
    print(f"     {output_file}")
    print(f" -> Total de registros procesados: {len(sample_records)}")
    
    # 5. Comprobación de persistencia
    print("\n" + "=" * 70)
    print("  CONFIRMACIÓN DE ARQUITECTURA (DOCKER VOLUME):")
    print("  Si montaste el volumen con -v, este archivo ahora existe")
    print("  físicamente en tu máquina Windows, fuera de este contenedor.")
    print("=" * 70)

if __name__ == "__main__":
    main()
