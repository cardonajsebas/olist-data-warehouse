# Data Catalog

## Overview

This catalog documents all tables and views across the three layers of the Olist Data Warehouse. It serves as the single reference for understanding the raw data, transformation decisions, and analytical models built on top of it.

- **Source:** [Kaggle — Olist Brazilian E-Commerce](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce)
- **Database:** `olist_dwh` (PostgreSQL)
- **Architecture:** Medallion — Bronze / Silver / Gold
- **Coverage:** ~100,000 orders · 2016–2018 · Brazil

---

## Table of Contents

1. [Bronze Layer — Raw Ingestion](#bronze-layer--raw-ingestion)
2. [Silver Layer — Cleaning & Standardization](#silver-layer--cleaning--standardization)
3. [Gold Layer — Analytical Views](#gold-layer--analytical-views)
4. [Known Data Quality Issues](#known-data-quality-issues)

---

# Bronze Layer — Raw Ingestion

All source CSV files are loaded as-is into the Bronze schema with no transformations applied. All columns are stored as `VARCHAR` regardless of their original data type — casting happens in Silver.

- **Object type:** Tables
- **Load strategy:** Full load — Truncate & Insert
- **Schema:** `bronze`

## Table Index

| # | Table Name | Source CSV | Row Count |
|---|---|---|---|
| 1 | [crm_customers](#bronzecrm_customers) | `olist_customers_dataset.csv` | 99,441 |
| 2 | [crm_order_reviews](#bronzecrm_order_reviews) | `olist_order_reviews_dataset.csv` | 99,224 |
| 3 | [erp_orders](#bronzeerp_orders) | `olist_orders_dataset.csv` | 99,441 |
| 4 | [erp_order_items](#bronzeerp_order_items) | `olist_order_items_dataset.csv` | 112,650 |
| 5 | [erp_order_payments](#bronzeerp_order_payments) | `olist_order_payments_dataset.csv` | 103,886 |
| 6 | [erp_products](#bronzeerp_products) | `olist_products_dataset.csv` | 32,951 |
| 7 | [erp_sellers](#bronzeerp_sellers) | `olist_sellers_dataset.csv` | 3,095 |
| 8 | [erp_geolocation](#bronzeerp_geolocation) | `olist_geolocation_dataset.csv` | 1,000,163 |
| 9 | [erp_product_category_translation](#bronzeerp_product_category_translation) | `product_category_name_translation.csv` | 71 |

---

## Bronze Table Details

---

### bronze.crm_customers

**Description:** Raw customer data from the CRM source. Each row represents a unique customer record linked to an order. The same physical customer may appear multiple times with different `customer_id` values across orders.

**Grain:** One row per customer per order.

**Primary Key:** `customer_id`

| Column | Data Type | Nullable | Description |
|---|---|---|---|
| `customer_id` | VARCHAR | No | Unique identifier per order (not per physical customer) |
| `customer_unique_id` | VARCHAR | No | Identifier for the actual physical customer across orders |
| `customer_zip_code_prefix` | VARCHAR | No | First 5 digits of the customer's ZIP code |
| `customer_city` | VARCHAR | No | Customer city name |
| `customer_state` | VARCHAR | No | Customer state abbreviation (e.g. SP, RJ) |

> All columns stored as VARCHAR in Bronze — types are cast in Silver.

**Notes:**
- Use `customer_unique_id` for customer-level analysis (repeat purchases, lifetime value)
- Use `customer_id` only for order-level joins
- City names have encoding issues and inconsistent casing — standardized in Silver

---

### bronze.crm_order_reviews

**Description:** Raw customer satisfaction reviews submitted after delivery. Each order can have one review.

**Grain:** One row per review.

**Primary Key:** `review_id`

| Column | Data Type | Nullable | Description |
|---|---|---|---|
| `review_id` | VARCHAR | No | Unique identifier for the review |
| `order_id` | VARCHAR | No | Foreign key to `erp_orders` |
| `review_score` | VARCHAR | No | Customer rating from 1 (worst) to 5 (best) |
| `review_comment_title` | VARCHAR | Yes | Optional review title written by the customer |
| `review_comment_message` | VARCHAR | Yes | Optional review body written by the customer |
| `review_creation_date` | VARCHAR | No | Date the review survey was sent to the customer |
| `review_answer_timestamp` | VARCHAR | Yes | Date and time the customer submitted the review |

> All columns stored as VARCHAR in Bronze — types are cast in Silver.

**Notes:**
- Review comments are in Portuguese
- High null rate expected on `review_comment_title` and `review_comment_message` — most customers only submit a score
- Comment fields contain commas, line breaks and special characters causing CSV parsing issues — loaded via Python script (`import_reviews.py`)
- Sentiment analysis possible on comment fields (Phase 2 / ML use case)

---

### bronze.erp_orders

**Description:** Raw core order records from the ERP source. Central table of the data model — connects to most other tables via `order_id`.

**Grain:** One row per order.

**Primary Key:** `order_id`

| Column | Data Type | Nullable | Description |
|---|---|---|---|
| `order_id` | VARCHAR | No | Unique identifier for the order |
| `customer_id` | VARCHAR | No | Foreign key to `crm_customers` |
| `order_status` | VARCHAR | No | Order lifecycle status (e.g. delivered, shipped, canceled) |
| `order_purchase_timestamp` | VARCHAR | No | Date and time the order was placed |
| `order_approved_at` | VARCHAR | Yes | Date and time the payment was approved |
| `order_delivered_carrier_date` | VARCHAR | Yes | Date the order was handed to the carrier |
| `order_delivered_customer_date` | VARCHAR | Yes | Date the order was delivered to the customer |
| `order_estimated_delivery_date` | VARCHAR | No | Estimated delivery date shown to the customer at purchase |

> All columns stored as VARCHAR in Bronze — types are cast in Silver.

**Notes:**
- `order_status` values include: `delivered`, `shipped`, `canceled`, `unavailable`, `invoiced`, `processing`, `created`, `approved`
- Delivery timestamp columns are nullable — expected for canceled or undelivered orders
- Delivery delay can be derived in Gold by comparing `order_delivered_customer_date` vs `order_estimated_delivery_date`

---

### bronze.erp_order_items

**Description:** Raw line items per order. An order can have multiple items, potentially from different sellers.

**Grain:** One row per item per order.

**Primary Key:** `order_id` + `order_item_id`

| Column | Data Type | Nullable | Description |
|---|---|---|---|
| `order_id` | VARCHAR | No | Foreign key to `erp_orders` |
| `order_item_id` | VARCHAR | No | Sequential item number within the order (1, 2, 3...) |
| `product_id` | VARCHAR | No | Foreign key to `erp_products` |
| `seller_id` | VARCHAR | No | Foreign key to `erp_sellers` |
| `shipping_limit_date` | VARCHAR | No | Seller's deadline to hand the item to the carrier |
| `price` | VARCHAR | No | Item price in BRL |
| `freight_value` | VARCHAR | No | Freight cost for this item in BRL |

> All columns stored as VARCHAR in Bronze — types are cast in Silver.

**Notes:**
- Total order value = SUM of `price` + `freight_value` across all items in the order
- A single order can involve multiple sellers (marketplace model)

---

### bronze.erp_order_payments

**Description:** Raw payment information per order. An order can have multiple payment entries if the customer split the payment across methods.

**Grain:** One row per payment method per order.

**Primary Key:** `order_id` + `payment_sequential`

| Column | Data Type | Nullable | Description |
|---|---|---|---|
| `order_id` | VARCHAR | No | Foreign key to `erp_orders` |
| `payment_sequential` | VARCHAR | No | Sequence number when multiple payment methods are used |
| `payment_type` | VARCHAR | No | Payment method (credit_card, boleto, voucher, debit_card) |
| `payment_installments` | VARCHAR | No | Number of installments chosen by the customer |
| `payment_value` | VARCHAR | No | Transaction value in BRL |

> All columns stored as VARCHAR in Bronze — types are cast in Silver.

**Notes:**
- `boleto` is a Brazilian cash payment slip — common in Brazilian e-commerce
- Customers can pay with voucher + credit card simultaneously, resulting in 2 rows per order
- `payment_installments` = 1 means paid in full (no installments)

---

### bronze.erp_products

**Description:** Raw product attributes for items sold on the Olist marketplace.

**Grain:** One row per product.

**Primary Key:** `product_id`

| Column | Data Type | Nullable | Description |
|---|---|---|---|
| `product_id` | VARCHAR | No | Unique product identifier |
| `product_category_name` | VARCHAR | Yes | Product category name in Portuguese |
| `product_name_lenght` | VARCHAR | Yes | Character length of the product name |
| `product_description_lenght` | VARCHAR | Yes | Character length of the product description |
| `product_photos_qty` | VARCHAR | Yes | Number of photos published for the product |
| `product_weight_g` | VARCHAR | Yes | Product weight in grams |
| `product_length_cm` | VARCHAR | Yes | Product length in centimeters |
| `product_height_cm` | VARCHAR | Yes | Product height in centimeters |
| `product_width_cm` | VARCHAR | Yes | Product width in centimeters |

> All columns stored as VARCHAR in Bronze — types are cast in Silver.

**Notes:**
- `product_category_name` is in Portuguese — joined with `erp_product_category_translation` for English names in Gold
- Column names contain source typos (`lenght` instead of `length`) — preserved as-is in Bronze, corrected in Silver
- High null rate across dimension columns — flagged and preserved in Silver

---

### bronze.erp_sellers

**Description:** Raw seller information for merchants operating on the Olist marketplace.

**Grain:** One row per seller.

**Primary Key:** `seller_id`

| Column | Data Type | Nullable | Description |
|---|---|---|---|
| `seller_id` | VARCHAR | No | Unique seller identifier |
| `seller_zip_code_prefix` | VARCHAR | No | First 5 digits of the seller's ZIP code |
| `seller_city` | VARCHAR | No | Seller city name |
| `seller_state` | VARCHAR | No | Seller state abbreviation (e.g. SP, RJ) |

> All columns stored as VARCHAR in Bronze — types are cast in Silver.

**Notes:**
- City names have the same encoding/casing inconsistencies as `crm_customers` — standardized in Silver
- Seller geographic distribution is heavily concentrated in São Paulo state

---

### bronze.erp_geolocation

**Description:** Raw geolocation data mapping Brazilian ZIP code prefixes to geographic coordinates.

**Grain:** Multiple rows per ZIP code prefix — several lat/lng entries per ZIP by design.

**Primary Key:** None (duplicates expected by design)

| Column | Data Type | Nullable | Description |
|---|---|---|---|
| `geolocation_zip_code_prefix` | VARCHAR | No | First 5 digits of the ZIP code |
| `geolocation_lat` | VARCHAR | No | Latitude coordinate |
| `geolocation_lng` | VARCHAR | No | Longitude coordinate |
| `geolocation_city` | VARCHAR | No | City name |
| `geolocation_state` | VARCHAR | No | State abbreviation |

> All columns stored as VARCHAR in Bronze — types are cast in Silver.

**Notes:**
- Largest table in the dataset (~1M rows) due to multiple coordinates per ZIP prefix
- Deduplicated in Silver using AVG lat/lng per ZIP prefix (~1M → ~19k rows)
- Contains outlier coordinates outside Brazil bounds — filtered in Silver

---

### bronze.erp_product_category_translation

**Description:** Raw lookup table mapping Portuguese product category names to English equivalents.

**Grain:** One row per category.

**Primary Key:** `product_category_name`

| Column | Data Type | Nullable | Description |
|---|---|---|---|
| `product_category_name` | VARCHAR | No | Category name in Portuguese |
| `product_category_name_english` | VARCHAR | No | Category name translated to English |

> All columns stored as VARCHAR in Bronze — types are cast in Silver.

**Notes:**
- Small reference table (71 rows)
- Some categories in `erp_products` may not have a matching translation — handled with null-safe join in Gold

---

# Silver Layer — Cleaning & Standardization

Silver tables are cleaned and standardized versions of their Bronze counterparts. All columns are cast to proper data types. No joins or business logic are applied — Silver maintains a 1:1 relationship with Bronze tables.

- **Object type:** Tables
- **Load strategy:** Full load — Truncate & Insert
- **Schema:** `silver`

## Row Count Summary — Bronze vs Silver

| Table | Bronze Rows | Silver Rows | Notes |
|---|---|---|---|
| `crm_customers` | 99,441 | 99,441 | No row reduction |
| `crm_order_reviews` | 99,224 | 99,224 | No row reduction |
| `erp_orders` | 99,441 | 99,441 | No row reduction |
| `erp_order_items` | 112,650 | 112,650 | No row reduction |
| `erp_order_payments` | 103,886 | 103,886 | No row reduction |
| `erp_products` | 32,951 | 32,951 | No row reduction |
| `erp_sellers` | 3,095 | 3,095 | No row reduction |
| `erp_geolocation` | 1,000,163 | ~19,000 | Deduplicated to one row per ZIP prefix |
| `erp_product_category_translation` | 71 | 71 | No row reduction |

## Transformations Applied

| Area | Transformation |
|---|---|
| Data types | All columns cast to proper types (TIMESTAMP, DECIMAL, INTEGER, VARCHAR with length) |
| String standardization | City names lowercased and trimmed, state codes uppercased |
| ZIP codes | Padded to 5 characters using `LPAD` across customers, sellers and geolocation |
| Column renames | Typos corrected in `erp_products` (`lenght` → `length`) |
| Null handling | Empty strings converted to NULL via `NULLIF`, delivery date nulls preserved intentionally |
| Deduplication | `erp_geolocation` reduced from ~1M to ~19k rows using `AVG` lat/lng per ZIP prefix |
| Outlier filtering | Geolocation coordinates outside Brazil bounds removed (lat: -34 to 5, lng: -74 to -28) |
| Score validation | `review_score` validated to range 1–5, out-of-range values set to NULL |

---

# Gold Layer — Analytical Views

The Gold layer implements a Star Schema optimized for business reporting and ad-hoc SQL analysis. All Gold objects are **views** derived directly from Silver tables — no physical data is loaded into Gold.

- **Object type:** Views (no physical load)
- **Load strategy:** None — derived from Silver at query time
- **Schema:** `gold`
- **Model:** Star Schema
- **Grain:** One row per order item (`order_id` + `order_item_id`)

## Star Schema Overview

```
                            dim_customers
                                  |
             dim_products ── fact_orders ── dim_sellers
                                  |
                               dim_date
```

| View | Type | Grain | Source Tables |
|---|---|---|---|
| `dim_customers` | Dimension | One row per customer record | `crm_customers`, `erp_geolocation` |
| `dim_products` | Dimension | One row per product | `erp_products`, `erp_product_category_translation` |
| `dim_sellers` | Dimension | One row per seller | `erp_sellers`, `erp_geolocation` |
| `dim_date` | Dimension | One row per calendar date | `erp_orders` (derived) |
| `fact_orders` | Fact | One row per order item | `erp_orders`, `erp_order_items`, `erp_order_payments`, `crm_order_reviews` |

---

## Dimension Views

---

### gold.dim_customers

**Description:** Customer dimension enriched with geolocation data. Each row represents a unique customer record linked to an order. Note that the same physical customer may appear multiple times with different `customer_id` values — use `customer_unique_id` for customer-level analysis.

**Surrogate Key:** `customer_key`
**Natural Key:** `customer_id`

| Column | Data Type | Description |
|---|---|---|
| `customer_key` | INTEGER | Surrogate key — system generated via ROW_NUMBER() |
| `customer_id` | VARCHAR | Order-level customer identifier — use for joins to fact |
| `customer_unique_id` | VARCHAR | Physical customer identifier — use for repeat purchase analysis |
| `customer_zip_code_prefix` | VARCHAR(5) | 5-digit ZIP code prefix |
| `customer_city` | VARCHAR | Customer city (lowercase, standardized) |
| `customer_state` | VARCHAR(2) | Customer state abbreviation (uppercase) |
| `customer_lat` | DECIMAL | Latitude coordinate from geolocation lookup |
| `customer_lng` | DECIMAL | Longitude coordinate from geolocation lookup |

**Notes:**
- `customer_lat` and `customer_lng` derived from `erp_geolocation` via ZIP prefix join — may be NULL if ZIP has no geolocation match
- Use `customer_unique_id` to identify repeat customers across multiple orders

---

### gold.dim_products

**Description:** Product dimension enriched with English category names. Portuguese category names from the source are replaced with English equivalents via the translation lookup. Products without a matching translation default to `'unknown'`.

**Surrogate Key:** `product_key`
**Natural Key:** `product_id`

| Column | Data Type | Description |
|---|---|---|
| `product_key` | INTEGER | Surrogate key — system generated via ROW_NUMBER() |
| `product_id` | VARCHAR | Original product identifier from source |
| `product_category` | VARCHAR | English category name (defaults to `'unknown'` if no translation) |
| `product_name_length` | INTEGER | Character length of product name |
| `product_description_length` | INTEGER | Character length of product description |
| `product_photos_qty` | INTEGER | Number of product photos published |
| `product_weight_g` | INTEGER | Product weight in grams |
| `product_length_cm` | INTEGER | Product length in centimeters |
| `product_height_cm` | INTEGER | Product height in centimeters |
| `product_width_cm` | INTEGER | Product width in centimeters |

**Notes:**
- Column name typos from source (`lenght`) corrected in Silver — Gold uses the correct spelling
- Physical dimension columns enable logistics and shipping cost analysis
- `product_category` shows `'unknown'` for ~600 products with no category in source

---

### gold.dim_sellers

**Description:** Seller dimension enriched with geolocation data. Represents merchants operating on the Olist marketplace. Geographic distribution is heavily concentrated in São Paulo state.

**Surrogate Key:** `seller_key`
**Natural Key:** `seller_id`

| Column | Data Type | Description |
|---|---|---|
| `seller_key` | INTEGER | Surrogate key — system generated via ROW_NUMBER() |
| `seller_id` | VARCHAR | Original seller identifier from source |
| `seller_zip_code_prefix` | VARCHAR(5) | 5-digit ZIP code prefix |
| `seller_city` | VARCHAR | Seller city (lowercase, standardized) |
| `seller_state` | VARCHAR(2) | Seller state abbreviation (uppercase) |
| `seller_lat` | DECIMAL | Latitude coordinate from geolocation lookup |
| `seller_lng` | DECIMAL | Longitude coordinate from geolocation lookup |

**Notes:**
- `seller_lat` and `seller_lng` derived from `erp_geolocation` via ZIP prefix join — may be NULL if ZIP has no geolocation match
- Geographic coordinates enable seller-to-customer distance calculations

---

### gold.dim_date

**Description:** Date dimension derived from order purchase timestamps. Contains one row per distinct calendar date present in the orders dataset. Covers the period 2016–2018 aligned with the Olist dataset coverage.

**Surrogate Key:** `date_key` (YYYYMMDD integer format, e.g. 20180115)
**Natural Key:** `full_date`

| Column | Data Type | Description |
|---|---|---|
| `date_key` | INTEGER | Surrogate key in YYYYMMDD format (e.g. 20180115) |
| `full_date` | DATE | Calendar date |
| `year` | INTEGER | Year (e.g. 2018) |
| `quarter` | INTEGER | Quarter of year (1–4) |
| `month` | INTEGER | Month number (1–12) |
| `month_name` | VARCHAR | Full month name (e.g. January) |
| `week_of_year` | INTEGER | ISO week number (1–53) |
| `day_of_week` | INTEGER | Day of week — 0=Sunday, 6=Saturday (PostgreSQL EXTRACT DOW) |
| `day_name` | VARCHAR | Full day name (e.g. Monday) |
| `is_weekend` | BOOLEAN | TRUE if Saturday or Sunday |

**Notes:**
- Derived from distinct `order_purchase_timestamp` dates in `silver.erp_orders`
- Date range: 2016–2018 aligned with Olist dataset
- `date_key` integer format enables fast range filtering (e.g. `date_key BETWEEN 20170101 AND 20171231`)
- `day_of_week` uses PostgreSQL `EXTRACT(DOW)` — 0=Sunday, 6=Saturday

---

## Fact View

---

### gold.fact_orders

**Description:** Central fact view for order-item level analysis. Integrates order, item, payment and review data into a single denormalized analytical view. Connects to all four dimension views via surrogate keys. This is the primary entry point for all analytical queries against the warehouse.

**Grain:** One row per order item (`order_id` + `order_item_id`)

**Dimension Keys:**

| Column | References |
|---|---|
| `customer_key` | `dim_customers.customer_key` |
| `product_key` | `dim_products.product_key` |
| `seller_key` | `dim_sellers.seller_key` |
| `date_key` | `dim_date.date_key` |

**Full Column Reference:**

| Column | Data Type | Description |
|---|---|---|
| `order_id` | VARCHAR | Order identifier |
| `order_item_id` | INTEGER | Item sequence number within the order |
| `customer_key` | INTEGER | FK to `dim_customers` |
| `product_key` | INTEGER | FK to `dim_products` |
| `seller_key` | INTEGER | FK to `dim_sellers` |
| `date_key` | INTEGER | FK to `dim_date` |
| `order_status` | VARCHAR | Order lifecycle status |
| `order_purchase_timestamp` | TIMESTAMP | Date and time the order was placed |
| `order_approved_at` | TIMESTAMP | Date and time payment was approved |
| `order_delivered_carrier_date` | TIMESTAMP | Date order was handed to carrier |
| `order_delivered_customer_date` | TIMESTAMP | Date order was delivered to customer |
| `order_estimated_delivery_date` | TIMESTAMP | Estimated delivery date shown at purchase |
| `delivery_delay_days` | INTEGER | Days late (positive) or early (negative) vs estimate — NULL for non-delivered orders |
| `is_on_time` | BOOLEAN | TRUE if delivered on or before estimated date — NULL for non-delivered orders |
| `price` | DECIMAL(10,2) | Item price in BRL |
| `freight_value` | DECIMAL(10,2) | Shipping cost for this item in BRL |
| `total_amount` | DECIMAL(10,2) | price + freight_value |
| `payment_value` | DECIMAL(10,2) | Total payment value for the order (all items combined) |
| `payment_type` | VARCHAR | Payment method (credit_card, boleto, voucher, debit_card) |
| `payment_installments` | INTEGER | Number of installments chosen by customer |
| `review_score` | INTEGER | Customer satisfaction score (1–5) — NULL if no review submitted |
| `review_creation_date` | TIMESTAMP | Date the review survey was sent |

**Notes:**
- `payment_value` is aggregated at order level (SUM across all payment methods) — represents total order value, not individual item value
- `delivery_delay_days` and `is_on_time` only populated for `order_status = 'delivered'`
- A single order with multiple items will have multiple rows — use `COUNT(DISTINCT order_id)` for order-level metrics
- `review_score` is joined at order level — all items in the same order share the same review score

---

## Example Analytical Queries

The following queries demonstrate common analytical patterns against the Gold layer views.

```sql
-- Total revenue by product category
SELECT
    dp.product_category,
    ROUND(SUM(f.price)::NUMERIC, 2) AS total_revenue,
    COUNT(DISTINCT f.order_id)      AS total_orders
FROM gold.fact_orders f
JOIN gold.dim_products dp ON f.product_key = dp.product_key
GROUP BY dp.product_category
ORDER BY total_revenue DESC;

-- Monthly order volume and revenue trend
SELECT
    dd.year,
    dd.month,
    dd.month_name,
    COUNT(DISTINCT f.order_id)      AS total_orders,
    ROUND(SUM(f.price)::NUMERIC, 2) AS total_revenue
FROM gold.fact_orders f
JOIN gold.dim_date dd ON f.date_key = dd.date_key
GROUP BY dd.year, dd.month, dd.month_name
ORDER BY dd.year, dd.month;

-- Delivery performance by seller state
SELECT
    ds.seller_state,
    COUNT(DISTINCT f.order_id)                        AS delivered_orders,
    ROUND(AVG(f.delivery_delay_days)::NUMERIC, 1)     AS avg_delay_days,
    ROUND(
        SUM(CASE WHEN f.is_on_time THEN 1 ELSE 0 END)
        * 100.0 / COUNT(*), 2
    )                                                 AS on_time_pct
FROM gold.fact_orders f
JOIN gold.dim_sellers ds ON f.seller_key = ds.seller_key
WHERE f.order_status = 'delivered'
GROUP BY ds.seller_state
ORDER BY delivered_orders DESC;

-- Average review score by product category
SELECT
    dp.product_category,
    ROUND(AVG(f.review_score)::NUMERIC, 2) AS avg_review_score,
    COUNT(f.review_score)                  AS reviews_count
FROM gold.fact_orders f
JOIN gold.dim_products dp ON f.product_key = dp.product_key
WHERE f.review_score IS NOT NULL
GROUP BY dp.product_category
ORDER BY avg_review_score DESC;
```

---

# Known Data Quality Issues

| Table | Issue | Severity | Status | Resolution |
|---|---|---|---|---|
| `erp_products` | Column name typos (`lenght`) | Low | Resolved | Corrected in Silver (`lenght` → `length`) |
| `erp_products` | High null rate on dimension columns | Medium | Accepted | Nulls preserved in Silver and Gold |
| `crm_customers` | City name encoding/casing inconsistencies | Medium | Resolved | Standardized in Silver (LOWER + TRIM) |
| `erp_sellers` | City name encoding/casing inconsistencies | Medium | Resolved | Standardized in Silver (LOWER + TRIM) |
| `erp_geolocation` | Duplicate ZIP entries (~1M rows) | Medium | Resolved | Deduplicated in Silver using AVG lat/lng per ZIP |
| `erp_geolocation` | Coordinates outside Brazil | Low | Resolved | Filtered in Silver (lat: -34 to 5, lng: -74 to -28) |
| `erp_orders` | Nulls in delivery timestamp columns | Low | Accepted | Expected for non-delivered orders — preserved intentionally |
| `crm_order_reviews` | High null rate on comment fields | Low | Accepted | Expected — most customers only submit a score |
| `crm_order_reviews` | Special characters and line breaks causing CSV parsing failures | Medium | Resolved | Loaded via Python script (`import_reviews.py`) |
| `erp_product_category_translation` | Unmatched categories in products table | Low | Resolved | Handled with `COALESCE` to `'unknown'` in Gold |

---

*Last updated: 2026-03-20*
*Author: John S Cardona*