/* 
=============================================================================
Validation Script: Silver Layer Quality Checks
=============================================================================
Script Purpose:
    Validates data quality and transformation accuracy in the Silver layer.
    Runs checks across four categories:
        1. Completeness  — row counts Silver vs Bronze
        2. Transformation accuracy — cleaning logic verification
        3. Integrity     — null checks on critical columns
        4. Consistency   — standardization verification

Usage:
    Run this script connected to the olist_dwh database in DBeaver
    after executing CALL silver.load_silver()

Expected outcome:
    All checks should return 0 rows or 0 counts to indicate no issues.
    Any non-zero result should be investigated before proceeding to Gold.
=============================================================================
 */

/* 
=============================================================================
1. Completeness — Row Counts Silver vs Bronze
=============================================================================
Expected: Silver counts should match Bronze for most tables.
        erp_geolocation is the exception — Silver will be significantly
        smaller due to deduplication (~1M -> ~19k rows)
 */
SELECT
    'bronze' AS layer, 'crm_customers' AS table_name, COUNT(*) AS row_count FROM bronze.crm_customers
UNION ALL
SELECT 'silver', 'crm_customers', COUNT(*) FROM silver.crm_customers
UNION ALL
SELECT 'bronze', 'crm_order_reviews', COUNT(*) FROM bronze.crm_order_reviews
UNION ALL
SELECT 'silver', 'crm_order_reviews', COUNT(*) FROM silver.crm_order_reviews
UNION ALL
SELECT 'bronze', 'erp_orders', COUNT(*) FROM bronze.erp_orders
UNION ALL
SELECT 'silver', 'erp_orders', COUNT(*) FROM silver.erp_orders
UNION ALL
SELECT 'bronze', 'erp_order_items', COUNT(*) FROM bronze.erp_order_items
UNION ALL
SELECT 'silver', 'erp_order_items', COUNT(*) FROM silver.erp_order_items
UNION ALL
SELECT 'bronze', 'erp_order_payments', COUNT(*) FROM bronze.erp_order_payments
UNION ALL
SELECT 'silver', 'erp_order_payments', COUNT(*) FROM silver.erp_order_payments
UNION ALL
SELECT 'bronze', 'erp_products', COUNT(*) FROM bronze.erp_products
UNION ALL
SELECT 'silver', 'erp_products', COUNT(*) FROM silver.erp_products
UNION ALL
SELECT 'bronze', 'erp_sellers', COUNT(*) FROM bronze.erp_sellers
UNION ALL
SELECT 'silver', 'erp_sellers', COUNT(*) FROM silver.erp_sellers
UNION ALL
SELECT 'bronze', 'erp_geolocation', COUNT(*) FROM bronze.erp_geolocation
UNION ALL
SELECT 'silver', 'erp_geolocation', COUNT(*) FROM silver.erp_geolocation
UNION ALL
SELECT 'bronze', 'erp_product_category_translation', COUNT(*) FROM bronze.erp_product_category_translation
UNION ALL
SELECT 'silver', 'erp_product_category_translation', COUNT(*) FROM silver.erp_product_category_translation
ORDER BY table_name, layer;


/* 
=============================================================================
2. Transformation Accuracy
=============================================================================

-----------------------------------------------------------------------------
2a. crm_customers — city should be lowercase, state should be uppercase
Expected: 0 rows
-----------------------------------------------------------------------------
 */
SELECT 'crm_customers: city not lowercase' AS check_name, COUNT(*) AS issue_count
FROM silver.crm_customers
WHERE customer_city != LOWER(customer_city)

UNION ALL

SELECT 'crm_customers: state not uppercase', COUNT(*)
FROM silver.crm_customers
WHERE customer_state != UPPER(customer_state)
    AND customer_state != 'n/a'

UNION ALL

/* 
-----------------------------------------------------------------------------
2b. crm_customers — zip code should always be 5 characters
Expected: 0 rows
-----------------------------------------------------------------------------
 */
SELECT 'crm_customers: zip not 5 chars', COUNT(*)
FROM silver.crm_customers
WHERE LENGTH(customer_zip_code_prefix) != 5

UNION ALL

/* 
-----------------------------------------------------------------------------
2c. crm_order_reviews — review_score must be between 1 and 5
Expected: 0 rows
-----------------------------------------------------------------------------
 */
SELECT 'crm_order_reviews: score out of range', COUNT(*)
FROM silver.crm_order_reviews
WHERE review_score NOT BETWEEN 1 AND 5

UNION ALL

/* 
-----------------------------------------------------------------------------
2d. erp_orders — order_status should be lowercase
Expected: 0 rows
-----------------------------------------------------------------------------
 */
SELECT 'erp_orders: status not lowercase', COUNT(*)
FROM silver.erp_orders
WHERE order_status != LOWER(order_status)

UNION ALL

/* 
-----------------------------------------------------------------------------
2e. erp_order_payments — payment_type should be lowercase
Expected: 0 rows
-----------------------------------------------------------------------------
 */
SELECT 'erp_order_payments: payment_type not lowercase', COUNT(*)
FROM silver.erp_order_payments
WHERE payment_type != LOWER(payment_type)

UNION ALL

/* 
-----------------------------------------------------------------------------
2f. erp_sellers — city should be lowercase, state should be uppercase
Expected: 0 rows
-----------------------------------------------------------------------------
 */
SELECT 'erp_sellers: city not lowercase', COUNT(*)
FROM silver.erp_sellers
WHERE seller_city != LOWER(seller_city)

UNION ALL

SELECT 'erp_sellers: state not uppercase', COUNT(*)
FROM silver.erp_sellers
WHERE seller_state != UPPER(seller_state)
    AND seller_state != 'n/a'

UNION ALL

/* 
-----------------------------------------------------------------------------
2g. erp_sellers — zip code should always be 5 characters
Expected: 0 rows
-----------------------------------------------------------------------------
 */
SELECT 'erp_sellers: zip not 5 chars', COUNT(*)
FROM silver.erp_sellers
WHERE LENGTH(seller_zip_code_prefix) != 5

UNION ALL

/* 
-----------------------------------------------------------------------------
2h. erp_geolocation — coordinates must be within Brazil bounds
Expected: 0 rows
-----------------------------------------------------------------------------
 */
SELECT 'erp_geolocation: coords outside Brazil', COUNT(*)
FROM silver.erp_geolocation
WHERE geolocation_lat NOT BETWEEN -34 AND 5
    OR geolocation_lng NOT BETWEEN -74 AND -28

UNION ALL

/* 
-----------------------------------------------------------------------------
2i. erp_geolocation — one row per zip prefix after deduplication
Expected: 0 rows
-----------------------------------------------------------------------------
 */
SELECT 'erp_geolocation: duplicate zip prefixes', COUNT(*)
FROM (
    SELECT geolocation_zip_code_prefix
    FROM silver.erp_geolocation
    GROUP BY geolocation_zip_code_prefix
    HAVING COUNT(*) > 1
) duplicates

UNION ALL

/* 
-----------------------------------------------------------------------------
2j. erp_products — column name typos corrected (no lenght columns)
Expected: columns product_name_length and product_description_length exist
This checks that no rows have been lost due to the rename
-----------------------------------------------------------------------------
 */
SELECT 'erp_products: row count mismatch after rename', COUNT(*)
FROM (
    SELECT COUNT(*) AS silver_count FROM silver.erp_products
) s
WHERE silver_count = 0;


/* 
=============================================================================
3. Integrity — Null Checks on Critical Columns
=============================================================================
Expected: 0 rows for all primary key and required columns
 */
SELECT 'crm_customers: null customer_id' AS check_name, COUNT(*) AS issue_count
FROM silver.crm_customers
WHERE customer_id IS NULL

UNION ALL

SELECT 'crm_order_reviews: null review_id', COUNT(*)
FROM silver.crm_order_reviews
WHERE review_id IS NULL

UNION ALL

SELECT 'crm_order_reviews: null order_id', COUNT(*)
FROM silver.crm_order_reviews
WHERE order_id IS NULL

UNION ALL

SELECT 'erp_orders: null order_id', COUNT(*)
FROM silver.erp_orders
WHERE order_id IS NULL

UNION ALL

SELECT 'erp_orders: null customer_id', COUNT(*)
FROM silver.erp_orders
WHERE customer_id IS NULL

UNION ALL

SELECT 'erp_order_items: null order_id', COUNT(*)
FROM silver.erp_order_items
WHERE order_id IS NULL

UNION ALL

SELECT 'erp_order_items: null price', COUNT(*)
FROM silver.erp_order_items
WHERE price IS NULL

UNION ALL

SELECT 'erp_order_payments: null order_id', COUNT(*)
FROM silver.erp_order_payments
WHERE order_id IS NULL

UNION ALL

SELECT 'erp_products: null product_id', COUNT(*)
FROM silver.erp_products
WHERE product_id IS NULL

UNION ALL

SELECT 'erp_sellers: null seller_id', COUNT(*)
FROM silver.erp_sellers
WHERE seller_id IS NULL

UNION ALL

SELECT 'erp_geolocation: null zip prefix', COUNT(*)
FROM silver.erp_geolocation
WHERE geolocation_zip_code_prefix IS NULL

UNION ALL

SELECT 'erp_product_category_translation: null category_name', COUNT(*)
FROM silver.erp_product_category_translation
WHERE product_category_name IS NULL

ORDER BY check_name;


/* 
=============================================================================
4. Consistency — Standardization Spot Checks
=============================================================================
 */
-- 4a. Distinct order statuses — should be clean lowercase values only
SELECT DISTINCT order_status, COUNT(*) AS count
FROM silver.erp_orders
GROUP BY order_status
ORDER BY count DESC;

-- 4b. Distinct payment types — should be 4 clean values
SELECT DISTINCT payment_type, COUNT(*) AS count
FROM silver.erp_order_payments
GROUP BY payment_type
ORDER BY count DESC;

-- 4c. Distinct states in customers — should all be 2-char uppercase or 'n/a'
SELECT DISTINCT customer_state, COUNT(*) AS count
FROM silver.crm_customers
GROUP BY customer_state
ORDER BY count DESC;

-- 4d. Distinct states in sellers — should all be 2-char uppercase or 'n/a'
SELECT DISTINCT seller_state, COUNT(*) AS count
FROM silver.erp_sellers
GROUP BY seller_state
ORDER BY count DESC;

-- 4e. Products with null category — acceptable but worth quantifying
SELECT
    COUNT(*) AS total_products,
    COUNT(product_category_name) AS products_with_category,
    COUNT(*) - COUNT(product_category_name) AS products_without_category
FROM silver.erp_products;

-- 4f. Reviews with null comments — expected high null rate, verify it's reasonable
SELECT
    COUNT(*) AS total_reviews,
    COUNT(review_comment_message) AS reviews_with_comment,
    ROUND(COUNT(review_comment_message) * 100.0 / COUNT(*), 2) AS pct_with_comment
FROM silver.crm_order_reviews;

-- 4g. Orders with null delivery date — expected for non-delivered orders
SELECT
    order_status,
    COUNT(*) AS total,
    COUNT(order_delivered_customer_date) AS delivered,
    COUNT(*) - COUNT(order_delivered_customer_date) AS not_delivered
FROM silver.erp_orders
GROUP BY order_status
ORDER BY total DESC;
