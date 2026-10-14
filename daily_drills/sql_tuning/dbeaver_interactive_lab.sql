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
