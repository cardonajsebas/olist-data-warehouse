/* 
=============================================================================
Stored Procedure: Bronze Layer - Data Ingestion
=============================================================================
Description:
    Truncates and loads data into the 'bronze' schema from CSV files.
    This procedure handles all ERP and CRM sources except for reviews.
    No transformations are applied.

Source:      Olist Brazilian E-Commerce Dataset (Kaggle)
Target:      bronze schema in olist_dwh database
Load Type:   Full load - Truncate & Insert

Usage:
    CALL bronze.load_bronze();
    Run this script connected to the olist_dwh database in DBeaver
    or via: psql -U postgres -d olist_dwh -f scripts/bronze/load_bronze.sql

Notes:
    - Update the file paths in each COPY command to match your local setup
    - All data types are VARCHAR in Bronze — casting happens in Silver
=============================================================================
 */


CREATE OR REPLACE PROCEDURE bronze.load_bronze()
LANGUAGE plpgsql
AS $$
DECLARE
    v_start_time TIMESTAMP;
    v_end_time TIMESTAMP;
    v_batch_start_time TIMESTAMP;
    v_batch_end_time TIMESTAMP;
BEGIN
    v_batch_start_time := clock_timestamp();

    RAISE NOTICE '================================================';
    RAISE NOTICE 'Loading Bronze Layer';
    RAISE NOTICE '================================================';

    -----------------------------------------------------------------------------
    -- 1. CRM Sources
    -----------------------------------------------------------------------------
    RAISE NOTICE '------------------------------------------------';
    RAISE NOTICE 'Loading CRM Tables';
    RAISE NOTICE '------------------------------------------------';

    -- Table: bronze.crm_customers
    v_start_time := clock_timestamp();
    RAISE NOTICE '>> Truncating Table: bronze.crm_customers';
    TRUNCATE TABLE bronze.crm_customers;
    RAISE NOTICE '>> Inserting Data Into: bronze.crm_customers';
    COPY bronze.crm_customers
    FROM '/home/sebas_cardona/my_projects/olist-data-warehouse/datasets/crm/olist_customers_dataset.csv' 
    WITH (FORMAT CSV, HEADER, DELIMITER ',');
    v_end_time := clock_timestamp();
    RAISE NOTICE '>> Load Duration: % seconds', EXTRACT(EPOCH FROM (v_end_time - v_start_time));

    -----------------------------------------------------------------------------
    -- 2. ERP Sources
    -----------------------------------------------------------------------------
    RAISE NOTICE '------------------------------------------------';
    RAISE NOTICE 'Loading ERP Tables';
    RAISE NOTICE '------------------------------------------------';

    -- Table: bronze.erp_orders
    v_start_time := clock_timestamp();
    RAISE NOTICE '>> Truncating Table: bronze.erp_orders';
    TRUNCATE TABLE bronze.erp_orders;
    RAISE NOTICE '>> Inserting Data Into: bronze.erp_orders';
    COPY bronze.erp_orders
    FROM '/home/sebas_cardona/my_projects/olist-data-warehouse/datasets/erp/olist_orders_dataset.csv' 
    WITH (FORMAT CSV, HEADER, DELIMITER ',');
    v_end_time := clock_timestamp();
    RAISE NOTICE '>> Load Duration: % seconds', EXTRACT(EPOCH FROM (v_end_time - v_start_time));

    -- Table: bronze.erp_order_items
    v_start_time := clock_timestamp();
    RAISE NOTICE '>> Truncating Table: bronze.erp_order_items';
    TRUNCATE TABLE bronze.erp_order_items;
    RAISE NOTICE '>> Inserting Data Into: bronze.erp_order_items';
    COPY bronze.erp_order_items
    FROM '/home/sebas_cardona/my_projects/olist-data-warehouse/datasets/erp/olist_order_items_dataset.csv' 
    WITH (FORMAT CSV, HEADER, DELIMITER ',');
    v_end_time := clock_timestamp();
    RAISE NOTICE '>> Load Duration: % seconds', EXTRACT(EPOCH FROM (v_end_time - v_start_time));

    -- Table: bronze.erp_order_payments
    v_start_time := clock_timestamp();
    RAISE NOTICE '>> Truncating Table: bronze.erp_order_payments';
    TRUNCATE TABLE bronze.erp_order_payments;
    RAISE NOTICE '>> Inserting Data Into: bronze.erp_order_payments';
    COPY bronze.erp_order_payments
    FROM '/home/sebas_cardona/my_projects/olist-data-warehouse/datasets/erp/olist_order_payments_dataset.csv' 
    WITH (FORMAT CSV, HEADER, DELIMITER ',');
    v_end_time := clock_timestamp();
    RAISE NOTICE '>> Load Duration: % seconds', EXTRACT(EPOCH FROM (v_end_time - v_start_time));

    -- Table: bronze.erp_products
    v_start_time := clock_timestamp();
    RAISE NOTICE '>> Truncating Table: bronze.erp_products';
    TRUNCATE TABLE bronze.erp_products;
    RAISE NOTICE '>> Inserting Data Into: bronze.erp_products';
    COPY bronze.erp_products
    FROM '/home/sebas_cardona/my_projects/olist-data-warehouse/datasets/erp/olist_products_dataset.csv' 
    WITH (FORMAT CSV, HEADER, DELIMITER ',');
    v_end_time := clock_timestamp();
    RAISE NOTICE '>> Load Duration: % seconds', EXTRACT(EPOCH FROM (v_end_time - v_start_time));

    -- Table: bronze.erp_sellers
    v_start_time := clock_timestamp();
    RAISE NOTICE '>> Truncating Table: bronze.erp_sellers';
    TRUNCATE TABLE bronze.erp_sellers;
    RAISE NOTICE '>> Inserting Data Into: bronze.erp_sellers';
    COPY bronze.erp_sellers
    FROM '/home/sebas_cardona/my_projects/olist-data-warehouse/datasets/erp/olist_sellers_dataset.csv' 
    WITH (FORMAT CSV, HEADER, DELIMITER ',');
    v_end_time := clock_timestamp();
    RAISE NOTICE '>> Load Duration: % seconds', EXTRACT(EPOCH FROM (v_end_time - v_start_time));

    -- Table: bronze.erp_geolocation
    v_start_time := clock_timestamp();
    RAISE NOTICE '>> Truncating Table: bronze.erp_geolocation';
    TRUNCATE TABLE bronze.erp_geolocation;
    RAISE NOTICE '>> Inserting Data Into: bronze.erp_geolocation';
    COPY bronze.erp_geolocation
    FROM '/home/sebas_cardona/my_projects/olist-data-warehouse/datasets/erp/olist_geolocation_dataset.csv' 
    WITH (FORMAT CSV, HEADER, DELIMITER ',');
    v_end_time := clock_timestamp();
    RAISE NOTICE '>> Load Duration: % seconds', EXTRACT(EPOCH FROM (v_end_time - v_start_time));

    -- Table: bronze.erp_product_category_translation
    v_start_time := clock_timestamp();
    RAISE NOTICE '>> Truncating Table: bronze.erp_product_category_translation';
    TRUNCATE TABLE bronze.erp_product_category_translation;
    RAISE NOTICE '>> Inserting Data Into: bronze.erp_product_category_translation';
    COPY bronze.erp_product_category_translation
    FROM '/home/sebas_cardona/my_projects/olist-data-warehouse/datasets/erp/product_category_name_translation.csv' 
    WITH (FORMAT CSV, HEADER, DELIMITER ',');
    v_end_time := clock_timestamp();
    RAISE NOTICE '>> Load Duration: % seconds', EXTRACT(EPOCH FROM (v_end_time - v_start_time));

    v_batch_end_time := clock_timestamp();
    RAISE NOTICE '================================================';
    RAISE NOTICE 'Loading Bronze Layer is Completed';
    RAISE NOTICE '   - Total Load Duration: % seconds', EXTRACT(EPOCH FROM (v_batch_end_time - v_batch_start_time));
    RAISE NOTICE '================================================';

EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE '================================================';
    RAISE NOTICE 'ERROR OCCURRED DURING LOADING BRONZE LAYER';
    RAISE NOTICE 'Error Message: %', SQLERRM;
    RAISE NOTICE 'Error Code: %', SQLSTATE;
    RAISE NOTICE '================================================';
END;
$$;

/* 
=============================================================================
Row Count Validation
=============================================================================
Run these queries after loading to verify row counts match source CSVs
 */
SELECT 'crm_customers'                  AS table_name, COUNT(*) AS row_count FROM bronze.crm_customers
UNION ALL
SELECT 'crm_order_reviews'              AS table_name, COUNT(*) AS row_count FROM bronze.crm_order_reviews
UNION ALL
SELECT 'erp_orders'                     AS table_name, COUNT(*) AS row_count FROM bronze.erp_orders
UNION ALL
SELECT 'erp_order_items'                AS table_name, COUNT(*) AS row_count FROM bronze.erp_order_items
UNION ALL
SELECT 'erp_order_payments'             AS table_name, COUNT(*) AS row_count FROM bronze.erp_order_payments
UNION ALL
SELECT 'erp_products'                   AS table_name, COUNT(*) AS row_count FROM bronze.erp_products
UNION ALL
SELECT 'erp_sellers'                    AS table_name, COUNT(*) AS row_count FROM bronze.erp_sellers
UNION ALL
SELECT 'erp_geolocation'                AS table_name, COUNT(*) AS row_count FROM bronze.erp_geolocation
UNION ALL
SELECT 'erp_product_category_translation' AS table_name, COUNT(*) AS row_count FROM bronze.erp_product_category_translation
ORDER BY table_name;
