-- ==============================================================================
-- DAILY DRILL 01: ADVANCED WINDOW FUNCTIONS (LIVE CODING INTERVIEW PATTERNS)
-- Candidato: Kevin Arciniegas
-- Motor recomendado: PostgreSQL / Snowflake / BigQuery / SparkSQL
-- ==============================================================================

-- Esquema de prueba (Simulación de tabla de órdenes de e-commerce)
/*
CREATE TABLE orders (
    order_id INT,
    customer_id INT,
    order_date DATE,
    category VARCHAR(50),
    amount NUMERIC(10, 2)
);
*/

-- ------------------------------------------------------------------------------
-- PATRÓN 1: TOP 3 CLIENTES CON MAYOR FACTURACIÓN POR CATEGORÍA
-- Pregunta típica: "¿Cuál es la diferencia entre ROW_NUMBER, RANK y DENSE_RANK si hay empates?"
-- ------------------------------------------------------------------------------
WITH customer_totals AS (
    SELECT 
        category,
        customer_id,
        SUM(amount) AS total_spent
    FROM orders
    GROUP BY category, customer_id
),
ranked_customers AS (
    SELECT 
        category,
        customer_id,
        total_spent,
        -- DENSE_RANK asegura que si dos clientes gastaron exactamente lo mismo, compartan puesto 
        -- y el siguiente puesto sea consecutivo (sin huecos en la clasificación)
        DENSE_RANK() OVER (
            PARTITION BY category 
            ORDER BY total_spent DESC
        ) AS spending_rank
    FROM customer_totals
)
SELECT 
    category,
    spending_rank,
    customer_id,
    total_spent
FROM ranked_customers
WHERE spending_rank <= 3
ORDER BY category, spending_rank;


-- ------------------------------------------------------------------------------
-- PATRÓN 2: TOTAL ACUMULADO (RUNNING TOTAL) POR CLIENTE CON CONTROL DE MARCO
-- Pregunta típica: "¿Por qué `ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW` es crucial para el rendimiento?"
-- ------------------------------------------------------------------------------
SELECT 
    order_id,
    customer_id,
    order_date,
    amount,
    -- Sin 'ROWS BETWEEN...', el motor evalúa por defecto 'RANGE BETWEEN...' lo cual fuerza 
    -- procesamiento extra para agrupar duplicados en fecha. Especificar ROWS optimiza el escaneo.
    SUM(amount) OVER (
        PARTITION BY customer_id 
        ORDER BY order_date, order_id
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS running_customer_total
FROM orders
ORDER BY customer_id, order_date;


-- ------------------------------------------------------------------------------
-- PATRÓN 3: CRECIMIENTO MES SOBRE MES (MONTH-OVER-MONTH - MoM GROWTH)
-- Pregunta típica: "Calcula el porcentaje de variación mensual evitando división por cero"
-- ------------------------------------------------------------------------------
WITH monthly_sales AS (
    SELECT 
        DATE_TRUNC('month', order_date)::DATE AS sales_month,
        SUM(amount) AS current_month_revenue
    FROM orders
    GROUP BY 1
),
sales_with_lag AS (
    SELECT 
        sales_month,
        current_month_revenue,
        -- LAG obtiene el valor del mes inmediatamente anterior en la serie temporal
        LAG(current_month_revenue, 1) OVER (ORDER BY sales_month) AS previous_month_revenue
    FROM monthly_sales
)
SELECT 
    sales_month,
    current_month_revenue,
    previous_month_revenue,
    current_month_revenue - previous_month_revenue AS absolute_growth,
    ROUND(
        (current_month_revenue - previous_month_revenue) / NULLIF(previous_month_revenue, 0) * 100.0, 
        2
    ) AS mom_growth_percentage
FROM sales_with_lag
ORDER BY sales_month;
