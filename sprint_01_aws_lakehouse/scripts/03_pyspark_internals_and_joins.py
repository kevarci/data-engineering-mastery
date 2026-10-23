# Databricks notebook source
# ==============================================================================
# LABORATORIO DE PYSPARK INTERNALS: CATALYST, SHUFFLE & OPTIMIZACIÓN DE JOINS
# Autor: Kevin Stick Arciniegas Marquez
# Sprint: 01 — Fundamentos de AWS & Big Data Distribuido
# Objetivo: Diagnosticar planes de ejecución físicos, eliminar Shuffles con 
#           Broadcast Joins y resolver problemas de Data Skew (Sesgo de Datos).
# ==============================================================================

# COMMAND ----------
# 1. VERIFICACIÓN DEL CLÚSTER Y ENTORNO SPARK
print("=" * 80)
print(f"Versión de Apache Spark: {spark.version}")
print(f"Adaptive Query Execution (AQE) Activo: {spark.conf.get('spark.sql.adaptive.enabled')}")
print("=" * 80)

# COMMAND ----------
# 2. EL OPTIMIZADOR CATALYST EN ACCIÓN: INSPECCIÓN DE PLANES CON .explain(True)
from pyspark.sql import functions as F

# Generamos un DataFrame transaccional de 500,000 filas
df_base = spark.range(0, 500000).toDF("id")

df_transacciones = df_base.select(
    F.col("id").alias("transaction_id"),
    (F.col("id") % 1000).alias("customer_id"),
    (F.col("id") % 5).alias("category_id"),
    F.round(F.rand(seed=42) * 1000, 2).alias("amount"),
    F.when(F.rand(seed=1) < 0.8, "COMPLETED").otherwise("PENDING").alias("status")
)

# Consulta con filtro al final (para probar si Catalyst hace Predicate Pushdown)
df_filtrado = (
    df_transacciones
    .withColumn("amount_with_tax", F.round(F.col("amount") * 1.16, 2))
    .filter(F.col("status") == "COMPLETED")
    .filter(F.col("amount") > 500.0)
    .select("transaction_id", "customer_id", "category_id", "amount_with_tax")
)

print("--- PLAN DE EJECUCIÓN EXTENDIDO (LAS 4 FASES DE CATALYST) ---")
# explain(mode="extended") imprime: Parsed, Analyzed, Optimized y Physical Plan
df_filtrado.explain(mode="extended")

# COMMAND ----------
# 3. EL COMBATE DE JOINS: SORT-MERGE JOIN (CON SHUFFLE) VS BROADCAST HASH JOIN (SIN SHUFFLE)

# Creamos una tabla dimensional pequeña de Categorías (5 filas, < 1 KB)
df_categorias = spark.createDataFrame([
    (0, "Electronics", "High-Tech"),
    (1, "Home & Kitchen", "Household"),
    (2, "Fashion & Apparel", "Lifestyle"),
    (3, "Health & Beauty", "Personal Care"),
    (4, "Books & Media", "Entertainment")
], ["category_id", "category_name", "department"])

# Desactivamos temporalmente el autobroadcast para forzar el Join tradicional con Shuffle
spark.conf.set("spark.sql.autoBroadcastJoinThreshold", -1)

print("\n" + "=" * 80)
print("EXPERIMENTO 1: JOIN TRADICIONAL (SORT-MERGE O SHUFFLE HASH JOIN)")
print("Observa en el plan la presencia de 'Exchange hashpartitioning' (¡ESTO ES SHUFFLE!)")
print("=" * 80)

df_join_shuffle = df_transacciones.join(df_categorias, on="category_id", how="inner")
df_join_shuffle.explain()

# COMMAND ----------
# 4. OPTIMIZACIÓN SENIOR: BROADCAST HASH JOIN (MAP-SIDE JOIN)

print("\n" + "=" * 80)
print("EXPERIMENTO 2: BROADCAST HASH JOIN FORZADO CON broadcast()")
print("Observa cómo desaparece el 'Exchange' y se reemplaza por 'BroadcastExchange'")
print("¡CERO SHUFFLE para la tabla grande de transacciones!")
print("=" * 80)

from pyspark.sql.functions import broadcast

df_join_broadcast = df_transacciones.join(broadcast(df_categorias), on="category_id", how="inner")
df_join_broadcast.explain()

# Reactivamos el umbral estándar de 10 MB para producción
spark.conf.set("spark.sql.autoBroadcastJoinThreshold", 10485760)

# COMMAND ----------
# 5. MITIGACIÓN DE DATA SKEW MEDIANTE LA TÉCNICA DE "SALTING"

# Simulamos una tabla con sesgo severo: el cliente 999 tiene el 70% de todas las ventas
df_skewed = df_transacciones.withColumn(
    "customer_id",
    F.when(F.rand(seed=99) < 0.70, F.lit(999)).otherwise(F.col("customer_id"))
)

print("\n" + "=" * 80)
print("SIMULACIÓN DE DATA SKEW: Cliente 999 acapara el volumen")
print("=" * 80)
df_skewed.groupBy("customer_id").count().orderBy(F.col("count").desc()).show(5)

# TÉCNICA DE SALTING:
# Dividimos artificialmente el cliente 999 en 4 'salazones' (0, 1, 2, 3)
SALT_FACTOR = 4

df_salted = df_skewed.withColumn("salt", F.floor(F.rand(seed=123) * SALT_FACTOR))
df_salted = df_salted.withColumn(
    "salted_customer_id", 
    F.concat(F.col("customer_id"), F.lit("_"), F.col("salt"))
)

print("Tabla con Salting aplicado (La carga del cliente 999 se distribuye en 4 particiones):")
df_salted.groupBy("salted_customer_id").count().orderBy(F.col("count").desc()).show(8)

print("✅ Laboratorio de PySpark Internals completado con éxito.")
