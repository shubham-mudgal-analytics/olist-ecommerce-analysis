-- ============================================================
-- 00 - Import Verification and Data Quality Checks
-- Project: Olist E-Commerce Analysis | DB: ecommerce
-- Run order: 00_verify_import_and_quality.sql -> 02_analysis_queries.sql
-- ============================================================
USE ecommerce;
GO

-- ------------------------------------------------------------
-- 0. Row count per table
-- Q:    Does each table have the expected number of rows?
-- Exp:  Row counts match the source CSV files
-- ------------------------------------------------------------
SELECT t.name AS TableName,
       SUM(p.rows) AS TotalRows
FROM sys.tables AS t
JOIN sys.partitions AS p ON p.object_id = t.object_id
WHERE p.index_id IN (0, 1)
GROUP BY t.name
ORDER BY TotalRows DESC;
GO

-- ------------------------------------------------------------
-- 1. NULL values in critical columns
-- Q:    Are any important fields empty?
-- Exp:  all 0, except Null_DeliveredDate = 2,965
--       (orders that were never delivered)
-- ------------------------------------------------------------
SELECT
    SUM(CASE WHEN order_id IS NULL THEN 1 ELSE 0 END)                      AS Null_OrderId,
    SUM(CASE WHEN customer_id IS NULL THEN 1 ELSE 0 END)                   AS Null_CustomerId,
    SUM(CASE WHEN order_status IS NULL THEN 1 ELSE 0 END)                  AS Null_OrderStatus,
    SUM(CASE WHEN order_purchase_timestamp IS NULL THEN 1 ELSE 0 END)      AS Null_OrderPurchaseDate,
    SUM(CASE WHEN order_delivered_customer_date IS NULL THEN 1 ELSE 0 END) AS Null_DeliveredDate,
    SUM(CASE WHEN order_estimated_delivery_date IS NULL THEN 1 ELSE 0 END) AS Null_EstimatedDate
FROM orders;
GO

-- ------------------------------------------------------------
-- 2. Duplicate order_id
-- Q:    Is every order listed only once?
-- Exp:  0 rows
-- ------------------------------------------------------------
SELECT
    order_id,
    COUNT(*) AS OrderCount
FROM orders
GROUP BY order_id
HAVING COUNT(*) > 1;
GO

-- ------------------------------------------------------------
-- 3. Duplicate review_id
-- Q:    Are there repeated review IDs?
-- Exp:  789 (known issue in the source data, not an import error)
-- ------------------------------------------------------------
SELECT COUNT(*) AS Duplicate_ReviewIds
FROM (
    SELECT review_id
    FROM order_reviews
    GROUP BY review_id
    HAVING COUNT(*) > 1
) AS x;
GO

-- ------------------------------------------------------------
-- 4. Date logic - impossible dates
-- Q:    Does any date occur before the purchase date?
-- Exp:  Delivered_Before_Purchase = 0
--       Approved_Before_Purchase  = 0
--       Carrier_Date_Before_Purchase   = 166
-- ------------------------------------------------------------
SELECT
    SUM(CASE WHEN order_delivered_customer_date < order_purchase_timestamp THEN 1 ELSE 0 END) AS Delivered_Before_Purchase,
    SUM(CASE WHEN order_approved_at < order_purchase_timestamp THEN 1 ELSE 0 END)             AS Approved_Before_Purchase,
    SUM(CASE WHEN order_delivered_carrier_date < order_purchase_timestamp THEN 1 ELSE 0 END)  AS Carrier_Date_Before_Purchase
FROM orders;
GO

-- ------------------------------------------------------------
-- 5. Orphan records (LEFT JOIN + IS NULL)
-- Q:    Does every child record have a matching parent record?
-- Exp:  all three = 0
-- ------------------------------------------------------------
SELECT COUNT(*) AS Orphan_Items
FROM order_items oi
LEFT JOIN orders o ON o.order_id = oi.order_id
WHERE o.order_id IS NULL;
GO

SELECT COUNT(*) AS Orphan_Customers
FROM orders o
LEFT JOIN customers c ON c.customer_id = o.customer_id
WHERE c.customer_id IS NULL;
GO

SELECT COUNT(*) AS Orphan_Products
FROM order_items oi
LEFT JOIN products p ON p.product_id = oi.product_id
WHERE p.product_id IS NULL;
GO

-- ------------------------------------------------------------
-- 6. Numeric ranges - price and freight
-- Q:    Are there any unrealistic values (zero, negative, extreme)?
-- Exp:  Min_Price = 0.85   | Max_Price = 6,735   | Avg_Price = 120.65
--       Min_Freight = 0    | Max_Freight = 409.68 | Avg_Freight = 19.99
--       Zero_Price_Items = 0 | Negative_Freight = 0
-- ------------------------------------------------------------
SELECT
    CAST(MIN(price) AS DECIMAL(10,2))                   AS Min_Price,
    CAST(MAX(price) AS DECIMAL(10,2))                   AS Max_Price,
    CAST(AVG(price) AS DECIMAL(10,2))                   AS Avg_Price,
    CAST(MIN(freight_value) AS DECIMAL(10,2))           AS Min_Freight,
    CAST(MAX(freight_value) AS DECIMAL(10,2))           AS Max_Freight,
    CAST(AVG(freight_value) AS DECIMAL(10,2))           AS Avg_Freight,
    SUM(CASE WHEN price <= 0 THEN 1 ELSE 0 END)         AS Zero_Price_Items,
    SUM(CASE WHEN freight_value < 0 THEN 1 ELSE 0 END)  AS Negative_Freight
FROM order_items;
GO

-- ------------------------------------------------------------
-- 7. Category mapping - missing category or translation
-- Q:    Which products cannot be mapped to an English category?
-- Exp:  3 result rows: 
--       NULL (610 products)
--       pc_gamer (3 products)
--       portateis_cozinha_e_preparadores_de_alimentos (10 products)
-- ------------------------------------------------------------
SELECT
    p.product_category_name,
    COUNT(*) AS Products
FROM products p
LEFT JOIN product_category_name_translation t
       ON t.product_category_name = p.product_category_name
WHERE t.product_category_name IS NULL
GROUP BY p.product_category_name;
GO
