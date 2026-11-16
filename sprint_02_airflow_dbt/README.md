# Module 02: Enterprise DataOps, Airflow Orchestration & Modern Data Stack (dbt)

> **Architecture:** Containerized ELT Pipeline & Kimball Dimensional Modeling  
> **Core Stack:** Apache Airflow 2.8, dbt Core, Docker Compose, PostgreSQL / Microsoft SQL Server  
> **Author:** Kevin Stick Arciniegas Marquez (Lead Data & Cloud Engineer)

---

## 1. System Architecture

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

## 2. Core Engineering Capabilities:
1. **Containerized Orchestration (`docker-compose.yml`):** Production Airflow stack configured with volume bindings for `./dags`, `./logs`, and `./plugins`.
2. **Modular dbt Core Project:**
   * `stg_` models (data cleansing, contract enforcement, and explicit type casting).
   * `int_` models (business logic, aggregations, and intermediate transformations).
   * `fct_` and `dim_` models (Kimball dimensional star schemas optimized for analytical querying).
3. **Automated Quality Assurances:** Comprehensive `dbt test` suites validating uniqueness, not-null constraints, and referential integrity.
4. **Interactive Data Catalog & Lineage:** Dynamic documentation generation reflecting end-to-end data lineage.
