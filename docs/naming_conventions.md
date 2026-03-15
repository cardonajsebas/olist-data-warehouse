# Naming Conventions

This document outlines the naming conventions used for schemas, tables, views, columns, and other objects in the data warehouse.

## Table of Contents
1. [General Principles](#general-principles)
2. [Source System Mapping](#source-system-mapping)
3. [Table Naming Conventions](#table-naming-conventions)
   - [Bronze Rules](#bronze-rules)
   - [Silver Rules](#silver-rules)
   - [Gold Rules](#gold-rules)
4. [Column Naming Conventions](#column-naming-conventions)
   - [Surrogate Keys](#surrogate-keys)
   - [Foreign Keys](#foreign-keys)
   - [Boolean Columns](#boolean-columns)
   - [Date and Timestamp Columns](#date-and-timestamp-columns)
   - [Technical Columns](#technical-columns)
5. [Load Scripts](#load-scripts)

---

## General Principles

- **Format**: Use `snake_case` - lowercase letters with underscores (`_`) to separate words.
- **Language**: Use English for all names.
- **Avoid Reserved Words**: Do not use SQL reserved words as object names.
- **Clarity over brevity**: Names should be descriptive and self-explanatory.

---

## Source System Mapping

The Olist dataset is treated as originating from two source systems, mapped as follows:

| Source System | Prefix | Tables |
|---|---|---|
| Customer Relationship Management | `crm` | `customers`, `order_reviews` |
| Enterprise Resource Planning | `erp` | `orders`, `order_items`, `order_payments`, `products`, `sellers`, `geolocation`, `product_category_name_translation` |

> This mapping is a logical classification applied for consistency with medallion architecture conventions. The original Olist dataset does not distinguish between source systems explicitly.

---

## Table Naming Conventions

### Bronze Rules

All Bronze tables preserve the original source table names, stripped of the `olist_` prefix, and prefixed with the source system name.

**Pattern:** `<sourcesystem>_<entity>`

| Component | Description |
|---|---|
| `<sourcesystem>` | Name of the source system (`crm` or `erp`) |
| `<entity>` | Original table name from the source, without the `olist_` prefix |

**Examples:**

| Source CSV | Bronze Table | Description |
|---|---|---|
| `olist_customers_dataset.csv` | `crm_customers` | Raw customer data |
| `olist_order_reviews_dataset.csv` | `crm_order_reviews` | Raw review data |
| `olist_orders_dataset.csv` | `erp_orders` | Raw order records |
| `olist_order_items_dataset.csv` | `erp_order_items` | Raw order line items |
| `olist_order_payments_dataset.csv` | `erp_order_payments` | Raw payment records |
| `olist_products_dataset.csv` | `erp_products` | Raw product data |
| `olist_sellers_dataset.csv` | `erp_sellers` | Raw seller data |
| `olist_geolocation_dataset.csv` | `erp_geolocation` | Raw geolocation data |
| `product_category_name_translation.csv` | `erp_product_category_translation` | Raw category translations |

> No transformations are applied in Bronze. Data is loaded as-is from the source CSVs.

---

### Silver Rules

Silver tables follow the same naming pattern as Bronze. Names are intentionally identical to their Bronze counterparts. This makes lineage tracking straightforward and signals that Silver is a cleaned and standardized version of the same entity, not a new one.

**Pattern:** `<sourcesystem>_<entity>`

| Component | Description |
|---|---|
| `<sourcesystem>` | Name of the source system (`crm` or `erp`) |
| `<entity>` | Same entity name as the corresponding Bronze table |

**Examples:**

| Bronze Table | Silver Table | Changes Applied |
|---|---|---|
| `crm_customers` | `crm_customers` | Standardized city names, casing |
| `erp_orders` | `erp_orders` | Nulls handled, data types cast |
| `erp_products` | `erp_products` | Column typos corrected, nulls flagged |
| `erp_geolocation` | `erp_geolocation` | Deduplicated, outlier coordinates removed |

> Silver applies cleaning, standardization, normalization, and enrichment. The data model remains flat (no joins) — integration happens in Gold.

---

### Gold Rules

Gold tables use business-aligned names with a category prefix that describes the table's role in the dimensional model.

**Pattern:** `<category>_<entity>`

| Component | Description |
|---|---|
| `<category>` | Role of the table (`dim`, `fact`, `report`) |
| `<entity>` | Descriptive, business-friendly name aligned with the domain |

**Examples:**

| Gold Table | Description |
|---|---|
| `dim_customers` | Dimension table for customer data |
| `dim_products` | Dimension table for product data |
| `dim_sellers` | Dimension table for seller data |
| `dim_date` | Date dimension table |
| `dim_geolocation` | Geolocation dimension table |
| `fact_orders` | Fact table for order-level metrics |
| `fact_order_items` | Fact table for item-level metrics |
| `report_sales_monthly` | Aggregated report for monthly sales trends |
| `report_customer_segments` | Aggregated report for customer segmentation |

#### Glossary of Category Patterns

| Pattern | Meaning | Example |
|---|---|---|
| `dim_` | Dimension table | `dim_customers`, `dim_products` |
| `fact_` | Fact table | `fact_orders`, `fact_order_items` |
| `report_` | Aggregated report table | `report_sales_monthly` |

> Gold objects are implemented as **views** in this project, not physical tables. This avoids data duplication and ensures Gold always reflects the latest Silver data.

---

## Column Naming Conventions

### Surrogate Keys

All primary keys in dimension tables use the suffix `_key`. Surrogate keys are system-generated and have no business meaning.

**Pattern:** `<table_name>_key`

**Examples:**

| Column | Table | Description |
|---|---|---|
| `customer_key` | `dim_customers` | Surrogate key for customer dimension |
| `product_key` | `dim_products` | Surrogate key for product dimension |
| `seller_key` | `dim_sellers` | Surrogate key for seller dimension |
| `date_key` | `dim_date` | Surrogate key for date dimension |

---

### Foreign Keys

Foreign keys in fact tables reference dimension surrogate keys and use the same `_key` suffix to make joins self-documenting.

**Examples:**

| Column | Table | References |
|---|---|---|
| `customer_key` | `fact_orders` | `dim_customers.customer_key` |
| `product_key` | `fact_order_items` | `dim_products.product_key` |
| `seller_key` | `fact_order_items` | `dim_sellers.seller_key` |
| `date_key` | `fact_orders` | `dim_date.date_key` |

---

### Boolean Columns

Boolean columns use the prefix `is_` or `has_` to make their meaning immediately clear.

**Pattern:** `is_<condition>` or `has_<condition>`

**Examples:**

| Column | Description |
|---|---|
| `is_delivered` | Whether the order was successfully delivered |
| `is_late_delivery` | Whether delivery exceeded the estimated date |
| `has_review` | Whether the order has an associated review |

---

### Date and Timestamp Columns

- Date-only columns use the suffix `_date`
- Datetime/timestamp columns use the suffix `_timestamp` or `_at`

**Examples:**

| Column | Type | Description |
|---|---|---|
| `order_purchase_date` | DATE | Date the order was placed |
| `order_purchase_timestamp` | TIMESTAMP | Full datetime the order was placed |
| `order_delivered_at` | TIMESTAMP | Datetime the order was delivered |
| `dwh_load_date` | DATE | Date the record was loaded into the DWH |

---

### Technical Columns

All system-generated metadata columns use the prefix `dwh_` to distinguish them from business columns.

**Pattern:** `dwh_<column_name>`

**Examples:**

| Column | Description |
|---|---|
| `dwh_load_date` | Date the record was loaded into the warehouse |
| `dwh_load_timestamp` | Full timestamp of the load |
| `dwh_source` | Source system the record originated from |

---

## Load Scripts

All scripts responsible for loading data into each layer follow a consistent naming pattern.

**Pattern:** `load_<layer>.sql`

**Examples:**

| Script | Description |
|---|---|
| `load_bronze.sql` | Loads raw CSV data into the Bronze schema |
| `load_silver.sql` | Cleans and transforms Bronze data into Silver |
| `load_gold.sql` | Builds analytical views in the Gold schema |

> Note: Unlike SQL Server where this logic would live in stored procedures, in PostgreSQL these are implemented as plain SQL scripts or functions. The naming convention remains consistent for clarity.

---

*Last updated: 2026-03-14*
*Credit: Inspired by [Data with Baraa](https://www.youtube.com/@DataWithBaraa)*