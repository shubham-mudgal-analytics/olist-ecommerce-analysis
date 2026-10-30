-- ============================================================
-- 00 - Import Verification and Data Quality Checks
-- Project: Olist E-Commerce Analysis | DB: ecommerce
-- Run order: 00_verify_import_and_quality.sql -> 02_analysis_queries.sql
-- ============================================================
USE ecommerce;
GO

-- ------------------------------------------------------------
-- 0. Row count per table
-- Q:   Does each table have the expected number of rows?
-- Exp: Row counts match the source CSV files
-- ------------------------------------------------------------
SELECT 'orders' AS TableName, COUNT(*) AS TotalRows FROM orders
UNION ALL
SELECT 'order_items', COUNT(*) FROM order_items
UNION ALL
SELECT 'customers', COUNT(*) FROM customers
UNION ALL
SELECT 'products', COUNT(*) FROM products
UNION ALL
SELECT 'order_reviews', COUNT(*) FROM order_reviews
UNION ALL
SELECT 'product_category_name_translation', COUNT(*) FROM product_category_name_translation;
GO

-- ------------------------------------------------------------
-- 1. NULL values in critical columns
-- Q:   Are any important fields empty?
-- Exp: all 0, except Null_DeliveredDate = 2,965
--      (orders that were never delivered)
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
-- Q:   Is every order listed only once?
-- Exp: 0 rows
-- ------------------------------------------------------------
SELECT order_id, COUNT(*) AS OrderCount
FROM orders
GROUP BY order_id
HAVING COUNT(*) > 1;
GO

-- ------------------------------------------------------------
-- 3. Duplicate review_id
-- Q:   Are there repeated review IDs?
-- Exp: 789 (known issue in the source data, not an import error)
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
-- Q:   Does any date occur before the purchase date?
-- Exp: Delivered_Before_Purchase = 0
--      Approved_Before_Purchase  = 0
--      Carrier_Date_Before_Purchase = 166
-- ------------------------------------------------------------
SELECT
    SUM(CASE WHEN order_delivered_customer_date < order_purchase_timestamp THEN 1 ELSE 0 END) AS Delivered_Before_Purchase,
    SUM(CASE WHEN order_approved_at < order_purchase_timestamp THEN 1 ELSE 0 END)             AS Approved_Before_Purchase,
    SUM(CASE WHEN order_delivered_carrier_date < order_purchase_timestamp THEN 1 ELSE 0 END)  AS Carrier_Date_Before_Purchase
FROM orders;
GO

-- ------------------------------------------------------------
-- 5. Orphan records (LEFT JOIN + IS NULL)
-- Q:   Does every child record have a matching parent record?
-- Exp: all three = 0
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
-- Q:   Are there any unrealistic values (zero, negative, extreme)?
-- Exp: Min_Price 0.85 | Max_Price 6,735
--      Min_Freight 0 | Max_Freight 409.68
--      Zero_Price_Items = 0 | Negative_Freight = 0
-- ------------------------------------------------------------
SELECT
    CAST(MIN(price) AS DECIMAL(10,2))                  AS Min_Price,
    CAST(MAX(price) AS DECIMAL(10,2))                  AS Max_Price,
    CAST(MIN(freight_value) AS DECIMAL(10,2))          AS Min_Freight,
    CAST(MAX(freight_value) AS DECIMAL(10,2))          AS Max_Freight,
    SUM(CASE WHEN price <= 0 THEN 1 ELSE 0 END)        AS Zero_Price_Items,
    SUM(CASE WHEN freight_value < 0 THEN 1 ELSE 0 END) AS Negative_Freight
FROM order_items;
GO

-- ------------------------------------------------------------
-- 7. Category mapping - missing category or translation
-- Q:   Which products cannot be mapped to an English category?
-- Exp: 3 result rows:
--      NULL (610 products)
--      pc_gamer (3 products)
--      portateis_cozinha_e_preparadores_de_alimentos (10 products)
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

-- ------------------------------------------------------------
-- Q8. Delivery date range
-- Q:   What is the first and last delivered date in the data?
-- Exp: Last_Delivered is in Aug 2018 or later
-- ------------------------------------------------------------
SELECT MIN(order_delivered_customer_date) AS First_Delivered,
       MAX(order_delivered_customer_date) AS Last_Delivered
FROM orders
WHERE order_status = 'delivered'
  AND order_delivered_customer_date IS NOT NULL;
GO

-- ------------------------------------------------------------
-- Q9. Delivered revenue in 2016
-- Q:   How much delivered product revenue is from 2016?
-- Exp: Revenue_2016 = 40,470.98
-- ------------------------------------------------------------
SELECT COUNT(DISTINCT o.order_id)     AS Orders_2016,
       CAST(SUM(oi.price) AS DECIMAL(14,2)) AS Revenue_2016
FROM order_items AS oi
INNER JOIN orders AS o ON o.order_id = oi.order_id
WHERE o.order_status = 'delivered'
  AND o.order_delivered_customer_date IS NOT NULL
  AND DATEPART(YEAR, o.order_delivered_customer_date) = 2016;
GO

-- ------------------------------------------------------------
-- Q10. Delivered orders without reviews, and duplicate review rows
-- Q:   How many delivered orders have no review, and how many review rows are extra?
-- Exp: Delivered 96,470 | With_Review 95,824 | No_Review 646 | Review_Rows 96,353 | Extra_Rows 529
-- ------------------------------------------------------------
WITH delivered AS (
    SELECT order_id
    FROM orders
    WHERE order_status = 'delivered'
      AND order_delivered_customer_date IS NOT NULL
),
reviewed AS (
    SELECT d.order_id
    FROM delivered AS d
    INNER JOIN order_reviews AS r ON r.order_id = d.order_id
)
SELECT (SELECT COUNT(*) FROM delivered)                          AS Delivered,
       (SELECT COUNT(DISTINCT order_id) FROM reviewed)           AS With_Review,
       (SELECT COUNT(*) FROM delivered)
     - (SELECT COUNT(DISTINCT order_id) FROM reviewed)           AS No_Review,
       (SELECT COUNT(*) FROM reviewed)                           AS Review_Rows,
       (SELECT COUNT(*) FROM reviewed)
     - (SELECT COUNT(DISTINCT order_id) FROM reviewed)           AS Extra_Rows;
GO

-- ------------------------------------------------------------
-- Q11. Delivered orders with no delivery date
-- Q:   Which orders are marked delivered but have no delivery date, and what is their revenue?
-- Exp: Orders 8 | Revenue 1,249.18
-- ------------------------------------------------------------
SELECT COUNT(DISTINCT o.order_id)            AS Orders,
       CAST(SUM(oi.price) AS DECIMAL(14,2))  AS Revenue
FROM orders AS o
INNER JOIN order_items AS oi ON oi.order_id = o.order_id
WHERE o.order_status = 'delivered'
  AND o.order_delivered_customer_date IS NULL;
GO

-- ------------------------------------------------------------
-- Q12. Delivered orders in Sep-Oct 2018, with and without items
-- Q:   How many delivered orders fall in Sep-Oct 2018, and how many of them have items?
-- Exp: Orders_Sep_Oct_2018 = 59 | With_Items = orders with at least one order_items row
-- ------------------------------------------------------------
WITH sep_oct AS (
    SELECT o.order_id,
           CASE WHEN EXISTS (
                    SELECT 1 FROM order_items AS oi WHERE oi.order_id = o.order_id
                ) THEN 1 ELSE 0 END AS Has_Items
    FROM orders AS o
    WHERE o.order_status = 'delivered'
      AND o.order_delivered_customer_date >= '2018-09-01'
      AND o.order_delivered_customer_date <  '2018-11-01'
)
SELECT COUNT(*)       AS Orders_Sep_Oct_2018,
       SUM(Has_Items) AS With_Items
FROM sep_oct;
GO

-- ------------------------------------------------------------
-- Q13. Product revenue by delivered month (same base as Q1)
-- Q:   Do the monthly delivered revenues add up to the Q1 total of 13,220,248.93?
-- Exp: Total of Revenue = 13,220,248.93
--      Sep 2018 and Oct 2018 revenue is not zero
-- ------------------------------------------------------------
SELECT DATEPART(YEAR,  o.order_delivered_customer_date) AS Yr,
       DATEPART(MONTH, o.order_delivered_customer_date) AS Mth,
       COUNT(DISTINCT o.order_id)                       AS Orders,
       CAST(SUM(oi.price) AS DECIMAL(14,2))             AS Revenue
FROM order_items AS oi
INNER JOIN orders AS o ON o.order_id = oi.order_id
WHERE o.order_status = 'delivered'
  AND o.order_delivered_customer_date IS NOT NULL
GROUP BY DATEPART(YEAR,  o.order_delivered_customer_date),
         DATEPART(MONTH, o.order_delivered_customer_date)
ORDER BY Yr, Mth;
GO
