# Sprint 2: DataOps, Orquestación con Airflow & Modern Data Stack (dbt)

> **Duración:** Semanas 3 y 4  
> **Objetivo:** Desplegar un clúster local de Apache Airflow en Docker Compose y modelar un Data Warehouse modular con dbt Core (esquema en estrella Kimball + pruebas de datos automatizadas).

---

## 1. Arquitectura del Proyecto

```
┌────────────────────────────────────────────────────────┐
│                   DOCKER COMPOSE                       │
│ ┌──────────────┐  ┌──────────────┐  ┌────────────────┐ │
│ │  PostgreSQL  │  │    Redis     │  │  Airflow Web   │ │
│ │  (Metastore) │  │   (Broker)   │  │  & Scheduler   │ │
│ └──────┬───────┘  └──────┬───────┘  └───────┬────────┘ │
└────────┼─────────────────┼──────────────────┼──────────┘
         │                 │                  │
         └─────────────────┴──────────────────┘
                           │
                           ▼
                  ┌──────────────────┐
                  │   AIRFLOW DAG    │
                  └────────┬─────────┘
                           │
                           ▼
                  ┌──────────────────┐
                  │     dbt Core     │
                  │ Staging -> Marts │
                  │     Testing      │
                  └──────────────────┘
```

---

## 2. Componentes que se implementarán:
1. `docker-compose.yml`: Stack productivo de Airflow con volúmenes mapeados para `./dags`, `./logs` y `./plugins`.
2. Proyecto `dbt`:
   * Modelos `stg_` (limpieza y tipos).
   * Modelos `int_` (transformaciones intermedias).
   * Modelos `fct_` y `dim_` (hechos y dimensiones en estrella).
3. Pruebas de calidad automáticas (`unique`, `not_null`, `relationships`).
4. Generación y hosting del catálogo de linaje interactivo de dbt.
