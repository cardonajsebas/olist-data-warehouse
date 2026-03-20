/* 
=============================================================================
Gold Layer: Dimension and Fact Views
=============================================================================
Script Purpose:
    Creates all Gold layer views implementing the Star Schema.
    Views are derived directly from Silver tables, no physical data is loaded into Gold. All views reflect the latest Silver data at query time.

Objects created:
    Dimensions: gold.dim_customers, gold.dim_products,
                gold.dim_sellers,   gold.dim_date
    Facts:      gold.fact_orders

Usage:
    Run this script connected to the olist_dwh database in DBeaver
    or via: psql -U postgres -d olist_dwh -f scripts/gold/load_gold.sql
=============================================================================
 */

/* 
=============================================================================
DIMENSION VIEWS
=============================================================================
 */

/* 
-----------------------------------------------------------------------------
View: gold.dim_customers
-----------------------------------------------------------------------------
Description:
    Customer dimension enriched with geolocation data.
    Joins crm_customers with erp_geolocation on zip_code_prefix to add geographic coordinates to each customer record.

Grain: one row per unique customer (customer_unique_id)
Surrogate key: customer_key generated via ROW_NUMBER()

Source tables:
    silver.crm_customers
    silver.erp_geolocation
-----------------------------------------------------------------------------
 */
DROP VIEW IF EXISTS gold.dim_customers;

CREATE VIEW gold.dim_customers AS
SELECT
    ROW_NUMBER() OVER (ORDER BY c.customer_unique_id) AS customer_key,
    c.customer_id,
    c.customer_unique_id,
    c.customer_zip_code_prefix,
    c.customer_city,
    c.customer_state,
    g.geolocation_lat                                 AS customer_lat,
    g.geolocation_lng                                 AS customer_lng
FROM silver.crm_customers c
LEFT JOIN silver.erp_geolocation g
    ON c.customer_zip_code_prefix = g.geolocation_zip_code_prefix;


/* 
-----------------------------------------------------------------------------
View: gold.dim_products
-----------------------------------------------------------------------------
Description:
    Product dimension enriched with English category names.
    Joins erp_products with erp_product_category_translation to replace
    Portuguese category names with their English equivalents.

Grain: one row per product
Surrogate key: product_key generated via ROW_NUMBER()

Source tables:
    silver.erp_products
    silver.erp_product_category_translation
-----------------------------------------------------------------------------
 */
DROP VIEW IF EXISTS gold.dim_products;

CREATE VIEW gold.dim_products AS
SELECT
    ROW_NUMBER() OVER (ORDER BY p.product_id)            AS product_key,
    p.product_id,
    COALESCE(t.product_category_name_english, 'unknown') AS product_category,
    p.product_name_length,
    p.product_description_length,
    p.product_photos_qty,
    p.product_weight_g,
    p.product_length_cm,
    p.product_height_cm,
    p.product_width_cm
FROM silver.erp_products p
LEFT JOIN silver.erp_product_category_translation t
    ON p.product_category_name = t.product_category_name;


/* 
-----------------------------------------------------------------------------
View: gold.dim_sellers
-----------------------------------------------------------------------------
Description:
    Seller dimension enriched with geolocation data.
    Joins erp_sellers with erp_geolocation on zip_code_prefix to add
    geographic coordinates to each seller record.

Grain: one row per seller
Surrogate key: seller_key generated via ROW_NUMBER()

Source tables:
    silver.erp_sellers
    silver.erp_geolocation
-----------------------------------------------------------------------------
 */
DROP VIEW IF EXISTS gold.dim_sellers;

CREATE VIEW gold.dim_sellers AS
SELECT
    ROW_NUMBER() OVER (ORDER BY s.seller_id)    AS seller_key,
    s.seller_id,
    s.seller_zip_code_prefix,
    s.seller_city,
    s.seller_state,
    g.geolocation_lat                           AS seller_lat,
    g.geolocation_lng                           AS seller_lng
FROM silver.erp_sellers s
LEFT JOIN silver.erp_geolocation g
    ON s.seller_zip_code_prefix = g.geolocation_zip_code_prefix;


/* 
-----------------------------------------------------------------------------
View: gold.dim_date
-----------------------------------------------------------------------------
Description:
    Date dimension derived from order purchase timestamps in erp_orders.
    Generates one row per distinct date with useful time attributes for
    analytical queries — year, quarter, month, week, day of week.

Grain: one row per distinct calendar date present in the orders data
Surrogate key: date_key in YYYYMMDD integer format (e.g. 20180115)

Source tables:
    silver.erp_orders
-----------------------------------------------------------------------------
 */
DROP VIEW IF EXISTS gold.dim_date;

CREATE VIEW gold.dim_date AS
SELECT
    TO_CHAR(d.order_date, 'YYYYMMDD')::INTEGER     AS date_key,
    d.order_date                                   AS full_date,
    EXTRACT(YEAR FROM d.order_date)::INTEGER       AS year,
    EXTRACT(QUARTER FROM d.order_date)::INTEGER    AS quarter,
    EXTRACT(MONTH FROM d.order_date)::INTEGER      AS month,
    TO_CHAR(d.order_date, 'Month')                 AS month_name,
    EXTRACT(WEEK FROM d.order_date)::INTEGER       AS week_of_year,
    EXTRACT(DOW FROM d.order_date)::INTEGER        AS day_of_week,
    TO_CHAR(d.order_date, 'Day')                   AS day_name,
    CASE
        WHEN EXTRACT(DOW FROM d.order_date) IN (0, 6)
            THEN TRUE
        ELSE FALSE
    END                                            AS is_weekend
FROM (
    SELECT DISTINCT
        order_purchase_timestamp::DATE AS order_date
    FROM silver.erp_orders
    WHERE order_purchase_timestamp IS NOT NULL
) d;


/* 
=============================================================================
FACT VIEW
=============================================================================

-----------------------------------------------------------------------------
View: gold.fact_orders
-----------------------------------------------------------------------------
Description:
    Central fact view for order-item level analysis.
    Integrates erp_orders, erp_order_items, erp_order_payments and
    crm_order_reviews into a single denormalized analytical view.
    Joins to all four dimension views via surrogate keys.

Grain: one row per order item (order_id + order_item_id)

Measures:
    price            — item price in BRL
    freight_value    — shipping cost in BRL
    total_amount     — price + freight_value
    payment_value    — total payment value for the order
    review_score     — customer satisfaction score (1-5)

Source tables:
    silver.erp_orders
    silver.erp_order_items
    silver.erp_order_payments
    silver.crm_order_reviews

Dimension joins:
    gold.dim_customers  via customer_unique_id
    gold.dim_products   via product_id
    gold.dim_sellers    via seller_id
    gold.dim_date       via order purchase date
-----------------------------------------------------------------------------
 */
DROP VIEW IF EXISTS gold.fact_orders;

CREATE VIEW gold.fact_orders AS
SELECT
    -- Keys
    oi.order_id,
    oi.order_item_id,
    dc.customer_key,
    dp.product_key,
    ds.seller_key,
    dd.date_key,

    -- Order attributes
    o.order_status,
    o.order_purchase_timestamp,
    o.order_approved_at,
    o.order_delivered_carrier_date,
    o.order_delivered_customer_date,
    o.order_estimated_delivery_date,

    -- Delivery performance
    CASE
        WHEN o.order_status = 'delivered'
        AND o.order_delivered_customer_date IS NOT NULL
        AND o.order_estimated_delivery_date IS NOT NULL
            THEN EXTRACT(
                    DAY FROM (
                        o.order_delivered_customer_date
                        - o.order_estimated_delivery_date
                    )
                )::INTEGER
        ELSE NULL
    END             AS delivery_delay_days,

    CASE
        WHEN o.order_status = 'delivered'
        AND o.order_delivered_customer_date IS NOT NULL
        AND o.order_estimated_delivery_date IS NOT NULL
            THEN o.order_delivered_customer_date
                <= o.order_estimated_delivery_date
        ELSE NULL
    END             AS is_on_time,

    -- Financial measures
    oi.price,
    oi.freight_value,
    oi.price + COALESCE(oi.freight_value, 0)    AS total_amount,
    pay.payment_value,
    pay.payment_type,
    pay.payment_installments,

    -- Review
    r.review_score,
    r.review_creation_date

FROM silver.erp_order_items oi

-- Core order attributes
INNER JOIN silver.erp_orders o
    ON oi.order_id = o.order_id

-- Customer dimension
LEFT JOIN gold.dim_customers dc
    ON o.customer_id = dc.customer_id

-- Product dimension
LEFT JOIN gold.dim_products dp
    ON oi.product_id = dp.product_id

-- Seller dimension
LEFT JOIN gold.dim_sellers ds
    ON oi.seller_id = ds.seller_id

-- Date dimension
LEFT JOIN gold.dim_date dd
    ON o.order_purchase_timestamp::DATE = dd.full_date

-- Payments — aggregated to order level to avoid fan-out
LEFT JOIN (
    SELECT
        order_id,
        SUM(payment_value)          AS payment_value,
        MAX(payment_type)           AS payment_type,
        MAX(payment_installments)   AS payment_installments
    FROM silver.erp_order_payments
    GROUP BY order_id
) pay ON oi.order_id = pay.order_id

-- Reviews
LEFT JOIN silver.crm_order_reviews r
    ON oi.order_id = r.order_id;
