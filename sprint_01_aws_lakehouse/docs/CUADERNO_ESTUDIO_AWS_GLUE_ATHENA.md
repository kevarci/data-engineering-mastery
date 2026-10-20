# 📓 Cuaderno de Cátedra: Arquitectura Serverless en AWS (S3 + Glue + Athena)

> **Instructor:** Ingeniero Senior / Career Coach Técnico  
> **Estudiante:** Kevin Stick Arciniegas Marquez  
> **Sprint:** 01 — Fundamentos de AWS & Big Data Distribuido  
> **Bloque 1:** Core Cloud Lakehouse Project  
> **Herramientas de Estudio:** Amazon S3, AWS Glue Data Catalog, AWS Glue Crawlers, Amazon Athena (Presto/Trino)

---

## 📑 Índice de Contenidos

1. [El Desacoplamiento Serverless en AWS: Almacenamiento, Metadatos y Cómputo](#1-el-desacoplamiento-serverless-en-aws)
2. [El Layout de Amazon S3 & Particionado Hive-Style](#2-el-layout-de-amazon-s3--particionado-hive-style)
3. [AWS Glue Data Catalog & Schema Inference con Crawlers](#3-aws-glue-data-catalog--schema-inference-con-crawlers)
4. [Amazon Athena: Cómputo Serverless, DDL y MSCK REPAIR](#4-amazon-athena-cómputo-serverless-ddl-y-msck-repair)
5. [Partition Pruning & Optimización Extrema de Costos](#5-partition-pruning--optimización-extrema-de-costos)
6. [Simulador de Consultas Analíticas en Presto/Athena SQL](#6-simulador-de-consultas-analíticas-en-prestoathena-sql)
7. [Preguntas Clave de Entrevistas de Arquitectura AWS](#7-preguntas-clave-de-entrevistas-de-arquitectura-aws)

---

## 1. El Desacoplamiento Serverless en AWS

En las arquitecturas de datos tradicionales (como un Data Warehouse en Oracle o SQL Server), el **almacenamiento** y el **cómputo** viven en el mismo servidor físico. Si te quedas sin disco, debes pagar por un servidor más grande aunque no uses más CPU.

En la arquitectura moderna de **Serverless Lakehouse en AWS**, los tres pilares están **100% desacoplados e independientes**:

```
┌────────────────────────────────────────────────────────────────────────┐
│                        ARQUITECTURA SERVERLESS AWS                     │
├────────────────────────────────────────────────────────────────────────┤
│                                                                        │
│  1. ALMACENAMIENTO (Data Lake)                                         │
│     ┌──────────────────────────────────────────────────────────────┐   │
│     │                      Amazon S3                              │   │
│     │  - Almacena PB de datos en formato columnar abierto (Parquet) │   │
│     │  - Durabilidad del 99.999999999% (11 nueves)                 │   │
│     │  - Costo: ~$0.023 por GB al mes                              │   │
│     └──────────────────────────────┬───────────────────────────────┘   │
│                                    │                                   │
│  2. METADATOS (Catálogo)           ▼                                   │
│     ┌──────────────────────────────────────────────────────────────┐   │
│     │                   AWS Glue Data Catalog                      │   │
│     │  - Catálogo centralizado compatible con Apache Hive Metastore│   │
│     │  - Conoce tablas, columnas, esquemas y rutas en S3           │   │
│     │  - Los Glue Crawlers escanean S3 y crean tablas sin código   │   │
│     └──────────────────────────────┬───────────────────────────────┘   │
│                                    │                                   │
│  3. CÓMPUTO ANALÍTICO (Motor SQL)  ▼                                   │
│     ┌──────────────────────────────────────────────────────────────┐   │
│     │                     Amazon Athena                            │   │
│     │  - Motor SQL interactivo serverless basado en Presto / Trino │   │
│     │  - Cero infraestructura que administrar o aprovisionar       │   │
│     │  - Modelo de precios: $5.00 dólares por cada TB escaneado    │   │
│     └──────────────────────────────────────────────────────────────┘   │
└────────────────────────────────────────────────────────────────────────┘
```

---

## 2. El Layout de Amazon S3 & Particionado Hive-Style

### A. Jerarquía Corporativa de Buckets
Un Data Lake profesional se organiza en prefijos estrictamente tipados según la madurez de los datos:

```
s3://kevin-enterprise-lakehouse-prod/
│
├── bronze/                     <-- Datos crudos inmutables (append-only)
│   └── transactions/
│       └── year=2026/month=10/day=18/part-001.parquet
│
├── silver/                     <-- Datos limpios, tipados y desduplicados
│   └── transactions/
│       └── year=2026/month=10/day=18/part-001.snappy.parquet
│
└── gold/                       <-- Marts analíticos agregados para negocio
    └── customer_analytics/
        └── part-001.snappy.parquet
```

### B. ¿Qué es el Particionado Hive-Style?
Cuando guardamos las carpetas en el formato:
`.../year=2026/month=10/day=18/`

* **Sintaxis Clave=Valor:** El motor de consulta (Athena / Spark / Presto) interpreta el nombre del directorio antes del `=` como el **nombre de la columna virtual**, y lo que está después como su **valor**.
* **Ventaja:** Estas columnas (`year`, `month`, `day`) **no necesitan existir físicamente dentro de los archivos Parquet**, lo que ahorra millones de bytes repetitivos en disco.

---

## 3. AWS Glue Data Catalog & Schema Inference con Crawlers

Amazon S3 es solo un sistema de archivos en la nube. Para que herramientas como Athena, Power BI o QuickSight puedan consultar esos archivos con `SELECT * FROM tabla`, necesitan saber **el esquema**.

### A. ¿Qué hace un AWS Glue Crawler?
Un **Crawler** es un proceso por lotes que:
1. Se conecta a una ruta de S3 (ej. `s3://mi-bucket/silver/transactions/`).
2. Lee los metadatos de los primeros archivos Parquet (el pie de página o *footer* del Parquet contiene el esquema exacto).
3. Infiriendo tipos: Detecta que `customer_id` es `bigint`, `amount` es `decimal(10,2)` y `sale_date` es `date`.
4. Detecta las particiones automáticamente (`year`, `month`, `day`).
5. Registra la tabla en el **AWS Glue Data Catalog**.

```
[S3: Archivos Parquet] ────► [Glue Crawler] ────► [Glue Data Catalog] ────► [Athena SQL]
                                (Escaneo)           (Tabla con Esquema)      (Consultas)
```

---

## 4. Amazon Athena: Cómputo Serverless, DDL y MSCK REPAIR

### A. Creación Manual de Tablas Externas (DDL)
Si no usas un Crawler, puedes crear la tabla manualmente en Athena apuntando a S3:

```sql
CREATE EXTERNAL TABLE IF NOT EXISTS silver_transactions (
    transaction_id STRING,
    customer_id BIGINT,
    sale_date TIMESTAMP,
    amount DECIMAL(10, 2),
    status STRING
)
PARTITIONED BY (
    year INT,
    month INT,
    day INT
)
STORED AS PARQUET
LOCATION 's3://kevin-enterprise-lakehouse-prod/silver/transactions/'
TBLPROPERTIES ('parquet.compression' = 'SNAPPY');
```

> ⚠️ **Regla de Oro de Tablas Externas:**  
> Al usar la palabra `EXTERNAL`, le dices al motor: *"Los datos le pertenecen a S3, no a Athena"*. Si ejecutas un `DROP TABLE silver_transactions;`, **solo borras los metadatos del catálogo; los archivos en S3 quedan intactos**.

### B. El Comando de Sincronización: `MSCK REPAIR TABLE`
Si agregas nuevas carpetas en S3 (por ejemplo, el lote del día de hoy `day=19`), Athena no las verá de inmediato porque el Catálogo aún no las conoce.

Tienes dos opciones:
1. Correr el Glue Crawler de nuevo (tarda 1 a 2 minutos).
2. Ejecutar directamente en Athena:
```sql
MSCK REPAIR TABLE silver_transactions;
```
* **`MSCK`** (*Metastore Consistency Check*): Inspecciona la ruta de S3, encuentra todas las particiones que no estén en el catálogo y las registra en milisegundos.

---

## 5. Partition Pruning & Optimización Extrema de Costos

### A. La Matemática Financiera de Amazon Athena
* **Tarifa:** \$5.00 USD por cada **1 Terabyte (TB)** de datos escaneados del almacenamiento de S3.
* Si tu consulta escanea 100 GB, pagas: $\frac{100}{1024} \times \$5.00 \approx \$0.48 \text{ USD}$.
* Si escanea 10 MB, pagas: $\frac{0.01}{1024} \times \$5.00 \approx \$0.00004 \text{ USD}$.

### B. El Desastre del Junior vs La Técnica del Senior:

#### ❌ Consulta Ineficiente (Full Table Scan):
```sql
-- ESCANEA EL 100% DE LA TABLA (10 TB de datos = $50.00 dólares a la factura)
SELECT SUM(amount)
FROM silver_transactions
WHERE date_format(sale_date, '%Y-%m-%d') = '2026-10-18';
```
* **¿Por qué falla?**  
  Al aplicar la función `date_format()` sobre la columna interna `sale_date`, Athena se ve obligado a abrir y descomprimir **todos los archivos de todos los años y meses** para evaluar la fecha fila por fila.

#### ✅ Consulta Senior (Partition Pruning Activo):
```sql
-- ESCANEA SOLO LA PARTICIÓN DEL DÍA (15 MB = $0.00007 dólares)
SELECT SUM(amount)
FROM silver_transactions
WHERE year = 2026 
  AND month = 10 
  AND day = 18;
```
* **¿Por qué vuela en rendimiento?**  
  El optimizador lee las columnas de partición `year`, `month`, `day` y **descarta físicamente las carpetas de los otros años y meses**. Ni siquiera solicita esos archivos a S3.

---

## 6. Simulador de Consultas Analíticas en Presto/Athena SQL

### Consulta 1: Agregación de Ventas por Canal con Fechas
```sql
SELECT 
    year,
    month,
    status,
    COUNT(*) AS total_transacciones,
    ROUND(SUM(amount), 2) AS volumen_total,
    ROUND(AVG(amount), 2) AS ticket_promedio
FROM silver_transactions
WHERE year = 2026 AND month = 10
GROUP BY year, month, status
ORDER BY volumen_total DESC;
```

### Consulta 2: Detección de Clientes con Mayor Actividad
```sql
SELECT 
    customer_id,
    COUNT(transaction_id) AS total_compras,
    ROUND(SUM(amount), 2) AS gasto_acumulado
FROM silver_transactions
WHERE year = 2026
GROUP BY customer_id
HAVING COUNT(transaction_id) >= 10
ORDER BY gasto_acumulado DESC
LIMIT 50;
```

---

## 7. Preguntas Clave de Entrevistas de Arquitectura AWS

### P1: "¿Cómo optimizas los costos y el tiempo de respuesta de Amazon Athena en un Lakehouse masivo?"
> **Respuesta Senior:**  
> Aplico cuatro estrategias fundamentales:  
> 1. **Formato Columnar (Parquet/ORC):** Permite que Athena solo lea las columnas involucradas en el `SELECT` y descarte las demás (*column projection*).  
> 2. **Compresión Snappy o Gzip:** Reduce el tamaño físico en S3, lo que disminuye directamente los Gigabytes leídos y el costo de \$5/TB.  
> 3. **Particionado Inteligente (Hive-Style):** Particiono por temporalidad (`year/month/day`) para habilitar *Partition Pruning* con filtros directos en el `WHERE`.  
> 4. **Compactación de Archivos Pequeños:** Evito millones de archivos de pocos KBs compactándolos en archivos de 128 MB a 512 MB mediante `OPTIMIZE` en Delta Lake o trabajos de compactación en Spark.

### P2: "¿Qué diferencia existe entre `MSCK REPAIR TABLE` y ejecutar un Glue Crawler?"
> **Respuesta Senior:**  
> `MSCK REPAIR TABLE` es un comando ligero de Athena que únicamente busca carpetas nuevas en S3 que coincidan con la estructura de particiones ya existente y las añade al catálogo; no detecta cambios en las columnas ni infiere nuevos esquemas.  
> Un **AWS Glue Crawler** es un servicio completo de orquestación que no solo detecta nuevas particiones, sino que también inspecciona el contenido de los archivos para detectar evolución de esquemas (*Schema Evolution*, como nuevas columnas añadidas) y clasifica automáticamente formatos desconocidos.

### P3: "¿Qué es el 'Small File Problem' en Amazon S3 y por qué degrada tanto a Athena como a Spark?"
> **Respuesta Senior:**  
> Ocurre cuando se ingieren flujos de streaming o micro-batches que generan miles o millones de archivos diminutos (ej. de 50 KB cada uno).  
> Cada archivo en S3 requiere una solicitud HTTP `GET`, lectura de metadatos del footer de Parquet y apertura de sockets de red. El tiempo de sobrecarga (*overhead*) de coordinar 100,000 llamadas HTTP supera por mucho al tiempo real de cómputo. Se soluciona compactando los datos periódicamente en archivos de 128 MB a 512 MB, permitiendo lecturas secuenciales de alto rendimiento.

### P4: "¿Qué sucede con los datos en S3 si ejecuto `DROP TABLE` sobre una tabla de Athena creada con `EXTERNAL`?"
> **Respuesta Senior:**  
> En una tabla declarada como `EXTERNAL`, Athena y el Glue Data Catalog solo administran los metadatos (el esquema y la ubicación). Ejecutar `DROP TABLE` elimina la definición de la tabla en el catálogo, pero **los archivos Parquet físicos en Amazon S3 permanecen 100% intactos y a salvo**. Para eliminar los datos físicos sería necesario vaciar el bucket en S3 o borrar el prefijo mediante AWS CLI o SDK.

---

## 8. El Blueprint de Producción Senior: Flujo de 5 Fases & Gobernanza

Para operar como un verdadero Senior Data Engineer, nunca se expone la capa Bronze directamente a los usuarios finales. Se implementa un **flujo orquestado de 5 fases**:

```
[Fuentes / APIs / SFTP]
          │
          ▼
1. INGESTA BRONZE (S3)          -> Datos crudos inmutables (histórico puro).
          │
          ▼
2. PROCESAMIENTO (PySpark)      -> Limpieza, deduplicación, casteo estricto,
   (Databricks / AWS Glue Job)     particionado Hive-style y compresión Snappy/Parquet.
          │
          ▼
3. PERSISTENCIA SILVER & GOLD   -> Se guardan en S3 en capas limpias y agregadas.
          │
          ▼
4. CATALOGACIÓN (Glue Catalog)  -> El Crawler o el propio job de Spark registra las
                                   tablas Silver y Gold en el catálogo de metadatos.
          │
          ▼
5. CONSUMO OPTIMIZADO (Athena)  -> Los tableros de Power BI, analistas y científicos
                                   consultan GOLD usando Partition Pruning sin riesgo de
                                   datos duplicados ni sobrecostos de escaneo.
```

### Matriz de Gobernanza de Acceso a las Capas:

| Capa en S3 | ¿Se Cataloga con Glue? | ¿Quién tiene permiso de consultarla con Athena? |
| :--- | :---: | :--- |
| **🥇 Capa GOLD** | **¡SIEMPRE!** | **Usuarios de Negocio, Finanzas, BI y Dashboards (Power BI / QuickSight).** Solo ven métricas limpias, confiables y agregadas. |
| **🥈 Capa SILVER** | **¡SÍ, TAMBIÉN!** | **Data Scientists e Ingenieros de Datos.** Necesitan la data transaccional limpia, fila por fila y sin duplicados, para entrenar modelos de Machine Learning o hacer análisis forenses profundos. |
| **🥉 Capa BRONZE** | *Opcional (Solo uso interno)* | **Solo el equipo central de Data Engineering.** Jamás se expone a negocio porque contiene duplicados y datos crudos. |

> 💡 **Pro-Tip de Nivel Senior:**  
> En entornos modernos de PySpark / Databricks, no siempre es necesario esperar a que corra un Glue Crawler. Al terminar el job de Spark, puedes registrar la tabla directamente con:  
> `df_silver.write.mode("overwrite").format("parquet").saveAsTable("glue_catalog.silver_transactions")`  
> Esto actualiza los metadatos en tiempo real sin incurrir en costos adicionales de Crawler.

