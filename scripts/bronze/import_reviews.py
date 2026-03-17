import psycopg2
import csv
import os
from dotenv import load_dotenv

load_dotenv()

DB_NAME = os.getenv("DB_NAME")
DB_USER = os.getenv("DB_USER")
DB_PASS = os.getenv("DB_PASS")
DB_HOST = os.getenv("DB_HOST")

conn = psycopg2.connect(
    dbname=DB_NAME,
    user=DB_USER,
    password=DB_PASS,
    host=DB_HOST
)
cur = conn.cursor()

with open('PATH/to/olist-data-warehouse/datasets/crm/olist_order_reviews_dataset.csv', 'r', encoding='utf-8') as f:
    reader = csv.reader(f)
    next(reader)  # skip header
    for row in reader:
        cur.execute("""
            INSERT INTO bronze.crm_order_reviews VALUES (%s, %s, %s, %s, %s, %s, %s)
        """, row)

conn.commit()
cur.close()
conn.close()
print("Done!")
