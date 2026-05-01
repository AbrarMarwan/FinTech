from collections import defaultdict
from datetime import datetime

def analyze_behavior(transactions):
    if not transactions:
        return []

    insights = []
    total = sum(t["amount"] for t in transactions)

    categories = defaultdict(float)

    for t in transactions:
        categories[t["category"]] += t["amount"]

    top_category = max(categories, key=categories.get)
    percentage = (categories[top_category] / total) * 100

    insights.append({
        "type": "category",
        "category": top_category,
        "percentage": round(percentage, 2)
    })

    first = 0
    last = 0

    for t in transactions:
        day = datetime.strptime(t["date"], "%Y-%m-%d").day
        if day <= 15:
            first += t["amount"]
        else:
            last += t["amount"]

    if last > first * 1.3:
        insights.append({
            "type": "late_spending"
        })

    return insights