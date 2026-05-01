 # إنشاء الاتصال
import sqlite3
import os

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
DB_PATH = os.path.join(BASE_DIR, "financial_advisor.db")

conn = sqlite3.connect(DB_PATH)
cursor = conn.cursor()
# =========================
# 👤 Users Table
# =========================
cursor.execute("""
CREATE TABLE IF NOT EXISTS users (
    user_id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    phone_number TEXT UNIQUE,
    balance REAL DEFAULT 0,
    total_savings REAL DEFAULT 0
)
""")

# =========================
# 💸 Transactions Table
# =========================
cursor.execute("""
CREATE TABLE IF NOT EXISTS transactions (
    transaction_id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER,
    amount REAL NOT NULL,
    category TEXT,
    type TEXT CHECK(type IN ('expense','income')),
    date TEXT,
    FOREIGN KEY(user_id) REFERENCES users(user_id)
)
""")

# =========================
# 💰 Savings Table
# =========================
cursor.execute("""
CREATE TABLE IF NOT EXISTS savings (
    saving_id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER,
    amount REAL NOT NULL,
    type TEXT CHECK(type IN ('deposit','withdraw')),
    date TEXT,
    FOREIGN KEY(user_id) REFERENCES users(user_id)
)
""")

# حفظ وإغلاق
conn.commit()
conn.close()

print("✅ Database created successfully!")