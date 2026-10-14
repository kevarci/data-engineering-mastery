# Daily Drill 1: Funciones de Ventana Avanzadas en SQL

> **Objetivo:** Dominar los patrones de funciones de ventana que aparecen en el 95% de las pruebas técnicas de Live Coding para Data Engineers y Data Analysts.

---

## Patrones a Resolver en `01_window_functions.sql`:

1. **Top N por Categoría con Desempate Limpio:**
   * Comparación entre `ROW_NUMBER()`, `RANK()` y `DENSE_RANK()`.
   * Cuándo usar cada una y cómo evitar descartar registros empatados en reportes de auditoría financiera.
2. **Cálculo de Totales Acumulados (*Running Total*):**
   * Sintaxis de marcos de agregación: `ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW`.
   * Impacto en rendimiento frente a subconsultas correlacionadas.
3. **Crecimiento Mes sobre Mes (*Month-over-Month Growth - MoM*):**
   * Uso de `LAG()` y `LEAD()` con valores por defecto para evitar nulos.
   * Cálculo de porcentaje de variación entre periodos consecutivos.
4. **Medias Móviles (*Rolling Average*):**
   * Cálculo de promedio de los últimos 7 días con `ROWS BETWEEN 6 PRECEDING AND CURRENT ROW`.
5. **Detección de Brechas e Islas (*Gaps & Islands Problem*):**
   * Agrupación de eventos consecutivos (por ejemplo, clientes que realizaron compras en días consecutivos).
