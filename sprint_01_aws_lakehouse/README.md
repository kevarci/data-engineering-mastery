# Sprint 1: Serverless Lakehouse en AWS con PySpark y Delta Lake

> **Duración:** Semanas 1 y 2  
> **Objetivo:** Construir una arquitectura Lakehouse Medallion (Bronze -> Silver -> Gold) en AWS + Databricks que sustituya los scripts aislados de Pandas por procesamiento distribuido masivo.

---

## 1. Diagrama de la Arquitectura del Proyecto

```
┌─────────────────┐       ┌──────────────────────┐       ┌──────────────────────┐
│  Datos Crudos   │       │  Capa Bronze / Raw   │       │  Capa Silver / Clean │
│  (Transacciones)├──────►│  Amazon S3 Bucket    ├──────►│  Databricks PySpark  │
│  CSV / Parquet  │       │  Partición por Fecha │       │  Limpieza & Tipado   │
└─────────────────┘       └──────────────────────┘       └──────────┬───────────┘
                                                                    │
                                                                    ▼
┌─────────────────┐       ┌──────────────────────┐       ┌──────────────────────┐
│  Consultas SQL  │       │  Catálogo Central    │       │  Capa Gold / Marts   │
│  Amazon Athena  │◄──────┤  AWS Glue Catalog    │◄──────┤  Delta Lake (ACID)   │
│  (Bajo Costo)   │       │  (Glue Crawler)      │       │  Métricas de Negocio │
└─────────────────┘       └──────────────────────┘       └──────────────────────┘
```

---

## 2. Hoja de Ruta Paso a Paso del Sprint 1

### Paso 1: Generación de Datos Masivos Particionados (Local)
* Ejecuta el script `scripts/generate_sample_dataset.py` para generar 100,000+ transacciones simuladas realistas con marcas de tiempo, clientes, montos y métodos de pago.
* Estructura de particionado en local: `data/raw/year=2026/month=10/day=DD/*.parquet`.

### Paso 2: Creación del Bucket en Amazon S3 y Subida de Datos
* Crear un bucket en AWS S3: `kevin-lakehouse-data-dev` (en una región cercana como `us-east-1`).
* Subir los datos particionados a la ruta `s3://kevin-lakehouse-data-dev/bronze/transactions/`.

### Paso 3: Conexión con Databricks Community Edition (Gratis)
* Crear cuenta gratuita en [Databricks Community Edition](https://community.cloud.databricks.com/).
* Configurar un clúster Spark gratuito.
* Escribir un Notebook en PySpark:
  1. **Lectura Bronze:** Leer los datos de S3 o montados en DBFS.
  2. **Transformación Silver:** Limpieza de nulos, deduplicación de IDs, conversión a tipos Timestamp y Decimal, y validación de reglas de negocio.
  3. **Persistencia Gold en Delta Lake:** Agregaciones por cliente y categoría, guardado con formato `format("delta")` y prueba de comandos `OPTIMIZE` y `Z-ORDER BY`.

### Paso 4: Catalogación con AWS Glue & Consulta en Athena
* Crear un **Glue Crawler** que apunte a `s3://kevin-lakehouse-data-dev/gold/`.
* Ejecutar el crawler para que detecte el esquema e infiera la tabla en el **Glue Data Catalog**.
* Abrir **Amazon Athena** y ejecutar consultas analíticas SQL en segundos sin pagar por un servidor activo.

---

## 3. Entregables para tu Portfolio al terminar el Sprint 1:
1. Repositorio en GitHub con:
   * Notebook de PySpark limpio y comentado.
   * Diagrama de arquitectura en PNG / Excalidraw.
   * `README.md` detallando reducción de costos y tiempos de consulta en Delta Lake vs CSV/JSON.
2. Actualización de 2 líneas en tu CV maestro.

---

## 📓 Cuadernos de Cátedra & Documentación Técnica
* 📘 [NOTAS_CLASE_DATABRICKS.md](docs/NOTAS_CLASE_DATABRICKS.md) - Cómputo Distribuido con PySpark, Databricks y Delta Lake (ACID, Z-Order & Time Travel).
* 📙 [CUADERNO_ESTUDIO_AWS_GLUE_ATHENA.md](docs/CUADERNO_ESTUDIO_AWS_GLUE_ATHENA.md) - Arquitectura Serverless en AWS: Layout S3 Hive-Style, Glue Data Catalog, Crawlers y Partition Pruning en Athena.

