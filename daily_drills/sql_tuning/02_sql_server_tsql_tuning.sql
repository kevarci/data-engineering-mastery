-- ==============================================================================
-- DAILY DRILL 02: MICROSOFT SQL SERVER & T-SQL PERFORMANCE TUNING
-- Candidato: Kevin Arciniegas
-- Motor: Microsoft SQL Server 2019/2022 / Azure SQL Database
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- PATRÓN 1: ELIMINACIÓN DE "KEY LOOKUP" CON ÍNDICES CUBRIENTES (COVERING INDEX)
-- Pregunta típica: "¿Qué es un Key Lookup en el Execution Plan y cómo lo solucionas?"
-- ------------------------------------------------------------------------------
-- Supón la tabla:
-- CREATE TABLE FactSales (
--     SaleID BIGINT IDENTITY PRIMARY KEY, -- Clustered Index por defecto
--     CustomerID INT NOT NULL,
--     SaleDate DATETIME2 NOT NULL,
--     Amount DECIMAL(12, 2) NOT NULL,
--     RegionID INT NOT NULL
-- );

-- Consulta de reporte que corre miles de veces por minuto:
-- SELECT CustomerID, SaleDate, Amount FROM FactSales WHERE CustomerID = 4500 AND SaleDate >= '2026-01-01';

-- Solución Senior:
-- Si creas solo: CREATE NONCLUSTERED INDEX IX_Customer ON FactSales(CustomerID, SaleDate);
-- El motor hace Index Seek sobre IX_Customer, pero tiene que ir al Clustered Index para traer 'Amount' (Key Lookup costoso).
-- La solución óptima es un ÍNDICE CUBRIENTE usando INCLUDE:
/*
CREATE NONCLUSTERED INDEX IX_FactSales_Customer_Date_Covering
ON FactSales (CustomerID, SaleDate)
INCLUDE (Amount); -- Amount se almacena en el nivel hoja sin agrandar el árbol B-Tree
*/


-- ------------------------------------------------------------------------------
-- PATRÓN 2: OBTENER LOS TOP 3 PEDIDOS MÁS RECIENTES POR CLIENTE CON CROSS APPLY
-- Pregunta típica: "¿Cuándo usar CROSS APPLY en lugar de un LEFT/INNER JOIN con subconsulta?"
-- ------------------------------------------------------------------------------
-- Con CROSS APPLY podemos invocar una subconsulta correlacionada o una función con valores de tabla
-- que se evalúa fila por fila para cada cliente de forma altamente eficiente:
/*
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
*/


-- ------------------------------------------------------------------------------
-- PATRÓN 3: STORED PROCEDURE ROBUSTO CON TRANSACCIÓN Y MANEJO DE ERRORES (TRY...CATCH)
-- Pregunta típica: "¿Cómo aseguras atomicidad y rollback automático ante bloqueos o fallos?"
-- ------------------------------------------------------------------------------
/*
CREATE OR ALTER PROCEDURE dbo.usp_UpsertCustomerBalance
    @CustomerID INT,
    @NewTransactionAmount DECIMAL(12, 2),
    @TransactionRef VARCHAR(50)
AS
BEGIN
    -- SET NOCOUNT ON evita mensajes de 'X rows affected' en red
    SET NOCOUNT ON;
    
    -- XACT_ABORT ON garantiza que si ocurre un error de ejecución o timeout,
    -- la transacción completa se revierta automáticamente (evita transacciones huérfanas)
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        -- 1. Insertar la transacción
        INSERT INTO CustomerTransactions (CustomerID, Amount, RefCode, CreatedAt)
        VALUES (@CustomerID, @NewTransactionAmount, @TransactionRef, SYSDATETIME());

        -- 2. Actualizar el saldo agregado
        UPDATE CustomerAccount
        SET CurrentBalance = CurrentBalance + @NewTransactionAmount,
            LastUpdated = SYSDATETIME()
        WHERE CustomerID = @CustomerID;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        -- Si hay una transacción activa sin confirmar, revertir
        IF (XACT_STATE()) <> 0
        BEGIN
            ROLLBACK TRANSACTION;
        END;

        -- Registrar el error o relanzar con THROW
        DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
        DECLARE @ErrorSeverity INT = ERROR_SEVERITY();
        DECLARE @ErrorState INT = ERROR_STATE();

        RAISERROR(@ErrorMessage, @ErrorSeverity, @ErrorState);
        RETURN -1;
    END CATCH;
END;
*/


-- ------------------------------------------------------------------------------
-- PATRÓN 4: #TEMP TABLE VS @TABLE VARIABLE (¿CUÁNDO USAR CUÁL?)
-- ------------------------------------------------------------------------------
-- Regla Senior de SQL Server:
-- 1. @Table (Variable de tabla): 
--    - El optimizador ASUME SIEMPRE que tiene 1 SOLA FILA (estimación de cardinalidad = 1).
--    - Úsala SOLO para menos de 100 filas. Si metes miles de filas, los JOINs usarán Nested Loops 
--      ineficientes y colapsarán la CPU.
-- 2. #Temp Table (Tabla temporal):
--    - Vive en TempDB, pero SÍ tiene estadísticas e índices reales.
--    - Es la opción por defecto para manipular grandes volúmenes intermedios en procedimientos de ETL.
