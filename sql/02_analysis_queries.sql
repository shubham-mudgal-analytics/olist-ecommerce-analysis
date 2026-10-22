-- ============================================================
-- 02 - Analysis Queries
-- Project: Olist E-Commerce Analysis | DB: ecommerce
-- Run order: 00_verify_import_and_quality.sql -> 02_analysis_queries.sql
-- Note: revenue = delivered orders only (oi.price, excluding freight)
-- ============================================================
USE ecommerce;


GO
-- ------------------------------------------------------------
-- Q1. Overall KPIs
-- Q:    Total orders, revenue, average order value, delivery time?
-- Exp:  orders 96,470 | revenue 13.22M | AOV 137.04 | delivery ~12 days
-- ------------------------------------------------------------
SELECT COUNT(DISTINCT o.order_id) AS Total_Orders,
       COUNT(DISTINCT c.customer_unique_id) AS Unique_Customers,
       COUNT(*) AS Order_Items,
       CAST (SUM(oi.price) AS DECIMAL (14, 2)) AS Product_Revenue,
       CAST (SUM(oi.freight_value) AS DECIMAL (14, 2)) AS Freight_Revenue,
       CAST (SUM(oi.price) / COUNT(DISTINCT o.order_id) AS DECIMAL (10, 2)) AS Avg_Order_Value,
       CAST (AVG(CAST (oi.price AS DECIMAL (10, 2))) AS DECIMAL (10, 2)) AS Avg_Item_Price,
       CAST (AVG (
                 CAST (DATEDIFF (
                     day,
                     o.order_purchase_timestamp,
                     o.order_delivered_customer_date
                 ) AS DECIMAL (6, 2))
             ) AS DECIMAL (6, 2)) AS Avg_Delivery_Days
FROM   orders AS o
       INNER JOIN
       order_items AS oi
       ON oi.order_id = o.order_id
       INNER JOIN
       customers AS c
       ON c.customer_id = o.customer_id
WHERE  o.order_status = 'delivered'
       AND o.order_delivered_customer_date IS NOT NULL;


GO
-- ------------------------------------------------------------
-- Q2. Monthly revenue trend + MoM growth + running total
-- Q:    How is revenue moving month by month?
-- Exp:  Jan 2017 – Aug 2018 (2016 excluded)
-- ------------------------------------------------------------
WITH     monthly
AS       (SELECT   DATEFROMPARTS (
                       YEAR (o.order_purchase_timestamp),
                       MONTH (o.order_purchase_timestamp),
                       1
                   ) AS Month_Start,
                   COUNT(DISTINCT o.order_id) AS Orders,
                   SUM(oi.price) AS Revenue
          FROM     orders AS o
                   INNER JOIN
                   order_items AS oi
                   ON oi.order_id = o.order_id
          WHERE    o.order_status = 'delivered'
                   AND o.order_delivered_customer_date IS NOT NULL
                   AND o.order_purchase_timestamp >= '2017-01-01'
          GROUP BY DATEFROMPARTS (
                       YEAR (o.order_purchase_timestamp),
                       MONTH (o.order_purchase_timestamp),
                       1
                   ))
SELECT   Month_Start,
         Orders,
         CAST (Revenue AS DECIMAL (18, 2)) AS Revenue,
         CAST (Revenue - LAG(Revenue) OVER (ORDER BY Month_Start) AS DECIMAL (18, 2)) AS MoM_Change,
         CAST ((Revenue - LAG(Revenue) OVER (ORDER BY Month_Start)) * 100.0 / NULLIF (LAG(Revenue) OVER (ORDER BY Month_Start), 0) AS DECIMAL (18, 2)) AS MoM_Pct,
         CAST (SUM(Revenue) OVER (ORDER BY Month_Start ROWS UNBOUNDED PRECEDING) AS DECIMAL (18, 2)) AS Running_Total
FROM     monthly
ORDER BY Month_Start;


GO
-- ------------------------------------------------------------
-- Q3. Top 10 product categories by revenue
-- Q:    Which categories drive revenue, and how concentrated is it?
-- Exp:  10 rows | top 8 categories = 54.5% of revenue
-- ------------------------------------------------------------
WITH     category_revenue
AS       (SELECT   ISNULL(t.product_category_name_english, p.product_category_name) AS Category,
                   COUNT(DISTINCT o.order_id) AS Orders,
                   SUM(oi.price) AS Revenue
          FROM     order_items AS oi
                   INNER JOIN
                   orders AS o
                   ON o.order_id = oi.order_id
                   INNER JOIN
                   products AS p
                   ON p.product_id = oi.product_id
                   LEFT OUTER JOIN
                   product_category_name_translation AS t
                   ON t.product_category_name = p.product_category_name
          WHERE    o.order_status = 'delivered'
                   AND o.order_delivered_customer_date IS NOT NULL
          GROUP BY ISNULL(t.product_category_name_english, p.product_category_name))
SELECT   TOP 10 Category,
                Orders,
                CAST (Revenue AS DECIMAL (14, 2)) AS Revenue,
                CAST (Revenue * 100.0 / SUM(Revenue) OVER () AS DECIMAL (5, 2)) AS Revenue_Pct
FROM     category_revenue
ORDER BY Revenue DESC;


GO
-- ------------------------------------------------------------
-- Q4. Review score distribution
-- Q:    How are ratings spread across 1 to 5?
-- Exp:  5-star ~57% | 4-star ~19% | 3-star ~8% | 2-star ~3% | 1-star ~11%
-- Note: all reviews, including orders that were not delivered
-- ------------------------------------------------------------
SELECT   review_score,
         COUNT(*) AS Reviews,
         CAST (COUNT(*) * 100.0 / SUM (
                                      COUNT (*)
                                  ) OVER () AS DECIMAL (5, 2)) AS Pct_Of_Total
FROM     order_reviews
GROUP BY review_score
ORDER BY review_score;


GO
-- ------------------------------------------------------------
-- Q5. Delivery performance
-- Q:    How long does delivery take, and how many orders are late?
-- Exp:  delivered 96,470 | actual 12.00 days vs promised 24.00 days
--       late 7,826 (8.11%) | avg 8.00 days late
-- ------------------------------------------------------------
SELECT COUNT(*) AS Delivered_Orders,
       CAST (AVG (
                 DATEDIFF (
                     day,
                     o.order_purchase_timestamp,
                     o.order_delivered_customer_date
                 )
             ) AS DECIMAL (6, 2)) AS Avg_Delivery_Days,
       CAST (AVG (
                 DATEDIFF (
                     day,
                     o.order_purchase_timestamp,
                     o.order_estimated_delivery_date
                 )
             ) AS DECIMAL (6, 2)) AS Avg_Promised_Days,
       SUM(CASE WHEN o.order_delivered_customer_date > o.order_estimated_delivery_date THEN 1 ELSE 0 END) AS Late_Orders,
       CAST (SUM(CASE WHEN o.order_delivered_customer_date > o.order_estimated_delivery_date THEN 1 ELSE 0 END) * 100.0 / COUNT(*) AS DECIMAL (5, 2)) AS Late_Pct,
       CAST (AVG (
                 CASE WHEN o.order_delivered_customer_date > o.order_estimated_delivery_date THEN DATEDIFF (
                     day,
                     o.order_estimated_delivery_date,
                     o.order_delivered_customer_date
                 ) END
             ) AS DECIMAL (6, 2)) AS Avg_Days_Late
FROM   orders AS o
WHERE  o.order_status = 'delivered'
       AND o.order_delivered_customer_date IS NOT NULL;


GO
-- ------------------------------------------------------------
-- Q6. Late delivery vs review score
-- Q:    Does a late delivery affect the customer rating?
-- Exp:  On Time 4.29 | Late 2.57 | drop 40.1%
--       Late 7,700 orders (7.99%) of reviewed delivered orders
-- ------------------------------------------------------------
SELECT   CASE WHEN o.order_delivered_customer_date > o.order_estimated_delivery_date THEN 'Late' ELSE 'On Time' END AS Delivery_Status,
         COUNT(*) AS Orders,
         CAST (COUNT(*) * 100.0 / SUM (
                                      COUNT (*)
                                  ) OVER () AS DECIMAL (5, 2)) AS Pct_Of_Orders,
         CAST (AVG(CAST (r.review_score AS DECIMAL (3, 2))) AS DECIMAL (4, 2)) AS Avg_Review_Score,
         SUM(CASE WHEN r.review_score = 5 THEN 1 ELSE 0 END) AS Five_Star,
         SUM(CASE WHEN r.review_score = 1 THEN 1 ELSE 0 END) AS One_Star,
         CAST (SUM(CASE WHEN r.review_score <= 2 THEN 1 ELSE 0 END) * 100.0 / COUNT(*) AS DECIMAL (5, 2)) AS Low_Review_Pct
FROM     orders AS o
         INNER JOIN
         order_reviews AS r
         ON r.order_id = o.order_id
WHERE    o.order_status = 'delivered'
         AND o.order_delivered_customer_date IS NOT NULL
GROUP BY CASE WHEN o.order_delivered_customer_date > o.order_estimated_delivery_date THEN 'Late' ELSE 'On Time' END;


GO
-- ------------------------------------------------------------
-- Q7. Repeat vs one-time customers
-- Q:    How many customers come back for a second order?
-- Exp:  One-time 97% | Repeat 3%
-- ------------------------------------------------------------
WITH     customer_orders
AS       (SELECT   c.customer_unique_id,
                   COUNT(DISTINCT o.order_id) AS Orders
          FROM     orders AS o
                   INNER JOIN
                   customers AS c
                   ON c.customer_id = o.customer_id
          WHERE    o.order_status = 'delivered'
                   AND o.order_delivered_customer_date IS NOT NULL
          GROUP BY c.customer_unique_id)
SELECT   CASE WHEN Orders = 1 THEN 'One-time (1 order)' ELSE 'Repeat (2+ orders)' END AS Customer_Type,
         COUNT(*) AS Customers,
         CAST (COUNT(*) * 100.0 / SUM (
                                      COUNT (*)
                                  ) OVER () AS DECIMAL (5, 2)) AS Customer_Pct
FROM     customer_orders
GROUP BY CASE WHEN Orders = 1 THEN 'One-time (1 order)' ELSE 'Repeat (2+ orders)' END;


GO
-- ------------------------------------------------------------
-- Q8. Top 3 categories per customer state
-- Q:    Which categories lead in each state?
-- Exp:  81 rows (27 states x 3 categories)
-- ------------------------------------------------------------
WITH     category_state
AS       (SELECT   c.customer_state,
                   ISNULL(t.product_category_name_english, p.product_category_name) AS Category,
                   SUM(oi.price) AS Revenue
          FROM     order_items AS oi
                   INNER JOIN
                   orders AS o
                   ON o.order_id = oi.order_id
                   INNER JOIN
                   customers AS c
                   ON c.customer_id = o.customer_id
                   INNER JOIN
                   products AS p
                   ON p.product_id = oi.product_id
                   LEFT OUTER JOIN
                   product_category_name_translation AS t
                   ON t.product_category_name = p.product_category_name
          WHERE    o.order_status = 'delivered'
                   AND o.order_delivered_customer_date IS NOT NULL
          GROUP BY c.customer_state,
                   ISNULL(t.product_category_name_english, p.product_category_name)),
         ranked
AS       (SELECT customer_state,
                 Category,
                 Revenue,
                 ROW_NUMBER() OVER (PARTITION BY customer_state ORDER BY Revenue DESC) AS Row_Num
          FROM   category_state)
SELECT   customer_state,
         Row_Num AS Rank_In_State,
         Category,
         CAST (Revenue AS DECIMAL (14, 2)) AS Revenue
FROM     ranked
WHERE    Row_Num <= 3
ORDER BY customer_state,
         Row_Num;


GO

