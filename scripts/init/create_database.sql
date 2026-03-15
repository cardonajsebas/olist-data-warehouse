/*
 =============================================================================
 Create Database: olist_dwh
 =============================================================================
 Description: Creates the main database for the Olist Data Warehouse project.
              Run this script as the postgres superuser before executing
              any other scripts.

 Usage:
   psql -U postgres -f scripts/init/create_database.sql
 =============================================================================
*/

-- Create the main data warehouse database
CREATE DATABASE olist_dwh
    ENCODING = 'UTF8'
    LC_COLLATE = 'en_US.UTF-8'
    LC_CTYPE = 'en_US.UTF-8'
    TEMPLATE = template0;
