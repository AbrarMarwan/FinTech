def calculate_risk_score(transactions, db_context):
    """
    Calculates a dynamic risk score based on proportional user data.
    Eliminates all hardcoded static thresholds.
    """
    if not transactions:
        return {"score": 0, "level": "لا توجد بيانات"}

    # Dynamic Thresholds from Context
    balance = db_context.get("available_balance", 0)
    avg_spending = db_context.get("average_spending", 0)
    savings = db_context.get("savings_balance", 0)
    
    # Proportional "High Value" Threshold: 10% of balance or 2x avg spending
    high_threshold = max(balance * 0.1, avg_spending * 2) if balance > 0 or avg_spending > 0 else 500
    
    score = 0
    total_spent = sum(t["amount"] for t in transactions if t.get("is_expense", True))

    # 1. Proportional Spending Risk (Spending vs Balance)
    if balance > 0:
        spending_ratio = total_spent / balance
        if spending_ratio > 0.8:
            score += 40
        elif spending_ratio > 0.5:
            score += 20

    # 2. Volatility Risk (Proportion of Large Transactions)
    high_value_txns = [t["amount"] for t in transactions if t["amount"] > high_threshold]
    if total_spent > 0:
        high_value_ratio = sum(high_value_txns) / total_spent
        if high_value_ratio > 0.4:
            score += 30
        elif high_value_ratio > 0.2:
            score += 15

    # 3. Liquidity Risk (Spending vs Savings)
    if savings > 0:
        if total_spent > savings:
            score += 30
        elif total_spent > (savings * 0.5):
            score += 15
    elif total_spent > 0: # No savings but spending
        score += 30

    # Cap score at 100
    score = min(score, 100)

    if score < 30:
        level = "خطورة منخفضة"
    elif score < 70:
        level = "خطورة متوسطة"
    else:
        level = "خطورة عالية"

    return {"score": score, "level": level}