# Database Performance Engineering: Window Functions & Engine Tuning

> **Focus:** Relational Engine Internals, Query Optimization & Execution Plan Diagnostics  
> **Engine Environments:** Microsoft SQL Server (T-SQL), PostgreSQL, SQLite (120,000+ records)  
> **Author:** Kevin Stick Arciniegas Marquez (Lead Data Engineer)

---

## 1. Overview & Capabilities Demonstrated

This module contains production-grade SQL and T-SQL optimizations designed for high-throughput relational workloads and large transactional tables.

### Key Optimization Patterns:

1. **Execution Plan Diagnostics (`EXPLAIN QUERY PLAN`):**
   * Eliminating $O(N)$ sequential Table Scans by transforming them into $O(\log N)$ B-Tree Index Seeks.
2. **Covering Indexes (`INCLUDE`):**
   * Eliminating expensive **Key Lookups / Bookmark Lookups** by appending projected columns to leaf nodes.
3. **Filtered / Partial Indexes:**
   * Indexing exclusively active operational subsets (`WHERE Status = 'PENDING'`), saving **97% of storage footprint** and minimizing index maintenance overhead during heavy insert bursts.
4. **Physical Join Selection & Memory Management:**
   * Identifying when the engine selects **Nested Loops**, **Merge Join**, or **Hash Match**.
   * Preventing fatal **Hash Spills to TempDB** caused by outdated statistics and insufficient memory grants.
5. **Advanced Analytical SQL:**
   * Tie-handling differentiation (`ROW_NUMBER()` vs `RANK()` vs `DENSE_RANK()`).
   * Explicit physical window frame definitions (`ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW`) to prevent CPU-intensive logical `RANGE` spooling.
   * Period-over-Period (MoM) delta calculations via `LAG()` and `LEAD()` without correlated self-joins.
   * Atomic Upsert patterns (`MERGE INTO` / `ON CONFLICT DO UPDATE`).

---

## 2. Test Suite & Scripts

* **`dbeaver_interactive_lab.sql`:** Complete benchmark suite designed to run in DBeaver against a 120,000+ record dataset (`tuning_lab.db`).
* **`01_window_functions.sql`:** Analytical patterns and moving aggregates for financial and e-commerce reporting.
* **`02_sql_server_tsql_tuning.sql`:** T-SQL deep engine tuning, indexed views, and transactional isolation patterns.
* **`seed_tuning_data.py`:** Synthetic data generator creating high-cardinality facts and dimensions.
