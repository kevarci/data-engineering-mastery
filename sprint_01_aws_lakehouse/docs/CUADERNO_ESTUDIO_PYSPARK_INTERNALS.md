# 📓 Cuaderno de Cátedra: PySpark Internals, Catalyst Optimizer & Optimización de Joins

> **Instructor:** Ingeniero Senior / Career Coach Técnico  
> **Estudiante:** Kevin Stick Arciniegas Marquez  
> **Sprint:** 01 — Fundamentos de AWS & Big Data Distribuido  
> **Bloque 1:** Core Cloud Lakehouse Project  
> **Herramientas de Estudio:** Apache Spark 3.5, PySpark, Databricks, Delta Lake

---

## 📑 Índice de Contenidos

1. [La Anatomía del Clúster: Driver, Executors, Cores y Particiones](#1-la-anatomía-del-clúster)
2. [Evaluación Perezosa (Lazy Evaluation) y el Optimizador Catalyst](#2-evaluación-perezosa-lazy-evaluation-y-catalyst)
3. [Narrow vs Wide Dependencies: La Anatomía del SHUFFLE](#3-narrow-vs-wide-dependencies-la-anatomía-del-shuffle)
4. [Estrategias de Joins en PySpark: Broadcast Hash Join vs Sort-Merge Join](#4-estrategias-de-joins-en-pyspark)
5. [El Problema del Sesgo de Datos (Data Skew) & La Técnica de "Salting"](#5-el-problema-del-sesgo-de-datos-data-skew--salting)
6. [Gestión de Memoria Unificada en Spark (Execution vs Storage & Spills)](#6-gestión-de-memoria-unificada-en-spark)
7. [Laboratorio Práctico: Inspección del Plan Físico con `.explain(True)`](#7-laboratorio-práctico-inspección-del-plan-físico)
8. [Simulador de Preguntas Trampa de Entrevistas](#8-simulador-de-preguntas-trampa-de-entrevistas)

---

## 1. La Anatomía del Clúster: Driver, Executors, Cores y Particiones

En Apache Spark, el cómputo distribuido no ocurre por arte de magia; sigue una jerarquía estricta de coordinación y ejecución:

```
┌────────────────────────────────────────────────────────────────────────┐
│                        ARQUITECTURA DE UN CLÚSTER SPARK                │
├────────────────────────────────────────────────────────────────────────┤
│                                                                        │
│                       ┌──────────────────────┐                         │
│                       │     DRIVER NODE      │                         │
│                       │ (Cerebro del Clúster)│                         │
│                       │  - SparkSession      │                         │
│                       │  - Crea el DAG       │                         │
│                       │  - Coordina Tareas   │                         │
│                       └──────────┬───────────┘                         │
│                                  │                                     │
│                     Cluster Manager (YARN / K8s)                       │
│                                  │                                     │
│         ┌────────────────────────┼────────────────────────┐            │
│         ▼                        ▼                        ▼            │
│  ┌──────────────┐         ┌──────────────┐         ┌──────────────┐    │
│  │ WORKER NODE  │         │ WORKER NODE  │         │ WORKER NODE  │    │
│  │ ┌──────────┐ │         │ ┌──────────┐ │         │ ┌──────────┐ │    │
│  │ │Executor 1│ │         │ │Executor 2│ │         │ │Executor 3│ │    │
│  │ │Core1 Core2││         │ │Core1 Core2││         │ │Core1 Core2││    │
│  │ └──────────┘ │         │ └──────────┘ │         │ └──────────┘ │    │
│  └──────────────┘         └──────────────┘         └──────────────┘    │
│         │                        │                        │            │
│         └────────────────────────┼────────────────────────┘            │
│                                  ▼                                     │
│                      [ALMACENAMIENTO: S3 / HDFS]                       │
└────────────────────────────────────────────────────────────────────────┘
```

* **Driver Node:** El nodo maestro. Ejecuta la función `main()`, crea la `SparkSession`, compila el código en etapas (*Stages*) y tareas (*Tasks*), pero **nunca debe procesar datos pesados**.
* **Worker Nodes & Executors:** Máquinas secundarias donde corren procesos de JVM llamados **Executors**. Cada Executor dispone de núcleos de CPU (*Cores*) y memoria RAM para procesar particiones en paralelo.
* **Partición de Datos:** La unidad mínima atómica de datos en Spark. Si un DataFrame tiene 200 particiones y tienes 20 cores en total, Spark procesará 20 particiones a la vez en 10 oleadas (*waves*).

---

## 2. Evaluación Perezosa (Lazy Evaluation) y Catalyst

### A. ¿Por qué Spark es "Lazy"?
En Pandas, si escribes 5 filtros consecutivos, Pandas lee y crea 5 DataFrames intermedios en memoria RAM.  
En PySpark, las **Transformaciones** son 100% perezosas (*lazy*): solo registran un nodo en un árbol de dependencias llamado **DAG (Directed Acyclic Graph)**.

El cómputo real **solo se dispara cuando ejecutas una Acción** (`.count()`, `.show()`, `.collect()`, `.write.save()`).

### B. El Motor de Optimización Catalyst
Antes de ejecutar una sola línea en las CPUs, el optimizador **Catalyst** somete el código a 4 fases:

```
[Código PySpark]
       │
       ▼
1. Plan Lógico No Resuelto (Unresolved Logical Plan)  -> Valida sintaxis
       │
       ▼
2. Plan Lógico Analizado (Analyzed Logical Plan)       -> Valida catálogos y tipos de datos
       │
       ▼
3. Plan Lógico Optimizado (Optimized Logical Plan)     -> Aplica reglas:
       │                                                 * Predicate Pushdown (empuja filtros al origen)
       │                                                 * Column Pruning (descarta columnas no usadas)
       ▼
4. Plan Físico (Physical Plan)                         -> Elige algoritmos reales (Broadcast vs Sort-Merge)
       │
       ▼
[Código Bytecode Generado por Tungsten en C++]
```

---

## 3. Narrow vs Wide Dependencies: La Anatomía del SHUFFLE

Esta es la distinción técnica más crítica para entender el rendimiento en Big Data:

```
┌─────────────────────────────────┐       ┌─────────────────────────────────┐
│  NARROW DEPENDENCY (Sin Red)    │       │   WIDE DEPENDENCY (SHUFFLE)     │
├─────────────────────────────────┤       ├─────────────────────────────────┤
│ Partición 1 ──────► Tarea 1     │       │ Part. 1 ───┬─────────► Tarea 1  │
│ Partición 2 ──────► Tarea 2     │       │            ├─────────► Tarea 2  │
│ Partición 3 ──────► Tarea 3     │       │ Part. 2 ───┴─────────► Tarea 3  │
│ (1 a 1: Cero movimiento de red) │       │ (Todos con todos: Red saturada) │
└─────────────────────────────────┘       └─────────────────────────────────┘
```

| Tipo de Dependencia | Operaciones PySpark | ¿Provoca Shuffle? | Impacto en Rendimiento |
| :--- | :--- | :---: | :--- |
| **Estrecha (*Narrow*)** | `.select()`, `.filter()`, `.withColumn()`, `.drop()` | ❌ **NO** | 🟢 **Óptimo:** Ejecución en memoria directa en cada Worker. |
| **Ancha (*Wide*)** | `.groupBy()`, `.distinct()`, `.join()`, `.orderBy()`, `.repartition()` | ✅ **SÍ** | 🔴 **Costoso:** Las máquinas se envían datos por red y escriben en disco. |

### ⚠️ ¿Por qué el Shuffle es el enemigo #1 del clúster?
1. **Serialización:** Convierte objetos en memoria a bytes.
2. **I/O de Disco:** Escribe los datos a barajar en el disco local del Worker (*Shuffle Write*).
3. **Red:** Transfiere cientos de Gigabytes entre servidores a través de la red local.
4. **I/O de Lectura:** El Worker receptor lee esos bytes y los deserializa (*Shuffle Read*).
5. **Riesgo OOM:** Si una máquina recibe más datos de los que caben en su RAM, colapsa con `OutOfMemoryError`.

---

## 4. Estrategias de Joins en PySpark

Cuando unes dos DataFrames en Spark:
```python
df_resultado = df_grande.join(df_pequeno, on="id")
```

El optimizador de Spark evalúa la mejor estrategia física:

### A. Broadcast Hash Join (BHJ) — *El Santo Grial de los Joins*
* **Cuándo se usa:** Cuando una de las dos tablas es **pequeña** (por defecto, menor a **10 MB**, configurable con `spark.sql.autoBroadcastJoinThreshold`).
* **Cómo funciona:** El Driver descarga la tabla pequeña y la **copia entera (difunde) a la memoria RAM de todos los Workers**.
* **Ventaja:** **CERO SHUFFLE.** La tabla grande nunca se mueve de sus nodos.
* **Sintaxis explícita Senior:**
```python
from pyspark.sql.functions import broadcast

df_final = df_transacciones_grandes.join(
    broadcast(df_dim_tiendas), 
    on="tienda_id", 
    how="inner"
)
```

### B. Sort-Merge Join (SMJ) — *El Estándar para Tablas Gigantes*
* **Cuándo se usa:** Cuando **ambas tablas son enormes** y ninguna cabe en la memoria de un solo nodo.
* **Cómo funciona:**
  1. **Shuffle:** Baraja ambas tablas por la clave del join para que las filas con la misma clave caigan en el mismo Worker.
  2. **Sort:** Cada Worker ordena los datos localmente por la clave.
  3. **Merge:** Recorre ambas listas ordenadas en un solo pase lineal $O(M + N)$.
* **Ventaja:** Altamente escalable, no colapsa por memoria porque puede derramar (*spill*) a disco si es necesario.

### C. Shuffle Hash Join (SHJ)
* Similar a Sort-Merge, pero en vez de ordenar, construye una tabla hash en memoria. Se usa cuando una tabla es moderadamente más pequeña que la otra pero demasiado grande para un Broadcast.

---

## 5. El Problema del Sesgo de Datos (Data Skew) & "Salting"

### ¿Qué es Data Skew?
Ocurre cuando la distribución de tus datos **no es uniforme**.  
* Ejemplo: En una tienda de e-commerce, el cliente `ID = 0` (usuarios no registrados o compras anónimas) representa el **40% de todas las ventas del país**.
* Al hacer un `df.groupBy("customer_id")` o un `join`, **un solo Executor del clúster recibe el 40% de los datos**, mientras los otros 19 ejecutores terminan en 5 segundos y se quedan ociosos.
* **El síntoma en Databricks:** La barra de progreso se queda pegada en **"Stage 3: 199/200 Tasks"** durante 45 minutos.

---

### La Solución de Arquitectura: Técnica de "Salting" (Salazón de Claves)

Consiste en **descomponer artificialmente la clave sesgada** agregándole un número aleatorio (*sal*), para repartir la carga uniformemente en varios ejecutores:

```
[Clave Sesgada Original]               [Con Técnica de Salting (1 a 4)]
  Cliente_0 (1,000,000 filas)  ──►      Cliente_0_sal1 (250,000 filas) -> Executor 1
                               ──►      Cliente_0_sal2 (250,000 filas) -> Executor 2
                               ──►      Cliente_0_sal3 (250,000 filas) -> Executor 3
                               ──►      Cliente_0_sal4 (250,000 filas) -> Executor 4
```

```python
from pyspark.sql.functions import concat, col, lit, rand, floor

# 1. Agregar sal (número aleatorio entre 0 y 3) a la tabla sesgada
SALT_FACTOR = 4
df_salado = df_ventas.withColumn(
    "salted_customer_id", 
    concat(col("customer_id"), lit("_"), floor(rand() * SALT_FACTOR))
)
```

---

## 6. Gestión de Memoria Unificada en Spark

A partir de Spark 1.6+, la memoria de un Executor JVM se gestiona mediante el **Unified Memory Manager**:

```
┌────────────────────────────────────────────────────────────────────────┐
│                   MEMORIA DEL EXECUTOR JVM (RAM)                       │
├────────────────────────────────────────────────────────────────────────┤
│ 1. Reserved Memory (~300 MB): Uso interno del sistema Spark.           │
│ 2. User Memory (~25%): Estructuras de datos propias del usuario.      │
│ 3. Spark Memory (~75% restante):                                       │
│    ┌──────────────────────────────────┬──────────────────────────────┐ │
│    │     STORAGE MEMORY (Caché)       │   EXECUTION MEMORY (Cómputo) │ │
│    │  Guarda DataFrames cacheados     │  Memoria para Joins, Shuffles│ │
│    │  (.cache(), .persist()).         │  y Agregaciones (Sorts).     │ │
│    └──────────────────────────────────┴──────────────────────────────┘ │
│    * Dinámico: Si no hay caché, Execution toma el 100% del espacio.    │
└────────────────────────────────────────────────────────────────────────┘
```

* **¿Qué es un Spill to Disk?**  
  Si la memoria de *Execution* se satura durante un Shuffle o un Sort masivo, Spark escribe temporalmente los bloques excedentes al disco local del Worker.  
* **Impacto:** La tarea no colapsa, pero su velocidad se reduce drásticamente (el disco es **10 a 50 veces más lento que la RAM**).

---

## 7. Laboratorio Práctico: Inspección del Plan Físico con `.explain(True)`

En nuestro script [`03_pyspark_internals_lab.py`](file:///c:/Users/pc/Desktop/Proyectos%20BigData/mastery-lab/sprint_01_aws_lakehouse/scripts/03_pyspark_internals_lab.py), ejecutamos la inspección de planes:

```python
# Inspeccionar las 4 fases de optimización Catalyst:
df_transformado.explain(mode="extended")
```

En la salida de la consola identificamos:
* `AdaptiveSparkPlan (AQE)`: Optimización adaptable en tiempo de ejecución.
* `BroadcastHashJoin`: Confirmación de que el join eliminó el Shuffle.
* `Filter (Predicate Pushdown)`: Confirmación de que el filtro se aplicó antes de leer datos.

---

## 8. Simulador de Preguntas Trampa de Entrevistas

### P1: "¿Qué diferencia existe entre una Transformación y una Acción en PySpark?"
> **Respuesta Senior:**  
> Las transformaciones (como `.select()`, `.filter()` o `.groupBy()`) son operaciones perezosas (*lazy*) que no ejecutan cómputo inmediato; simplemente construyen un grafo acíclico dirigido (DAG) que registra el linaje de los datos.  
> Las acciones (como `.count()`, `.show()`, `.collect()` o `.write()`) son los disparadores que obligan al optimizador Catalyst a compilar el DAG en un plan físico optimizado y enviar las tareas a los ejecutores del clúster.

### P2: "¿Por qué un Broadcast Hash Join es tan eficiente y cuándo deberías forzarlo con `broadcast()`?"
> **Respuesta Senior:**  
> Porque elimina por completo la etapa de **Shuffle (barajado de datos por la red)**. En un Broadcast Join, la tabla pequeña se descarga al Driver y se envía completa a la memoria de cada Executor, permitiendo que cada nodo una sus particiones locales de la tabla grande sin transmitir nada por la red. Se debe forzar cuando una tabla dimensional mide menos de 10 MB a 100 MB y Spark no la detecta automáticamente debido a estadísticas desactualizadas.

### P3: "¿Qué es el problema de 'Data Skew' y qué síntoma visual presenta en la UI de Spark o Databricks?"
> **Respuesta Senior:**  
> Ocurre cuando una clave de agrupación o join está desproporcionadamente concentrada en pocas filas (ej. compras sin registrar asociadas al ID 0). El síntoma visual típico en la UI de Spark es que el 99% de las tareas de una etapa terminan en segundos, pero la última tarea (ej. la tarea 199 de 200) se queda ejecutándose sola durante decenas de minutos porque un único Executor está procesando casi todo el volumen de datos. Se soluciona mediante técnicas de *Salting* o activando *Adaptive Query Execution (AQE)* con coalescing de particiones sesgadas.

### P4: "¿Por qué se desaconseja el uso indiscriminado de `.cache()` o `.persist()` en todos los DataFrames?"
> **Respuesta Senior:**  
> Porque la memoria RAM de los ejecutores es finita y compartida entre almacenamiento (*Storage Memory*) y cómputo (*Execution Memory*). Si cacheamos DataFrames que solo se usan una vez, saturamos la memoria de almacenamiento, obligando a Spark a derramar datos a disco (*Spill to Disk*) durante shuffles o joins posteriores, lo que destruye el rendimiento general del clúster. Solo se debe cachear un DataFrame cuando se va a reutilizar múltiples veces en acciones independientes costosas.

### P5: "¿Cuál es la diferencia entre `.repartition(N)` y `.coalesce(N)`?"
> **Respuesta Senior:**  
> `.repartition(N)` realiza un **Full Shuffle** a través de la red para redistribuir los datos de manera uniforme en $N$ particiones, permitiendo tanto aumentar como disminuir el número de particiones.  
> `.coalesce(N)` **evita el Shuffle** combinando particiones existentes en el mismo nodo local; por ello, solo puede usarse para **reducir** el número de particiones (por ejemplo, antes de guardar un DataFrame pequeño en disco para no generar cientos de archivos pequeños).
