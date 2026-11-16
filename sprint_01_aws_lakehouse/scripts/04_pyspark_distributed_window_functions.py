# Databricks notebook source
# ==============================================================================
# LABORATORIO DE PYSPARK: WINDOW FUNCTIONS DISTRIBUIDAS & SHUFFLE OPTIMIZATION
# Autor: Kevin Stick Arciniegas Marquez
# Sprint: 01 — Fundamentos de AWS & Big Data Distribuido
# Archivo: 04_pyspark_distributed_window_functions.py
# ==============================================================================
# ¿QUÉ PROBLEMA DE ARQUITECTURA RESOLVEMOS EN ESTE LABORATORIO?
# En un clúster distribuido (Databricks / EMR), una función de ventana obliga a
# transportar datos entre máquinas por la red (Shuffle).
# Si no se diseña correctamente, puede provocar OutOfMemory (OOM) o tareas
# rezagadas (Stragglers).
#
# En este laboratorio dominamos:
# 1. Top N por Categoría con row_number() y dense_rank() sin colapsar el clúster.
# 2. Análisis temporal con lag() y lead() para detección de Churn (Cero Self-Joins).
# 3. Totales Acumulados (Running Totals) con marcos físicos optimizados (rowsBetween).
# 4. Deduplicación analítica idempotente en la capa Bronze/Silver.
# ==============================================================================

# COMMAND ----------
# 1. INICIALIZACIÓN DEL ENTORNO SPARK (Compatible con Databricks y Local)
from pyspark.sql import SparkSession
from pyspark.sql import functions as F
from pyspark.sql.window import Window

try:
    # En Databricks, la sesión 'spark' ya está inyectada en el entorno
    spark
except NameError:
    # Si se ejecuta en local, creamos la sesión Spark local
    spark = SparkSession.builder \
        .appName("PySpark-Window-Functions-Lab") \
        .master("local[*]") \
        .getOrCreate()

print("=" * 80)
print(f"[*] Entorno PySpark Inicializado con éxito. Versión: {spark.version}")
print("=" * 80)

# COMMAND ----------
# 2. GENERACIÓN DEL DATASET TRANSACCIONAL DE PRUEBA
# Simulamos un lote realista de transacciones de e-commerce con clientes, categorías y fechas
raw_data = [
    # (transaction_id, customer_id, category, amount, transaction_date, updated_at)
    (1001, "CUST_01", "Electronics", 1200.00, "2026-10-01", "2026-10-01 10:00:00"),
    (1002, "CUST_02", "Electronics", 850.00,  "2026-10-02", "2026-10-02 11:30:00"),
    (1003, "CUST_01", "Electronics", 1200.00, "2026-10-05", "2026-10-05 14:15:00"), # Empate en monto con 1001
    (1004, "CUST_03", "Electronics", 450.00,  "2026-10-06", "2026-10-06 09:00:00"),
    (1005, "CUST_02", "Home",        350.00,  "2026-10-01", "2026-10-01 12:00:00"),
    (1006, "CUST_04", "Home",        920.00,  "2026-10-03", "2026-10-03 16:45:00"),
    (1007, "CUST_02", "Home",        920.00,  "2026-10-04", "2026-10-04 18:20:00"), # Empate en monto con 1006
    (1008, "CUST_05", "Home",        150.00,  "2026-10-08", "2026-10-08 10:10:00"),
    (1009, "CUST_01", "Books",       45.00,   "2026-10-02", "2026-10-02 08:30:00"),
    (1010, "CUST_03", "Books",       120.00,  "2026-10-07", "2026-10-07 15:00:00"),
    (1011, "CUST_05", "Books",       85.00,   "2026-10-09", "2026-10-09 11:45:00"),
    # Registros duplicados para el ejercicio de deduplicación:
    (1001, "CUST_01", "Electronics", 1250.00, "2026-10-01", "2026-10-01 10:15:00")  # Versión corregida más reciente
]

columns = ["transaction_id", "customer_id", "category", "amount", "transaction_date", "updated_at"]
df_transactions = spark.createDataFrame(raw_data, columns) \
    .withColumn("amount", F.col("amount").cast("double")) \
    .withColumn("transaction_date", F.to_date("transaction_date")) \
    .withColumn("updated_at", F.to_timestamp("updated_at"))

print(f"\n[+] DataFrame base cargado con {df_transactions.count()} registros:")
df_transactions.show(truncate=False)

# COMMAND ----------
# 3. PASO 1: TOP N POR CATEGORÍA (ROW_NUMBER vs DENSE_RANK)
# Problema: Obtener las 2 compras más grandes por cada categoría comercial.
# ¿Cómo lo ejecuta Spark?
# partitionBy("category") aplica un Hash Partitioning que envía todos los datos de una
# categoría a un mismo Executor, donde se ordenan localmente en memoria.

window_category = Window.partitionBy("category").orderBy(F.col("amount").desc())

df_ranked = df_transactions.select(
    "transaction_id",
    "customer_id",
    "category",
    "amount",
    F.row_number().over(window_category).alias("rnk_row_number"),
    F.dense_rank().over(window_category).alias("rnk_dense_rank")
)

print("\n" + "=" * 80)
print("PASO 1: COMPARATIVA ROW_NUMBER vs DENSE_RANK (OBSERVA LOS EMPATES)")
print("=" * 80)
df_ranked.show(truncate=False)

# Filtro Top 2 con DENSE_RANK (Justicia de negocio: incluye empates en los primeros lugares)
df_top2 = df_ranked.filter(F.col("rnk_dense_rank") <= 2)
print("\n[+] Top 2 de transacciones por categoría (filtrado con DENSE_RANK <= 2):")
df_top2.show(truncate=False)

# COMMAND ----------
# 4. PASO 2: ANÁLISIS TEMPORAL DISTRIBUIDO CON LAG() Y LEAD() (DETECCIÓN DE CHURN)
# Problema: Medir cuántos días transcurren entre compras de un mismo cliente.
# Un desarrollador Junior intenta hacer un 'SELF-JOIN' entre la tabla y sí misma,
# lo cual provoca un Shuffle cuadrático O(N^2) que congela el clúster.
# Un Senior usa LAG() en una sola pasada lineal O(N) por partición.

window_customer_timeline = Window.partitionBy("customer_id").orderBy("transaction_date")

df_customer_churn = df_transactions.select(
    "customer_id",
    "transaction_id",
    "transaction_date",
    "amount",
    # Traemos la fecha y monto de la compra anterior:
    F.lag("transaction_date", 1).over(window_customer_timeline).alias("fecha_compra_anterior"),
    F.lag("amount", 1).over(window_customer_timeline).alias("monto_compra_anterior")
).withColumn(
    # Calculamos los días transcurridos desde su última interacción:
    "dias_desde_ultima_compra",
    F.datediff(F.col("transaction_date"), F.col("fecha_compra_anterior"))
)

print("\n" + "=" * 80)
print("PASO 2: ANÁLISIS TEMPORAL CON LAG() - DIAS ENTRE COMPRAS (SIN SELF-JOIN)")
print("=" * 80)
df_customer_churn.show(truncate=False)

# COMMAND ----------
# 5. PASO 3: TOTALES ACUMULADOS CON MARCOS FÍSICOS (ROWS BETWEEN)
# Problema: Calcular el ingreso acumulado (Running Total) de la empresa día a día por categoría.
# ¿Por qué usar 'rowsBetween' en PySpark?
# Por defecto, un ORDER BY sin marco físico evalúa RANGE BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW,
# lo que obliga a Spark a comparar valores lógicos de fecha.
# Al especificar explícitamente rowsBetween(Window.unboundedPreceding, Window.currentRow),
# Spark usa un puntero físico de filas en memoria, acelerando el cómputo hasta 10 veces.

window_running_total = Window.partitionBy("category") \
    .orderBy("transaction_date") \
    .rowsBetween(Window.unboundedPreceding, Window.currentRow)

df_running_totals = df_transactions.select(
    "category",
    "transaction_date",
    "transaction_id",
    "amount",
    F.round(F.sum("amount").over(window_running_total), 2).alias("acumulado_categoria")
)

print("\n" + "=" * 80)
print("PASO 3: RUNNING TOTALS CON MARCO FÍSICO OPTIMIZADO (ROWS BETWEEN)")
print("=" * 80)
df_running_totals.show(truncate=False)

# COMMAND ----------
# 6. PASO 4: DEDUPLICACIÓN ANALÍTICA IDEMPOTENTE (PATRÓN BRONZE -> SILVER)
# Problema: En arquitecturas de datos en tiempo real o micro-lotes, la red o el productor
# envían transacciones duplicadas (ej: transaction_id 1001 se envió dos veces).
# Un Senior deduplica conservando la versión con el 'updated_at' más reciente.

window_dedup = Window.partitionBy("transaction_id").orderBy(F.col("updated_at").desc())

df_deduplicated = df_transactions \
    .withColumn("version_rank", F.row_number().over(window_dedup)) \
    .filter(F.col("version_rank") == 1) \
    .drop("version_rank")

print("\n" + "=" * 80)
print("PASO 4: DEDUPLICACIÓN IDEMPOTENTE (CONSERVAR REGISTRO MÁS RECIENTE)")
print("=" * 80)
print(f"Total registros antes de deduplicar : {df_transactions.count()}")
print(f"Total registros tras deduplicación  : {df_deduplicated.count()}")
print("\nRegistros limpios deduplicados (Capa Silver):")
df_deduplicated.show(truncate=False)

# COMMAND ----------
# 7. INSPECCIÓN DEL PLAN FÍSICO DE CATALYST PARA UNA WINDOW FUNCTION
print("\n" + "=" * 80)
print("INSPECCIÓN DEL PLAN FÍSICO (OBSERVA EL OPERADOR 'Window' y 'Exchange')")
print("=" * 80)
# 'Exchange hashpartitioning' es el Shuffle físico por red.
# 'Window' es el cálculo vectorial de las funciones analíticas en memoria.
df_ranked.explain()
