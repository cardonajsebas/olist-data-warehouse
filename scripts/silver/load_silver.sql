/* 
=============================================================================
Stored Procedure: Load Silver Layer (Bronze -> Silver)
=============================================================================
Script Purpose:
    This procedure performs the ETL process to populate the 'silver' schema
    tables from the 'bronze' schema.
    Actions Performed:
        - Truncates Silver tables
        - Inserts transformed and cleansed data from Bronze into Silver

Parameters:
    None. This procedure does not accept parameters or return values.

Usage:
    CALL silver.load_silver();
    Run this script connected to the olist_dwh database in DBeaver
=============================================================================
 */

CREATE OR REPLACE PROCEDURE silver.load_silver()
LANGUAGE plpgsql
AS $$
DECLARE
    v_start_time      TIMESTAMP;
    v_end_time        TIMESTAMP;
    v_batch_start     TIMESTAMP;
    v_batch_end       TIMESTAMP;
BEGIN
    v_batch_start := clock_timestamp();

    RAISE NOTICE '================================================';
    RAISE NOTICE 'Loading Silver Layer';
    RAISE NOTICE '================================================';

/* 
    =========================================================================
    CRM Tables
    =========================================================================
 */
    RAISE NOTICE '------------------------------------------------';
    RAISE NOTICE 'Loading CRM Tables';
    RAISE NOTICE '------------------------------------------------';

/* 
    -------------------------------------------------------------------------
    Table: silver.crm_customers
    Transformations:
        - TRIM + LOWER city names to fix encoding and casing inconsistencies
        - LPAD zip code prefix to ensure 5-char format
        - Empty state values defaulted to 'n/a'
        - UPPER state abbreviations for consistency
    -------------------------------------------------------------------------
 */
    v_start_time := clock_timestamp();
    RAISE NOTICE '>> Truncating Table: silver.crm_customers';
    TRUNCATE TABLE silver.crm_customers;

    RAISE NOTICE '>> Inserting Data Into: silver.crm_customers';
    INSERT INTO silver.crm_customers (
        customer_id,
        customer_unique_id,
        customer_zip_code_prefix,
        customer_city,
        customer_state
    )
    SELECT
        customer_id,
        customer_unique_id,
        LPAD(TRIM(customer_zip_code_prefix), 5, '0')    AS customer_zip_code_prefix,
        LOWER(TRIM(customer_city))                       AS customer_city,
        CASE
            WHEN TRIM(customer_state) IS NULL
                OR TRIM(customer_state) = '' THEN 'n/a'
            ELSE UPPER(TRIM(customer_state))
        END                                              AS customer_state
    FROM bronze.crm_customers
    WHERE customer_id IS NOT NULL;

    v_end_time := clock_timestamp();
    RAISE NOTICE '>> Load Duration: % seconds', EXTRACT(EPOCH FROM (v_end_time - v_start_time));
    RAISE NOTICE '>> -------------';

/* 
    -------------------------------------------------------------------------
    Table: silver.crm_order_reviews
    Transformations:
        - review_score cast to INTEGER, validated within range 1-5
        - Dates cast to TIMESTAMP
        - Comment fields trimmed, empty strings converted to NULL
        - Nulls on comment fields preserved intentionally (high null rate expected)
    -------------------------------------------------------------------------
 */
    v_start_time := clock_timestamp();
    RAISE NOTICE '>> Truncating Table: silver.crm_order_reviews';
    TRUNCATE TABLE silver.crm_order_reviews;

    RAISE NOTICE '>> Inserting Data Into: silver.crm_order_reviews';
    INSERT INTO silver.crm_order_reviews (
        review_id,
        order_id,
        review_score,
        review_comment_title,
        review_comment_message,
        review_creation_date,
        review_answer_timestamp
    )
    SELECT
        review_id,
        order_id,
        CASE
            WHEN review_score::INTEGER BETWEEN 1 AND 5
                THEN review_score::INTEGER
            ELSE NULL
        END                                             AS review_score,
        NULLIF(TRIM(review_comment_title), '')          AS review_comment_title,
        NULLIF(TRIM(review_comment_message), '')        AS review_comment_message,
        review_creation_date::TIMESTAMP                 AS review_creation_date,
        NULLIF(review_answer_timestamp, '')::TIMESTAMP  AS review_answer_timestamp
    FROM bronze.crm_order_reviews
    WHERE review_id IS NOT NULL
        AND order_id  IS NOT NULL;

    v_end_time := clock_timestamp();
    RAISE NOTICE '>> Load Duration: % seconds', EXTRACT(EPOCH FROM (v_end_time - v_start_time));
    RAISE NOTICE '>> -------------';


/* 
    =========================================================================
    ERP Tables
    =========================================================================
 */
    RAISE NOTICE '------------------------------------------------';
    RAISE NOTICE 'Loading ERP Tables';
    RAISE NOTICE '------------------------------------------------';

/* 
    -------------------------------------------------------------------------
    Table: silver.erp_orders
    Transformations:
        - All timestamp columns cast to TIMESTAMP
        - order_status standardized to lowercase and trimmed
        - Delivery date nulls preserved (expected for non-delivered orders)
    -------------------------------------------------------------------------
 */
    v_start_time := clock_timestamp();
    RAISE NOTICE '>> Truncating Table: silver.erp_orders';
    TRUNCATE TABLE silver.erp_orders;

    RAISE NOTICE '>> Inserting Data Into: silver.erp_orders';
    INSERT INTO silver.erp_orders (
        order_id,
        customer_id,
        order_status,
        order_purchase_timestamp,
        order_approved_at,
        order_delivered_carrier_date,
        order_delivered_customer_date,
        order_estimated_delivery_date
    )
    SELECT
        order_id,
        customer_id,
        LOWER(TRIM(order_status))                               AS order_status,
        order_purchase_timestamp::TIMESTAMP                     AS order_purchase_timestamp,
        NULLIF(order_approved_at, '')::TIMESTAMP                AS order_approved_at,
        NULLIF(order_delivered_carrier_date, '')::TIMESTAMP     AS order_delivered_carrier_date,
        NULLIF(order_delivered_customer_date, '')::TIMESTAMP    AS order_delivered_customer_date,
        NULLIF(order_estimated_delivery_date, '')::TIMESTAMP    AS order_estimated_delivery_date
    FROM bronze.erp_orders
    WHERE order_id IS NOT NULL;

    v_end_time := clock_timestamp();
    RAISE NOTICE '>> Load Duration: % seconds', EXTRACT(EPOCH FROM (v_end_time - v_start_time));
    RAISE NOTICE '>> -------------';

/* 
    -------------------------------------------------------------------------
    Table: silver.erp_order_items
    Transformations:
        - order_item_id cast to INTEGER
        - price and freight_value cast to DECIMAL
        - shipping_limit_date cast to TIMESTAMP
        - Null or empty prices flagged with NULL (not imputed)
    -------------------------------------------------------------------------
 */
    v_start_time := clock_timestamp();
    RAISE NOTICE '>> Truncating Table: silver.erp_order_items';
    TRUNCATE TABLE silver.erp_order_items;

    RAISE NOTICE '>> Inserting Data Into: silver.erp_order_items';
    INSERT INTO silver.erp_order_items (
        order_id,
        order_item_id,
        product_id,
        seller_id,
        shipping_limit_date,
        price,
        freight_value
    )
    SELECT
        order_id,
        order_item_id::INTEGER                          AS order_item_id,
        product_id,
        seller_id,
        shipping_limit_date::TIMESTAMP                  AS shipping_limit_date,
        CASE
            WHEN price IS NULL
                OR TRIM(price) = '' THEN NULL
            ELSE price::DECIMAL(10, 2)
        END                                             AS price,
        CASE
            WHEN freight_value IS NULL
                OR TRIM(freight_value) = '' THEN NULL
            ELSE freight_value::DECIMAL(10, 2)
        END                                             AS freight_value
    FROM bronze.erp_order_items
    WHERE order_id      IS NOT NULL
        AND order_item_id IS NOT NULL;

    v_end_time := clock_timestamp();
    RAISE NOTICE '>> Load Duration: % seconds', EXTRACT(EPOCH FROM (v_end_time - v_start_time));
    RAISE NOTICE '>> -------------';

/* 
    -------------------------------------------------------------------------
    Table: silver.erp_order_payments
    Transformations:
        - payment_sequential and payment_installments cast to INTEGER
        - payment_value cast to DECIMAL
        - payment_type standardized to lowercase and trimmed
    -------------------------------------------------------------------------
 */
    v_start_time := clock_timestamp();
    RAISE NOTICE '>> Truncating Table: silver.erp_order_payments';
    TRUNCATE TABLE silver.erp_order_payments;

    RAISE NOTICE '>> Inserting Data Into: silver.erp_order_payments';
    INSERT INTO silver.erp_order_payments (
        order_id,
        payment_sequential,
        payment_type,
        payment_installments,
        payment_value
    )
    SELECT
        order_id,
        payment_sequential::INTEGER         AS payment_sequential,
        LOWER(TRIM(payment_type))           AS payment_type,
        payment_installments::INTEGER       AS payment_installments,
        payment_value::DECIMAL(10, 2)       AS payment_value
    FROM bronze.erp_order_payments
    WHERE order_id           IS NOT NULL
        AND payment_sequential IS NOT NULL;

    v_end_time := clock_timestamp();
    RAISE NOTICE '>> Load Duration: % seconds', EXTRACT(EPOCH FROM (v_end_time - v_start_time));
    RAISE NOTICE '>> -------------';

/* 
    -------------------------------------------------------------------------
    Table: silver.erp_products
    Transformations:
        - Column name typos corrected (lenght -> length)
        - All numeric columns cast to INTEGER
        - product_category_name standardized to lowercase and trimmed
        - Empty strings converted to NULL across all nullable columns
    -------------------------------------------------------------------------
 */
    v_start_time := clock_timestamp();
    RAISE NOTICE '>> Truncating Table: silver.erp_products';
    TRUNCATE TABLE silver.erp_products;

    RAISE NOTICE '>> Inserting Data Into: silver.erp_products';
    INSERT INTO silver.erp_products (
        product_id,
        product_category_name,
        product_name_length,
        product_description_length,
        product_photos_qty,
        product_weight_g,
        product_length_cm,
        product_height_cm,
        product_width_cm
    )
    SELECT
        product_id,
        NULLIF(LOWER(TRIM(product_category_name)), '')  AS product_category_name,
        NULLIF(product_name_lenght, '')::INTEGER         AS product_name_length,
        NULLIF(product_description_lenght, '')::INTEGER  AS product_description_length,
        NULLIF(product_photos_qty, '')::INTEGER          AS product_photos_qty,
        NULLIF(product_weight_g, '')::INTEGER            AS product_weight_g,
        NULLIF(product_length_cm, '')::INTEGER           AS product_length_cm,
        NULLIF(product_height_cm, '')::INTEGER           AS product_height_cm,
        NULLIF(product_width_cm, '')::INTEGER            AS product_width_cm
    FROM bronze.erp_products
    WHERE product_id IS NOT NULL;

    v_end_time := clock_timestamp();
    RAISE NOTICE '>> Load Duration: % seconds', EXTRACT(EPOCH FROM (v_end_time - v_start_time));
    RAISE NOTICE '>> -------------';

/* 
    -------------------------------------------------------------------------
    Table: silver.erp_sellers
    Transformations:
        - TRIM + LOWER city names (same logic as crm_customers)
        - UPPER state abbreviations
        - LPAD zip code prefix to 5 chars
    -------------------------------------------------------------------------
 */
    v_start_time := clock_timestamp();
    RAISE NOTICE '>> Truncating Table: silver.erp_sellers';
    TRUNCATE TABLE silver.erp_sellers;

    RAISE NOTICE '>> Inserting Data Into: silver.erp_sellers';
    INSERT INTO silver.erp_sellers (
        seller_id,
        seller_zip_code_prefix,
        seller_city,
        seller_state
    )
    SELECT
        seller_id,
        LPAD(TRIM(seller_zip_code_prefix), 5, '0')  AS seller_zip_code_prefix,
        LOWER(TRIM(seller_city))                     AS seller_city,
        CASE
            WHEN TRIM(seller_state) IS NULL
                OR TRIM(seller_state) = '' THEN 'n/a'
            ELSE UPPER(TRIM(seller_state))
        END                                          AS seller_state
    FROM bronze.erp_sellers
    WHERE seller_id IS NOT NULL;

    v_end_time := clock_timestamp();
    RAISE NOTICE '>> Load Duration: % seconds', EXTRACT(EPOCH FROM (v_end_time - v_start_time));
    RAISE NOTICE '>> -------------';

/* 
    -------------------------------------------------------------------------
    Table: silver.erp_geolocation
    Transformations:
        - Deduplicated to one row per zip prefix using AVG lat/lng
        - Coordinates cast to DECIMAL, outliers outside Brazil filtered 
        Brazil bounds — lat: -34 to 5, lng: -74 to -28
        - city standardized to lowercase and trimmed
        - state standardized to uppercase
    -------------------------------------------------------------------------
 */
    v_start_time := clock_timestamp();
    RAISE NOTICE '>> Truncating Table: silver.erp_geolocation';
    TRUNCATE TABLE silver.erp_geolocation;

    RAISE NOTICE '>> Inserting Data Into: silver.erp_geolocation';
    INSERT INTO silver.erp_geolocation (
        geolocation_zip_code_prefix,
        geolocation_lat,
        geolocation_lng,
        geolocation_city,
        geolocation_state
    )
    SELECT
        LPAD(TRIM(geolocation_zip_code_prefix), 5, '0') AS geolocation_zip_code_prefix,
        ROUND(AVG(geolocation_lat::DECIMAL), 6)         AS geolocation_lat,
        ROUND(AVG(geolocation_lng::DECIMAL), 6)         AS geolocation_lng,
        LOWER(TRIM(MIN(geolocation_city)))              AS geolocation_city,
        UPPER(TRIM(MIN(geolocation_state)))             AS geolocation_state
    FROM bronze.erp_geolocation
    WHERE geolocation_lat::DECIMAL BETWEEN -34 AND 5
        AND geolocation_lng::DECIMAL BETWEEN -74 AND -28    -- Filter outliers outside Brazil
    GROUP BY TRIM(geolocation_zip_code_prefix);

    v_end_time := clock_timestamp();
    RAISE NOTICE '>> Load Duration: % seconds', EXTRACT(EPOCH FROM (v_end_time - v_start_time));
    RAISE NOTICE '>> -------------';

/* 
    -------------------------------------------------------------------------
    Table: silver.erp_product_category_translation
    Transformations:
        - Both columns standardized to lowercase and trimmed
        - Empty English translations converted to NULL
    -------------------------------------------------------------------------
 */
    v_start_time := clock_timestamp();
    RAISE NOTICE '>> Truncating Table: silver.erp_product_category_translation';
    TRUNCATE TABLE silver.erp_product_category_translation;

    RAISE NOTICE '>> Inserting Data Into: silver.erp_product_category_translation';
    INSERT INTO silver.erp_product_category_translation (
        product_category_name,
        product_category_name_english
    )
    SELECT
        LOWER(TRIM(product_category_name))                      AS product_category_name,
        NULLIF(LOWER(TRIM(product_category_name_english)), '')  AS product_category_name_english
    FROM bronze.erp_product_category_translation
    WHERE product_category_name IS NOT NULL;

    v_end_time := clock_timestamp();
    RAISE NOTICE '>> Load Duration: % seconds', EXTRACT(EPOCH FROM (v_end_time - v_start_time));
    RAISE NOTICE '>> -------------';


/* 
    =========================================================================
    Batch Summary
    =========================================================================
 */
    v_batch_end := clock_timestamp();
    RAISE NOTICE '================================================';
    RAISE NOTICE 'Loading Silver Layer is Completed';
    RAISE NOTICE '   - Total Load Duration: % seconds',
        EXTRACT(EPOCH FROM (v_batch_end - v_batch_start));
    RAISE NOTICE '================================================';

EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE '================================================';
    RAISE NOTICE 'ERROR OCCURRED DURING LOADING SILVER LAYER';
    RAISE NOTICE 'Error Message: %', SQLERRM;
    RAISE NOTICE 'Error Code:    %', SQLSTATE;
    RAISE NOTICE '================================================';
    RAISE;
END;
$$;

/* 
=============================================================================
Row Count Validation
=============================================================================
Run these queries after loading to verify row counts against Bronze
 */
SELECT 'crm_customers'                    AS table_name, COUNT(*) AS row_count FROM silver.crm_customers
UNION ALL
SELECT 'crm_order_reviews'                AS table_name, COUNT(*) AS row_count FROM silver.crm_order_reviews
UNION ALL
SELECT 'erp_orders'                       AS table_name, COUNT(*) AS row_count FROM silver.erp_orders
UNION ALL
SELECT 'erp_order_items'                  AS table_name, COUNT(*) AS row_count FROM silver.erp_order_items
UNION ALL
SELECT 'erp_order_payments'               AS table_name, COUNT(*) AS row_count FROM silver.erp_order_payments
UNION ALL
SELECT 'erp_products'                     AS table_name, COUNT(*) AS row_count FROM silver.erp_products
UNION ALL
SELECT 'erp_sellers'                      AS table_name, COUNT(*) AS row_count FROM silver.erp_sellers
UNION ALL
SELECT 'erp_geolocation'                  AS table_name, COUNT(*) AS row_count FROM silver.erp_geolocation
UNION ALL
SELECT 'erp_product_category_translation' AS table_name, COUNT(*) AS row_count FROM silver.erp_product_category_translation
ORDER BY table_name;

