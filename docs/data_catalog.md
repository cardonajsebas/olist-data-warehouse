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

*Last updated: 2026-03-14*
*Author: John S Cardona*