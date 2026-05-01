from flask import Flask, request, jsonify

# ===== DB =====
from db.queries import get_all_users, get_transactions, get_balance, get_savings_balance

# ===== AI Analysis (Local logic) =====
from ai_engine.analyzer import analyze_behavior
from ai_engine.ai_formatter import enhance_insights
from ai_engine.scoring import calculate_risk_score
from ai_engine.personality import detect_personality

# ===== AI (OpenRouter) =====
from api.ai_service import smart_route


app = Flask(__name__)

# =========================================
# 📊 تحليل المستخدم (النقطة الأساسية في مشروعك)
# =========================================
@app.route("/analysis/<int:user_id>")
def analysis(user_id):
    users = get_all_users()
    user = next((u for u in users if u["user_id"] == user_id), None)

    if not user:
        return jsonify({"error": "المستخدم غير موجود"}), 404

    transactions = get_transactions(user_id)
    balance = get_balance(user_id)
    savings = get_savings_balance(user_id)

    # تحليل داخلي
    raw = analyze_behavior(transactions)

    # Build db_context from the financial_advisor DB's own data
    db_context = _build_db_context(transactions, balance, savings)

    # تحسين باستخدام AI — enriched with live financial context
    ai_result = enhance_insights(raw, user["name"], db_context=db_context)

    # سكورات
    risk = calculate_risk_score(transactions, db_context)
    personality = detect_personality(transactions, db_context if db_context else {})

    # API Contract Alignment: Exact JSON keys matching AiAnalysisData mapping
    return jsonify({
        "user_name": user["name"],
        "personality": personality,
        "risk_score": risk.get("score", 0),
        "risk_level": risk.get("level", "غير معروف"),
        "ai_result": ai_result
    })


def _build_db_context(transactions, balance=0, savings=0):
    """Build financial context dict from the user's transaction history and live balances."""
    # Data Purity: Ensure zero-state is handled gracefully
    total_expenses = sum(t["amount"] for t in transactions) if transactions else 0
    count = len(transactions) if transactions else 0
    avg_spending = (total_expenses / count) if count > 0 else 0

    category_totals = {}
    if transactions:
        for t in transactions:
            cat = t.get("category", "أخرى")
            category_totals[cat] = category_totals.get(cat, 0) + t["amount"]

    top_category = max(category_totals, key=category_totals.get) if category_totals else "لا يوجد"
    top_percentage = round((category_totals[top_category] / total_expenses) * 100, 1) if total_expenses > 0 and category_totals else 0.0

    return {
        "savings_balance": savings,
        "available_balance": balance,
        "balance": balance,  # personality.py expects 'balance'
        "average_spending": avg_spending, # personality.py expects 'average_spending'
        "top_expense_category": top_category,
        "top_expense_percentage": top_percentage,
    }


# =========================================
# 🤖 AI مباشر (أسئلة المستخدم)
# =========================================
@app.route("/ask", methods=["POST"])
def ask():
    data = request.get_json()

    if not data or "message" not in data:
        return jsonify({"error": "No message provided"}), 400

    user_message = data["message"]

    ai_response = smart_route(user_message)

    return jsonify({
        "response": ai_response
    })


# =========================================
# 🚀 تشغيل السيرفر
# =========================================
if __name__ == "__main__":
    app.run(debug=True)