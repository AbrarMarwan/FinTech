from typing import List, Dict, Any

def detect_personality(transactions: List[Dict[str, Any]], user_financial_data: Dict[str, float]) -> str:
    if not transactions:
        return "لا يوجد بيانات"

    sorted_transactions = sorted(transactions, key=lambda t: t.get("date", ""))

    total_spent = sum(float(t.get("amount", 0.0)) for t in sorted_transactions)
    count = len(sorted_transactions)

    rapid_count = 0
    for i in range(1, count):
        if sorted_transactions[i].get("date") == sorted_transactions[i-1].get("date"):
            rapid_count += 1

    balance = float(user_financial_data.get("balance", 0.0))
    avg_spending = float(user_financial_data.get("average_spending", 0.0))

    if balance > 0:
        high_value_threshold = balance * 0.05
    elif avg_spending > 0:
        high_value_threshold = avg_spending * 1.5
    else:
        high_value_threshold = (total_spent / count) * 1.5 if count > 0 else 0.0

    high_value_total = sum(
        float(t.get("amount", 0.0)) 
        for t in sorted_transactions 
        if float(t.get("amount", 0.0)) > high_value_threshold
    )

    high_value_ratio = (high_value_total / total_spent) if total_spent > 0 else 0.0

    if rapid_count > count * 0.3 or high_value_ratio > 0.6:
        return "شخص اندفاعي"
    elif count < 5:
        return "حذر في الصرف"
    else:
        return "متوازن"