import sqlite3
import os

import sqlite3

DB_NAME = "db/financial_advisor.db"  # 🔥 هنا الحل

def get_connection():
    conn = sqlite3.connect(DB_NAME)
    conn.row_factory = sqlite3.Row
    return conn


def fetch_all(query, params=()):
    conn = get_connection()
    cursor = conn.cursor()

    cursor.execute(query, params)
    rows = cursor.fetchall()

    conn.close()
    return rows