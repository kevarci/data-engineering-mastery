# 📓 Cuaderno de Cátedra: Window Functions Distribuidas en Apache Spark (PySpark)

> **Instructor:** Ingeniero Senior / Career Coach Técnico  
> **Estudiante:** Kevin Stick Arciniegas Marquez  
> **Sprint 1:** AWS Lakehouse & PySpark Distribuido  
> **Plataforma de Ejecución:** Databricks Community Edition / Apache Spark 3.5

---

## 📑 Índice de Contenidos
1. [La Mentalidad Senior: Window Functions en un Clúster Distribuido](#1-la-mentalidad-senior-window-functions-en-un-clúster-distribuido)
2. [Anatomía del Shuffle en Window Functions (El Operador Exchange)](#2-anatomía-del-shuffle-en-window-functions)
3. [El Peligro Mortal: El "Global Window" y el Colapso por OOM](#3-el-peligro-mortal-el-global-window-y-el-colapso-por-oom)
4. [Los 4 Patrones de Producción en PySpark](#4-los-4-patrones-de-producción-en-pyspark)
   - [Patrón 1: Top N por Categoría (ROW_NUMBER vs DENSE_RANK)](#patrón-1-top-n-por-categoría)
   - [Patrón 2: Detección de Churn con LAG / LEAD (Cero Self-Joins)](#patrón-2-detección-de-churn-con-lag--lead)
   - [Patrón 3: Running Totals y Marcos Físicos (rowsBetween vs rangeBetween)](#patrón-3-running-totals-y-marcos-físicos)
   - [Patrón 4: Deduplicación Idempotente Bronze → Silver](#patrón-4-deduplicación-idempotente-bronze--silver)
5. [Data Skew en Window Functions y Mitigación con Salting](#5-data-skew-en-window-functions-y-mitigación-con-salting)
6. [Simulador de Preguntas Trampa de Entrevistas](#6-simulador-de-preguntas-trampa-de-entrevistas)

---

## 1. La Mentalidad Senior: Window Functions en un Clúster Distribuido

En una base de datos relacional tradicional (como PostgreSQL o SQL Server), una función de ventana se ejecuta en un único servidor que comparte memoria RAM y núcleos de CPU.

En **Apache Spark**, los datos están particionados y distribuidos físicamente a lo largo de decenas o cientos de servidores (**Executors**).

```
┌────────────────────────────────────────────────────────────────────────────────────────┐
│               DIFERENCIA ENTRE GROUPBY Y WINDOW FUNCTION EN PYSPARK                   │
├──────────────────────────┬─────────────────────────────────────────────────────────────┤
│ GROUP BY (Colapsa filas) │ Reduce la cardinalidad: 10,000 filas se convierten en 5     │
│                          │ filas agregadas (un resumen por categoría).                 │
├──────────────────────────┼─────────────────────────────────────────────────────────────┤
│ WINDOW FUNCTION          │ Mantiene la granularidad original: cada una de las 10,000   │
│ (Conserva filas)         │ filas sigue existiendo, pero se le adjunta el cálculo       │
│                          │ relativo a su grupo (puesto, acumulado o fila previa).      │
└──────────────────────────┴─────────────────────────────────────────────────────────────┘
```

---

## 2. Anatomía del Shuffle en Window Functions

Cuando defines una especificación de ventana en PySpark:
```python
window_spec = Window.partitionBy("category").orderBy(col("amount").desc())
```

El **Optimizador Catalyst** genera un plan físico compuesto por 3 etapas fundamentales:

```
[Particiones en Disco/S3]
          │
          ▼
┌───────────────────────────────────┐
│  Exchange hashpartitioning(...)   │ ◄─── SHUFFLE: Envía filas con el mismo hash de 
│                                   │      'category' a través de la red hacia el mismo Executor
└─────────────────┬─────────────────┘
                  │
                  ▼
┌───────────────────────────────────┐
│     Sort [category, amount DESC]  │ ◄─── ORDENAMIENTO LOCAL: Cada Executor ordena en su RAM
└─────────────────┬─────────────────┘
                  │
                  ▼
┌───────────────────────────────────┐
│              Window               │ ◄─── CÁLCULO VECTORIAL: row_number, rank, sum...
└───────────────────────────────────┘
```

1. **Exchange (`hashpartitioning`):** Es la fase de **Shuffle**. Spark aplica una función de hash a la columna `category`. Todos los registros con el mismo valor (ej. `"Electronics"`) son transportados por la red hacia el mismo Executor.
2. **Sort:** Dentro de la memoria del Executor asignado, Spark ordena las filas por la columna indicada en el `orderBy`.
3. **Window:** Spark recorre las filas ordenadas aplicando las funciones analíticas (`row_number()`, `dense_rank()`, `sum()`, etc.) y emite las columnas resultantes.

---

## 3. El Peligro Mortal: El "Global Window" y el Colapso por OOM

### El Error del Desarrollador Junior:
```python
# ❌ ERROR CATASTRÓFICO: Window sin partitionBy
window_global = Window.orderBy(col("transaction_date"))
df.withColumn("global_rank", row_number().over(window_global))
```

### ¿Por qué esto revienta el clúster?
Para ordenar **todas las filas del dataset de forma global**, Spark no puede trabajar en paralelo. Está obligado a enviar **el 100% de los datos de todos los nodos hacia UN SOLO EXECUTOR**:

```
[Executor 1] ───┐
[Executor 2] ───┼───► SHUFFLE TOTAL POR RED ───► [ Executor 0 ] ──► 🔥 java.lang.OutOfMemoryError
[Executor 3] ───┤                                 (Saturado al 100% de RAM,
[Executor 4] ───┘                                  mientras los demás están en 0%)
```

> ⚠️ **Regla de Oro en Producción:**  
> **Nunca uses `Window.orderBy()` sin `partitionBy()` sobre datasets masivos en PySpark.**  
> Si requieres un ID secuencial global, utiliza `monotonically_increasing_id()` o particiona previamente por año/mes/región.

---

## 4. Los 4 Patrones de Producción en PySpark

### Patrón 1: Top N por Categoría
Para extraer los $N$ mejores productos o clientes por departamento sin sesgos:
```python
window_cat = Window.partitionBy("category").orderBy(col("amount").desc())

df_top_n = (
    df
    .withColumn("rnk", dense_rank().over(window_cat))
    .filter(col("rnk") <= 2)
)
```
* **`row_number()`:** Si dos compras empatan en \$1,000, una recibe el puesto 1 y la otra el 2 de forma arbitraria.
* **`dense_rank()`:** Ambas reciben el puesto 1, y la siguiente recibe el 2, garantizando justicia de negocio y evitando descartar transacciones empatadas.

---

### Patrón 2: Detección de Churn con `LAG` / `LEAD` (Cero Self-Joins)
Para medir la frecuencia de compra de un cliente y detectar riesgo de abandono (*Churn*):
```python
window_customer = Window.partitionBy("customer_id").orderBy("transaction_date")

df_churn = (
    df
    .withColumn("fecha_anterior", lag("transaction_date", 1).over(window_customer))
    .withColumn("dias_inactivo", datediff(col("transaction_date"), col("fecha_anterior")))
)
```
* **Ventaja Arquitectónica:** Un desarrollador Junior hace un `JOIN` de la tabla consigo misma (`df.join(df, ...)`), lo que causa una explosión combinatoria cuadrática $O(N^2)$. `LAG()` resuelve el problema en una sola pasada en memoria ($O(N)$).

---

### Patrón 3: Running Totals y Marcos Físicos (`rowsBetween` vs `rangeBetween`)
Para calcular el acumulado de ingresos a lo largo del tiempo:
```python
# ✅ OPTIMIZADO: Marco físico con punteros de fila
window_running = (
    Window.partitionBy("category")
    .orderBy("transaction_date")
    .rowsBetween(Window.unboundedPreceding, Window.currentRow)
)

df_totals = df.withColumn("ingreso_acumulado", round(sum("amount").over(window_running), 2))
```
* **`rangeBetween` (Lógico):** Evalúa el valor del dato (ej. fechas idénticas las suma juntas). Es computacionalmente más costoso porque compara valores de columnas en cada paso.
* **`rowsBetween` (Físico):** Trabaja con punteros de índice en el búfer de memoria (`unboundedPreceding` = desde el inicio de la partición hasta la fila actual). **Es hasta 10 veces más rápido en Spark.**

---

### Patrón 4: Deduplicación Idempotente Bronze → Silver
En la ingesta de streaming o micro-lotes hacia el Lakehouse, pueden llegar eventos duplicados por fallos de red. Para quedarnos con la versión más reciente (*Latest Record Wins*):
```python
window_dedup = Window.partitionBy("transaction_id").orderBy(col("updated_at").desc())

df_silver = (
    df_bronze
    .withColumn("dedup_rank", row_number().over(window_dedup))
    .filter(col("dedup_rank") == 1)
    .drop("dedup_rank")
)
```

---

## 5. Data Skew en Window Functions y Mitigación con Salting

Si en tu empresa la categoría `"Electronics"` representa el **85% de todas las ventas mundiales**:
* Cuando Spark ejecute `Window.partitionBy("category")`, el 85% de los datos viajarán a un solo Executor.
* Verás en la UI de Spark que 99 tareas terminan en 10 segundos, pero **1 tarea solitaria se queda corriendo por 45 minutos** (*Straggler Task*).

### La Solución Senior: Salting de Dos Fases
1. **Fase 1:** Agregar una columna de sal aleatoria: `salted_key = concat(col("category"), lit("_"), rand(0, 9).cast("int"))`.
2. Particionar por `salted_key`: los datos de `"Electronics"` se reparten equitativamente entre 10 particiones distintas en paralelo.
3. **Fase 2:** Agregar los resultados intermedios y consolidar a nivel de `category`.

---

## 6. Simulador de Preguntas Trampa de Entrevistas

### P1: *"¿Por qué una Window Function en PySpark suele ser más eficiente que un `groupBy` seguido de un `join`?"*
> **Respuesta Senior:**  
> Porque hacer un `groupBy` para calcular un valor agregado (como el promedio o el total) y luego unirlo de vuelta al DataFrame original requiere **dos fases de Shuffle independientes**: una para agrupar y otra para el `join`.  
> En cambio, una Window Function realiza **un solo Shuffle de particionamiento** (`Exchange hashpartitioning`). Una vez que las filas residen en el Executor, calcula las agregaciones y las mantiene adjuntas a cada fila en un solo pase por memoria, ahorrando el 50% de I/O de red.

### P2: *"¿Qué sucede si ejecutas `Window.orderBy('date')` sobre un dataset de 100 millones de filas sin `partitionBy()`?"*
> **Respuesta Senior:**  
> Se produce un cuello de botella catastrófico conocido como **Global Shuffle**. Al no haber partición, Spark no puede distribuir el trabajo y está obligado a mover los 100 millones de registros a través de la red hacia un único nodo Executor para poder ordenarlos secuencialmente. Esto satura la memoria RAM del nodo, degradando drásticamente el clúster o provocando un fallo por `OutOfMemoryError (OOM)`.

### P3: *"¿Cuál es la diferencia de rendimiento entre `rowsBetween` y `rangeBetween` en Spark?"*
> **Respuesta Senior:**  
> `rowsBetween` define el marco de cálculo basándose en la **posición física de las filas** (desplazamientos de índice en el búfer de memoria), lo que permite iteraciones lineales ultrarrápidas.  
> `rangeBetween` define el marco basándose en el **valor lógico de los datos** (por ejemplo, valores de fechas o montos), obligando al motor a evaluar y comparar los valores de las columnas para cada fila para determinar qué registros entran en el rango, lo cual introduce un alto costo de cómputo en CPU.

### P4: *"¿Cómo usarías Window Functions para deduplicar un flujo de eventos CDC (Change Data Capture) en una tabla Delta Lake?"*
> **Respuesta Senior:**  
> Defino una especificación de ventana particionada por la clave primaria del negocio y ordenada de forma descendente por la marca de tiempo de actualización:  
> `Window.partitionBy("business_id").orderBy(col("updated_at").desc())`.  
> Asigno un ranking con `row_number()` y filtro únicamente los registros con ranking igual a 1. Esto garantiza que ante múltiples modificaciones del mismo registro, seleccionemos de forma determinista e idempotente el estado más reciente para procesar el `MERGE INTO` en Delta Lake.

### P5: *"Si una partición en `Window.partitionBy('category')` es desproporcionadamente gigante debido a Data Skew, ¿cómo lo solucionas?"*
> **Respuesta Senior:**  
> Aplico una técnica de **Salting analítico**. Creo una clave compuesta artificial concatenando la columna con un número aleatorio (ej. `category + "_" + random(0, 9)`). Esto divide la categoría masiva en 10 subparticiones manejables que se distribuyen uniformemente entre los Executors, eliminando las tareas rezagadas (*Stragglers*). Posteriormente, si se requiere consolidación, se hace un segundo pase liviano sobre los datos ya pre-reducidos.
