/* 
=============================================================================
DDL Script: Create Silver Tables
=============================================================================
Script Purpose:
    This script creates tables in the 'silver' schema, dropping existing
    tables if they already exist.
    Run this script to re-define the DDL structure of Silver tables.

Warning:
    Running this script will drop and recreate all Silver tables.
    All existing data in the Silver schema will be lost.
    Run the load script after this to reload data.

Dependencies:
    Bronze tables must exist and be populated before running load_silver.sql

Usage:
    Run this script connected to the olist_dwh database in DBeaver
    or via: psql -U postgres -d olist_dwh -f scripts/silver/ddl_silver.sql
=============================================================================
 */


/* 
=============================================================================
CRM Source Tables
=============================================================================

-----------------------------------------------------------------------------
Table: silver.crm_customers
Source: bronze.crm_customers
Changes: data types cast, city/state standardized, zip padded to 5 chars
-----------------------------------------------------------------------------
 */
DROP TABLE IF EXISTS silver.crm_customers;

CREATE TABLE silver.crm_customers (
    customer_id               VARCHAR(32)  NOT NULL,
    customer_unique_id        VARCHAR(32)  NOT NULL,
    customer_zip_code_prefix  VARCHAR(5),
    customer_city             VARCHAR(100),
    customer_state            VARCHAR(2)
);

/* 
-----------------------------------------------------------------------------
Table: silver.crm_order_reviews
Source: bronze.crm_order_reviews
Changes: review_score cast to INTEGER, dates cast to TIMESTAMP,
        comment fields trimmed, nulls preserved
-----------------------------------------------------------------------------
 */
DROP TABLE IF EXISTS silver.crm_order_reviews;

CREATE TABLE silver.crm_order_reviews (
    review_id                 VARCHAR(32)  NOT NULL,
    order_id                  VARCHAR(32)  NOT NULL,
    review_score              INTEGER,
    review_comment_title      VARCHAR(100),
    review_comment_message    TEXT,
    review_creation_date      TIMESTAMP,
    review_answer_timestamp   TIMESTAMP
);


/* 
=============================================================================
ERP Source Tables
=============================================================================

-----------------------------------------------------------------------------
Table: silver.erp_orders
Source: bronze.erp_orders
Changes: all timestamp columns cast to TIMESTAMP, order_status standardized,
        delivery date nulls preserved and documented
-----------------------------------------------------------------------------
 */
DROP TABLE IF EXISTS silver.erp_orders;

CREATE TABLE silver.erp_orders (
    order_id                        VARCHAR(32)  NOT NULL,
    customer_id                     VARCHAR(32)  NOT NULL,
    order_status                    VARCHAR(20),
    order_purchase_timestamp        TIMESTAMP,
    order_approved_at               TIMESTAMP,
    order_delivered_carrier_date    TIMESTAMP,
    order_delivered_customer_date   TIMESTAMP,
    order_estimated_delivery_date   TIMESTAMP
);

/* -----------------------------------------------------------------------------
Table: silver.erp_order_items
Source: bronze.erp_order_items
Changes: order_item_id cast to INTEGER, price/freight cast to DECIMAL,
        shipping_limit_date cast to TIMESTAMP, null prices flagged
-----------------------------------------------------------------------------
 */
DROP TABLE IF EXISTS silver.erp_order_items;

CREATE TABLE silver.erp_order_items (
    order_id              VARCHAR(32)     NOT NULL,
    order_item_id         INTEGER         NOT NULL,
    product_id            VARCHAR(32),
    seller_id             VARCHAR(32),
    shipping_limit_date   TIMESTAMP,
    price                 DECIMAL(10, 2),
    freight_value         DECIMAL(10, 2)
);

/* 
-- -----------------------------------------------------------------------------
-- Table: silver.erp_order_payments
-- Source: bronze.erp_order_payments
-- Changes: payment_sequential and installments cast to INTEGER,
--          payment_value cast to DECIMAL, payment_type standardized
-- -----------------------------------------------------------------------------
 */
DROP TABLE IF EXISTS silver.erp_order_payments;

CREATE TABLE silver.erp_order_payments (
    order_id                VARCHAR(32)     NOT NULL,
    payment_sequential      INTEGER         NOT NULL,
    payment_type            VARCHAR(20),
    payment_installments    INTEGER,
    payment_value           DECIMAL(10, 2)
);

/* 
-----------------------------------------------------------------------------
Table: silver.erp_products
Source: bronze.erp_products
Changes: column name typos corrected (lenght -> length),
        numeric columns cast to INTEGER, category_name standardized
-----------------------------------------------------------------------------
 */
DROP TABLE IF EXISTS silver.erp_products;

CREATE TABLE silver.erp_products (
    product_id                    VARCHAR(32)  NOT NULL,
    product_category_name         VARCHAR(100),
    product_name_length           INTEGER,
    product_description_length    INTEGER,
    product_photos_qty            INTEGER,
    product_weight_g              INTEGER,
    product_length_cm             INTEGER,
    product_height_cm             INTEGER,
    product_width_cm              INTEGER
);

/* 
-- -----------------------------------------------------------------------------
-- Table: silver.erp_sellers
-- Source: bronze.erp_sellers
-- Changes: city/state standardized, zip padded to 5 chars
-- -----------------------------------------------------------------------------
 */
DROP TABLE IF EXISTS silver.erp_sellers;

CREATE TABLE silver.erp_sellers (
    seller_id                 VARCHAR(32)  NOT NULL,
    seller_zip_code_prefix    VARCHAR(5),
    seller_city               VARCHAR(100),
    seller_state              VARCHAR(2)
);

/* 
-- -----------------------------------------------------------------------------
-- Table: silver.erp_geolocation
-- Source: bronze.erp_geolocation
-- Changes: deduplicated to one row per zip prefix using AVG lat/lng,
--          coordinates cast to DECIMAL, outliers outside Brazil filtered,
--          city/state standardized
-- -----------------------------------------------------------------------------
 */
DROP TABLE IF EXISTS silver.erp_geolocation;

CREATE TABLE silver.erp_geolocation (
    geolocation_zip_code_prefix   VARCHAR(5)      NOT NULL,
    geolocation_lat               DECIMAL(9, 6),
    geolocation_lng               DECIMAL(9, 6),
    geolocation_city              VARCHAR(100),
    geolocation_state             VARCHAR(2)
);

/* 
-- -----------------------------------------------------------------------------
-- Table: silver.erp_product_category_translation
-- Source: bronze.erp_product_category_translation
-- Changes: both columns standardized to lowercase and trimmed
-- -----------------------------------------------------------------------------
 */
DROP TABLE IF EXISTS silver.erp_product_category_translation;

CREATE TABLE silver.erp_product_category_translation (
    product_category_name           VARCHAR(100)  NOT NULL,
    product_category_name_english   VARCHAR(100)
);


