from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from typing import List
from datetime import datetime, timedelta
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
    cleaned = text.replace("\n", " ").strip()

                                      
    parts = cleaned.split("2.")
    if len(parts) == 2:
        insight = parts[0].replace("1.", "").strip()
        rec = parts[1].strip()
        if insight and rec:
            return insight, rec

                                                                     
    match = re.match(
        r"[1١][.)]\s*(.+?)\s*[2٢][.)]\s*(.+)",
        cleaned,
    )
    if match:
        return match.group(1).strip(), match.group(2).strip()

                                     
    lines = [line.strip() for line in text.strip().splitlines() if line.strip()]
    if len(lines) >= 2:
        return lines[0], lines[1]

                                                                      
    return fallback_insight, cleaned if cleaned else "استمر في مراقبة مصروفاتك اليومية لتحقيق توازن مالي أفضل."


from openrouter import OpenRouter

                                                          
@router.get("/insights", response_model=InsightsResponse)
def get_user_insights(user_id: int = 1, db: Session = Depends(get_db)):
    cutoff = datetime.utcnow() - timedelta(days=30)
    transactions = db.query(Transaction).filter(
        Transaction.user_id == user_id,
        Transaction.icon_name != "savings",
        Transaction.created_at >= cutoff
    ).all()

    expenses = []
    incomes = []
    cat_sums: dict[str, float] = {}

    for t in transactions:
        try:
            val = float(t.amount.replace(",", "").replace("-", "").replace("+", "").strip())
        except (ValueError, AttributeError):
            continue

        if t.is_expense:
            expenses.append(val)
            if t.category in LEGACY_CATEGORY_MAP:
                cat_label = CATEGORY_LABELS[LEGACY_CATEGORY_MAP[t.category]]
            elif t.category in TransactionCategory.__members__.values():
                cat_label = CATEGORY_LABELS[TransactionCategory(t.category)]
            else:
                cat_label = CATEGORY_LABELS[TransactionCategory.OTHER]
            cat_sums[cat_label] = cat_sums.get(cat_label, 0.0) + val
        else:
            incomes.append(val)

    total_expense = sum(expenses)
    total_income = sum(incomes)
    filtered_cats = {k: v for k, v in cat_sums.items() if k != CATEGORY_LABELS[TransactionCategory.OTHER]}
    top_categories = sorted(filtered_cats.items(), key=lambda x: x[1], reverse=True)[:3]
    summary_str = ", ".join([f"{k}: YR {v:,.0f}" for k, v in top_categories])

    if not transactions:
        return InsightsResponse(
            insight_text="هذا حساب جديد ولم تُسجل فيه معاملات بعد، لذلك لا توجد بيانات كافية لإصدار حكم على وضعك المالي.",
            recommendation_text="ابدأ بإضافة دخلك ومصروفاتك اليومية، وبعد تكوّن البيانات سيعرض لك التطبيق نمط إنفاقك وتوصيات مخصصة بناءً على معاملاتك الفعلية."
        )

    if not expenses and incomes:
        return InsightsResponse(
            insight_text="سجلت دخلاً خلال آخر 30 يومًا دون تسجيل مصروفات، لذلك لا يمكن تقييم نمط الإنفاق حتى الآن.",
            recommendation_text="أضف مصروفاتك اليومية حتى يحسب التطبيق توزيع الإنفاق ونسبة الادخار ويقترح لك خطوات مناسبة."
        )

    if expenses and not incomes:
        fallback_insight = "تم تسجيل مصروفات خلال آخر 30 يومًا، لكن لا توجد بيانات دخل مسجلة للمقارنة معها."
        fallback_rec = "سجل دخلك أيضًا، وابدأ بتحديد حد للإنفاق في أعلى فئاتك حتى يصبح تقييم وضعك المالي أدق."
    elif len(expenses) < 3:
        fallback_insight = "عدد المصروفات المسجلة ما زال محدودًا، لذلك هذا التحليل أولي وليس حكمًا نهائيًا على عادات الإنفاق."
        fallback_rec = "استمر في تسجيل مصروفاتك خلال الأيام القادمة، وسيتحسن التحليل كلما زادت البيانات الفعلية."
    else:
        top_names = " و ".join([k for k, _ in top_categories[:2]]) if top_categories else "الفئات المسجلة"
        expense_ratio = (total_expense / total_income * 100) if total_income > 0 else 0
        if total_income > 0 and expense_ratio >= 90:
            fallback_insight = f"مصروفاتك تمثل نحو {expense_ratio:.0f}% من دخلك المسجل، وأعلى الإنفاق يتركز في {top_names}."
            fallback_rec = "راجع أعلى فئة إنفاق أولًا، وخفّض المصروفات غير الضرورية قبل زيادة أي التزام جديد."
        elif total_income > 0 and expense_ratio >= 70:
            fallback_insight = f"مصروفاتك تمثل نحو {expense_ratio:.0f}% من دخلك، مع تركّز ملحوظ في {top_names}."
            fallback_rec = "ضع سقفًا أسبوعيًا للفئة الأعلى إنفاقًا وحاول الاحتفاظ بجزء ثابت من الدخل قبل الإنفاق."
        else:
            fallback_insight = f"أعلى فئات إنفاقك حاليًا هي {top_names}، والتحليل مبني على معاملاتك المسجلة خلال آخر 30 يومًا."
            fallback_rec = "استمر في تسجيل معاملاتك وخصص مبلغًا ثابتًا للادخار قبل المصروفات الاختيارية."

    api_key = os.getenv("OPENROUTER_API_KEY", "")
    if not api_key:
        return InsightsResponse(insight_text=fallback_insight, recommendation_text=fallback_rec)

    try:
        client = OpenRouter(api_key=api_key)
        result = client.chat.send(
            model="openai/gpt-oss-120b:free",
            messages=[
                {
                    "role": "system",
                    "content": (
                        "أنت مستشار مالي ذكي. حلل البيانات الفعلية فقط ولا تفترض وجود بيانات غير موجودة. "
                        "إذا كانت البيانات قليلة فلا تصف المستخدم بأنه متوازن أو ناجح ماليًا. "
                        "أجب بجملتين بالعربية فقط بدون مقدمات: 1. ملاحظة دقيقة عن البيانات. 2. توصية عملية قابلة للتنفيذ. "
                        "ابدأ كل جملة بالرقم متبوعًا بنقطة."
                    ),
                },
                {
                    "role": "user",
                    "content": (
                        f"عدد المعاملات: {len(transactions)}، عدد المصروفات: {len(expenses)}، "
                        f"إجمالي المصروفات: YR {total_expense:,.0f}، إجمالي الدخل: YR {total_income:,.0f}. "
                        f"أعلى الفئات: {summary_str or 'لا توجد فئات كافية'}."
                    ),
                },
            ],
        )
        ai_text = result.choices[0].message.content or ""
        insight, rec = _parse_ai_response(ai_text, fallback_insight)
        return InsightsResponse(insight_text=insight, recommendation_text=rec)
    except Exception:
        return InsightsResponse(insight_text=fallback_insight, recommendation_text=fallback_rec)
