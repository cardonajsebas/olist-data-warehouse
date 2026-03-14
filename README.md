# Olist Data Warehouse

An end-to-end data warehouse project built on the **Olist Brazilian E-Commerce** public dataset. This project demonstrates modern data engineering practices, from raw data ingestion, to analytical-ready models. Following a **Medallion Architecture** (Bronze → Silver → Gold) implemented in **PostgreSQL**.

> Built as a portfolio project to showcase data engineering skills including SQL development, ETL pipeline design, data modeling, data quality practices, and cloud migration.

---

## 📐 Data Architecture

This project follows the **Medallion Architecture** pattern with three distinct layers:

![Data Architecture Diagram](docs/data_architecture.png)

| Layer | Description | Object Type | Load Strategy |
|---|---|---|---|
| 🟤 **Bronze** | Raw data ingested as-is from source CSV files | Tables | Full load · Truncate & Insert |
| ⚪ **Silver** | Cleaned, standardized and normalized data | Tables | Full load · Truncate & Insert |
| 🟡 **Gold** | Business-ready analytical models | Views | No load · Derived from Silver |

## 🗃️ Data Model

The source data consists of 9 interrelated tables centered around `olist_orders` as the core fact entity. Relationships are documented in [`docs/erd.drawio`](docs/erd.drawio).

The Gold layer will implement a **Star Schema** with:
- **Fact tables** — `fact_orders`, `fact_order_items`
- **Dimension tables** — `dim_customers`, `dim_products`, `dim_sellers`, `dim_date`, `dim_geolocation`

---

## 📖 Project Overview

| | |
|---|---|
| **Dataset** | [Olist Brazilian E-Commerce](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce) |
| **Source Tables** | CSV files |
| **Database** | PostgreSQL (local) → GCP Cloud SQL (Phase 2) |
| **Modeling** | Star Schema (Fact + Dimension tables) |
| **Analytics** | SQL-based reporting on customer behavior, product performance and sales trends |

### What this project covers

- **Data Architecture** — Designing a modern data warehouse using Medallion Architecture
- **ETL Pipelines** — Extracting, transforming and loading data across Bronze, Silver and Gold layers
- **Data Modeling** — Building fact and dimension tables optimized for analytical queries
- **Data Quality** — Validation scripts ensuring integrity and consistency across layers
- **Analytics & Reporting** — SQL-based insights on e-commerce business metrics

---

## 🗂️ Repository Structure

```
olist-data-warehouse/
│
├── datasets/                     # Raw Olist CSV source files (9 tables)
│
├── docs/                         # Architecture diagrams and documentation
│   ├── data_architecture.drawio  # High-level architecture diagram
│   ├── data_flow.drawio          # ETL data flow diagram
│   ├── erd.drawio        # Star schema / ERD diagram
│   ├── data_catalog.md           # Table and column definitions with metadata
│   └── naming_conventions.md     # Naming standards for tables, columns and scripts
│
├── scripts/                      # SQL scripts organized by layer
│   ├── init/                     # Database and schema initialization
│   ├── bronze/                   # Raw data load scripts
│   ├── silver/                   # Cleaning and transformation scripts
│   └── gold/                     # Analytical views and models
│
├── tests/                        # Data quality and validation scripts
│
├── README.md
├── .gitignore
└── LICENSE
```

---

## 🛠️ Tech Stack

| Tool | Purpose |
|---|---|
| **PostgreSQL** | Core database engine |
| **Draw.io** | Architecture and data model diagrams |
| **GitHub** | Version control and project planning |
| **GitHub Projects** | Agile project management (Scrum-like board) |

---

## 🚀 How to Run

> Prerequisites: PostgreSQL installed and running locally. See setup instructions below.

### 1. Clone the repository

```bash
git clone https://github.com/your-username/olist-data-warehouse.git
cd olist-data-warehouse
```

### 2. Initialize the database

```bash
psql -U postgres -f scripts/init/create_database.sql
psql -U postgres -f scripts/init/create_schemas.sql
```

### 3. Load Bronze layer

```bash
psql -U postgres -d olist_dwh -f scripts/bronze/load_bronze.sql
```

### 4. Load Silver layer

```bash
psql -U postgres -d olist_dwh -f scripts/silver/load_silver.sql
```

### 5. Build Gold layer

```bash
psql -U postgres -d olist_dwh -f scripts/gold/load_gold.sql
```

---

## 📊 Data Source

The **Olist Brazilian E-Commerce** dataset contains ~100,000 orders placed between 2016 and 2018 across multiple marketplaces in Brazil. It includes information on order status, pricing, payment, freight, customer location, product attributes, and customer reviews.

| Table | Description |
|---|---|
| `olist_orders` | Core order records with status and timestamps |
| `olist_order_items` | Individual items per order with pricing and freight |
| `olist_order_payments` | Payment method and installment details |
| `olist_order_reviews` | Customer review scores and comments |
| `olist_customers` | Customer location and unique identifiers |
| `olist_products` | Product attributes and category |
| `olist_sellers` | Seller location and identifiers |
| `olist_geolocation` | ZIP code level lat/lng coordinates |
| `product_category_name_translation` | Portuguese to English category mapping |

---

## 📋 Project Status

This project is tracked using [GitHub Projects](https://github.com/users/cardonajsebas/projects/1). Below is the current milestone progress:

| Milestone | Status |
|---|---|
| 1 · Requirements Analysis | 🔄 In Progress |
| 2 · Data Architecture Design | ⏳ Planned |
| 3 · Environment & Project Initialization | ⏳ Planned |
| 4 · Data Integration (ETL Pipelines) | ⏳ Planned |

---

## 🗺️ Roadmap

- **Phase 1 — Local Data Warehouse** *(current)*
  - PostgreSQL on local environment
  - Full ETL pipeline across Bronze, Silver and Gold layers
  - SQL-based analytics and reporting

- **Phase 2 — Cloud Migration** *(planned)*
  - Migrate to GCP Cloud SQL (PostgreSQL)
  - Explore BigQuery for analytical layer
  - CI/CD pipeline integration

---

## 📄 License


---

## 🙋 About

Built by **[John S Cardona]** as a portfolio project to demonstrate data engineering skills.  
Dataset sourced from [Kaggle — Olist Brazilian E-Commerce](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce) under the [CC BY-NC-SA 4.0](https://creativecommons.org/licenses/by-nc-sa/4.0/) license.

[![LinkedIn](https://img.shields.io/badge/LinkedIn-0077B5?style=for-the-badge&logo=linkedin&logoColor=white)](https://linkedin.com/in/sebastian-cardona)
[![GitHub](https://img.shields.io/badge/GitHub-100000?style=for-the-badge&logo=github&logoColor=white)](https://github.com/cardonajsebas)
