<div align="center">

# ⚡ LABORATORIO ENTERPRISE DE DATOS & CLOUD
### *Arquitecturas Cloud Escalables • Pipelines Distribuidos Lakehouse • Optimización y Tuning de Bases de Datos*

<p align="center">
  <a href="README.md">
    <img src="https://img.shields.io/badge/Versi%C3%B3n_en_Espa%C3%B1ol-🇪🇸-2ea44f?style=for-the-badge&logoColor=white" alt="Versión en Español" height="34" />
  </a>
  &nbsp;&nbsp;&nbsp;&nbsp;
  <a href="README_EN.md">
    <img src="https://img.shields.io/badge/English_Version-🇬🇧-0969da?style=for-the-badge&logoColor=white" alt="English Version" height="34" />
  </a>
</p>

[![AWS](https://img.shields.io/badge/AWS-Cloud%20Data%20Stack-232F3E?style=for-the-badge&logo=amazon-aws&logoColor=white)](https://aws.amazon.com/)
[![Apache Spark](https://img.shields.io/badge/Apache%20Spark-3.5%20%7C%20PySpark-E25A1C?style=for-the-badge&logo=apache-spark&logoColor=white)](https://spark.apache.org/)
[![Databricks](https://img.shields.io/badge/Databricks-Delta%20Lake%20ACID-FF3621?style=for-the-badge&logo=databricks&logoColor=white)](https://databricks.com/)
[![Airflow](https://img.shields.io/badge/Apache%20Airflow-Orquestaci%C3%B3n-017CEE?style=for-the-badge&logo=apache-airflow&logoColor=white)](https://airflow.apache.org/)
[![dbt](https://img.shields.io/badge/dbt%20Core-Transformaciones-FF694B?style=for-the-badge&logo=dbt&logoColor=white)](https://getdbt.com/)
[![Docker](https://img.shields.io/badge/Docker-Contenedores%20%26%20Compose-2496ED?style=for-the-badge&logo=docker&logoColor=white)](https://www.docker.com/)
[![SQL Server](https://img.shields.io/badge/SQL%20Server-T--SQL%20Tuning-CC292B?style=for-the-badge&logo=microsoft-sql-server&logoColor=white)](https://www.microsoft.com/sql-server)
[![Python](https://img.shields.io/badge/Python-3.12-3776AB?style=for-the-badge&logo=python&logoColor=white)](https://www.python.org/)

<p align="center">
  <b>Diseñado por <a href="https://github.com/kevarci">Kevin Stick Arciniegas Marquez</a></b><br>
  <i>Ingeniero de Datos & Cloud • Sistemas Distribuidos • Optimización de Consultas & Rendimiento</i>
</p>

---

</div>

## 📌 Resumen Ejecutivo

Este repositorio es un monorepo de nivel productivo que contiene arquitecturas de datos de punta a punta diseñadas para soportar cargas analíticas masivas, transformaciones distribuidas, orquestación tolerante a fallos y optimización profunda de motores relacionales.

* **Lakehouse Distribuido:** Construido sobre la **Arquitectura Medallion (Bronze $\rightarrow$ Silver $\rightarrow$ Gold)** utilizando AWS S3, PySpark y Delta Lake.
* **DataOps Moderno:** Orquestación multicontenedor con Apache Airflow, Docker Compose, SQL Server y modelado dimensional modular con dbt Core.
* **Ingeniería de Rendimiento (SQL Tuning):** Comprensión profunda de motores relacionales, diagnóstico con planes de ejecución (`EXPLAIN QUERY PLAN`), índices cubrientes (`INCLUDE`) e índices filtrados/parciales.

---

## 🚀 Tablero de Entregas & Hoja de Ruta

```
┌────────────────────────────────────────────────────────────────────────────────────────┐
│  ESTADO GENERAL DEL PROYECTO                                                           │
│  [■■■■■■■■■■■■■■□□□□□□] 70% Entregables de Sprint 1 Completados                        │
└────────────────────────────────────────────────────────────────────────────────────────┘
```

| Fase / Hito | Arquitectura & Alcance | Stack Principal | Estado |
| :--- | :--- | :--- | :---: |
| **Sprint 1: Lakehouse Serverless en AWS** | Lakehouse Medallion escalable en AWS. Ingesta particionada en Parquet, limpieza con PySpark, transacciones ACID con Delta Lake, catálogo con AWS Glue y consultas analíticas en Athena. | `AWS S3` `PySpark` `Databricks` `Delta Lake` `AWS Glue` `Athena` | 🟡 **EN CURSO (70% Completado)** |
| **Sprint 2: DataOps & Orquestación** | Pipeline ELT corporativo en Docker. Ingesta relacional desde SQL Server, DAGs modulares con TaskFlow API, modelado dimensional Kimball con dbt Core y contratos de datos automáticos. | `Apache Airflow` `Docker Compose` `dbt Core` `SQL Server` `PostgreSQL` | ⚪ Planificado |
| **Sprint 3: MLOps & Servicio de GenAI** | Microservicio de inferencia de alto rendimiento con FastAPI, tracking de experimentos en MLflow, imágenes Docker multi-stage y recuperación semántica RAG con base de datos vectorial. | `FastAPI` `MLflow` `ChromaDB` `pgvector` `LangChain` `Redis` | ⚪ Planificado |

---

## 📚 Cuadernos de Cátedra & Notas de Ingeniería

Para profundizar en los conceptos arquitectónicos, patrones de diseño y preparación de entrevistas técnicas, este repositorio incluye **3 cuadernos de cátedra de nivel Senior**:

| Cuaderno de Cátedra | Tema Principal | Conceptos Clave | Enlace |
| :--- | :--- | :--- | :---: |
| 📘 **Cátedra 01: Databricks & Lakehouse** | Arquitectura Medallion & Delta Lake | SparkSession, Cómputo Distribuido, `dropDuplicates`, Delta Log, `OPTIMIZE`, `Z-ORDER`, Time Travel | [Ver Cuaderno 01](sprint_01_aws_lakehouse/NOTAS_CLASE_DATABRICKS.md) |
| 📗 **Cátedra 02: SQL & T-SQL Performance** | Optimización de Bases de Datos | `EXPLAIN QUERY PLAN` (Scan vs Seek), Índices `INCLUDE`, Índices Filtrados, `CROSS APPLY`, Window Functions (`DENSE_RANK`, `ROWS BETWEEN`, `LAG`) | [Ver Cuaderno 02](daily_drills/sql_tuning/CUADERNO_ESTUDIO_SQL_TUNING.md) |
| 📙 **Cátedra 03: Infra & DataOps** | Automatización en Linux & Cloud | Bash Strict Mode (`set -euo pipefail`), Rutas dinámicas, Programación defensiva, Idempotencia con `aws s3 sync` | [Ver Cuaderno 03](daily_drills/CUADERNO_ESTUDIO_BASH_DATAOPS.md) |

---

## 🏛️ Arquitectura Activa: Serverless Lakehouse (Sprint 1)

```
                               FLUJO DE INGESTA Y PROCESAMIENTO
                                  
 ┌──────────────────────┐        ┌───────────────────────┐        ┌───────────────────────┐
 │   INGESTA CRUDA      │        │  CAPA BRONZE (RAW)    │        │  CAPA SILVER (CLEAN)  │
 │ 100,000+ Transacciones├──────►│    Amazon S3 Bucket   ├───────►│  Databricks PySpark   │
 │  Parquet Particionado│        │  year=YYYY/month=MM   │        │ Limpieza & Tipado     │
 └──────────────────────┘        └───────────────────────┘        └───────────┬───────────┘
                                                                              │
                                                                              ▼
 ┌──────────────────────┐        ┌───────────────────────┐        ┌───────────────────────┐
 │   CONSULTAS SQL      │        │  CATÁLOGO CENTRALIZADO│        │   CAPA GOLD (MARTS)   │
 │   Amazon Athena      │◄───────┤    AWS Glue Catalog   │◄───────┤   Delta Lake (ACID)   │
 │ Consultas Bajo Costo │        │    (Glue Crawler)     │        │  Métricas de Negocio  │
 └──────────────────────┘        └───────────────────────┘        └───────────────────────┘
```

### Componentes de Ingeniería del Sprint 1:
1. **Pipeline de Datos Particionado (`generate_sample_dataset.py`):**
   * Genera más de 100,000 eventos transaccionales realistas de e-commerce y pagos.
   * Particionado físico en directorios Parquet (`year=2026/month=10/day=DD`) para maximizar el **predicate pushdown** y reducir costos de escaneo en la nube.
2. **Automatización Defensiva en Bash (`sync_bronze_lakehouse.sh`):**
   * Construido con **Bash Strict Mode** (`set -euo pipefail`) para detenerse inmediatamente ante fallos.
   * Detección dinámica de rutas relativas (portable entre Windows, contenedores Linux y servidores EC2).
   * Sincronización idempotente con **`aws s3 sync`** y simulaciones de seguridad con `--dryrun`.

---

## ⚡ Ingeniería de Rendimiento & Internals de Bases de Datos (`daily_drills/`)

En entornos corporativos, escribir SQL no basta; **entender cómo el motor almacena y lee los datos es lo que garantiza tiempos de respuesta en milisegundos**.

```
┌────────────────────────────────────────────────────────────────────────────────────────┐
│  BENCHMARK: 120,000 FILAS TABLE SCAN VS. BÚSQUEDA POR ÍNDICE B-TREE                    │
├────────────────────────────────┬───────────────────────────────────────────────────────┤
│ SIN ÍNDICE (Table Scan):       │ detail: SCAN FactSales                                │
│ Costo: Alto I/O ($O(N)$)       │ Lee 120,000 filas de forma secuencial en disco        │
├────────────────────────────────┼───────────────────────────────────────────────────────┤
│ CON ÍNDICE COMPUESTO:          │ detail: SEARCH FactSales USING INDEX IX_Cust_Date     │
│ Costo: Milisegundos ($O(\log N)$) Salto binario directo a las hojas del árbol B-Tree   │
└────────────────────────────────┴───────────────────────────────────────────────────────┘
```

### 🎯 Competencias Demostradas en Código:
* **Índices Filtrados (Partial Indexes):** Indexación exclusiva de registros operativos frecuentes (`WHERE Status = 'PENDING'`), ahorrando el **97% de espacio en disco** y acelerando las inserciones de ventas completadas.
* **Índices Cubrientes (`INCLUDE`):** Almacenamiento de columnas proyectadas en el nivel hoja para eliminar el costoso **Key Lookup / Bookmark Lookup**.
* **Funciones de Ventana Avanzadas:**
  * **Resolución de Empates:** Diferenciación estricta entre `DENSE_RANK()`, `RANK()` y `ROW_NUMBER()`.
  * **Totales Acumulados Optimizados:** Definición física del marco (`ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW`) para evitar sobrecostos por escaneos `RANGE`.
  * **Análisis Periodo a Periodo (MoM):** Cálculo de variaciones porcentuales sin hacer `SELF JOIN` mediante `LAG()` y `LEAD()`.

---

## 📂 Topología del Repositorio

```bash
mastery-lab/
├── sprint_01_aws_lakehouse/            # SPRINT 1: Serverless Lakehouse en AWS
│   ├── README.md                       # Diagrama de arquitectura y guía paso a paso
│   ├── scripts/                        # Ingesta, validación y jobs de PySpark
│   │   ├── generate_sample_dataset.py  # Generador de dataset Parquet particionado
│   │   └── sync_bronze_lakehouse.sh    # Script de automatización en Bash
│   └── data/                           # Capa de datos crudos locales (ignorado en Git)
├── sprint_02_airflow_dbt/              # SPRINT 2: DataOps, Airflow y dbt Core
│   └── README.md                       # Guía de orquestación en contenedores
├── sprint_03_mlops_rag/                # SPRINT 3: MLOps Productivo y GenAI
│   └── README.md                       # FastAPI, Model Registry y Base Vectorial
└── daily_drills/                       # Drills Técnicos & Performance Engineering
    └── sql_tuning/                     # Laboratorio para SQL Server, Postgres y motores analíticos
        ├── 01_window_functions.sql     # Patrones frecuentes de entrevistas técnicas
        ├── 02_sql_server_tsql_tuning.sql # Tuning profundo de motor y transacciones
        └── dbeaver_interactive_lab.sql # Suite de pruebas ejecutada en 120,000+ registros
```

---

## 🛠️ Ecosistema Tecnológico

| Categoría | Tecnologías y Herramientas |
| :--- | :--- |
| **Cloud & Almacenamiento** | AWS S3, AWS Glue, Amazon Athena, Delta Lake, Formato Parquet |
| **Procesamiento de Datos** | Apache Spark, PySpark, Databricks, Python 3.12, DuckDB |
| **Orquestación & DevOps** | Apache Airflow, Docker, Docker Compose, Git, Bash Scripting |
| **Modelado de Datos & SQL**| Microsoft SQL Server, PostgreSQL, dbt Core, T-SQL, DBeaver |
| **Servicio de Modelos & IA** | FastAPI, MLflow, Scikit-learn, ChromaDB, LangChain |

---

## 🛡️ Estándares Productivos
1. **Idempotencia por Diseño:** Todos los pipelines ETL pueden reejecutarse sin generar datos duplicados ni inconsistencias.
2. **Operaciones Defensivas:** Scripts con códigos de salida estrictos, validación previa de insumos y modos `--dryrun`.
3. **Optimización de I/O:** Priorización de compresión columnar, particionado inteligente y cobertura de índices antes de escalar cómputo innecesariamente.

---

<div align="center">
  <sub>Mantenido por <b>Kevin Stick Arciniegas Marquez</b> • Abierto a oportunidades en Ingeniería de Datos y Arquitectura Cloud.</sub>
</div>
