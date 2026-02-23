/* ============================================================
   Cafe Operations Data Recovery & Sales Audit
   Data Cleaning Script
   Author: Ezz El Dean Hashish
   Description: Full cleaning workflow for operational recovery
============================================================ */


-- 1. Create Backup Working Table

CREATE TABLE cafe_data_clean AS 
SELECT * FROM cafe_sales_raw;



-- 2. Initial Exploration

-- Check duplicate Transaction IDs
SELECT COUNT(*) AS total_rows,
       COUNT(DISTINCT Transaction_ID) AS distinct_transactions
FROM cafe_data_clean;

-- Explore Item values
SELECT DISTINCT Item
FROM cafe_data_clean;



-- 3. Standardize Item Column

UPDATE cafe_data_clean
SET Item = UPPER(TRIM(Item));

UPDATE cafe_data_clean
SET Item = NULL
WHERE Item IN ('UNKNOWN', 'ERROR', '');



-- 4. Clean Numeric Columns (Before Type Conversion)

UPDATE cafe_data_clean
SET Quantity = NULL
WHERE Quantity IN ('UNKNOWN', 'ERROR', '');

UPDATE cafe_data_clean
SET Price_Per_Unit = NULL
WHERE Price_Per_Unit IN ('UNKNOWN', 'ERROR', '');

UPDATE cafe_data_clean
SET Total_Spent = NULL
WHERE Total_Spent IN ('UNKNOWN', 'ERROR', '');



-- 5. Convert Data Types

ALTER TABLE cafe_data_clean 
MODIFY COLUMN Quantity INT;

ALTER TABLE cafe_data_clean
MODIFY COLUMN Price_Per_Unit DECIMAL(10,2),
MODIFY COLUMN Total_Spent DECIMAL(10,2);



-- 6. Mathematical Imputation

-- Fill missing Quantity
UPDATE cafe_data_clean
SET Quantity = Total_Spent / Price_Per_Unit
WHERE Quantity IS NULL
AND Price_Per_Unit IS NOT NULL
AND Total_Spent IS NOT NULL
AND Price_Per_Unit <> 0;

-- Fill missing Total_Spent
UPDATE cafe_data_clean
SET Total_Spent = Quantity * Price_Per_Unit
WHERE Total_Spent IS NULL
AND Quantity IS NOT NULL
AND Price_Per_Unit IS NOT NULL;

-- Fill missing Price_Per_Unit
UPDATE cafe_data_clean
SET Price_Per_Unit = Total_Spent / Quantity
WHERE Price_Per_Unit IS NULL
AND Quantity IS NOT NULL
AND Total_Spent IS NOT NULL
AND Quantity <> 0;



-- 7. Business Logic Imputation

-- Cookies are always priced at $1
UPDATE cafe_data_clean
SET Price_Per_Unit = 1
WHERE Item = 'COOKIE'
AND Price_Per_Unit IS NULL;

-- Items priced at $5 are Salads
UPDATE cafe_data_clean
SET Item = 'SALAD'
WHERE Price_Per_Unit = 5
AND Item IS NULL;

-- Default $4 missing items to SANDWICH (based on frequency analysis)
UPDATE cafe_data_clean
SET Item = 'SANDWICH'
WHERE Price_Per_Unit = 4
AND Item IS NULL;



-- 8. Clean Payment & Location

UPDATE cafe_data_clean
SET Payment_Method = UPPER(TRIM(Payment_Method));

UPDATE cafe_data_clean
SET Payment_Method = NULL
WHERE Payment_Method IN ('UNKNOWN', 'ERROR', '');

UPDATE cafe_data_clean
SET Location = UPPER(TRIM(Location));

UPDATE cafe_data_clean
SET Location = NULL
WHERE Location IN ('UNKNOWN', 'ERROR', '');



-- 9. Date Cleaning

UPDATE cafe_data_clean
SET Transaction_Date = NULL
WHERE Transaction_Date IN ('UNKNOWN', 'ERROR', '');

ALTER TABLE cafe_data_clean
MODIFY COLUMN Transaction_Date DATE;



-- 10. Exploratory Financial Pattern Check

WITH price_check AS (
    SELECT 
        Transaction_ID,
        Item,
        Quantity,
        Price_Per_Unit,
        Total_Spent,
        (Total_Spent / Quantity) AS derived_price
    FROM cafe_data_clean
    WHERE Quantity IS NOT NULL
	AND Quantity <> 0
    AND Total_Spent IS NOT NULL
)

SELECT *
FROM price_check
WHERE derived_price <> Price_Per_Unit;



-- 11. Final Validation Checks

-- Remaining NULLs in financial columns
SELECT *
FROM cafe_data_clean
WHERE Quantity IS NULL
OR Price_Per_Unit IS NULL
OR Total_Spent IS NULL;

-- Check financial consistency
SELECT *
FROM cafe_data_clean
WHERE Total_Spent <> Quantity * Price_Per_Unit
AND Quantity IS NOT NULL
AND Price_Per_Unit IS NOT NULL;

-- Check duplicate transactions
SELECT Transaction_ID, COUNT(*)
FROM cafe_data_clean
GROUP BY Transaction_ID
HAVING COUNT(*) > 1;