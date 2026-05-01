from db.connection import fetch_all
from db.connection import get_connection
def get_transactions(user_id):
    rows = fetch_all("""
        SELECT amount, category, date
        FROM transactions
        WHERE user_id = ? AND type = 'expense'
    """, (user_id,))

    # 🔥 نحول من Row → dict
    transactions = []
    for r in rows:
        transactions.append({
            "amount": r["amount"],
            "category": r["category"],
            "date": r["date"]
        })

    return transactions

def get_balance(user_id):
    # Balance = sum of income - sum of expense
    income_rows = fetch_all("SELECT SUM(amount) as total FROM transactions WHERE user_id = ? AND type = 'income'", (user_id,))
    expense_rows = fetch_all("SELECT SUM(amount) as total FROM transactions WHERE user_id = ? AND type = 'expense'", (user_id,))
    income = income_rows[0]["total"] if income_rows and income_rows[0]["total"] else 0
    expense = expense_rows[0]["total"] if expense_rows and expense_rows[0]["total"] else 0
    return income - expense

def get_savings_balance(user_id):
    # Savings = sum of deposit - sum of withdraw
    deposit_rows = fetch_all("SELECT SUM(amount) as total FROM savings WHERE user_id = ? AND type = 'deposit'", (user_id,))
    withdraw_rows = fetch_all("SELECT SUM(amount) as total FROM savings WHERE user_id = ? AND type = 'withdraw'", (user_id,))
    deposit = deposit_rows[0]["total"] if deposit_rows and deposit_rows[0]["total"] else 0
    withdraw = withdraw_rows[0]["total"] if withdraw_rows and withdraw_rows[0]["total"] else 0
    return deposit - withdraw


def add_user(name, phone):
    from db.connection import get_connection

    conn = get_connection()
    cursor = conn.cursor()

    cursor.execute("""
        INSERT INTO users (name, phone_number)
        VALUES (?, ?)
    """, (name, phone))

    conn.commit()
    conn.close()

def add_transaction(user_id, amount, category, t_type, date):
    from db.connection import get_connection

    conn = get_connection()
    cursor = conn.cursor()

    cursor.execute("""
        INSERT INTO transactions (user_id, amount, category, type, date)
        VALUES (?, ?, ?, ?, ?)
    """, (user_id, amount, category, t_type, date))

    conn.commit()
    conn.close()


def get_all_users():
    conn = get_connection()
    cursor = conn.cursor()

    cursor.execute("SELECT user_id, name FROM users")
    rows = cursor.fetchall()

    conn.close()

    return [
        {
            "user_id": r["user_id"],
            "name": r["name"]
        }
        for r in rows
    ]