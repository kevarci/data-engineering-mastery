# Databricks notebook source
# ==============================================================================
# PIPELINE MEDALLION LAKEHOUSE EN DATABRICKS (PYSPARK & DELTA LAKE)
# Autor: Kevin Stick Arciniegas Marquez
# Arquitectura: Bronze (Raw) -> Silver (Cleaned) -> Gold (Aggregated)
# ==============================================================================

# COMMAND ----------
# 1. COMPROBACIÓN DEL ENTORNO DISTRIBUIDO
print(f"Versión activa de Apache Spark: {spark.version}")
df_test = spark.range(5)
display(df_test)

# COMMAND ----------
# 2. CAPA BRONZE (RAW / INGESTA CRUDA)
from pyspark.sql import functions as F

# Generamos 100,000 registros sintéticos con duplicados intencionales
df_base = spark.range(0, 100000).toDF("id")

df_bronze = df_base.select(
    F.concat(F.lit("TXN_"), F.lpad((F.col("id") % 90000).cast("string"), 6, "0")).alias("transaction_id"),
    (F.floor(F.rand(seed=42) * 5000) + 1).cast("int").alias("customer_id"),
    F.concat(
        F.lit("2026-10-"),
        F.lpad((F.floor(F.rand(seed=12) * 28) + 1).cast("string"), 2, "0"),
        F.lit(" 14:30:00")
    ).alias("transaction_timestamp_raw"),
    F.round((F.rand(seed=7) * 1490) + 10, 2).alias("amount"),
    F.when(F.rand(seed=1) < 0.40, "CREDIT_CARD")
     .when(F.rand(seed=2) < 0.70, "PAYPAL")
     .when(F.rand(seed=3) < 0.90, "DEBIT_CARD")
     .otherwise("BANK_TRANSFER").alias("payment_method"),
    F.when(F.rand(seed=4) < 0.85, "COMPLETED")
     .when(F.rand(seed=5) < 0.95, "PENDING")
     .otherwise("CANCELLED").alias("status")
)

# Guardar como Managed Delta Table
df_bronze.write.format("delta").mode("overwrite").saveAsTable("bronze_transactions")
print(f"✅ Capa Bronze creada con éxito con {df_bronze.count():,} registros.")
display(spark.table("bronze_transactions").limit(5))

# COMMAND ----------
# 3. DIAGNÓSTICO Y AUDITORÍA DE CALIDAD DE DATOS
total_filas = spark.table("bronze_transactions").count()
ids_unicos = spark.table("bronze_transactions").select("transaction_id").distinct().count()
duplicados = total_filas - ids_unicos

print(f"Total registros: {total_filas:,}")
print(f"IDs únicos:      {ids_unicos:,}")
print(f"Duplicados:      {duplicados:,} ({(duplicados/total_filas)*100:.1f}%)")

# COMMAND ----------
# 4. CAPA SILVER (CLEANSED, DEDUPLICATED & PARTITIONED)
from pyspark.sql.types import DecimalType

df_silver = (
    spark.table("bronze_transactions")
    .dropDuplicates(["transaction_id"])
    .withColumn("transaction_timestamp", F.to_timestamp("transaction_timestamp_raw", "yyyy-MM-dd HH:mm:ss"))
    .withColumn("year", F.year("transaction_timestamp"))
    .withColumn("month", F.month("transaction_timestamp"))
    .withColumn("amount", F.col("amount").cast(DecimalType(10, 2)))
    .withColumn("silver_processed_at", F.current_timestamp())
    .drop("transaction_timestamp_raw")
)

df_silver.write.format("delta").mode("overwrite").partitionBy("year", "month").saveAsTable("silver_transactions")
print(f"✅ Capa Silver creada exitosamente con {spark.table('silver_transactions').count():,} registros únicos.")
display(spark.table("silver_transactions").limit(5))

# COMMAND ----------
# 5. CAPA GOLD (BUSINESS AGGREGATES & CUSTOMER MARTS)
df_gold_customers = (
    spark.table("silver_transactions")
    .filter(F.col("status") == "COMPLETED")
    .groupBy("customer_id")
    .agg(
        F.count("transaction_id").alias("total_orders"),
        F.round(F.sum("amount"), 2).alias("total_spent"),
        F.round(F.avg("amount"), 2).alias("avg_ticket"),
        F.max("transaction_timestamp").alias("last_purchase_date")
    )
    .withColumn(
        "customer_segment",
        F.when(F.col("total_spent") >= 2500, "VIP")
         .when(F.col("total_spent") >= 1000, "FRECUENTE")
         .otherwise("OCASIONAL")
    )
    .orderBy(F.col("total_spent").desc())
)

df_gold_customers.write.format("delta").mode("overwrite").saveAsTable("gold_customer_analytics")
print(f"✅ Capa Gold creada exitosamente con {spark.table('gold_customer_analytics').count():,} clientes analizados.")
display(spark.table("gold_customer_analytics").limit(10))

# COMMAND ----------
# 6. DELTA LAKE INTERNALS (AUDITORÍA & TIME TRAVEL)
# MAGIC %sql
# MAGIC DESCRIBE HISTORY gold_customer_analytics;

# COMMAND ----------
# 7. COMPACTACIÓN Y Z-ORDERING (DATA SKIPPING)
# MAGIC %sql
# MAGIC OPTIMIZE gold_customer_analytics ZORDER BY (customer_id);

# COMMAND ----------
# 8. VALIDACIÓN DE TIME TRAVEL
# MAGIC %sql
# MAGIC SELECT * FROM gold_customer_analytics VERSION AS OF 0 LIMIT 5;
