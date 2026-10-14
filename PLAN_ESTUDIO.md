# Plan de Estudio Acelerado de Alto Impacto: Data & Cloud Engineering

> **Rol del Mentor:** Ingeniero Senior / Career Coach Técnico
> **Candidato:** Kevin Stick Arciniegas Marquez
> **Situación:** En búsqueda activa de empleo. Disponibilidad inmediata.
> **Metodología:** *Zero-Fluff / Project-Driven Learning* (Aprender construyendo arquitecturas reales sobre la marcha).
> **Meta:** Convertir debilidades en competencias productivas comprobables en **6 semanas**, generando **3 proyectos de portafolio para producción** y actualizando el CV de forma escalonada cada 2 semanas.

---

## 1. El Principio de Realidad (Mentalidad Senior)

Cuando estás desempleado y necesitas resultados rápidos, **estudiar 6 temas distintos durante 1 hora cada uno al día es un error fatal**. Se llama *fatiga por cambio de contexto*: al final de la semana sientes que trabajaste 40 horas, pero no tienes nada tangible que subir a GitHub, nada que agregar a tu CV y te bloqueas en una prueba técnica.

### La Regla de Oro del Plan:

> **No estudiamos conceptos aislados: construimos pipelines de datos de punta a punta.**
> La teoría de AWS, Spark o Docker la aprendes cuando el pipeline te lance un error en la terminal. Cada sprint de 2 semanas debe culminar con un repositorio público en GitHub, un diagrama de arquitectura y 2 líneas nuevas de alto impacto en tu CV.

---

## 2. La Rutina Diaria: Estructura por Bloques (4.5 Horas de Enfoque Profundo)

Diseñado para no quemarte (*burnout*) y garantizar absorción real:

```
┌────────────────────────────────────────────────────────────────────────┐
│ 09:00 - 11:30 | BLOQUE 1: PROYECTO CORE (AWS + Big Data / MLOps)      │
│                 Manos en el código. Construcción del pipeline principal│
├────────────────────────────────────────────────────────────────────────┤
│ 11:30 - 12:00 | DESCANSO ACTIVO (Pausa mental)                         │
├────────────────────────────────────────────────────────────────────────┤
│ 12:00 - 13:00 | BLOQUE 2: HARD SKILL DRILL (SQL Tuning / Bash / DAX)   │
│                 Ejercicios duros de código para pasar pruebas técnicas │
├────────────────────────────────────────────────────────────────────────┤
│ 13:00 - 14:00 | ALMUERZO                                               │
├────────────────────────────────────────────────────────────────────────┤
│ 14:00 - 15:00 | BLOQUE 3: INFRA & DATAOPS (Docker, Airflow, CI/CD)     │
│                 Contenedores, orquestación y automatización            │
├────────────────────────────────────────────────────────────────────────┤
│ 15:00 - 15:30 | BLOQUE 4: CIERRE, PORTAFOLIO E INGLÉS TÉCNICO          │
│                 Git commit, documentar README y explicar en voz alta  │
└────────────────────────────────────────────────────────────────────────┘
```

---

## 3. Hoja de Ruta de 6 Semanas (3 Sprints de 2 Semanas)

---

### SPRINT 1 (Semanas 1 y 2): AWS Data Foundations + PySpark Distribuido

> **Objetivo:** Pasar de scripts locales con Pandas/PyArrow a procesamiento distribuido en la nube con AWS y Databricks.

#### Lo que vas a construir (Proyecto Entregable #1):

**"Serverless Lakehouse Pipeline en AWS con PySpark y Delta Lake"**

* Subes un dataset masivo crudo (ej. transacciones o logs públicos de millones de filas) a un bucket de **Amazon S3**.
* Conectas **Databricks Community Edition** (gratis) al dataset y ejecutas transformaciones distribuidas en **PySpark** implementando la arquitectura Medallion (**Bronze $\rightarrow$ Silver $\rightarrow$ Gold**).
* Persistes los datos en formato **Delta Lake** (probando operaciones `MERGE INTO`, `OPTIMIZE` y Time Travel).
* Creas un **AWS Glue Crawler** para catalogar la capa Gold en el **Glue Data Catalog**.
* Ejecutas consultas analíticas de bajo costo y alta velocidad mediante **Amazon Athena**.

#### Distribución Diaria (Semana 1 y 2):

* **Bloque 1 (2.5h - AWS & PySpark):**
  * *Días 1-3:* S3 (particionado por fechas `year/month`) + Glue Data Catalog + Athena.
  * *Días 4-7:* PySpark en Databricks (DataFrames distribuidos, agregaciones, `groupBy`, `join` broadcast vs shuffle hash join).
  * *Días 8-10:* Delta Lake (ACID, transacciones, optimización y compresión Parquet).
* **Bloque 2 (1h - SQL Server & T-SQL Performance Tuning):**
  * *Días 1-4:* Funciones de ventana avanzadas en T-SQL (`ROW_NUMBER`, `DENSE_RANK`, `LEAD`, `LAG`, marcos `ROWS BETWEEN`).
  * *Días 5-7:* **SQL Server Internals & Índices:** Clustered vs Non-Clustered Indexes, índices con columnas incluidas (`INCLUDE`) para eliminar *Key Lookups*, e índices filtrados.
  * *Días 8-10:* **Planes de Ejecución (Execution Plans en SSMS / ADS):** Detección de Index Scan vs Index Seek, Hash Match vs Nested Loops, Spills a TempDB. Patrones T-SQL (`CROSS APPLY`, `MERGE`, tablas temporales `#temp` vs variables de tabla `@table`, y Stored Procedures con `TRY...CATCH` transaccional).
* **Bloque 3 (1h - Bash Scripting en Linux):**
  * Escribir scripts `.sh` para automatizar la descarga, particionado y subida de archivos hacia AWS CLI con manejo de errores (`set -euo pipefail`).
* **Bloque 4 (30m - Cierre & Inglés):**
  * Grabar un video de 2 minutos o redactar el README en GitHub explicando en inglés: *"How I built a Medallion Lakehouse on AWS and Databricks"*.

#### Al finalizar la Semana 2:

* **Actualización en tu CV:**
  * En Habilidades: `AWS (S3, Glue, Athena)`, `Apache Spark`, `PySpark`, `Databricks`, `Delta Lake`, `Microsoft SQL Server (T-SQL, Index Tuning, Stored Procedures)`.
  * En Proyectos: Agregar el proyecto del Serverless Lakehouse con link a GitHub.

---

### SPRINT 2 (Semanas 3 y 4): DataOps, Orquestación con Airflow y Modern Data Stack (dbt)

> **Objetivo:** Eliminar la dependencia de `crontab` y demostrar que sabes orquestar flujos corporativos con Docker y dbt, conectando SQL Server y Cloud Warehouses.

#### Lo que vas a construir (Proyecto Entregable #2):

**"Orquestación Integral con Apache Airflow en Docker + Modelado Modular con dbt"**

* Levantas un clúster local de **Apache Airflow** (Webserver, Scheduler, Postgres, Redis) usando **Docker Compose**.
* Incorporas un contenedor de **Microsoft SQL Server (Linux image en Docker)** como base de datos transaccional origen.
* Creas un DAG en Python con dependencias, ingesta vía JDBC/PySpark, sensores, reintentos automáticos y alertas ante fallos.
* Conectas **dbt Core** (usando adaptadores `dbt-postgres`, `dbt-sqlserver` o `dbt-snowflake`):
  * Modelas tablas de Staging, Intermediate y Marts dimensionales (esquema en estrella Kimball).
  * Creas pruebas de integridad de datos (`dbt test` para unicidad, no nulos y relaciones foráneas).
  * Generas la documentación y linaje del dato (*data lineage*) interactivo de dbt.

#### Distribución Diaria (Semana 3 y 4):

* **Bloque 1 (2.5h - Airflow & dbt):**
  * *Días 1-4:* Configuración de Docker Compose para Airflow + contenedor de SQL Server. Creación de DAGs modulares con TaskFlow API (`@task`).
  * *Días 5-8:* dbt Core. Creación de modelos SQL modulares, Jinja templating, macros y snapshots (SCD Tipo 2).
  * *Días 9-10:* Integración de dbt dentro de tareas de Airflow (`BashOperator` / `Cosmos`).
* **Bloque 2 (1h - Data Modeling & Power BI DAX sobre SQL Server):**
  * *Días 1-5:* Modelado Dimensional formal (tablas de hechos vs dimensiones, esquemas en estrella sobre SQL Server).
  * *Días 6-10:* Power BI avanzado: conexión DirectQuery / Import a SQL Server, DAX con `CALCULATE`, `USERELATIONSHIP`, `ALL`, funciones de inteligencia de tiempo.
* **Bloque 3 (1h - Data Testing & Calidad):**
  * Implementar **Great Expectations** o pruebas nativas de dbt para garantizar "cero datos corruptos" (poniendo en valor tu pasado en QA).
* **Bloque 4 (30m - Cierre & Git):**
  * Configurar **GitHub Actions** para que corra un linter (`sqlfluff` y `ruff`) automáticamente en cada commit.

#### Al finalizar la Semana 4:

* **Actualización en tu CV:**
  * En Habilidades: `Apache Airflow`, `dbt Core`, `Microsoft SQL Server`, `Docker Compose`, `CI/CD (GitHub Actions)`, `Modelado Dimensional (Star Schema)`, `DAX Avanzado`.
  * En Proyectos: Agregar el repositorio del pipeline orquestado con Airflow y dbt.

---

### SPRINT 3 (Semanas 5 y 6): MLOps, APIs de Producción y RAG (GenAI Práctica)

> **Objetivo:** Convertirte en un Científico de Datos que sabe poner modelos en producción e implementar arquitecturas modernas de IA Generativa.

#### Lo que vas a construir (Proyecto Entregable #3):

**"API de Inferencia con FastAPI + MLOps (MLflow) + Asistente RAG con Vector DB"**

* Entrenas un modelo de Machine Learning en Scikit-learn registrando hiperparámetros, métricas y artefactos en **MLflow**.
* Empaquetas el modelo como una API REST de alto rendimiento usando **FastAPI** y **Pydantic** (con validación estricta de esquemas).
* Dockerizas la aplicación en una imagen ligera optimizada para producción.
* Agregas un endpoint de **IA Generativa / RAG**:
  * Ingesta de documentos de texto/PDFs.
  * Generación de embeddings y almacenamiento en una base de datos vectorial (**ChromaDB** o extensión `pgvector` en PostgreSQL).
  * Consulta semántica conectada a un LLM (mediante LangChain y OpenAI / Groq / Hugging Face).

#### Distribución Diaria (Semana 5 y 6):

* **Bloque 1 (2.5h - MLOps & FastAPI):**
  * *Días 1-4:* Servidor de MLflow local, tracking de experimentos y Model Registry.
  * *Días 5-7:* Desarrollo de la API REST con FastAPI (endpoints `/predict`, `/health`, manejo asíncrono con Pydantic).
  * *Días 8-10:* Contenedor Docker para producción (multi-stage build, no-root user).
* **Bloque 2 (1h - Ecosistema RAG & Vector DBs):**
  * *Días 1-5:* Embeddings, chunking de texto y consultas de similitud coseno en ChromaDB / pgvector.
  * *Días 6-10:* Pipeline RAG con LangChain (RetrievalQA chain y prompt engineering estructurado).
* **Bloque 3 (1h - NoSQL / Caching con Redis):**
  * Conectar **Redis** a la API de FastAPI para cachear predicciones repetitivas y reducir la latencia de 200ms a 5ms.
* **Bloque 4 (30m - Pitch de Entrevista en Inglés):**
  * Practicar cómo explicar en inglés el ciclo de vida de este modelo desde el entrenamiento hasta el serving en Docker.

#### Al finalizar la Semana 6:

* **Actualización en tu CV:**
  * En Habilidades: `MLflow (MLOps)`, `FastAPI`, `Docker`, `RAG (Retrieval-Augmented Generation)`, `Vector Databases (ChromaDB/pgvector)`, `LangChain`, `Redis`.
  * En Proyectos: Agregar el repositorio del microservicio de ML & RAG.

---

## 4. Herramientas y Recursos Gratuitos (100% Sin Costo)

No necesitas gastar dinero en suscripciones caras para dominar este stack:

| Necesidad                         | Herramienta Gratuita              | Cómo Usarla                                                                                                                                      |
| :-------------------------------- | :-------------------------------- | :------------------------------------------------------------------------------------------------------------------------------------------------ |
| **AWS Cloud**               | AWS Free Tier                     | 12 meses gratis de S3 (5 GB), Lambda (1M peticiones/mes), Glue (primer millón de objetos en catalog). Ten cuidado con apagar instancias EC2/RDS. |
| **Spark & Lakehouse**       | Databricks Community Edition      | Entorno Spark + Delta Lake gratuito en la nube sin costo alguno.                                                                                  |
| **Bases de Datos & Vector** | PostgreSQL local con `pgvector` | Instálalo en local o mediante Docker. Gratis e idéntico a producción.                                                                          |
| **Orquestación**           | Apache Airflow en Docker          | Levantar el stack oficial de Airflow en Docker Compose en tu máquina.                                                                            |
| **Transformación SQL**     | dbt Core                          | Open source y gratuito (se instala con `pip install dbt-postgres`).                                                                             |
| **Modern OLAP**             | DuckDB                            | Motor analítico embebido ultra rápido (`pip install duckdb`).                                                                                 |
| **Tracking de Modelos**     | MLflow                            | Servidor local gratuito (`mlflow ui`).                                                                                                          |
| **APIs de LLM para RAG**    | Groq Cloud / Hugging Face         | Groq ofrece inferencia de Llama 3 / Mixtral ultra rápida con API gratuita.                                                                       |

---

## 5. Estrategia de Búsqueda de Empleo Durante el Plan

Estar desempleado no significa esperar 6 semanas para enviar CVs. **Se aplica con un enfoque iterativo**:

* **Semanas 1 y 2:** Aplica a roles de **Analista de Datos / BI** y **Data Engineer Junior** (donde tu Python, SQL y Parquet ya son competitivos).
* **Semanas 3 y 4:** Tras terminar el Sprint 1 (AWS + PySpark), actualiza tu CV y empieza a postularte a vacantes de **Data Engineer Mid** que exijan Databricks, PySpark y AWS.
* **Semanas 5 y 6:** Con Airflow, dbt y MLOps en tu perfil, postula a vacantes de **Data Engineer Senior Stretch**, **Analytics Engineer** y **Machine Learning Engineer**.

---

*Este plan de estudio es tu contrato operativo de trabajo diario. La disciplina constante durante 4.5 horas al día supera cualquier curso teórico.*
