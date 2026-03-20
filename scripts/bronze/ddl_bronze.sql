/*
=============================================================================
Bronze Layer: Table Creation
=============================================================================
Description:
    Creates all Bronze layer tables.
    All columns are stored as VARCHAR to preserve raw data integrity.

Usage:
    Run this script connected to the olist_dwh database in DBeaver
    or via: psql -U postgres -d olist_dwh -f scripts/bronze/load_bronze.sql

Notes:
    - All data types are VARCHAR in Bronze — casting happens in Silver
=============================================================================
*/

/* 
=============================================================================
1. CRM Sources
=============================================================================

-----------------------------------------------------------------------------
Table: bronze.crm_customers
-----------------------------------------------------------------------------
 */
DROP TABLE IF EXISTS bronze.crm_customers;

CREATE TABLE bronze.crm_customers (
    customer_id               VARCHAR,
    customer_unique_id        VARCHAR,
    customer_zip_code_prefix  VARCHAR,
    customer_city             VARCHAR,
    customer_state            VARCHAR
);

/* 
-----------------------------------------------------------------------------
Table: bronze.crm_order_reviews
-----------------------------------------------------------------------------
 */
DROP TABLE IF EXISTS bronze.crm_order_reviews;

CREATE TABLE bronze.crm_order_reviews (
    review_id                 VARCHAR,
    order_id                  VARCHAR,
    review_score              VARCHAR,
    review_comment_title      VARCHAR,
    review_comment_message    VARCHAR,
    review_creation_date      VARCHAR,
    review_answer_timestamp   VARCHAR
);

/* 

=============================================================================
2. ERP Sources
=============================================================================

-----------------------------------------------------------------------------
Table: bronze.erp_orders
-----------------------------------------------------------------------------
 */
DROP TABLE IF EXISTS bronze.erp_orders;

CREATE TABLE bronze.erp_orders (
    order_id                        VARCHAR,
    customer_id                     VARCHAR,
    order_status                    VARCHAR,
    order_purchase_timestamp        VARCHAR,
    order_approved_at               VARCHAR,
    order_delivered_carrier_date    VARCHAR,
    order_delivered_customer_date   VARCHAR,
    order_estimated_delivery_date   VARCHAR
);

/* 
-----------------------------------------------------------------------------
Table: bronze.erp_order_items
-----------------------------------------------------------------------------
 */
DROP TABLE IF EXISTS bronze.erp_order_items;

CREATE TABLE bronze.erp_order_items (
    order_id              VARCHAR,
    order_item_id         VARCHAR,
    product_id            VARCHAR,
    seller_id             VARCHAR,
    shipping_limit_date   VARCHAR,
    price                 VARCHAR,
    freight_value         VARCHAR
);

/* 
-----------------------------------------------------------------------------
Table: bronze.erp_order_payments
-----------------------------------------------------------------------------
 */
DROP TABLE IF EXISTS bronze.erp_order_payments;

CREATE TABLE bronze.erp_order_payments (
    order_id                VARCHAR,
    payment_sequential      VARCHAR,
    payment_type            VARCHAR,
    payment_installments    VARCHAR,
    payment_value           VARCHAR
);

/* 
-- -----------------------------------------------------------------------------
-- Table: bronze.erp_products
-- -----------------------------------------------------------------------------
 */
DROP TABLE IF EXISTS bronze.erp_products;

CREATE TABLE bronze.erp_products (
    product_id                    VARCHAR,
    product_category_name         VARCHAR,
    product_name_lenght           VARCHAR,
    product_description_lenght    VARCHAR,
    product_photos_qty            VARCHAR,
    product_weight_g              VARCHAR,
    product_length_cm             VARCHAR,
    product_height_cm             VARCHAR,
    product_width_cm              VARCHAR
);

/* 
-----------------------------------------------------------------------------
Table: bronze.erp_sellers
-----------------------------------------------------------------------------
 */
DROP TABLE IF EXISTS bronze.erp_sellers;

CREATE TABLE bronze.erp_sellers (
    seller_id                 VARCHAR,
    seller_zip_code_prefix    VARCHAR,
    seller_city               VARCHAR,
    seller_state              VARCHAR
);

/* 
-----------------------------------------------------------------------------
Table: bronze.erp_geolocation
-----------------------------------------------------------------------------
 */
DROP TABLE IF EXISTS bronze.erp_geolocation;

CREATE TABLE bronze.erp_geolocation (
    geolocation_zip_code_prefix   VARCHAR,
    geolocation_lat               VARCHAR,
    geolocation_lng               VARCHAR,
    geolocation_city              VARCHAR,
    geolocation_state             VARCHAR
);

/* 
-----------------------------------------------------------------------------
Table: bronze.erp_product_category_translation
-----------------------------------------------------------------------------
 */
DROP TABLE IF EXISTS bronze.erp_product_category_translation;

CREATE TABLE bronze.erp_product_category_translation (
    product_category_name           VARCHAR,
    product_category_name_english   VARCHAR
);
