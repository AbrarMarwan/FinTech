from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from typing import List
import os
import re
from openrouter import OpenRouter
from database import get_db
from models import Transaction
from schemas import ExpenseAnalysisResponse, FinancialSummaryResponse, InsightsResponse
from crud import get_expense_analysis, get_financial_summary
from constants import TransactionCategory, CATEGORY_LABELS, LEGACY_CATEGORY_MAP

router = APIRouter(prefix="/analysis", tags=["Analysis"])

@router.get("/expenses", response_model=List[ExpenseAnalysisResponse])
def read_analysis(user_id: int = 1, db: Session = Depends(get_db)):
    return get_expense_analysis(db, user_id)

@router.get("/summary", response_model=FinancialSummaryResponse)
def read_financial_summary(user_id: int = 1, db: Session = Depends(get_db)):
    return get_financial_summary(db, user_id)


def _parse_ai_response(text: str, fallback_insight: str) -> tuple[str, str]:
    """Robustly parse AI output into (insight, recommendation).

    Supports multiple formats:
      - "1. ... 2. ..."  (numbered list)
      - Two lines separated by newlines
      - Single block of text (falls back gracefully)
    """
    cleaned = text.replace("\n", " ").strip()

    # Strategy 1: Split on "2." marker
    parts = cleaned.split("2.")
    if len(parts) == 2:
        insight = parts[0].replace("1.", "").strip()
        rec = parts[1].strip()
        if insight and rec:
            return insight, rec

    # Strategy 2: Regex for numbered sentences — e.g. "1) ... 2) ..."
    match = re.match(
        r"[1١][.)]\s*(.+?)\s*[2٢][.)]\s*(.+)",
        cleaned,
    )
    if match:
        return match.group(1).strip(), match.group(2).strip()

    # Strategy 3: Two non-empty lines
    lines = [line.strip() for line in text.strip().splitlines() if line.strip()]
    if len(lines) >= 2:
        return lines[0], lines[1]

    # Strategy 4: Fallback — use the entire text as the recommendation
    return fallback_insight, cleaned if cleaned else "استمر في مراقبة مصروفاتك اليومية لتحقيق توازن مالي أفضل."


from openrouter import OpenRouter
from cachetools import TTLCache

# Cache storing AI insights per user_id for up to 12 hours
insights_cache = TTLCache(maxsize=1000, ttl=12 * 60 * 60)

def invalidate_user_insights_cache(user_id: int):
    """Utility to clear cache when new transactions occur. 
    Call this from routers/transactions.py after adding/deleting a transaction."""
    if user_id in insights_cache:
        del insights_cache[user_id]


@router.get("/insights", response_model=InsightsResponse)
def get_user_insights(user_id: int = 1, db: Session = Depends(get_db)):
    """Fetch real transactions, aggregate, and generate AI insights via OpenRouter.
    FastAPI offloads sync routes to a threadpool, preventing event loop blocks natively."""
    
    # Check cache first to avoid slow network I/O
    cached_result = insights_cache.get(user_id)
    if cached_result:
        return cached_result

    # Filter out internal savings deposits so AI focuses on true expenses
    transactions = db.query(Transaction).filter(
        Transaction.user_id == user_id,
        Transaction.is_expense == True,
        Transaction.icon_name != "savings"
    ).all()

    cat_sums: dict[str, float] = {}
    for t in transactions:
        try:
            val = float(t.amount.replace(",", "").replace("-", "").replace("+", "").strip())
            
            # Normalize category string to a display name (Arabic)
            # If it's a legacy string, map it to Enum then label
            if t.category in LEGACY_CATEGORY_MAP:
                cat_label = CATEGORY_LABELS[LEGACY_CATEGORY_MAP[t.category]]
            elif t.category in TransactionCategory.__members__.values():
                cat_label = CATEGORY_LABELS[TransactionCategory(t.category)]
            else:
                cat_label = CATEGORY_LABELS.get(TransactionCategory.OTHER, CATEGORY_LABELS[TransactionCategory.OTHER])
                
            cat_sums[cat_label] = cat_sums.get(cat_label, 0.0) + val
        except ValueError:
            pass

    # AI Prompt Integrity: Filter out the "Other" category so advice is actionable.
    other_label = CATEGORY_LABELS[TransactionCategory.OTHER]
    filtered_cats = {k: v for k, v in cat_sums.items() if k != other_label}
    
    top_categories = sorted(filtered_cats.items(), key=lambda x: x[1], reverse=True)[:3]
    summary_str = ", ".join([f"{k}: YR {v:,.0f}" for k, v in top_categories])

    if top_categories:
        top_names = " و ".join([k for k, v in top_categories[:2]])
        fallback_insight = f"تحليلك يوضح أن نفقاتك تتركز على {top_names} بشكل أساسي هذا الشهر."
    else:
        fallback_insight = "تحليلك يظهر استهلاكاً متوازناً، استمر في إدارة نفقاتك بحكمة."

    fallback_rec = "استمر في مراقبة مصروفاتك اليومية لتحقيق توازن مالي أفضل."

    api_key = os.getenv("OPENROUTER_API_KEY", "")
    if not api_key:
        return InsightsResponse(insight_text=fallback_insight, recommendation_text=fallback_rec)

    try:
        # Using synchronous API call; FastAPI worker thread handles this safely
        client = OpenRouter(api_key=api_key)
        result = client.chat.send(
            model="openai/gpt-oss-120b:free",
            messages=[
                {
                    "role": "system",
                    "content": (
                        "أنت مستشار مالي ذكي. أجب بجملتين بالعربية فقط بدون مقدمات:\n"
                        "1. ملاحظة ودية عن عادات الإنفاق.\n"
                        "2. توصية عملية لتحسين الادخار.\n"
                        "ابدأ كل جملة بالرقم متبوعاً بنقطة."
                    ),
                },
                {
                    "role": "user",
                    "content": f"بيانات إنفاق المستخدم الأعلى: {summary_str}",
                },
            ],
        )

        ai_text = result.choices[0].message.content or ""
        insight, rec = _parse_ai_response(ai_text, fallback_insight)
        
        response = InsightsResponse(insight_text=insight, recommendation_text=rec)
        # Store in cache
        insights_cache[user_id] = response
        return response

    except Exception:
        # Graceful fallback per architectural constraints
        return InsightsResponse(
            insight_text=fallback_insight,
            recommendation_text=fallback_rec,
        )
