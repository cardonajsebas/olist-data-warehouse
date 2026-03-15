/*
 =============================================================================
 Create Schemas: bronze, silver, gold
 =============================================================================
 Description: Creates the three medallion architecture schemas within the
              olist_dwh database. Each schema represents a distinct layer
              in the data pipeline.

              bronze → raw data, loaded as-is from source CSVs
              silver → cleaned and standardized data
              gold   → business-ready views, star schema

 Usage:
   psql -U postgres -d olist_dwh -f scripts/init/create_schemas.sql
 =============================================================================
*/

-- Bronze: raw ingestion layer
CREATE SCHEMA IF NOT EXISTS bronze;

-- Silver: cleaning and standardization layer
CREATE SCHEMA IF NOT EXISTS silver;

-- Gold: analytical layer (views, star schema)
CREATE SCHEMA IF NOT EXISTS gold;
