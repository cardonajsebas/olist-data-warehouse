# Data Catalog

## Overview

This catalog documents all source tables from the **Olist Brazilian E-Commerce** dataset used in this project. It serves as the reference for understanding the raw data before any transformation is applied.

- **Source:** [Kaggle - Olist Brazilian E-Commerce](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce)
- **Layer:** Bronze (Raw)
- **Format:** CSV files
- **Total Tables:** 9
- **Coverage:** ~100,000 orders · 2016–2018 · Brazil

---

## Table Index

| # | Table Name | Description | Row count |
|---|---|---|---|
| 1 | [olist_orders](#1-olist_orders) | Core order records | 99,441 |
| 2 | [olist_order_items](#2-olist_order_items) | Line items per order | 112,650 |
| 3 | [olist_order_payments](#3-olist_order_payments) | Payment details per order | 103,886 |
| 4 | [olist_order_reviews](#4-olist_order_reviews) | Customer reviews per order | 99,224 |
| 5 | [olist_customers](#5-olist_customers) | Customer location and identifiers | 99,441 |
| 6 | [olist_products](#6-olist_products) | Product attributes and categories | 32,951 |
| 7 | [olist_sellers](#7-olist_sellers) | Seller location and identifiers | 3,095 |
| 8 | [olist_geolocation](#8-olist_geolocation) | ZIP code coordinates | 1,000,163 |
| 9 | [product_category_name_translation](#9-product_category_name_translation) | Category name translations | 71 |

---

## Table Details

---

### 1. olist_orders

**Description:** The core orders table. Each row represents a unique order placed on the Olist marketplace. This is the central table of the data model and connects to most other tables via `order_id`.

**Grain:** One row per order.

**Primary Key:** `order_id`

| Column | Data Type | Nullable | Description |
|---|---|---|---|
| `order_id` | VARCHAR | No | Unique identifier for the order |
| `customer_id` | VARCHAR | No | Foreign key to `olist_customers` |
| `order_status` | VARCHAR | No | Order lifecycle status (e.g. delivered, shipped, canceled) |
| `order_purchase_timestamp` | TIMESTAMP | No | Date and time the order was placed |
| `order_approved_at` | TIMESTAMP | Yes | Date and time the payment was approved |
| `order_delivered_carrier_date` | TIMESTAMP | Yes | Date the order was handed to the carrier |
| `order_delivered_customer_date` | TIMESTAMP | Yes | Date the order was delivered to the customer |
| `order_estimated_delivery_date` | TIMESTAMP | No | Estimated delivery date shown to the customer at purchase |

**Notes:**
- `order_status` values include: `delivered`, `shipped`, `canceled`, `unavailable`, `invoiced`, `processing`, `created`, `approved`
- Several timestamp columns are nullable -orders that were canceled or not yet delivered will have nulls in delivery-related fields
- Delivery delay can be derived by comparing `order_delivered_customer_date` vs `order_estimated_delivery_date`

---

### 2. olist_order_items

**Description:** Contains the individual items within each order. An order can have multiple items, potentially from different sellers.

**Grain:** One row per item per order (an order with 3 items will have 3 rows).

**Primary Key:** `order_id` + `order_item_id`

| Column | Data Type | Nullable | Description |
|---|---|---|---|
| `order_id` | VARCHAR | No | Foreign key to `olist_orders` |
| `order_item_id` | INTEGER | No | Sequential item number within the order (1, 2, 3...) |
| `product_id` | VARCHAR | No | Foreign key to `olist_products` |
| `seller_id` | VARCHAR | No | Foreign key to `olist_sellers` |
| `shipping_limit_date` | TIMESTAMP | No | Seller's deadline to hand the item to the carrier |
| `price` | DECIMAL | No | Item price in BRL |
| `freight_value` | DECIMAL | No | Freight cost for this item in BRL |

**Notes:**
- Total order value = SUM of `price` + `freight_value` across all items in the order
- A single order can involve multiple sellers (marketplace model)

---

### 3. olist_order_payments

**Description:** Contains payment information for each order. An order can have multiple payment entries if the customer split the payment across methods.

**Grain:** One row per payment method per order.

**Primary Key:** `order_id` + `payment_sequential`

| Column | Data Type | Nullable | Description |
|---|---|---|---|
| `order_id` | VARCHAR | No | Foreign key to `olist_orders` |
| `payment_sequential` | INTEGER | No | Sequence number when multiple payment methods are used |
| `payment_type` | VARCHAR | No | Payment method (credit_card, boleto, voucher, debit_card) |
| `payment_installments` | INTEGER | No | Number of installments chosen by the customer |
| `payment_value` | DECIMAL | No | Transaction value in BRL |

**Notes:**
- `boleto` is a Brazilian cash payment slip - common in Brazilian e-commerce
- Customers can pay with voucher + credit card simultaneously, resulting in 2 rows per order
- `payment_installments` = 1 means paid in full (no installments)

---

### 4. olist_order_reviews

**Description:** Contains customer satisfaction reviews submitted after delivery. Each order can have one review.

**Grain:** One row per review (one review per order).

**Primary Key:** `review_id`

| Column | Data Type | Nullable | Description |
|---|---|---|---|
| `review_id` | VARCHAR | No | Unique identifier for the review |
| `order_id` | VARCHAR | No | Foreign key to `olist_orders` |
| `review_score` | INTEGER | No | Customer rating from 1 (worst) to 5 (best) |
| `review_comment_title` | VARCHAR | Yes | Optional review title written by the customer |
| `review_comment_message` | VARCHAR | Yes | Optional review body written by the customer |
| `review_creation_date` | TIMESTAMP | No | Date the review survey was sent to the customer |
| `review_answer_timestamp` | TIMESTAMP | Yes | Date and time the customer submitted the review |

**Notes:**
- Review comments are in Portuguese
- High null rate expected on `review_comment_title` and `review_comment_message` -most customers only submit a score
- Sentiment analysis possible on comment fields (Phase 2 / ML use case)

---

### 5. olist_customers

**Description:** Contains customer information. Each row represents a unique customer record linked to an order -note that the same physical customer may appear multiple times with different `customer_id` values if they placed multiple orders.

**Grain:** One row per customer per order (not unique physical customers).

**Primary Key:** `customer_id`

| Column | Data Type | Nullable | Description |
|---|---|---|---|
| `customer_id` | VARCHAR | No | Unique identifier per order (not per physical customer) |
| `customer_unique_id` | VARCHAR | No | Identifier for the actual physical customer across orders |
| `customer_zip_code_prefix` | VARCHAR | No | First 5 digits of the customer's ZIP code |
| `customer_city` | VARCHAR | No | Customer city name |
| `customer_state` | VARCHAR | No | Customer state abbreviation (e.g. SP, RJ) |

**Notes:**
- Use `customer_unique_id` for customer-level analysis (repeat purchases, lifetime value)
- Use `customer_id` only for order-level joins
- City names may have encoding issues or inconsistent casing -flag for Silver layer cleaning

---

### 6. olist_products

**Description:** Contains product attributes for items sold on the platform.

**Grain:** One row per product.

**Primary Key:** `product_id`

| Column | Data Type | Nullable | Description |
|---|---|---|---|
| `product_id` | VARCHAR | No | Unique product identifier |
| `product_category_name` | VARCHAR | Yes | Product category name in Portuguese |
| `product_name_lenght` | INTEGER | Yes | Character length of the product name |
| `product_description_lenght` | INTEGER | Yes | Character length of the product description |
| `product_photos_qty` | INTEGER | Yes | Number of photos published for the product |
| `product_weight_g` | INTEGER | Yes | Product weight in grams |
| `product_length_cm` | INTEGER | Yes | Product length in centimeters |
| `product_height_cm` | INTEGER | Yes | Product height in centimeters |
| `product_width_cm` | INTEGER | Yes | Product width in centimeters |

**Notes:**
- `product_category_name` is in Portuguese -join with `product_category_name_translation` for English names
- Column names contain typos (`lenght` instead of `length`) -preserve as-is in Bronze, correct in Silver
- High nullable rate across dimension columns -flag for data quality assessment

---

### 7. olist_sellers

**Description:** Contains seller information for merchants operating on the Olist marketplace.

**Grain:** One row per seller.

**Primary Key:** `seller_id`

| Column | Data Type | Nullable | Description |
|---|---|---|---|
| `seller_id` | VARCHAR | No | Unique seller identifier |
| `seller_zip_code_prefix` | VARCHAR | No | First 5 digits of the seller's ZIP code |
| `seller_city` | VARCHAR | No | Seller city name |
| `seller_state` | VARCHAR | No | Seller state abbreviation (e.g. SP, RJ) |

**Notes:**
- City names may have the same encoding/casing inconsistencies as `olist_customers`
- Seller geographic distribution is heavily concentrated in São Paulo state

---

### 8. olist_geolocation

**Description:** Maps Brazilian ZIP code prefixes to geographic coordinates. Used for distance calculations and geographic visualizations.

**Grain:** Multiple rows per ZIP code prefix (several lat/lng entries per ZIP).

**Primary Key:** None (no unique key -duplicates expected by design)

| Column | Data Type | Nullable | Description |
|---|---|---|---|
| `geolocation_zip_code_prefix` | VARCHAR | No | First 5 digits of the ZIP code |
| `geolocation_lat` | DECIMAL | No | Latitude coordinate |
| `geolocation_lng` | DECIMAL | No | Longitude coordinate |
| `geolocation_city` | VARCHAR | No | City name |
| `geolocation_state` | VARCHAR | No | State abbreviation |

**Notes:**
- This is the largest table (~1M rows) due to multiple coordinates per ZIP
- Aggregation strategy needed in Silver (e.g. AVG lat/lng per ZIP prefix)
- Contains outlier coordinates outside Brazil -flag for data quality filtering

---

### 9. product_category_name_translation

**Description:** Lookup table mapping Portuguese product category names to their English equivalents.

**Grain:** One row per category.

**Primary Key:** `product_category_name`

| Column | Data Type | Nullable | Description |
|---|---|---|---|
| `product_category_name` | VARCHAR | No | Category name in Portuguese (join key to `olist_products`) |
| `product_category_name_english` | VARCHAR | No | Category name translated to English |

**Notes:**
- Small reference table (~71 rows)
- Some categories in `olist_products` may not have a matching translation -handle nulls in Silver

---

## Known Data Quality Issues

| Table | Issue | Severity | Planned Action |
|---|---|---|---|
| `olist_products` | Column name typos (`lenght`) | Low | Rename in Silver layer |
| `olist_products` | High null rate on dimension columns | Medium | Impute or flag nulls in Silver |
| `olist_customers` | City name encoding/casing inconsistencies | Medium | Standardize in Silver layer |
| `olist_sellers` | City name encoding/casing inconsistencies | Medium | Standardize in Silver layer |
| `olist_geolocation` | Duplicate ZIP entries (~1M rows) | Medium | Aggregate to one lat/lng per ZIP in Silver |
| `olist_geolocation` | Coordinates outside Brazil | Low | Filter outliers in Silver layer |
| `olist_orders` | Nulls in delivery timestamp columns | Low | Expected -document and preserve |
| `olist_order_reviews` | High null rate on comment fields | Low | Expected -document and preserve |
| `olist_order_reviews` | Comment fields contain commas and special characters causing CSV parsing issues | Medium | Use \copy with explicit quote handling for ingestion |
| `product_category_name_translation` | Unmatched categories in products table | Low | Left join with null handling in Silver |

---

# Data Catalog - Gold Layer

## Overview

This document covers the Gold layer of the Olist Data Warehouse, the analytical layer implementing a Star Schema optimized for business reporting and ad-hoc SQL analysis. All Gold objects are **views** derived directly from Silver tables. No physical data is loaded into Gold.

- **Layer:** Gold (Analytical)
- **Object type:** Views (no physical load)
- **Model:** Star Schema
- **Grain:** One row per order item (`order_id` + `order_item_id`)
- **Total views:** 5 (4 dimensions + 1 fact)

---

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

**Description:**
Customer dimension enriched with geolocation data. Each row represents a unique customer record linked to an order. Note that the same physical customer may appear multiple times with different `customer_id` values, use `customer_unique_id` for customer-level analysis (repeat purchases, LTV).

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
- `customer_lat` and `customer_lng` are derived from `erp_geolocation` via ZIP prefix join, may be NULL if ZIP has no geolocation match
- Use `customer_unique_id` to identify repeat customers across multiple orders

---

### gold.dim_products

**Description:**
Product dimension enriched with English category names. Portuguese category names from the source are replaced with English equivalents via the translation lookup. Products without a matching translation default to `'unknown'`.

**Surrogate Key:** `product_key`
**Natural Key:** `product_id`

| Column | Data Type | Description |
|---|---|---|
| `product_key` | INTEGER | Surrogate key, system generated via ROW_NUMBER() |
| `product_id` | VARCHAR | Original product identifier from source |
| `product_category` | VARCHAR | English category name (defaults to 'unknown' if no translation) |
| `product_name_length` | INTEGER | Character length of product name |
| `product_description_length` | INTEGER | Character length of product description |
| `product_photos_qty` | INTEGER | Number of product photos published |
| `product_weight_g` | INTEGER | Product weight in grams |
| `product_length_cm` | INTEGER | Product length in centimeters |
| `product_height_cm` | INTEGER | Product height in centimeters |
| `product_width_cm` | INTEGER | Product width in centimeters |

**Notes:**
- Column name typos from source (`lenght`) were corrected in Silver, Gold uses the correct spelling
- Physical dimension columns (weight, dimensions) enable logistics and shipping cost analysis
- `product_category` will show `'unknown'` for ~600 products with no category in source

---

### gold.dim_sellers

**Description:**
Seller dimension enriched with geolocation data. Represents merchants operating on the Olist marketplace. Geographic distribution is heavily concentrated in São Paulo state.

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
- `seller_lat` and `seller_lng` are derived from `erp_geolocation` via ZIP prefix join, may be NULL if ZIP has no geolocation match
- Geographic coordinates enable seller-to-customer distance calculations

---

### gold.dim_date

**Description:**
Date dimension derived from order purchase timestamps. Contains one row per distinct calendar date present in the orders dataset. Covers the period 2016–2018 aligned with the Olist dataset coverage.

**Surrogate Key:** `date_key` (YYYYMMDD integer format, e.g. 20180115)
**Natural Key:** `full_date`

| Column | Data Type | Description |
|---|---|---|
| `date_key` | INTEGER | Surrogate key in YYYYMMDD format (e.g. 20180115) |
| `full_date` | DATE | Calendar date |
| `year` | INTEGER | Year (e.g. 2018) |
| `quarter` | INTEGER | Quarter of year (1–4) |
| `month` | INTEGER | Month number (1–12) |
| `month_name` | VARCHAR | Full month name (e.g. 'January') |
| `week_of_year` | INTEGER | ISO week number (1–53) |
| `day_of_week` | INTEGER | Day of week (0=Sunday, 6=Saturday) |
| `day_name` | VARCHAR | Full day name (e.g. 'Monday') |
| `is_weekend` | BOOLEAN | TRUE if Saturday or Sunday |

**Notes:**
- Derived from distinct `order_purchase_timestamp` dates in `silver.erp_orders`
- Date range: 2016–2018 (aligned with Olist dataset)
- `date_key` integer format enables fast range filtering (e.g. `date_key BETWEEN 20170101 AND 20171231`)

---

## Fact View

---

### gold.fact_orders

**Description:**
Central fact view for order-item level analysis. Integrates order, item, payment and review data into a single denormalized analytical view. Connects to all four dimension views via surrogate keys. This is the primary entry point for all analytical queries against the warehouse.

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
| `delivery_delay_days` | INTEGER | Days late (positive) or early (negative) vs estimate. NULL for non-delivered orders |
| `is_on_time` | BOOLEAN | TRUE if delivered on or before estimated date. NULL for non-delivered orders |
| `price` | DECIMAL(10,2) | Item price in BRL |
| `freight_value` | DECIMAL(10,2) | Shipping cost for this item in BRL |
| `total_amount` | DECIMAL(10,2) | price + freight_value |
| `payment_value` | DECIMAL(10,2) | Total payment value for the order (all items combined) |
| `payment_type` | VARCHAR | Payment method (credit_card, boleto, voucher, debit_card) |
| `payment_installments` | INTEGER | Number of installments chosen by customer |
| `review_score` | INTEGER | Customer satisfaction score (1–5). NULL if no review submitted |
| `review_creation_date` | TIMESTAMP | Date the review survey was sent |

**Notes:**
- `payment_value` is aggregated at order level (SUM across all payment methods), it represents the total order value, not individual item value
- `delivery_delay_days` and `is_on_time` are only populated for `order_status = 'delivered'`, 7 canceled orders in the source had delivery timestamps populated, which are excluded by design
- A single order with multiple items will have multiple rows, aggregate with `COUNT(DISTINCT order_id)` for order-level metrics
- `review_score` is joined at order level, all items in the same order share the same review score

---

## Example Analytical Queries

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
    COUNT(DISTINCT f.order_id)                          AS delivered_orders,
    ROUND(AVG(f.delivery_delay_days)::NUMERIC, 1)       AS avg_delay_days,
    ROUND(
        SUM(CASE WHEN f.is_on_time THEN 1 ELSE 0 END)
        * 100.0 / COUNT(*), 2
    )                                                   AS on_time_pct
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

*Last updated: 2026-03-20*
*Author: John S Cardona*
