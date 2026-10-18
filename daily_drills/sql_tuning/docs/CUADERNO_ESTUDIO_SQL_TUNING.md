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
6. [Simulador de Preguntas Trampa de Entrevistas](#6-simulador-de-preguntas-trampa-de-entrevistas)

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

### A. `CROSS APPLY` vs `INNER JOIN`

#### La Pregunta de Entrevista:
> *"Necesitas obtener los TOP 3 pedidos más recientes de cada uno de nuestros 50,000 clientes. ¿Por qué `CROSS APPLY` suele ser más eficiente que un `JOIN` con subconsulta o una función de ventana?"*

```sql
SELECT 
    c.CustomerID,
    c.CustomerName,
    top_orders.SaleID,
    top_orders.SaleDate,
    top_orders.Amount
FROM DimCustomer c
CROSS APPLY (
    SELECT TOP (3) 
        s.SaleID,
        s.SaleDate,
        s.Amount
    FROM FactSales s
    WHERE s.CustomerID = c.CustomerID
    ORDER BY s.SaleDate DESC, s.SaleID DESC
) AS top_orders
ORDER BY c.CustomerID, top_orders.SaleDate DESC;
```

* **El problema de `ROW_NUMBER()`:** En tablas con millones de ventas, `ROW_NUMBER() OVER (PARTITION BY CustomerID...)` obliga al motor a particionar y ordenar **toda la historia de ventas** en memoria antes de poder filtrar `WHERE rnk <= 3`.
* **La ventaja de `CROSS APPLY`:** Evalúa la subconsulta correlacionada **cliente por cliente**. Si hay un índice en `(CustomerID, SaleDate DESC)`, va directo al índice, lee únicamente los 3 primeros registros y se detiene. Hace exactamente `50,000 clientes × 3 lecturas = 150,000 operaciones` en vez de escanear millones.

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

## 6. Simulador de Preguntas Trampa de Entrevistas

### P1: *"¿Por qué no creamos un índice sobre cada columna de la tabla para acelerar todas las consultas?"*
> **Respuesta Senior:**  
> Porque los índices no son gratuitos. Cada índice es una estructura de árbol B-Tree adicional que la base de datos debe mantener. Si una tabla tiene 8 índices, cada operación de `INSERT`, `UPDATE` o `DELETE` debe escribir 8 veces en disco. Demasiados índices destruyen el rendimiento de escritura de los sistemas transaccionales (OLTP). Solo se indexan las columnas de búsqueda de alta selectividad y se usan índices cubrientes (`INCLUDE`).

### P2: *"¿Qué diferencia hay entre `ROW_NUMBER()` y `DENSE_RANK()` en un reporte de los mejores 3 vendedores?"*
> **Respuesta Senior:**  
> `ROW_NUMBER()` asigna números secuenciales sin importar empates; si dos vendedores empataron en el primer lugar en ventas, a uno le dará el puesto 1 y al otro el puesto 2 de forma arbitraria. `DENSE_RANK()` reconoce el empate otorgándoles a ambos el puesto 1, y al siguiente vendedor le asigna el puesto 2 de forma consecutiva, garantizando justicia de negocio y evitando descartar vendedores empatados en el Top 3.

### P3: *"¿Por qué `LAST_VALUE()` devuelve la fila actual en lugar del último valor histórico del cliente?"*
> **Respuesta Senior:**  
> Porque según el estándar ANSI SQL, al usar `ORDER BY` sin especificar el marco físico, el motor aplica por defecto `RANGE BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW`. El marco termina en la fila actual (`CURRENT ROW`), haciendo que el motor sea ciego a los registros futuros dentro de la partición. Se soluciona forzando el marco completo: `ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING`.
