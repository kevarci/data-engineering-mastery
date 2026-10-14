# Sprint 3: MLOps, APIs de Producción y RAG (GenAI Práctica)

> **Duración:** Semanas 5 y 6  
> **Objetivo:** Poner modelos en producción mediante microservicios en FastAPI empaquetados en Docker, con tracking de experimentos en MLflow, caché en Redis y un asistente de búsqueda semántica RAG con base vectorial.

---

## 1. Arquitectura del Proyecto

```
                     ┌──────────────────┐
                     │ Petición Cliente │
                     └────────┬─────────┘
                              │
                              ▼
┌────────────────────────────────────────────────────────┐
│               FASTAPI EN CONTENEDOR DOCKER             │
│                                                        │
│  ┌─────────────────────────┐  ┌─────────────────────┐  │
│  │  Endpoint /predict (ML) │  │ Endpoint /ask (RAG) │  │
│  │  Scikit-learn + MLflow  │  │ LangChain + LLM API │  │
│  └────────────┬────────────┘  └──────────┬──────────┘  │
└───────────────┼──────────────────────────┼─────────────┘
                │                          │
                ▼                          ▼
      ┌──────────────────┐        ┌──────────────────┐
      │   Redis Cache    │        │ Vector Database  │
      │  (Low Latency)   │        │ ChromaDB/pgvector│
      └──────────────────┘        └──────────────────┘
```

---

## 2. Componentes que se implementarán:
1. Servidor local de **MLflow** para tracking de parámetros, métricas y registro de modelos entrenados.
2. API REST modular en **FastAPI** con validación mediante **Pydantic** y manejo asíncrono.
3. Integración de caché en **Redis** para evitar recomputar inferencias idénticas.
4. Módulo RAG con **LangChain** y base vectorial (**ChromaDB** o **pgvector**) para consultas en lenguaje natural sobre documentos no estructurados.
5. `Dockerfile` multi-stage optimizado para despliegue productivo.
