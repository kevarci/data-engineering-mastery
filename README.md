# Mastery Lab: Acelerador Técnico de Datos & Cloud

> **Ubicación:** `Proyectos BigData/mastery-lab`  
> **Candidato:** Kevin Stick Arciniegas Marquez  
> **Estrategia:** *Zero-Fluff / Project-Driven Learning* (Aprender sobre código real en producción)  
> **Documentos de Referencia:**
> * Plan de Estudio Detallado: [PLAN_ESTUDIO.md](file:///c:/Users/pc/Desktop/Proyectos%20BigData/mastery-lab/PLAN_ESTUDIO.md)
> * Diagnóstico de Brechas: [ANALISIS_BRECHAS.md](file:///c:/Users/pc/Desktop/Proyectos%20BigData/mastery-lab/ANALISIS_BRECHAS.md)

---

## 1. Estructura del Repositorio

```
mastery-lab/
├── README.md                           <- Este tablero de control y bitácora
├── PLAN_ESTUDIO.md                     <- Plan de 6 semanas y horarios diarios
├── ANALISIS_BRECHAS.md                 <- Diagnóstico técnico de 510 vacantes
├── sprint_01_aws_lakehouse/            <- SPRINT 1: S3 + PySpark + Databricks + Glue + Athena
│   ├── README.md                       <- Guía paso a paso y arquitectura del Proyecto 1
│   ├── scripts/                        <- Scripts de PySpark, ETL y generación de datos
│   └── infra/                          <- Plantillas y comandos de AWS CLI / IAM
├── sprint_02_airflow_dbt/              <- SPRINT 2: Docker Compose + Airflow + dbt Core
│   └── README.md                       <- Guía y arquitectura del Proyecto 2
├── sprint_03_mlops_rag/                <- SPRINT 3: FastAPI + MLflow + RAG (Vector DB)
│   └── README.md                       <- Guía y arquitectura del Proyecto 3
└── daily_drills/                       <- Ejercicios diarios de código duro (1 hora/día)
    ├── sql_tuning/                     <- T-SQL (SQL Server), Window functions, Índices INCLUDE, EXPLAIN
    ├── bash_scripting/                 <- Scripts Linux robustos para automatización
    └── data_modeling/                  <- Esquemas en estrella Kimball y fórmulas DAX
```

---

## 2. Tablero de Progreso (Sprints de 2 Semanas)

| Sprint / Fase | Objetivo Técnico | Entregable para Portfolio | Estado |
| :--- | :--- | :--- | :--- |
| **Sprint 1 (Sem. 1-2)** | **AWS Lakehouse & PySpark** | Pipeline Serverless Medallion (S3, Delta Lake, Glue, Athena) + T-SQL | 🟡 **EN CURSO (Día 1)** |
| **Sprint 2 (Sem. 3-4)** | **DataOps & Modern Stack** | Clúster Airflow en Docker + SQL Server + Modelado dbt Core | ⚪ Pendiente |
| **Sprint 3 (Sem. 5-6)** | **MLOps & GenAI Práctica** | API FastAPI en Docker + MLflow + Asistente RAG Vectorial | ⚪ Pendiente |

---

## 3. La Rutina Diaria (4.5 Horas de Enfoque Profundo)

```
┌────────────────────────────────────────────────────────────────────────┐
│ 09:00 - 11:30 | BLOQUE 1: PROYECTO CORE (AWS + Big Data / MLOps)      │
│                 Manos en el código. Construcción del pipeline principal│
├────────────────────────────────────────────────────────────────────────┤
│ 11:30 - 12:00 | DESCANSO ACTIVO (Pausa mental)                         │
├────────────────────────────────────────────────────────────────────────┤
│ 12:00 - 13:00 | BLOQUE 2: HARD SKILL DRILL (SQL Server T-SQL / DAX)   │
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

## 4. Bitácora de Trabajo

* **Día 1 (2026-10-14):**
  * **Bloque 1 (Proyecto Core):** Generación y particionado del dataset de transacciones (100,000+ filas, 29 archivos Parquet particionados por año/mes/día) para la capa Bronze de AWS S3.
  * **Bloque 2 (Hard Skill Drill):** Laboratorio interactivo en DBeaver (`tuning_lab.db`). Dominio de Window Functions (`ROW_NUMBER`, `RANK`, `DENSE_RANK`, `Running Total` con `ROWS BETWEEN`, `LAG`) y análisis de planes de ejecución (`SCAN` vs `SEARCH USING INDEX` e índices filtrados).
  * **Bloque 3 (Infra & DataOps):** Script de automatización en Bash (`sync_bronze_lakehouse.sh`) con `set -euo pipefail`, validación de directorios, conteo de particiones y preparación para sincronización con AWS CLI.
  * **Bloque 4 (Cierre & Portfolio):** Configuración de `.gitignore`, inicialización del repositorio Git y pitch de entrevista en inglés técnico.
