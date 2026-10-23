-- ==============================================================================
-- LABORATORIO INTERACTIVO DE SQL TUNING & WINDOW FUNCTIONS (DBEAVER)
-- Base de datos: tuning_lab.db (SQLite)
-- 120,000 registros en FactSales, 5,000 clientes en DimCustomer
-- ==============================================================================

-- ==============================================================================
-- SECCIÓN 1: COMPROBACIÓN INICIAL DE DATOS
-- ==============================================================================
-- 1.1 Ver clientes
SELECT * FROM DimCustomer LIMIT 10;

-- 1.2 Ver ventas masivas
SELECT * FROM FactSales LIMIT 10;

-- 1.3 Conteo de filas y distribución por estado
SELECT 
    Status, 
    COUNT(*) AS total_ventas,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM FactSales), 2) AS porcentaje
FROM FactSales
GROUP BY Status;


-- ==============================================================================
-- SECCIÓN 2: WINDOW FUNCTIONS DE ENTREVISTA (EN VIVO)
-- ==============================================================================

-- 2.1 TOP 3 CLIENTES POR CATEGORÍA CON DENSE_RANK()
-- (Compara el gasto total de clientes en cada categoría y extrae los 3 mejores)
WITH customer_totals AS (
    SELECT 
        category,
        customer_id,
        ROUND(SUM(amount), 2) AS total_spent
    FROM orders
    GROUP BY category, customer_id
),
ranked_customers AS (
    SELECT 
        category,
        customer_id,
        total_spent,
        DENSE_RANK() OVER (
            PARTITION BY category 
            ORDER BY total_spent DESC
        ) AS spending_rank
    FROM customer_totals
)
SELECT *
FROM ranked_customers
WHERE spending_rank <= 3
ORDER BY category, spending_rank;


-- 2.2 TOTAL ACUMULADO (RUNNING TOTAL) POR CLIENTE
-- Observa el uso de 'ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW'
SELECT 
    order_id,
    customer_id,
    order_date,
    amount,
    ROUND(SUM(amount) OVER (
        PARTITION BY customer_id 
        ORDER BY order_date, order_id
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ), 2) AS running_total
FROM orders
WHERE customer_id = 100
ORDER BY order_date;


-- 2.3 CRECIMIENTO MES SOBRE MES (MoM) CON LAG()
WITH monthly_sales AS (
    SELECT 
        STRFTIME('%Y-%m', order_date) AS sales_month,
        ROUND(SUM(amount), 2) AS current_month_revenue
    FROM orders
    GROUP BY 1
),
sales_with_lag AS (
    SELECT 
        sales_month,
        current_month_revenue,
        LAG(current_month_revenue, 1) OVER (ORDER BY sales_month) AS prev_month_revenue
    FROM monthly_sales
)
SELECT 
    sales_month,
    current_month_revenue,
    prev_month_revenue,
    ROUND(current_month_revenue - prev_month_revenue, 2) AS absolute_growth,
    ROUND((current_month_revenue - prev_month_revenue) / prev_month_revenue * 100.0, 2) AS mom_growth_pct
FROM sales_with_lag
ORDER BY sales_month;


-- ==============================================================================
-- SECCIÓN 3: PERFORMANCE TUNING & EXPLAIN QUERY PLAN (ÍNDICES)
-- ==============================================================================

-- 3.1 TEST DE TABLE SCAN (SIN ÍNDICE)
-- Ejecuta este EXPLAIN y fíjate en el resultado: SCAN TABLE FactSales (lee las 120,000 filas)
EXPLAIN QUERY PLAN
SELECT CustomerID, SaleDate, Amount 
FROM FactSales 
WHERE CustomerID = 4500 AND SaleDate >= '2026-01-01';


-- 3.2 CREACIÓN DEL ÍNDICE COMPUESTO
-- Creamos un índice sobre las columnas de búsqueda (CustomerID, SaleDate):
CREATE INDEX IF NOT EXISTS IX_FactSales_Customer_Date 
ON FactSales (CustomerID, SaleDate);


-- 3.3 TEST POST-ÍNDICE (INDEX SEEK / SEARCH)
-- Vuelve a ejecutar este EXPLAIN:
-- Ahora verás: SEARCH TABLE FactSales USING INDEX IX_FactSales_Customer_Date
EXPLAIN QUERY PLAN
SELECT CustomerID, SaleDate, Amount 
FROM FactSales 
WHERE CustomerID = 4500 AND SaleDate >= '2026-01-01';


-- 3.4 ÍNDICE FILTRADO (PARTIAL / FILTERED INDEX)
-- Recuerda: Solo el 3% de los pedidos son 'PENDING'
-- En lugar de indexar 120,000 filas, indexamos solo las ~3,600 filas pendientes:
CREATE INDEX IF NOT EXISTS IX_FactSales_Pending 
ON FactSales (SaleDate) 
WHERE Status = 'PENDING';

-- Ejecuta el plan: El motor usa el índice filtrado ultra-liviano
EXPLAIN QUERY PLAN
SELECT SaleID, CustomerID, Amount, SaleDate
FROM FactSales
WHERE Status = 'PENDING' AND SaleDate >= '2026-01-01';


-- ==============================================================================
-- SECCIÓN 4: PATRÓN TOP-N POR GRUPO (TOP 2 COMPRAS POR CLIENTE)
-- ==============================================================================
-- ¿QUÉ PROBLEMA DE NEGOCIO RESOLVEMOS?
-- Un reporte muy solicitado: "De cada cliente, extrae únicamente sus 2 compras
-- más caras registradas en la historia".
--
-- ¿POR QUÉ USAMOS UN CTE (WITH ...)?
-- Porque las funciones de ventana (como ROW_NUMBER) se calculan DESPUÉS del WHERE.
-- En SQL es ilegal escribir directamente: WHERE ROW_NUMBER() <= 2.
-- Por eso creamos una tabla virtual temporal con el ranking (el CTE)
-- y luego la filtramos en la consulta principal externa.
-- ==============================================================================

WITH RankedSales AS (
    -- PASO 1: Seleccionamos los datos base y calculamos el ranking numérico
    SELECT 
        c.CustomerID,       -- ID del cliente (Dimensión)
        c.CustomerName,     -- Nombre del cliente (Dimensión)
        s.SaleID,           -- ID único de la transacción (Hecho)
        s.SaleDate,         -- Fecha en que ocurrió la compra
        s.Amount,           -- Monto en dinero de la transacción
        
        -- AQUÍ OCURRE LA MAGIA DEL RANKING:
        ROW_NUMBER() OVER (
            -- 1. PARTITION BY CustomerID:
            -- Reinicia el contador a 1 cada vez que cambia de cliente.
            -- Es decir: El Cliente 1 tendrá sus puestos 1, 2, 3...
            --           El Cliente 2 empezará de nuevo en 1, 2, 3...
            PARTITION BY s.CustomerID 
            
            -- 2. ORDER BY s.Amount DESC:
            -- Ordena las compras de ESE cliente específico de la más cara a la más barata.
            -- Puesto 1 = La compra más cara de su historia.
            -- Puesto 2 = Su segunda mayor compra.
            ORDER BY s.Amount DESC
        ) AS ranking_compra

    -- Unimos la tabla de Clientes con su historial de Ventas
    FROM DimCustomer c
    JOIN FactSales s ON c.CustomerID = s.CustomerID
    
    -- Filtramos para hacer la prueba solo con los primeros 5 clientes
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


-- ==============================================================================
-- SECCIÓN 5: PATRÓN UPSERT ATÓMICO (MERGE / ON CONFLICT)
-- ==============================================================================
-- ¿QUÉ PROBLEMA DE NEGOCIO RESOLVEMOS?
-- En cargas diarias (ETL / ELT), recibimos un lote con transacciones nuevas
-- y transacciones existentes modificadas.
-- Un Junior hace: UPDATE ... seguido de INSERT ... (doble escaneo y riesgo de deadlocks).
-- Un Senior hace: Una sola sentencia atómica que actualiza si existe e inserta si no existe.
-- ==============================================================================

-- 5.1 Ejecutar el UPSERT atómico sobre FactSales
INSERT INTO FactSales (
    SaleID,
    CustomerID,
    SaleDate,
    Category,
    Amount,
    Status,
    RegionID
)
VALUES 
    -- Fila 1: VENTA EXISTENTE (SaleID 1 ya existe -> Se debe actualizar)
    (1, 1, '2026-10-19 12:00:00', 'Electronics', 3500.00, 'COMPLETED', 1),
    
    -- Fila 2: VENTA NUEVA (SaleID 999999 no existe -> Se debe insertar)
    (999999, 50, '2026-10-19 12:00:00', 'Home', 450.00, 'COMPLETED', 2)

-- LA CLÁUSULA DE RESOLUCIÓN ATÓMICA DE CONFLICTOS:
ON CONFLICT(SaleID) DO UPDATE SET
    Amount   = excluded.Amount,    -- "excluded" representa el nuevo dato que venía en el lote
    Status   = excluded.Status,    -- Actualizamos el estado al nuevo valor
    SaleDate = excluded.SaleDate;  -- Actualizamos la fecha de modificación

-- 5.2 Comprobación de auditoría
SELECT SaleID, CustomerID, SaleDate, Amount, Status 
FROM FactSales 
WHERE SaleID IN (1, 999999);


-- ==============================================================================
-- SECCIÓN 6: ALGORITMOS FÍSICOS DE JOIN Y AFINAMIENTO DE PLANES COMPLEJOS
-- ==============================================================================
-- ¿QUÉ PROBLEMA DE NEGOCIO Y PERFORMANCE ESTUDIAMOS?
-- Cuando hacemos JOIN entre dos tablas, el motor relacional no hace magia.
-- Debe elegir uno de 3 algoritmos físicos:
-- 1. Nested Loops Join: Ideal para tabla exterior pequeña + índice en tabla interior.
-- 2. Merge Join: Ideal para tablas masivas ya ordenadas físicamente (Clustered Index).
-- 3. Hash Match / Hash Join: Ideal para tablas no ordenadas ni indexadas (Build + Probe).
--
-- OBJETIVO DEL LABORATORIO INTERACTIVO:
-- Diagnosticar el plan de ejecución de un JOIN entre DimCustomer (5,000 filas)
-- y FactSales (120,000 filas), identificar el escaneo de tabla y optimizarlo con un índice.
-- ==============================================================================

-- 6.1 CONSULTA DE NEGOCIO: Top 10 Clientes de 'US' por volumen total de compras
-- Ejecuta primero con EXPLAIN QUERY PLAN para ver el plan antes del índice:
EXPLAIN QUERY PLAN
SELECT 
    c.CustomerID,
    c.CustomerName,
    COUNT(s.SaleID) AS total_pedidos,
    ROUND(SUM(s.Amount), 2) AS volumen_total
FROM DimCustomer c
JOIN FactSales s ON c.CustomerID = s.CustomerID
WHERE c.Country = 'US'
GROUP BY c.CustomerID, c.CustomerName
ORDER BY volumen_total DESC
LIMIT 10;

-- 6.2 DIAGNÓSTICO DEL PLAN ORIGINAL:
-- 1. SCAN c -> Escaneo completo de DimCustomer porque NO hay índice en Country (O(N)).
-- 2. SEARCH s USING INDEX IX_FactSales_Customer_Date (CustomerID=?) -> Nested Loops Join.
--    El motor usa cada cliente encontrado en c para saltar por el B-Tree de FactSales.
-- 3. USE TEMP B-TREE FOR ORDER BY -> Ordenamiento en memoria temporal porque el total
--    agregado SUM(Amount) se calcula en el momento.

-- 6.3 ACCIÓN DE TUNING SENIOR:
-- Creamos un índice secundario sobre la columna de filtro 'Country' en DimCustomer
CREATE INDEX IF NOT EXISTS IX_DimCustomer_Country ON DimCustomer(Country);

-- 6.4 VERIFICACIÓN DEL NUEVO PLAN TRAS LA OPTIMIZACIÓN:
-- Vuelve a ejecutar esta consulta y observa cómo 'SCAN c' se convierte en 'SEARCH c USING INDEX':
EXPLAIN QUERY PLAN
SELECT 
    c.CustomerID,
    c.CustomerName,
    COUNT(s.SaleID) AS total_pedidos,
    ROUND(SUM(s.Amount), 2) AS volumen_total
FROM DimCustomer c
JOIN FactSales s ON c.CustomerID = s.CustomerID
WHERE c.Country = 'US'
GROUP BY c.CustomerID, c.CustomerName
ORDER BY volumen_total DESC
LIMIT 10;

-- 6.5 CONSULTA REAL EN PRODUCCIÓN (Ver los 10 mejores clientes de US):
SELECT 
    c.CustomerID,
    c.CustomerName,
    COUNT(s.SaleID) AS total_pedidos,
    ROUND(SUM(s.Amount), 2) AS volumen_total
FROM DimCustomer c
JOIN FactSales s ON c.CustomerID = s.CustomerID
WHERE c.Country = 'US'
GROUP BY c.CustomerID, c.CustomerName
ORDER BY volumen_total DESC
LIMIT 10;




