# 📓 Cuaderno de Cátedra: SQL & T-SQL Performance Tuning + Window Functions

> **Instructor:** Ingeniero Senior / Career Coach Técnico  
> **Estudiante:** Kevin Stick Arciniegas Marquez  
> **Bloque 2:** Hard Skill Drills (Entrenamiento para Pruebas Técnicas en Vivo)  
> **Herramientas de Práctica:** DBeaver, SQLite (120,000+ registros), Microsoft SQL Server (T-SQL)

---

## 📑 Índice de Contenidos
1. [La Mentalidad Senior: ¿Qué es SQL Tuning?](#1-la-mentalidad-senior-qué-es-sql-tuning)
2. [Planes de Ejecución: Diagnóstico de Scan vs Seek](#2-planes-de-ejecución-diagnóstico-de-scan-vs-seek)
3. [Estrategias de Índices: Key Lookup, INCLUDE e Índices Filtrados](#3-estrategias-de-índices-key-lookup-include-e-índices-filtrados)
4. [T-SQL Internals: CROSS APPLY, Tablas Temporales y Transacciones](#4-t-sql-internals-cross-apply-tablas-temporales-y-transacciones)
5. [Funciones de Ventana de Alto Rendimiento (Window Functions)](#5-funciones-de-ventana-de-alto-rendimiento)
6. [Los 3 Algoritmos Físicos de JOIN y Spills a TempDB](#6-los-3-algoritmos-físicos-de-join-y-spills-a-tempdb)
7. [Simulador de Preguntas Trampa de Entrevistas](#7-simulador-de-preguntas-trampa-de-entrevistas)

---

## 1. La Mentalidad Senior: ¿Qué es SQL Tuning?

* **Escribir SQL Básico (Nivel Junior):** Conseguir que la consulta devuelva los datos correctos, sin importar cuánta memoria o tiempo consuma.
* **Hacer SQL Tuning (Nivel Senior):** Lograr que esa misma consulta devuelva el resultado consumiendo **10 a 100 veces menos I/O en disco, menos RAM y en milisegundos**.

### ¿Por qué esto define tu contratación?
En tablas con 10,000 filas cualquier consulta mal escrita responde rápido. Pero en una empresa con **50 millones de transacciones**:
1. Una consulta no afinada satura el CPU del servidor y bloquea las transacciones de los usuarios.
2. Un reporte de Power BI tarda 15 minutos en cargar en vez de 3 segundos.
3. En almacenes de datos en la nube (Snowflake, BigQuery, Athena), **las consultas no optimizadas aumentan la factura mensual en miles de dólares** porque cobran por terabytes escaneados.

---

## 2. Planes de Ejecución: Diagnóstico de Scan vs Seek

El **Plan de Ejecución** es el mapa interno que genera el optimizador de la base de datos para responder a tu consulta.

En DBeaver lo diagnosticamos con `EXPLAIN QUERY PLAN` sobre nuestra tabla de **120,000 ventas**:

```
┌────────────────────────────────────────────────────────────────────────────────────────┐
│  BENCHMARK: 120,000 ROWS TABLE SCAN VS. B-TREE SEARCH                                  │
├────────────────────────────────┬───────────────────────────────────────────────────────┤
│ SIN ÍNDICE (Table Scan):       │ detail: SCAN FactSales                                │
│ Costo: Alto I/O ($O(N)$)       │ Lee 120,000 filas de forma secuencial en disco        │
├────────────────────────────────┼───────────────────────────────────────────────────────┤
│ CON ÍNDICE COMPUESTO:          │ detail: SEARCH FactSales USING INDEX IX_Cust_Date     │
│ Costo: Milisegundos ($O(\log N)$) Salto binario directo a las hojas del árbol B-Tree   │
└────────────────────────────────┴───────────────────────────────────────────────────────┘
```

* **`SCAN` (Table Scan / Clustered Index Scan):**  
  El motor no tiene un índice adecuado, por lo que debe leer físicamente **cada una de las 120,000 páginas de datos**. Complejidad: lineal $O(N)$.
* **`SEARCH` (Index Seek):**  
  El motor navega por la estructura de árbol balanceado (**B-Tree**) del índice. En apenas **10 a 15 saltos de punteros en memoria**, ubica las filas exactas. Complejidad: logarítmica $O(\log N)$.

---

## 3. Estrategias de Índices: Key Lookup, INCLUDE e Índices Filtrados

### A. El Problema del "Key Lookup" (Bookmark Lookup)

#### ¿Por qué ocurre?
Imagina esta consulta frecuente:
```sql
SELECT CustomerID, SaleDate, Amount 
FROM FactSales 
WHERE CustomerID = 4500 AND SaleDate >= '2026-01-01';
```

Si creas un índice simple en las columnas de filtro:
```sql
CREATE NONCLUSTERED INDEX IX_Customer ON FactSales(CustomerID, SaleDate);
```

1. El motor hace un **Index Seek** ultra rápido en `IX_Customer` y encuentra las filas.
2. **Pero la columna `Amount` NO está en ese índice**.
3. Por cada fila encontrada, el motor se ve forzado a saltar a la tabla principal (el Clustered Index) a buscar el valor de `Amount`.
4. **Eso es un Key Lookup.** Si la consulta devuelve 50,000 filas, son 50,000 lecturas aleatorias de disco extra. En el Execution Plan de SSMS verás que el Key Lookup se come el **80% o 90% del costo total**.

---

### B. La Solución: Índice Cubriente con `INCLUDE` (Covering Index)

```sql
CREATE NONCLUSTERED INDEX IX_FactSales_Customer_Date_Covering
ON FactSales (CustomerID, SaleDate)
INCLUDE (Amount);
```

#### ¿Por qué `INCLUDE` y no poner `Amount` en la clave principal del índice?
* Si agregas `Amount` a la definición del índice (`ON FactSales (CustomerID, SaleDate, Amount)`), agrandas todas las ramas intermedias del árbol B-Tree, consumiendo más RAM y ralentizando todas las inserciones/actualizaciones (`INSERT`/`UPDATE`).
* Con **`INCLUDE (Amount)`**, el valor se guarda **únicamente en el nivel hoja** del índice.
* El índice ahora "cubre" el 100% de la consulta: el motor saca todas las columnas directamente del índice secundario sin tocar la tabla principal. **El Key Lookup desaparece por completo.**

---

### C. Índices Filtrados (Partial / Filtered Index)

> **Regla de Oro:** Si el 95% de tus datos son históricos o finalizados y tus consultas críticas solo operan sobre el 5% activo, **no indexes la tabla entera**.

#### Caso de Negocio Real:
En `FactSales`:
* 95% de las ventas son `COMPLETED`.
* Solo el 3% son `PENDING` (~3,600 filas de 120,000).

```sql
CREATE INDEX IX_FactSales_Pending 
ON FactSales (SaleDate) 
WHERE Status = 'PENDING';
```

#### Ventajas en Producción:
1. **Ahorro del 97% de espacio en memoria RAM y disco.**
2. **Cero penalización en escrituras:** Cuando el sistema inserte millones de ventas completadas, el motor **no toca este índice**, evitando la degradación de rendimiento típica.

---

## 4. T-SQL Internals: CROSS APPLY, Tablas Temporales y Transacciones

### A. `CROSS APPLY` vs `ROW_NUMBER()`: El Problema de los Top-N por Grupo

#### 1. La Pregunta Clásica de Entrevista:
> *"De una tabla con 50 millones de ventas, necesitas extraer únicamente las 2 mejores compras de cada cliente. ¿Cómo lo resuelves y qué ventajas de rendimiento tiene `CROSS APPLY` frente a `ROW_NUMBER()`?"*

---

#### 2. Solución Universal con CTE y `ROW_NUMBER()` (Comentada Paso a Paso):
Esta es la solución estándar ANSI SQL que corre en SQLite, PostgreSQL, Snowflake, Databricks y SQL Server:

```sql
-- PASO 1: Creamos un CTE (tabla virtual temporal en memoria) para rankear las compras.
-- ¿Por qué? Porque en SQL es ilegal escribir "WHERE ROW_NUMBER() <= 2" directamente.
WITH RankedSales AS (
    SELECT 
        c.CustomerID,       -- ID del cliente (Dimensión)
        c.CustomerName,     -- Nombre del cliente (Dimensión)
        s.SaleID,           -- ID único de la transacción (Hecho)
        s.SaleDate,         -- Fecha en que ocurrió la compra
        s.Amount,           -- Monto en dinero de la transacción
        
        -- AQUÍ OCURRE LA MAGIA DEL RANKING:
        ROW_NUMBER() OVER (
            -- PARTITION BY CustomerID:
            -- Reinicia el contador a 1 cada vez que cambia de cliente.
            -- El Cliente 1 tendrá sus puestos 1, 2, 3...
            -- El Cliente 2 volverá a empezar en 1, 2, 3...
            PARTITION BY s.CustomerID 
            
            -- ORDER BY s.Amount DESC:
            -- Ordena las compras de ESE cliente específico de mayor a menor monto.
            -- Puesto 1 = La compra más cara de su historia.
            -- Puesto 2 = Su segunda mayor compra.
            ORDER BY s.Amount DESC
        ) AS ranking_compra

    -- Unimos la tabla de Clientes con su historial de Ventas
    FROM DimCustomer c
    JOIN FactSales s ON c.CustomerID = s.CustomerID
    WHERE c.CustomerID IN (1, 2, 3, 4, 5)
)

-- PASO 2: Consulta final que extrae solo el TOP 2 de cada cliente
SELECT 
    CustomerID,
    CustomerName,
    SaleID,
    SaleDate,
    Amount,
    ranking_compra
FROM RankedSales

-- FILTRO DE NEGOCIO:
-- Excluimos los puestos 3, 4, 5... Nos quedamos ÚNICAMENTE con los 2 primeros puestos
WHERE ranking_compra <= 2

-- ORDEN FINAL:
-- Presentamos los resultados agrupados por cliente y de mayor a menor compra
ORDER BY CustomerID, ranking_compra;
```

---

#### 3. Solución Avanzada en Microsoft SQL Server con `CROSS APPLY`:
En T-SQL, podemos evitar particionar toda la historia de la tabla evaluando una subconsulta correlacionada fila por fila:

```sql
SELECT 
    c.CustomerID,
    c.CustomerName,
    top_orders.SaleID,
    top_orders.SaleDate,
    top_orders.Amount
FROM DimCustomer c
CROSS APPLY (
    -- Esta subconsulta se ejecuta de forma lateral POR CADA CLIENTE:
    SELECT TOP (2) 
        s.SaleID,
        s.SaleDate,
        s.Amount
    FROM FactSales s
    WHERE s.CustomerID = c.CustomerID
    ORDER BY s.Amount DESC
) AS top_orders
ORDER BY c.CustomerID, top_orders.Amount DESC;
```

---

#### 4. Comparativa de Rendimiento Senior (El Secreto del Optimizador):
* **El costo oculto de `ROW_NUMBER()`:** En tablas de 50 millones de ventas, el motor tiene que particionar y ordenar en memoria (**Sort operator**) **las 50 millones de filas**, para luego descartar el 95% al filtrar `WHERE ranking_compra <= 2`.
* **La ventaja letal de `CROSS APPLY`:** Si existe un índice compuesto en `FactSales(CustomerID, Amount DESC)`, `CROSS APPLY` entra directamente por el árbol B-Tree mediante un **Index Seek**, lee únicamente las 2 primeras hojas de ese cliente y **se detiene al instante**.
* **Matemática:** Si tienes 5,000 clientes, `CROSS APPLY` realiza exactamente $5,000 \times 2 = 10,000$ lecturas indexadas ultra-rápidas, en vez de ordenar 50 millones de registros en TempDB.

---

### B. `#temp` (Tabla Temporal) vs `@table` (Variable de Tabla)

| Característica | `@table` (Variable de Tabla) | `#temp` (Tabla Temporal) |
| :--- | :--- | :--- |
| **Ubicación** | Vive en memoria pero pasa a TempDB si crece. | Vive físicamente en TempDB. |
| **Estadísticas de Distribución** | ❌ **NO TIENE estadísticas.** | ✅ **SÍ TIENE estadísticas e índices.** |
| **Estimación del Optimizador** | El optimizador **siempre asume que tiene 1 SOLA FILA** (cardinalidad = 1). | El optimizador conoce el número exacto de filas. |
| **Cuándo usarla** | Exclusivamente para **menos de 100 filas**. | **Siempre que manipules miles de filas en ETLs.** |

> ⚠️ **Peligro en Producción:** Si metes 50,000 filas en una `@table` y haces un `JOIN`, el optimizador creerá que es 1 sola fila y elegirá un algoritmo de `Nested Loops` ineficiente, colapsando el CPU del servidor. Usa siempre `#temp` para volúmenes medianos o grandes.

---

### C. Stored Procedures Transaccionales con `TRY...CATCH` y `XACT_ABORT`

```sql
CREATE OR ALTER PROCEDURE dbo.usp_ProcessTransaction
    @CustomerID INT,
    @Amount DECIMAL(12, 2)
AS
BEGIN
    SET NOCOUNT ON;
    
    -- XACT_ABORT ON garantiza que si ocurre un error de ejecución o timeout,
    -- la transacción completa se revierta automáticamente (evita transacciones huérfanas)
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        INSERT INTO CustomerTransactions (CustomerID, Amount, CreatedAt)
        VALUES (@CustomerID, @Amount, SYSDATETIME());

        UPDATE CustomerAccount
        SET CurrentBalance = CurrentBalance + @Amount
        WHERE CustomerID = @CustomerID;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        -- Si hay una transacción activa sin confirmar, revertir inmediatamente
        IF (XACT_STATE()) <> 0
        BEGIN
            ROLLBACK TRANSACTION;
        END;

        DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
        RAISERROR(@ErrorMessage, 16, 1);
        RETURN -1;
    END CATCH;
END;
```

---

### D. `MERGE INTO` & UPSERT Atómico (La Muerte del Doble Pase)

En pipelines ETL / ELT cotidianos, recibimos lotes diarios con registros nuevos y registros existentes modificados.

#### 1. El Error del Junior (UPDATE seguido de INSERT manual):
```sql
-- ❌ INEFICIENTE Y PELIGROSO:
UPDATE FactSales SET Amount = s.Amount, Status = s.Status FROM StagingSales s WHERE FactSales.SaleID = s.SaleID;
INSERT INTO FactSales SELECT * FROM StagingSales WHERE SaleID NOT IN (SELECT SaleID FROM FactSales);
```
* **Peligros en producción:**
  1. **Doble escaneo de tabla:** Desperdicia I/O de disco y memoria al leer la tabla dos veces.
  2. **Condiciones de Carrera (*Race Conditions*):** Si otro proceso escribe en la tabla entre el UPDATE y el INSERT, se generan errores de clave duplicada o inconsistencias.
  3. **Bloqueos (*Deadlocks*):** Bloquea la tabla dos veces consecutivas, frenando las transacciones de los usuarios.

#### 2. La Solución Atómica Universal:
* **En SQLite 3.24+ y PostgreSQL (Sintaxis `ON CONFLICT`):**
```sql
INSERT INTO FactSales (SaleID, CustomerID, SaleDate, Category, Amount, Status, RegionID)
VALUES 
    (1, 1, '2026-10-19 12:00:00', 'Electronics', 3500.00, 'COMPLETED', 1),
    (999999, 50, '2026-10-19 12:00:00', 'Home', 450.00, 'COMPLETED', 2)
ON CONFLICT(SaleID) DO UPDATE SET
    Amount   = excluded.Amount,
    Status   = excluded.Status,
    SaleDate = excluded.SaleDate;
```

* **En Microsoft SQL Server y Delta Lake (Sintaxis `MERGE INTO` con Auditoría):**
```sql
MERGE INTO dbo.FactSales AS target
USING dbo.StagingSales AS source
ON target.SaleID = source.SaleID

-- Cuando ya existe: Se actualiza en el mismo pase
WHEN MATCHED AND (target.Amount <> source.Amount OR target.Status <> source.Status) THEN
    UPDATE SET 
        target.Amount   = source.Amount,
        target.Status   = source.Status,
        target.SaleDate = source.SaleDate

-- Cuando no existe: Se inserta
WHEN NOT MATCHED BY TARGET THEN
    INSERT (SaleID, CustomerID, SaleDate, Category, Amount, Status, RegionID)
    VALUES (source.SaleID, source.CustomerID, source.SaleDate, source.Category, source.Amount, source.Status, source.RegionID)

-- Auditoría en vivo de operaciones realizadas:
OUTPUT $action AS operacion_realizada, inserted.SaleID;
```

---



## 5. Funciones de Ventana de Alto Rendimiento

### A. La Estructura Fundamental
```sql
FUNCION() OVER (
    PARTITION BY columna_grupo   -- Reinicia la ventana para cada grupo
    ORDER BY columna_orden       -- Ordena dentro de la ventana
)
```

---

### B. La Regla de Oro ante Empates: `ROW_NUMBER` vs `RANK` vs `DENSE_RANK`

Si dos alumnos empatan con la nota máxima de **100** y el siguiente saca **90**:

```sql
WITH notas AS (
    SELECT 'Ana' AS alumno, 100 AS nota UNION ALL
    SELECT 'Carlos', 100 UNION ALL
    SELECT 'Beatriz', 90 UNION ALL
    SELECT 'Daniel', 80
)
SELECT 
    alumno, nota,
    ROW_NUMBER() OVER (ORDER BY nota DESC) AS row_num,
    RANK()       OVER (ORDER BY nota DESC) AS rnk,
    DENSE_RANK() OVER (ORDER BY nota DESC) AS dense_rnk
FROM notas;
```

| Alumno | Nota | `ROW_NUMBER` | `RANK` | `DENSE_RANK` | Comportamiento |
| :--- | :---: | :---: | :---: | :---: | :--- |
| **Ana** | 100 | 1 | 1 | 1 | Primer puesto empatado |
| **Carlos** | 100 | 2 | 1 | 1 | Primer puesto empatado |
| **Beatriz** | 90 | 3 | **3** *(salta el 2)* | **2** *(sin huecos)* | **`RANK` deja un hueco; `DENSE_RANK` es consecutivo** |
| **Daniel** | 80 | 4 | 4 | 3 | Siguiente puesto |

---

### C. Total Acumulado (*Running Total*) & El Tuning del Marco Físico

```sql
SELECT 
    SaleID, CustomerID, SaleDate, Amount,
    ROUND(SUM(Amount) OVER (
        PARTITION BY CustomerID 
        ORDER BY SaleDate
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ), 2) AS running_total
FROM FactSales
WHERE CustomerID = 100
ORDER BY SaleDate;
```

* **El Secreto de Rendimiento:** Si omites la cláusula `ROWS BETWEEN...`, el estándar SQL asume por defecto `RANGE BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW`.
* `RANGE` obliga al motor a comparar valores repetidos en disco y crea un spool temporal en TempDB.
* Especificar explícitamente **`ROWS`** le ordena al motor sumar directamente en memoria fila por fila física, siendo **5 a 10 veces más rápido**.

---

### D. Comparaciones con el Pasado y Futuro: `LAG()` y `LEAD()`

Calcula variaciones porcentuales o deltas temporales sin hacer un costoso `SELF JOIN`:

```sql
WITH compras AS (
    SELECT 
        SaleID, CustomerID, SaleDate,
        Amount AS compra_actual,
        LAG(Amount, 1) OVER (ORDER BY SaleDate) AS compra_anterior
    FROM FactSales
    WHERE CustomerID = 100
)
SELECT 
    SaleID, CustomerID, SaleDate,
    compra_actual, compra_anterior,
    ROUND(compra_actual - compra_anterior, 2) AS variacion
FROM compras;
```

---

### E. Promedios Móviles (*Moving Averages*) & Ventanas Deslizantes

Un **Promedio Móvil** calcula el promedio de una serie temporal desplazando una ventana fija de $N$ filas sobre cada registro para **suavizar picos y ruidos atípicos**, revelando la verdadera tendencia de gasto o consumo.

#### La Gran Pregunta de Negocio y Arquitectura:
> *"¿La columna de promedio calcula el promedio en base a la venta de ese `SaleID` único? Es decir, ¿para cada transacción me dice el promedio de su compra actual y sus 2 anteriores?"*

**Respuesta Técnica de Nivel Senior:**  
**Exactamente SÍ.** A diferencia de una agregación con `GROUP BY` (que colapsa las filas y destruye la identidad de cada transacción individual), una **Función de Ventana (`OVER (...)`) preserva el 100% del grano fino de la tabla**. 

Cada fila del resultado sigue siendo un registro único con su propio `SaleID`. Lo que hace el motor de base de datos es:
1. Posicionarse en la fila física de ese `SaleID` específico.
2. Leer el monto de esa venta actual (`CURRENT ROW`).
3. Retroceder a las 2 ventas inmediatamente anteriores en el tiempo pertenecientes a ese mismo cliente (`2 PRECEDING`).
4. Calcular el promedio de esas 3 ventas y escribirlo en esa misma fila.

De este modo, para cada `SaleID` individual, el negocio puede saber al instante si esa compra específica estuvo por encima o por debajo de su tendencia reciente de gasto.

```sql
SELECT 
    SaleID, CustomerID, SaleDate, Amount,
    ROUND(AVG(Amount) OVER (
        PARTITION BY CustomerID 
        ORDER BY SaleDate, SaleID
        ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
    ), 2) AS promedio_movil_3_compras
FROM FactSales
WHERE CustomerID = 100
ORDER BY SaleDate, SaleID;
```

#### ¿Cómo rueda la ventana fila por fila a nivel de cada `SaleID`? (Demostración Paso a Paso):

Imagina las siguientes 4 compras consecutivas del cliente 100:

```
┌─────────┬──────────┬──────────┬────────────────────────────────────────────────────────────────────────┐
│ SaleID  │ Fecha    │ Monto    │ Promedio Móvil (ROWS BETWEEN 2 PRECEDING AND CURRENT ROW)              │
├─────────┼──────────┼──────────┼────────────────────────────────────────────────────────────────────────┤
│ #1042   │ 10 Enero │ $100.00  │ $100.00  -> Evaluando #1042: Solo existe esta compra.                  │
│         │          │          │             Cálculo: $100 / 1                                          │
│ #1089   │ 15 Febr. │ $200.00  │ $150.00  -> Evaluando #1089: Su compra + 1 anterior (#1042).           │
│         │          │          │             Cálculo: ($100 + $200) / 2                                 │
│ #1150   │ 20 Marzo │ $300.00  │ $200.00  -> Evaluando #1150: Su compra + 2 anteriores (#1089 y #1042). │
│         │          │          │             Cálculo: ($100 + $200 + $300) / 3                          │
│ #1210   │ 25 Abril │ $600.00  │ $366.67  -> Evaluando #1210: ¡La ventana se desliza!                   │
│         │          │          │             Deja fuera #1042. Promedia #1089, #1150 y #1210:           │
│         │          │          │             Cálculo: ($200 + $300 + $600) / 3                          │
└─────────┴──────────┴──────────┴────────────────────────────────────────────────────────────────────────┘
```

* **`2 PRECEDING`**: Toma las 2 filas anteriores inmediatas dentro de la partición del cliente.
* **`AND CURRENT ROW`**: Incluye la fila donde está evaluando el motor (`SaleID` en curso).
* **Resultado:** Cada venta individual (`SaleID`) mantiene su propia identidad y auditoría, pero enriquecida con la tendencia temporal inmediata de su cliente.

---

### F. La Trampa Clásica de `FIRST_VALUE()` vs `LAST_VALUE()` & El Marco Físico

En entrevistas técnicas y reportes analíticos, es muy común querer contextualizar cada transacción individual con la **primera** y la **última** compra registrada de ese cliente.

#### 1. El Error Frecuente (El "Marco Invisible" por Defecto):
```sql
-- ❌ ERROR COMÚN: LAST_VALUE devuelve la fila actual, no la última histórica
SELECT 
    SaleID, CustomerID, SaleDate, Amount,
    FIRST_VALUE(Amount) OVER (
        PARTITION BY CustomerID 
        ORDER BY SaleDate, SaleID
    ) AS primera_compra,
    LAST_VALUE(Amount) OVER (
        PARTITION BY CustomerID 
        ORDER BY SaleDate, SaleID
    ) AS ultima_compra_ENGANOSA
FROM FactSales
WHERE CustomerID = 100;
```

* **¿Por qué falla `LAST_VALUE`?**  
  Por el estándar ANSI SQL, si hay un `ORDER BY` y no defines el marco físico, el motor inyecta automáticamente:  
  `RANGE BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW`.
* Por lo tanto, el marco termina en la fila actual (`CURRENT ROW`). Para el motor, ¡el "último valor" visible en ese instante es la fila donde está parado!

#### 2. La Solución Senior (Expandir la ventana al infinito):
```sql
-- ✅ SOLUCIÓN SENIOR: Ventana completa de inicio a fin
SELECT 
    SaleID, CustomerID, SaleDate, Amount,
    FIRST_VALUE(Amount) OVER (
        PARTITION BY CustomerID 
        ORDER BY SaleDate, SaleID
        ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
    ) AS primera_compra_real,
    LAST_VALUE(Amount) OVER (
        PARTITION BY CustomerID 
        ORDER BY SaleDate, SaleID
        ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
    ) AS ultima_compra_real
FROM FactSales
WHERE CustomerID = 100
ORDER BY SaleDate, SaleID;
```

#### 3. Granularidad Transaccional vs Contexto de Entidad:
* **`SaleID` (Grano Fino):** Cada fila es una transacción única en el tiempo con su monto propio (`Amount`). La transacción no tiene "primera o última", es un evento atómico puntual.
* **`CustomerID` (Partición / Entidad):** Es la persona que realiza múltiples compras. La ventana adjunta a esa fila los hitos globales del cliente (`primera_compra_real` y `ultima_compra_real`), permitiendo comparar si esa compra puntual `#2000` (\$3,000) superó su ticket de entrada inicial (\$150) o su ticket final conocido (\$850).

---

### G. Segmentación de Negocio con `NTILE(N)` (Cuartiles, Deciles y Percentiles)

Cuando Marketing, Finanzas o Riesgo solicita clasificar a toda la cartera de usuarios en grupos equitativos de gasto o actividad (ej. el 25% VIP, el 25% alto, el 25% medio y el 25% bajo), `NTILE(N)` reparte a la población automáticamente en $N$ cubetas (*buckets*) iguales en una sola pasada.

#### 1. Consulta Analítica: Segmentar y Etiquetar con `CASE`
```sql
WITH CustomerSpend AS (
    SELECT 
        CustomerID,
        ROUND(SUM(Amount), 2) AS total_gastado,
        COUNT(SaleID) AS total_compras
    FROM FactSales
    GROUP BY CustomerID
),
CustomerQuartiles AS (
    SELECT 
        CustomerID,
        total_gastado,
        total_compras,
        NTILE(4) OVER (ORDER BY total_gastado DESC) AS cuartil
    FROM CustomerSpend
)
SELECT 
    CustomerID,
    total_gastado,
    total_compras,
    cuartil,
    CASE cuartil
        WHEN 1 THEN 'Tier 1: VIP (Top 25%)'
        WHEN 2 THEN 'Tier 2: Alto Valor'
        WHEN 3 THEN 'Tier 3: Ticket Medio'
        WHEN 4 THEN 'Tier 4: Ocasional / Bajo'
    END AS segmento_cliente
FROM CustomerQuartiles
ORDER BY total_gastado DESC;
```

#### 2. Resumen Ejecutivo de Control (Auditoría de Cuartiles)
Para verificar la distribución matemática exacta de la cartera sin colapsar el cliente por cliente:

```sql
WITH CustomerSpend AS (
    SELECT 
        CustomerID,
        ROUND(SUM(Amount), 2) AS total_gastado
    FROM FactSales
    GROUP BY CustomerID
),
CustomerQuartiles AS (
    SELECT 
        CustomerID,
        total_gastado,
        NTILE(4) OVER (ORDER BY total_gastado DESC) AS cuartil
    FROM CustomerSpend
)
SELECT 
    cuartil,
    CASE cuartil
        WHEN 1 THEN 'Tier 1: VIP (Top 25%)'
        WHEN 2 THEN 'Tier 2: Alto Valor'
        WHEN 3 THEN 'Tier 3: Ticket Medio'
        WHEN 4 THEN 'Tier 4: Ocasional / Bajo'
    END AS segmento,
    COUNT(*) AS total_clientes,
    MIN(total_gastado) AS gasto_minimo,
    MAX(total_gastado) AS gasto_maximo,
    ROUND(AVG(total_gastado), 2) AS gasto_promedio
FROM CustomerQuartiles
GROUP BY cuartil
ORDER BY cuartil;
```

> 💡 **Nota de Arquitectura:** En una base con 5,000 clientes, `NTILE(4)` asigna exactamente 1,250 clientes a cada uno de los 4 cuartiles. Si aplicas un `LIMIT 20` ordenado descendente, verás exclusivamente a 20 miembros del Cuartil 1 (VIP), ya que para ver el Cuartil 2 tendrías que sobrepasar la fila 1,250.

---

## 6. Los 3 Algoritmos Físicos de JOIN y Spills a TempDB

En SQL lógico simplemente escribimos `JOIN ... ON ...`. Pero en el motor físico (SQL Server, PostgreSQL, Snowflake, Oracle, SQLite), el **Optimizador de Consultas basado en Costos (CBO)** debe elegir uno de 3 algoritmos físicos para procesar los datos:

```
┌────────────────────────────────────────────────────────────────────────────────────────┐
│             COMPARATIVA DE ALGORITMOS FÍSICOS DE JOIN EN MOTORES RELACIONALES          │
├───────────────────┬──────────────┬────────────────────────────┬────────────────────────┤
│ ALGORITMO         │ COMPLEJIDAD  │ MEJOR CASO                 │ PEOR CASO (PELIGRO)    │
├───────────────────┼──────────────┼────────────────────────────┼────────────────────────┤
│ Nested Loops Join │ O(M * log N) │ Tabla exterior pequeña +   │ Tabla interior grande  │
│                   │              │ índice en tabla interior   │ sin índices (O(M * N)) │
├───────────────────┼──────────────┼────────────────────────────┼────────────────────────┤
│ Merge Join        │ O(M + N)     │ Ambas tablas ordenadas     │ Requiere un operador   │
│                   │              │ previamente por la clave   │ SORT previo en memoria │
├───────────────────┼──────────────┼────────────────────────────┼────────────────────────┤
│ Hash Match Join   │ O(M + N)     │ Tablas grandes sin ordenar │ MEMORY SPILL a TempDB  │
│                   │              │ ni índices (Data Warehouse)│ si falta RAM (E/S disco│
└───────────────────┴──────────────┴────────────────────────────┴────────────────────────┤
```

### A. Nested Loops Join (Bucle Anidado)
* **Mecánica:** Funciona como un `for` anidado en programación. Para cada fila de la tabla exterior (*Driving Table*), el motor ejecuta una búsqueda binaria (*Index Seek*) en el árbol B-Tree de la tabla interior.
* **Cuándo se elige:** Cuando una de las tablas tiene pocas filas (después de aplicar el `WHERE`) y la otra tabla tiene un índice sobre la clave de unión.
* **Diagnóstico en DBeaver:**
  ```text
  SCAN c
  SEARCH s USING INDEX IX_FactSales_Customer_Date (CustomerID=?)
  ```

### B. Merge Join (Unión por Fusión)
* **Mecánica:** Similar a cómo se unen dos listas ordenadas en Merge Sort (efecto cremallera / zipper). Dos punteros avanzan simultáneamente de arriba hacia abajo sin retroceder.
* **Cuándo se elige:** Cuando ambas tablas **ya están físicamente ordenadas** por la clave de JOIN (por ejemplo, mediante un *Clustered Index* o la salida de un índice ordenado). Es extremadamente veloz y requiere casi cero memoria de trabajo.

### C. Hash Match / Hash Join (Unión por Tabla Hash)
* **Mecánica en 2 Fases:**
  1. **Fase de Construcción (Build Phase):** Toma la tabla más pequeña (estimada por las estadísticas), calcula un hash de la clave de join y crea una tabla hash en la memoria RAM (*Memory Grant*).
  2. **Fase de Sondeo (Probe Phase):** Lee la tabla grande secuencialmente, calcula el hash de su clave y busca de inmediato en la tabla hash en memoria.
* **El Peligro Crítico: Hash Spill a TempDB / Workfile Spill:**
  - Cuando el optimizador estima mal el volumen de datos (porque las estadísticas están obsoletas, *Stale Statistics*), asigna un **Memory Grant** insuficiente (ej. 20 MB).
  - Al ejecutar la consulta, la tabla hash requiere 500 MB.
  - Al quedarse sin RAM, el motor se desborda y comienza a escribir y leer páginas en el disco temporal (**TempDB** en SQL Server o `/tmp` en PostgreSQL).
  - **Impacto en producción:** El tiempo de ejecución se degrada de 1.5 segundos a 15 minutos, disparando el I/O del disco y congelando el servidor.

---

## 7. Simulador de Preguntas Trampa de Entrevistas

### P1: *"¿Por qué no creamos un índice sobre cada columna de la tabla para acelerar todas las consultas?"*
> **Respuesta Senior:**  
> Porque los índices no son gratuitos. Cada índice es una estructura de árbol B-Tree adicional que la base de datos debe mantener. Si una tabla tiene 8 índices, cada operación de `INSERT`, `UPDATE` o `DELETE` debe escribir 8 veces en disco. Demasiados índices destruyen el rendimiento de escritura de los sistemas transaccionales (OLTP). Solo se indexan las columnas de búsqueda de alta selectividad y se usan índices cubrientes (`INCLUDE`).

### P2: *"¿Qué diferencia hay entre `ROW_NUMBER()` y `DENSE_RANK()` en un reporte de los mejores 3 vendedores?"*
> **Respuesta Senior:**  
> `ROW_NUMBER()` asigna números secuenciales sin importar empates; si dos vendedores empataron en el primer lugar en ventas, a uno le dará el puesto 1 y al otro el puesto 2 de forma arbitraria. `DENSE_RANK()` reconoce el empate otorgándoles a ambos el puesto 1, y al siguiente vendedor le asigna el puesto 2 de forma consecutiva, garantizando justicia de negocio y evitando descartar vendedores empatados en el Top 3.

### P3: *"¿Por qué `LAST_VALUE()` devuelve la fila actual en lugar del último valor histórico del cliente?"*
> **Respuesta Senior:**  
> Porque según el estándar ANSI SQL, al usar `ORDER BY` sin especificar el marco físico, el motor aplica por defecto `RANGE BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW`. El marco termina en la fila actual (`CURRENT ROW`), haciendo que el motor sea ciego a los registros futuros dentro de la partición. Se soluciona forzando el marco completo: `ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING`.

### P4: *"En una tabla con 50 millones de transacciones, necesitas extraer las 2 mejores compras de cada uno de nuestros 5,000 clientes. ¿Por qué `CROSS APPLY` suele ser órdenes de magnitud más rápido que un CTE con `ROW_NUMBER() <= 2`?"*
> **Respuesta Senior:**  
> Porque un CTE con `ROW_NUMBER() OVER (PARTITION BY CustomerID ORDER BY Amount DESC)` obliga al optimizador a ordenar y particionar en memoria (**Sort operator**) **las 50 millones de filas completas**, para luego descartar el 95% de los datos al filtrar `WHERE rnk <= 2`.  
> En cambio, `CROSS APPLY` evalúa una subconsulta lateral cliente por cliente. Si contamos con un índice compuesto en `FactSales(CustomerID, Amount DESC)`, el motor realiza un **Index Seek** que va directo a la rama del cliente en el árbol B-Tree, extrae únicamente sus 2 filas superiores y **se detiene al instante**.  
> Esto transforma un escaneo y ordenamiento masivo de 50 millones de registros en apenas **10,000 lecturas indexadas en memoria ($5,000 \text{ clientes} \times 2$)**, reduciendo el tiempo de ejecución de minutos a milisegundos y evitando spools a TempDB.

### P5: *"¿Qué es un Upsert y por qué en producción nunca debes ejecutar un UPDATE manual seguido de un INSERT?"*
> **Respuesta Senior:**  
> Un Upsert (*Update + Insert*) sincroniza un lote entrante con una tabla destino. Ejecutar un `UPDATE` manual seguido de un `INSERT` es una mala práctica de producción por tres razones:  
> 1. **Doble Lectura:** El motor tiene que escanear la tabla objetivo dos veces, duplicando el consumo de I/O de disco y memoria.  
> 2. **Condiciones de Carrera (*Race Conditions*):** Si otro proceso escribe en la tabla entre el UPDATE y el INSERT, se pueden generar violaciones de clave primaria o inconsistencias graves.  
> 3. **Bloqueos (*Deadlocks*):** Adquiere dos bloqueos de escritura separados sobre la tabla, aumentando el riesgo de congelar transacciones concurrentes.  
> Se soluciona utilizando una sentencia atómica única en un solo pase de disco: `MERGE INTO` (en T-SQL, Delta Lake y Snowflake) o `INSERT INTO ... ON CONFLICT (...) DO UPDATE` (en PostgreSQL y SQLite).

### P6: *"¿Cuándo elige el optimizador un Hash Match Join en lugar de un Merge Join o Nested Loops, y cuál es el mayor peligro en producción?"*
> **Respuesta Senior:**  
> El optimizador elige un **Hash Match Join** cuando une dos conjuntos de datos medianos o grandes donde las columnas de unión **no están indexadas ni ordenadas físicamente**.  
> El peligro mortal en producción es el **Hash Spill a TempDB / Workfile Spill**. Si las estadísticas del catálogo están obsoletas (*Stale Statistics*), el motor subestima la cantidad de filas y le otorga una concesión de memoria RAM (*Memory Grant*) diminuta. Al desbordarse la tabla hash en la fase de construcción (*Build Phase*), el motor vuelca los datos a disco en TempDB, degradando la consulta de milisegundos a minutos y saturando el subsistema de almacenamiento del servidor.

### P7: *"¿Cómo se diagnostica y resuelve un Spill a TempDB en un entorno de producción?"*
> **Respuesta Senior:**  
> 1. **Diagnóstico:** En el Plan de Ejecución Gráfico aparece un ícono de advertencia amarillo (**Warning: Operator used TempDB to spill data during execution with spill level 1/2**) en operadores de `Sort` o `Hash Match`. En Extended Events o Profiler se monitorean los eventos `Sort Warnings` o `Hash Warning`.  
> 2. **Causa Raíz:** Casi siempre se debe a una discrepancia severa entre *Estimated Number of Rows* (ej. 1,000) y *Actual Number of Rows* (ej. 2,000,000), provocada por estadísticas desactualizadas o variables locales que impiden la estimación de parámetros (*Parameter Sniffing*).  
> 3. **Resolución:**  
>    - Actualizar estadísticas: `UPDATE STATISTICS FactSales WITH FULLSCAN;`  
>    - Si falta un índice, crear un índice que proporcione los datos pre-ordenados para habilitar un **Merge Join** o un **Index Seek**.  
>    - Como parche de emergencia controlado, ajustar el Memory Grant mediante hints (`OPTION (MIN_GRANT_PERCENT = 20)`).


