import sqlite3

db_path = "d:/Repos/python_projects/project_new/database/mali_wallet.db"
conn = sqlite3.connect(db_path)
cursor = conn.cursor()
try:
    cursor.execute("ALTER TABLE transactions ADD COLUMN category VARCHAR(100) DEFAULT 'أخرى'")
    conn.commit()
    print("Column added successfully.")
except Exception as e:
    print(f"Error: {e}")
finally:
    conn.close()
