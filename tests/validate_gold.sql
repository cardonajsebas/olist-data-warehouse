/* 
=============================================================================
Validation Script: Gold Layer Quality Checks
=============================================================================
Script Purpose:
    Validates referential integrity, measure quality and business logic
    correctness in the Gold layer views.

Categories:
    1. Referential integrity  — FK keys resolve to dimension keys
    2. Measure quality        — nulls and negatives on financial columns
    3. Derived column checks  — delivery delay and on-time flag logic
    4. Dimension completeness — surrogate key uniqueness per dimension
    5. Sanity checks          — business-level plausibility queries

Usage:
    Run after executing scripts/gold/load_gold.sql
    All checks in sections 1-4 should return 0 rows or 0 counts.
    Section 5 returns data for manual review.
=============================================================================
 */

/* 
=============================================================================
1. Referential Integrity
=============================================================================
Expected: 0 rows for all checks
Any non-zero result means a fact row has no matching dimension key
 */
SELECT 'fact_orders: unresolved customer_key' AS check_name,
    COUNT(*) AS issue_count
FROM gold.fact_orders
WHERE customer_key IS NULL

UNION ALL

SELECT 'fact_orders: unresolved product_key',
    COUNT(*)
FROM gold.fact_orders
WHERE product_key IS NULL

UNION ALL

SELECT 'fact_orders: unresolved seller_key',
    COUNT(*)
FROM gold.fact_orders
WHERE seller_key IS NULL

UNION ALL

SELECT 'fact_orders: unresolved date_key',
    COUNT(*)
FROM gold.fact_orders
WHERE date_key IS NULL

UNION ALL

-- Orphaned FK check — customer_key in fact not found in dim_customers
SELECT 'fact_orders: customer_key not in dim_customers',
    COUNT(*)
FROM gold.fact_orders f
WHERE NOT EXISTS (
    SELECT 1 FROM gold.dim_customers d
    WHERE d.customer_key = f.customer_key
)

UNION ALL

-- Orphaned FK check — product_key in fact not found in dim_products
SELECT 'fact_orders: product_key not in dim_products',
    COUNT(*)
FROM gold.fact_orders f
WHERE NOT EXISTS (
    SELECT 1 FROM gold.dim_products d
    WHERE d.product_key = f.product_key
)

UNION ALL

-- Orphaned FK check — seller_key in fact not found in dim_sellers
SELECT 'fact_orders: seller_key not in dim_sellers',
    COUNT(*)
FROM gold.fact_orders f
WHERE NOT EXISTS (
    SELECT 1 FROM gold.dim_sellers d
    WHERE d.seller_key = f.seller_key
)

UNION ALL

-- Orphaned FK check — date_key in fact not found in dim_date
SELECT 'fact_orders: date_key not in dim_date',
    COUNT(*)
FROM gold.fact_orders f
WHERE NOT EXISTS (
    SELECT 1 FROM gold.dim_date d
    WHERE d.date_key = f.date_key
)

ORDER BY check_name;


/* 
=============================================================================
2. Measure Quality
=============================================================================
Expected: 0 rows for all checks
 */
SELECT 'fact_orders: negative price' AS check_name,
        COUNT(*) AS issue_count
FROM gold.fact_orders
WHERE price < 0

UNION ALL

SELECT 'fact_orders: negative freight_value',
        COUNT(*)
FROM gold.fact_orders
WHERE freight_value < 0

UNION ALL

SELECT 'fact_orders: negative total_amount',
        COUNT(*)
FROM gold.fact_orders
WHERE total_amount < 0

UNION ALL

SELECT 'fact_orders: negative payment_value',
        COUNT(*)
FROM gold.fact_orders
WHERE payment_value < 0

UNION ALL

SELECT 'fact_orders: null price on delivered orders',
        COUNT(*)
FROM gold.fact_orders
WHERE price IS NULL
    AND order_status = 'delivered'

UNION ALL

SELECT 'fact_orders: review_score out of range',
        COUNT(*)
FROM gold.fact_orders
WHERE review_score IS NOT NULL
    AND review_score NOT BETWEEN 1 AND 5

ORDER BY check_name;


/* 
=============================================================================
3. Derived Column Checks
=============================================================================
 */
-- 3a. Delivery delay should only be populated for delivered orders
-- Expected: 0 rows
SELECT 'fact_orders: delay on non-delivered orders' AS check_name,
        COUNT(*) AS issue_count
FROM gold.fact_orders
WHERE delivery_delay_days IS NOT NULL
    AND order_status != 'delivered'

UNION ALL

-- 3b. is_on_time and delivery_delay_days should be consistent
-- if on time, delay should be <= 0. Expected: 0 rows
SELECT 'fact_orders: on_time flag inconsistent with delay',
        COUNT(*)
FROM gold.fact_orders
WHERE is_on_time = TRUE
    AND delivery_delay_days > 0

ORDER BY check_name;


/* 
=============================================================================
4. Dimension Completeness
=============================================================================
 */
-- 4a. Surrogate keys must be unique in each dimension
-- Expected: 0 rows

SELECT 'dim_customers: duplicate customer_key' AS check_name,
        COUNT(*) AS issue_count
FROM (
    SELECT customer_key
    FROM gold.dim_customers
    GROUP BY customer_key
    HAVING COUNT(*) > 1
) d

UNION ALL

SELECT 'dim_products: duplicate product_key',
        COUNT(*)
FROM (
    SELECT product_key
    FROM gold.dim_products
    GROUP BY product_key
    HAVING COUNT(*) > 1
) d

UNION ALL

SELECT 'dim_sellers: duplicate seller_key',
        COUNT(*)
FROM (
    SELECT seller_key
    FROM gold.dim_sellers
    GROUP BY seller_key
    HAVING COUNT(*) > 1
) d

UNION ALL

SELECT 'dim_date: duplicate date_key',
        COUNT(*)
FROM (
    SELECT date_key
    FROM gold.dim_date
    GROUP BY date_key
    HAVING COUNT(*) > 1
) d

UNION ALL

-- 4b. dim_products: no products without a category (should be 'unknown' not NULL)
SELECT 'dim_products: null category after translation',
        COUNT(*)
FROM gold.dim_products
WHERE product_category IS NULL

UNION ALL

-- 4c. dim_date: verify date range is within expected bounds (2016-2018)
SELECT 'dim_date: dates outside expected range',
        COUNT(*)
FROM gold.dim_date
WHERE year NOT BETWEEN 2016 AND 2018

ORDER BY check_name;


/* 
=============================================================================
5. Sanity Checks — Business Level
=============================================================================
These return data for manual review, not pass/fail checks.
Use to verify numbers are plausible before sign-off.
 */

-- 5a. Overall fact table row count and order count
SELECT
    COUNT(*)                        AS total_order_items,
    COUNT(DISTINCT order_id)        AS total_orders,
    COUNT(DISTINCT customer_key)    AS unique_customers,
    COUNT(DISTINCT product_key)     AS unique_products,
    COUNT(DISTINCT seller_key)      AS unique_sellers
FROM gold.fact_orders;

-- 5b. Revenue summary
SELECT
    ROUND(SUM(price)::NUMERIC, 2)           AS total_revenue,
    ROUND(AVG(price)::NUMERIC, 2)           AS avg_item_price,
    ROUND(SUM(freight_value)::NUMERIC, 2)   AS total_freight,
    ROUND(AVG(freight_value)::NUMERIC, 2)   AS avg_freight
FROM gold.fact_orders;

-- 5c. Order status distribution
SELECT
    order_status,
    COUNT(DISTINCT order_id)    AS order_count,
    ROUND(
        COUNT(DISTINCT order_id) * 100.0
        / SUM(COUNT(DISTINCT order_id)) OVER (),
    2)                          AS pct_of_total
FROM gold.fact_orders
GROUP BY order_status
ORDER BY order_count DESC;

-- 5d. Delivery performance summary
SELECT
    COUNT(DISTINCT order_id)                           AS delivered_orders,
    SUM(CASE WHEN is_on_time THEN 1 ELSE 0 END)        AS on_time,
    SUM(CASE WHEN NOT is_on_time THEN 1 ELSE 0 END)    AS late,
    ROUND(
        SUM(CASE WHEN is_on_time THEN 1 ELSE 0 END) * 100.0
        / NULLIF(COUNT(DISTINCT order_id), 0),
    2)                                                  AS on_time_pct,
    ROUND(AVG(delivery_delay_days)::NUMERIC, 1)         AS avg_delay_days
FROM gold.fact_orders
WHERE order_status = 'delivered';

-- 5e. Review score distribution
SELECT
    review_score,
    COUNT(*)                AS count,
    ROUND(
        COUNT(*) * 100.0
        / SUM(COUNT(*)) OVER (),
    2)                      AS pct_of_total
FROM gold.fact_orders
WHERE review_score IS NOT NULL
GROUP BY review_score
ORDER BY review_score DESC;

-- 5f. Revenue by year — verify data covers expected range
SELECT
    dd.year,
    COUNT(DISTINCT f.order_id)         AS total_orders,
    ROUND(SUM(f.price)::NUMERIC, 2)    AS total_revenue
FROM gold.fact_orders f
JOIN gold.dim_date dd ON f.date_key = dd.date_key
GROUP BY dd.year
ORDER BY dd.year;

-- 5g. Top 10 product categories by revenue
SELECT
    dp.product_category,
    COUNT(DISTINCT f.order_id)         AS total_orders,
    ROUND(SUM(f.price)::NUMERIC, 2)    AS total_revenue
FROM gold.fact_orders f
JOIN gold.dim_products dp ON f.product_key = dp.product_key
GROUP BY dp.product_category
ORDER BY total_revenue DESC
LIMIT 10;

-- 5h. Top 10 states by number of orders (customer location)
SELECT
    dc.customer_state,
    COUNT(DISTINCT f.order_id)         AS total_orders,
    ROUND(SUM(f.price)::NUMERIC, 2)    AS total_revenue
FROM gold.fact_orders f
JOIN gold.dim_customers dc ON f.customer_key = dc.customer_key
GROUP BY dc.customer_state
ORDER BY total_orders DESC
LIMIT 10;

SELECT
    order_id,
    order_status,
    order_delivered_customer_date,
    order_estimated_delivery_date,
    delivery_delay_days,
    is_on_time
FROM gold.fact_orders
WHERE delivery_delay_days IS NOT NULL
  AND order_status != 'delivered'
LIMIT 20;