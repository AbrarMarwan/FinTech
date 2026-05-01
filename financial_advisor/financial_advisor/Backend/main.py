from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
import uvicorn

# ===== DB =====
from db.queries import get_all_users, get_transactions

# ===== AI Analysis (Local logic) =====
from ai_engine.analyzer import analyze_behavior
from ai_engine.ai_formatter import enhance_insights
from ai_engine.scoring import calculate_risk_score
from ai_engine.personality import detect_personality

# ===== AI (OpenRouter) =====
from api.ai_service import smart_route

app = FastAPI(title="Financial Advisor API")

@app.get("/analysis/{user_id}")
def analysis(user_id: int):
    users = get_all_users()
    user = next((u for u in users if u["user_id"] == user_id), None)

    if not user:
        raise HTTPException(status_code=404, detail="المستخدم غير موجود")

    transactions = get_transactions(user_id)

    # تحليل داخلي
    raw = analyze_behavior(transactions)

    # Build db_context from the financial_advisor DB's own data
    db_context = _build_db_context(transactions)

    # تحسين باستخدام AI — enriched with live financial context
    ai_result = enhance_insights(raw, user["name"], db_context=db_context)

    # سكورات
    risk = calculate_risk_score(transactions)
    personality = detect_personality(transactions, db_context if db_context else {})

    return {
        "المستخدم": user["name"],
        "الشخصية المالية": personality,
        "درجة الخطورة": risk["score"],
        "مستوى الخطورة": risk["level"],
        "التحليلات": ai_result
    }


def _build_db_context(transactions):
    """Build financial context dict from the user's transaction history."""
    if not transactions:
        return None

    total_expenses = sum(t["amount"] for t in transactions)
    if total_expenses <= 0:
        return None

    # Compute per-category totals
    category_totals = {}
    for t in transactions:
        cat = t.get("category", "أخرى")
        category_totals[cat] = category_totals.get(cat, 0) + t["amount"]

    # Find top expense category
    top_category = max(category_totals, key=category_totals.get)
    top_percentage = round((category_totals[top_category] / total_expenses) * 100, 1)

    return {
        "savings_balance": 0,  # Not available in the AI engine's own DB
        "available_balance": 0,  # Not available in the AI engine's own DB
        "top_expense_category": top_category,
        "top_expense_percentage": top_percentage,
    }

class AskRequest(BaseModel):
    message: str

@app.post("/ask")
def ask(request: AskRequest):
    if not request.message:
        raise HTTPException(status_code=400, detail="No message provided")

    ai_response = smart_route(request.message)

    return {
        "response": ai_response
    }

if __name__ == "__main__":
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)