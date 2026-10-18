# 📓 Cuaderno de Cátedra: Arquitectura Lakehouse & PySpark en Databricks

> **Instructor:** Ingeniero Senior / Career Coach Técnico
> **Estudiante:** Kevin Stick Arciniegas Marquez
> **Sprint:** 01 — Fundamentos de AWS & Big Data Distribuido
> **Objetivo:** Dominar los conceptos arquitectónicos y prácticos de Apache Spark, Databricks y Delta Lake para entrevistas técnicas y entornos de producción.

---

## 📑 Índice de Lecciones

1. [De Single-Node (Colab/Pandas) a Cómputo Distribuido (Databricks/Spark)](#1-de-single-node-a-cómputo-distribuido)
2. [Anatomía de Databricks Serverless &amp; SparkSession](#2-anatomía-de-databricks-serverless--sparksession)
3. [La Arquitectura Medallion (Bronze -&gt; Silver -&gt; Gold)](#3-la-arquitectura-medallion-el-estándar-de-la-industria)
4. [Preguntas Clave de Entrevistas Técnicas](#4-preguntas-clave-de-entrevistas-técnicas)

---

## 1. De Single-Node a Cómputo Distribuido

### El Problema de la Computación Tradicional (Google Colab / Pandas)

* **Single-Node:** Toda la ejecución depende de una **única máquina virtual** con procesadores y memoria RAM limitados.
* **El Límite OOM (*Out Of Memory*):** Si intentas procesar un dataset de 50 GB en una máquina con 16 GB de RAM usando Pandas, el sistema operativo se queda sin memoria y el proceso se aborta (`Kernel Crash`).

### La Solución de Apache Spark

Apache Spark no intenta comprar una computadora más grande (**escalamiento vertical**); en su lugar, une decenas o cientos de computadoras normales en red (**escalamiento horizontal**).

```
                            ARQUITECTURA DE APACHE SPARK
                        
                               ┌───────────────────┐
                               │    DRIVER NODE    │
                               │  (Cerebro / Plan) │
                               └─────────┬─────────┘
                                         │ Coordina tareas
                     ┌───────────────────┼───────────────────┐
                     ▼                   ▼                   ▼
            ┌─────────────────┐ ┌─────────────────┐ ┌─────────────────┐
            │   WORKER NODE   │ │   WORKER NODE   │ │   WORKER NODE   │
            │   (Executor 1)  │ │   (Executor 2)  │ │   (Executor 3)  │
            │  Procesa Part. 1│ │  Procesa Part. 2│ │  Procesa Part. 3│
            └─────────────────┘ └─────────────────┘ └─────────────────┘
```

* **Driver Node:** Es el "director de orquesta". Recibe tu código en Python/SQL, construye el plan de ejecución optimizado (Catalyst Optimizer) y divide el trabajo en pequeñas tareas.
* **Worker Nodes (Executors):** Son los "músicos". Cada uno toma una partición de los datos en su memoria RAM local y ejecuta los cálculos en paralelo.

---

## 2. Anatomía de Databricks Serverless & SparkSession

### Cómputo Tradicional vs. Serverless

* **Clúster Clásico:** Requiere elegir cantidad de máquinas virtuales (VMs), tamaño de RAM, configurar auto-scaling y esperar 4 a 6 minutos mientras los servidores encienden.
* **Cómputo Serverless:** Databricks mantiene un pool de servidores calientes en la nube. Al abrir el Notebook, se conecta instantáneamente en segundos (`🟢 Serverless`) y escala de forma automática según la complejidad del pipeline.

### El Objeto Global `spark`

En scripts locales es obligatorio instanciar la sesión:

```python
# En local o scripts sueltos:
from pyspark.sql import SparkSession
spark = SparkSession.builder.appName("Lakehouse").getOrCreate()
```

En Databricks, el objeto **`spark`** ya viene pre-inicializado, optimizado con el motor **Photon (C++)** e inyectado en el runtime.

### Visualización: `display(df)` vs `df.show()`

* `df.show(5)`: Imprime texto ASCII plano en consola (método estándar de Spark Open Source).
* `display(df)`: Función rica nativa de Databricks que renderiza una tabla HTML interactiva con ordenamiento de columnas, paginación y generación de gráficos instantáneos con un solo clic.

---

## 3. La Arquitectura Medallion: El Estándar de la Industria

En lugar de tener un lago de datos caótico (*Data Swamp*), las empresas modernas organizan su almacenamiento en 3 capas de refinamiento progresivo:

```
┌─────────────────────────┐      ┌─────────────────────────┐      ┌─────────────────────────┐
│      CAPA BRONZE        │      │       CAPA SILVER       │      │        CAPA GOLD        │
│      (Raw / Crudo)      │ ───► │   (Cleansed / Limpio)   │ ───► │    (Curated / Negocio)  │
│  Datos crudos tal como  │      │  Tipado estricto, sin   │      │  Tablas agregadas, KPIs │
│  llegan de la fuente    │      │  nulos ni duplicados    │      │  listas para BI/ML      │
└─────────────────────────┘      └─────────────────────────┘      └─────────────────────────┘
```

### 1. Capa Bronze (Raw)

* **Objetivo:** Preservar la verdad histórica de los datos.
* **Regla:** **Nunca se modifican ni se filtran**. Si el sistema origen envió datos corruptos o valores nulos, se almacenan exactamente así para poder reprocesar o auditar en el futuro si una regla de negocio cambia.
* **Formato:** Parquet o Delta Lake crudo particionado por fecha de ingestión (`year=YYYY/month=MM/day=DD`).

### 2. Capa Silver (Enriched & Cleansed)

* **Objetivo:** Calidad y consistencia empresarial (*Enterprise Data Model*).
* **Operaciones clave:**
  * Deduplicación de transacciones usando claves primarias (`dropDuplicates(["transaction_id"])`).
  * Casteo estricto de tipos de datos (strings de fechas a `TimestampType`, montos a `DecimalType(10, 2)`).
  * Enriquecimiento y cruce con tablas dimensionales (ej. unir con clientes o productos).

### 3. Capa Gold (Business Aggregates)

* **Objetivo:** Máxima velocidad de consulta analítica.
* **Regla:** Aquí no se almacenan millones de eventos crudos, sino **agregaciones listas para consumir**:
  * Ventas totales por categoría y mes.
  * Métricas de retención de clientes.
* **Consumidores:** Cuadros de mando en Power BI, Tableau, APIs analíticas y modelos de Machine Learning.

---

## 4. Preguntas Clave de Entrevistas Técnicas

### P1: "¿Por qué usar PySpark en lugar de Pandas si ambos tienen DataFrames?"

> **Respuesta Senior:**
> Pandas está diseñado para trabajar en la memoria de un único procesador; si el volumen supera la RAM de esa máquina, colapsa.
> PySpark utiliza una abstracción distribuida (DataFrames sobre RDDs) que divide los datos en particiones y los procesa en paralelo sobre un clúster de múltiples nodos. Además, PySpark cuenta con el optimizador Catalyst, que analiza el plan lógico de la consulta y optimiza filtros y proyecciones antes de tocar el disco (*Lazy Evaluation*).

### P2: "¿Por qué la arquitectura Medallion almacena datos duplicados en 3 capas en lugar de guardar solo la versión limpia final?"

> **Respuesta Senior:**
> Por idempotencia, gobernanza y capacidad de auditoría. Si solo guardamos la capa final y una regla de negocio de limpieza estaba errónea, los datos originales se habrían perdido para siempre. Con la capa Bronze intacta, podemos corregir la lógica en la capa Silver y reprocesar el historial en cualquier momento sin volver a extraer datos de los sistemas transaccionales origen.

---

## 5. Lección Práctica: Capa Bronze & El Error `DBFS_DISABLED`

### ¿Qué aprendimos con el error `[DBFS_DISABLED]`?

* **El contexto:** Al intentar guardar en `/tmp/lakehouse/bronze/transactions/`, Databricks Serverless arrojó `SQLSTATE: 56038 Public DBFS root is disabled`.
* **La razón:** En Databricks moderno (2025+), el sistema de archivos público raíz de DBFS está bloqueado por directivas de seguridad para evitar fugas de datos y archivos huérfanos sin gobernanza.
* **La solución de producción:** Usar **Managed Tables (Tablas Administradas)** mediante `.saveAsTable("bronze_transactions")`.
* **Ventaja clave:** Al registrarse como tabla Delta en el catálogo, queda automáticamente disponible para:
  1. Consultas distribuidas en **PySpark** (`spark.table("bronze_transactions")`).
  2. Consultas analíticas en **SQL nativo** (`SELECT * FROM bronze_transactions`).
  3. Gobernanza y auditoría centralizada con Unity Catalog.

---

## 6. Diagnóstico de Calidad antes de construir la Capa Silver

Antes de escribir la capa Silver, un Ingeniero de Datos Senior realiza una **auditoría de calidad**:

1. **Detección de duplicados:** Comparar `count()` total vs `distinct().count()` de la clave primaria (`transaction_id`).
2. **Corrección de tipos de datos:**
   * Las fechas que vienen como `string` (`"2026-10-14 14:30:00"`) deben convertirse a `TimestampType` para habilitar funciones de partición y series temporales.
   * Los montos que vienen como `DoubleType` / `FloatType` deben convertirse a `DecimalType(10, 2)` para evitar errores de precisión de punto flotante en cálculos financieros.
3. **Reglas de negocio:** Filtrar transacciones con montos negativos o estados inválidos.

---

## 7. La Capa Silver: Transformaciones, Limpieza y Particionado

### ¿Cuál es el objetivo de la Capa Silver?
Llevar los datos crudos de la capa Bronze a un estado **confiable, tipado y optimizado** para el consumo de la empresa (*Cleaned & Enriched Single Source of Truth*).

### Técnicas de Ingeniería en PySpark:

#### 1. Deduplicación inteligente: `.dropDuplicates()` vs `.distinct()`
* **`df.distinct()`:** Compara **todas las columnas de la fila**. Si dos filas tienen el mismo ID pero una fecha ligeramente distinta, no las elimina.
* **`df.dropDuplicates(["transaction_id"])`:** Elimina duplicados basándose **únicamente en la clave primaria de negocio**. En producción siempre se usa esta para garantizar unicidad.

#### 2. Tipado Estricto de Fechas y Finanzas
* **String a Timestamp:**
  ```python
  F.to_timestamp("transaction_timestamp_raw", "yyyy-MM-dd HH:mm:ss")
  ```
  Permite extraer automáticamente componentes como `year()`, `month()` y `dayofmonth()`.
* **Float/Double a Decimal Financiero:**
  ```python
  F.col("amount").cast("decimal(10,2)")
  ```
  Evita errores de precisión de coma flotante (`IEEE 754`). En finanzas o contabilidad, **nunca se usa Float ni Double**.

#### 3. Metadatos de Auditoría y Linaje (*Data Lineage*)
Todo pipeline profesional agrega una columna con la fecha/hora exacta en la que se procesó el dato:
```python
F.current_timestamp().alias("silver_processed_at")
```

#### 4. Particionado Físico en Delta Lake
```python
df_silver.write.format("delta").mode("overwrite").partitionBy("year", "month").saveAsTable("silver_transactions")
```
* **¿Por qué particionar por `year` y `month`?**  
  Porque cuando una consulta posterior filtre `WHERE year = 2026 AND month = 10`, Spark hace **Partition Pruning** (poda de particiones): salta directamente a la carpeta de ese mes e ignora el 90% restante del disco, reduciendo drásticamente el tiempo de consulta y el costo en la nube.

---

## 8. La Capa Gold: Marts Analíticos & Delta Lake Internals

### ¿Cuál es el objetivo de la Capa Gold?
Mientras la capa Silver guarda el detalle transacción por transacción, la **Capa Gold** almacena **datos agregados y listos para el consumo de negocio (KPIs)**.

* **¿Por qué pre-calcular agregaciones?**  
  Porque si un dashboard de Power BI o un reporte financiero consulta 10 millones de filas cada vez que un gerente lo abre, el clúster se satura y la nube cobra miles de dólares en cómputo. En la capa Gold, la consulta lee tablas reducidas de alto rendimiento en **milisegundos**.

---

### Los Superpoderes de Delta Lake en Producción (Preguntas Fijas de Entrevista)

Delta Lake no es solo un formato de archivo; es una capa de almacenamiento que añade **capacidades de base de datos relacional a archivos Parquet en un Data Lake**:

#### 1. El Registro de Transacciones (`_delta_log`)
Delta Lake guarda una carpeta oculta `_delta_log/` con archivos JSON que registran cada commit atómico:
* **ACID Guarantees:** Si un job de Spark se cae a la mitad de una escritura, Delta Lake no deja datos corruptos o a medio escribir; simplemente aborta la transacción (*Atomicidad*).

#### 2. `OPTIMIZE` y `Z-ORDER BY` (La solución al *Small File Problem*)
* **El problema de los archivos pequeños:** Cuando Spark escribe en paralelo con cientos de Workers, puede generar miles de archivitos Parquet de 1 MB. Leer miles de archivos pequeños mata el rendimiento de lectura.
* **`OPTIMIZE tabla`:** Toma esos miles de archivos pequeños y los compacta en archivos grandes ideales de 1 GB.
* **`Z-ORDER BY (columna)`:** Reorganiza físicamente los datos dentro de los archivos Parquet para que las filas con valores similares queden juntas. Esto permite a Spark hacer **Data Skipping** (leer solo los archivos donde sabe que está el dato y saltarse el 90% restante sin tocarlos).

#### 3. Time Travel (Auditoría y Rollback)
Delta Lake mantiene el historial de cambios. Puedes consultar el estado exacto de una tabla en cualquier punto del pasado:
```sql
-- Consultar la versión 1 de la tabla antes de que se borraran o actualizaran datos:
SELECT * FROM gold_customer_metrics VERSION AS OF 1;
```

---

## 9. Celdas Políglotas (`%sql`) & Comandos de Producción en Delta Lake

### ¿Qué es una Celda Políglota?
En Databricks no estás atado a un solo lenguaje de programación. Puedes mezclar Python, SQL, Scala y Bash en el mismo cuaderno usando **comandos mágicos (*magic commands*)** en la primera línea de la celda:
* `%sql`: Permite escribir SQL ANSI puro sobre las tablas del Lakehouse.
* `%python`: Vuelve a Python/PySpark.
* `%sh`: Ejecuta comandos de terminal Linux (Bash).

---

### Comandos de Mantenimiento y Auditoría en Delta Lake:

#### 1. `DESCRIBE HISTORY nombre_tabla`
Muestra la bitácora completa de cambios de la tabla Delta:
* Versión (`version 0, 1, 2...`).
* Marca de tiempo (`timestamp`).
* Usuario o servicio que ejecutó la operación.
* Tipo de operación (`CREATE TABLE`, `MERGE`, `OPTIMIZE`, `DELETE`).
* Métricas operativas (cuántos archivos se agregaron o eliminaron).

#### 2. `OPTIMIZE nombre_tabla ZORDER BY (columna)`
* **Compactación:** Resuelve el problema de los archivos pequeños (*Small File Problem*) uniendo micro-archivos Parquet en bloques eficientes.
* **Z-ORDER:** Ordena multidimensionalmente los datos dentro de cada archivo para maximizar el **Data Skipping** (evita leer bloques de disco que no contienen el ID buscado).

#### 3. Time Travel: Consulta Histórica
Permite auditar el estado del Lakehouse en cualquier versión o fecha:
```sql
SELECT * FROM gold_customer_analytics VERSION AS OF 0;
```

---

## 10. Desglose de Métricas del Optimizador (ZOrderStats & Data Skipping)

Al ejecutar `OPTIMIZE gold_customer_analytics ZORDER BY (customer_id);`, Delta Lake devuelve un payload JSON con métricas operativas clave:

```json
{
  "totalConsideredFiles": 1,
  "totalFilesSkipped": 1,
  "numTableColumnsWithStats": 6,
  "zOrderStats": { ... }
}
```

### ¿Qué significan estas métricas en una auditoría técnica?
1. **`totalFilesSkipped: 1` (Protección contra Write Amplification):**  
   Delta Lake evaluó el tamaño del archivo existente (~42 KB) y determinó que ya estaba en un estado óptimo, evitando reescribir datos en disco innecesariamente.
2. **`numTableColumnsWithStats: 6` (Estadísticas Min/Max para Data Skipping):**  
   Delta Lake indexó las 6 columnas en el `_delta_log` guardando los valores mínimos y máximos de cada bloque. Cuando una consulta posterior filtre por `customer_id`, Spark revisa este catálogo y puede omitir la lectura del 90%+ de archivos que no contengan los IDs buscados (*Data Skipping*).

---

## 11. Hito Alcanzado: Paso 3 del Sprint 1 Completado al 100%

| Componente | Capa / Tecnología | Resultado Verificado |
| :--- | :--- | :--- |
| **Ingesta Cruda** | Capa Bronze (`bronze_transactions`) | 100,000 transacciones sintéticas con duplicados intencionales. |
| **Limpieza & Tipado** | Capa Silver (`silver_transactions`) | 90,000 registros únicos deduplicados (`dropDuplicates`), casteados a `Timestamp` y `Decimal(10,2)`, particionados por año y mes. |
| **Marts de Negocio** | Capa Gold (`gold_customer_analytics`) | Agregaciones analíticas por cliente (`total_spent`, `avg_ticket`, segmentación VIP/Frecuente/Ocasional). |
| **Internals Delta Lake** | Delta Log & Cómputo Distribuido | Auditoría con `DESCRIBE HISTORY`, compactación con `OPTIMIZE ZORDER` y validación de `Time Travel`. |

---

*(Este documento se actualizará continuamente al finalizar cada hito práctico).*
