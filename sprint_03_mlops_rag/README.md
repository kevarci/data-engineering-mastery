# Module 03: Production MLOps, High-Throughput Serving & GenAI (RAG)

> **Architecture:** High-Performance REST API, Model Lifecycle & Semantic Retrieval  
> **Core Stack:** FastAPI, Pydantic, MLflow, Redis, Docker, LangChain, ChromaDB / pgvector  
> **Author:** Kevin Stick Arciniegas Marquez (Lead Data & Cloud Engineer)

---

## 1. System Architecture

```
                     ┌──────────────────┐
                     │ Client Request   │
                     └────────┬─────────┘
                              │
                              ▼
┌────────────────────────────────────────────────────────┐
│             FASTAPI PRODUCTION CONTAINER               │
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

## 2. Core Engineering Capabilities:
1. **Experiment Tracking & Model Registry:** Centralized MLflow server tracking parameters, artifacts, and staging/production model transitions.
2. **High-Performance Async API (FastAPI):** Strict schema validation with Pydantic v2, dependency injection, and sub-15ms response times.
3. **Low-Latency Distributed Caching (Redis):** In-memory caching for repeated inference requests, reducing compute costs and query latency.
4. **Semantic Retrieval RAG Pipeline:** Context ingestion, chunking, and similarity search powered by LangChain and pgvector/ChromaDB.
5. **Hardened Production Dockerfile:** Multi-stage build pattern eliminating build dependencies and securing rootless execution.
