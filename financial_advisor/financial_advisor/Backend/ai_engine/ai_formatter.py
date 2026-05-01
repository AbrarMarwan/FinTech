from openrouter import OpenRouter
import os
from dotenv import load_dotenv

load_dotenv(dotenv_path="../.env")

# Security: API key loaded exclusively from environment — never hardcode secrets
OPENROUTER_API_KEY = os.getenv("OPENROUTER_API_KEY", "")


def enhance_insights(insights, user_name="المستخدم", db_context=None):
    """Generate AI-powered financial recommendations.

    Args:
        insights: Raw analysis data from the behavior analyzer.
        user_name: The user's display name for personalized prompts.
        db_context: Optional dict with live DB metrics:
            - savings_balance: float
            - available_balance: float
            - top_expense_category: str
            - top_expense_percentage: float
    """
    if not insights:
        return []

    # Guard: fail fast if the key is missing from the environment
    if not OPENROUTER_API_KEY:
        print("❌ OPENROUTER_API_KEY not set in environment")
        return _fallback_insights(insights, user_name)

    # Build financial context block from live DB data
    financial_context = ""
    if db_context:
        financial_context = f"""
    الوضع المالي الحالي للمستخدم:
    - رصيد المدخرات: {db_context.get('savings_balance', 0)} ريال
    - الرصيد المتاح: {db_context.get('available_balance', 0)} ريال
    - أعلى فئة مصروفات: {db_context.get('top_expense_category', 'غير محدد')} ({db_context.get('top_expense_percentage', 0)}%)
"""

    prompt = f"""
    أنت مستشار مالي داخل تطبيق ذكي.

    مهمتك:
    إعطاء توصية مالية واحدة فقط بناءً على البيانات، تكون واضحة ومباشرة.

    الشروط:
    - اكتب بالعربية
    - خاطب المستخدم باسمه: {user_name}
    - لا تعطي أكثر من توصية واحدة
    - اجعل التوصية عملية وقابلة للتنفيذ
    - أضف نشاط بسيط (challenge) يحفز المستخدم يبدأ فوراً
    - لا تستخدم ترقيم أو قائمة
    - لا تضف أي جمل ختامية مثل "أنا هنا للمساعدة"
    - الأسلوب يكون تحفيزي وقصير
    {financial_context}
    البيانات:
    {insights}
    """

    try:
        print("🚀 إرسال إلى OpenRouter باستخدام SDK...")
        # Safe log: confirm key is loaded without leaking the actual value
        print("🔑 API KEY loaded:", "Yes" if OPENROUTER_API_KEY else "No")

        with OpenRouter(api_key=OPENROUTER_API_KEY) as client:
            response = client.chat.send(
                model="deepseek/deepseek-chat-v3-0324",
                messages=[
                    {"role": "system", "content": "You are a financial advisor."},
                    {"role": "user", "content": prompt}
                ]
            )

            # ✅ التحقق من وجود نتائج
            if not hasattr(response, 'choices') or not response.choices:
                raise Exception("Empty response from OpenRouter SDK")

            text = response.choices[0].message.content
            print("✅ تم الرد من OpenRouter SDK")

            return [
                line.strip("- ").strip()
                for line in text.split("\n")
                if line.strip()
            ]

    except Exception as e:
        print("❌ فشل OpenRouter SDK، استخدام fallback")
        print("🔥 Error:", e)

        return _fallback_insights(insights, user_name)



def _fallback_insights(insights, user_name):
    """Offline fallback when the AI API is unavailable or misconfigured."""
    fallback = []

    for i in insights:
        if i["type"] == "category":
            fallback.append(
                f"{user_name}، إن {i['category']} تستهلك {i['percentage']}٪ من مصاريفك، حاول تقللها."
            )
        elif i["type"] == "late_spending":
            fallback.append(
                f"{user_name}، صرفك يزيد بنهاية الشهر، حاول تقسم ميزانيتك."
            )

    return fallback