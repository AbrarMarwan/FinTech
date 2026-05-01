from sqlalchemy.orm import Session
from sqlalchemy import func
from datetime import datetime, timedelta
import random
from models import User, Wallet, Transaction, GoldPrice, CurrencyRate, SavingsTransaction, ExpenseAnalysis
from schemas import (
    TransactionCreate, GoldPriceUpdate, CurrencyRateBase,
    SavingsTransactionCreate, ExpenseAnalysisBase, ExchangeRequest, GoldCalcRequest
)
from constants import TransactionCategory, CATEGORY_LABELS, LEGACY_CATEGORY_MAP
from typing import List, Optional

# ========== USERS ==========
def get_users(db: Session):
    return db.query(User).all()

def get_user(db: Session, user_id: int):
    return db.query(User).filter(User.id == user_id).first()

def seed_users(db: Session):
    """Create seed users on first run — idempotent."""
    # Before seeding, explicitly execute delete operations on the transactions (and legacy expense_analysis) tables to clear out old incompatible schemas.
    # We only clear if old ExpenseAnalysis data exists to avoid wiping data on every restart.
    if db.query(ExpenseAnalysis).count() > 0:
        db.query(ExpenseAnalysis).delete()
        db.query(Transaction).delete()
        db.commit()

    if db.query(User).count() > 0:
        # Re-seed if transactions were cleared
        if db.query(Transaction).count() == 0:
            seed_initial_transactions(db, user_id=1)
            seed_initial_transactions(db, user_id=2)
            seed_initial_transactions(db, user_id=3)
        return
    users = [
        User(name="أحمد محمد", phone_number="777000001"),
        User(name="سارة علي", phone_number="777000002"),
        User(name="خالد عمر", phone_number="777000003"),
    ]
    db.add_all(users)
    db.commit()

    # Create wallets with different balances for each user
    wallets = [
        Wallet(user_id=1, total_balance=1250500.0, available_amount=980000.0, savings_amount=270500.0),
        Wallet(user_id=2, total_balance=850000.0, available_amount=650000.0, savings_amount=200000.0),
        Wallet(user_id=3, total_balance=2100000.0, available_amount=1800000.0, savings_amount=300000.0),
    ]
    db.add_all(wallets)
    db.commit()

    # Seed initial savings transactions to match the wallet savings_amount
    for wallet in wallets:
        db.add(SavingsTransaction(
            user_id=wallet.user_id,
            amount=wallet.savings_amount,
            is_deposit=True
        ))
    db.commit()

    # Seed transactions per user
    seed_initial_transactions(db, user_id=1)
    seed_initial_transactions(db, user_id=2)
    seed_initial_transactions(db, user_id=3)

# ========== WALLET ==========
def get_wallet(db: Session, user_id: int = 1):
    wallet = db.query(Wallet).filter(Wallet.user_id == user_id).first()
    if not wallet:
        wallet = Wallet(
            user_id=user_id,
            total_balance=1250500.0,
            available_amount=980000.0,
            savings_amount=270500.0,
        )
        db.add(wallet)
        db.commit()
        db.refresh(wallet)
    return wallet

def update_wallet_balance(db: Session, user_id: int, total: float, available: float, savings: float):
    wallet = get_wallet(db, user_id)
    wallet.total_balance = total
    wallet.available_amount = available
    wallet.savings_amount = savings
    db.commit()
    db.refresh(wallet)
    return wallet

# ========== TRANSACTIONS ==========
def get_transactions(db: Session, user_id: int = 1, skip: int = 0, limit: int = 100):
    return (
        db.query(Transaction)
        .filter(Transaction.user_id == user_id)
        .order_by(Transaction.created_at.desc())
        .offset(skip)
        .limit(limit)
        .all()
    )

def create_transaction(db: Session, user_id: int, transaction: TransactionCreate):
    db_transaction = Transaction(user_id=user_id, **transaction.dict())
    db.add(db_transaction)
    db.commit()
    db.refresh(db_transaction)
    return db_transaction

def seed_initial_transactions(db: Session, user_id: int = 1):
    """
    Generates behavioral-specific data (filling up to 150 transactions) to trigger 
    AI personas and provide deep historical data for charts.
    """
    target_count = 150
    current_count = db.query(Transaction).filter(Transaction.user_id == user_id).count()
    
    if current_count >= target_count:
        return
    
    num_txns = target_count - current_count
    
    # Configuration for mock data with more variety
    expense_configs = [
        {"title": "سوبر ماركت الهدى", "icon": "shopping_cart", "cat": TransactionCategory.SHOPPING, "range": (5000, 35000)},
        {"title": "فاتورة الكهرباء", "icon": "receipt_long", "cat": TransactionCategory.BILLS, "range": (8000, 20000)},
        {"title": "إيجار الشقة", "icon": "home", "cat": TransactionCategory.RENT, "range": (150000, 200000)},
        {"title": "مطعم الرومانسية", "icon": "restaurant", "cat": TransactionCategory.FOOD, "range": (10000, 45000)},
        {"title": "كافيه ستاربكس", "icon": "local_cafe", "cat": TransactionCategory.FOOD, "range": (2000, 8000)},
        {"title": "صيدلية الدواء", "icon": "local_pharmacy", "cat": TransactionCategory.HEALTH, "range": (3000, 15000)},
        {"title": "شحن رصيد", "icon": "receipt_long", "cat": TransactionCategory.BILLS, "range": (1000, 10000)},
        {"title": "بنزين السيارة", "icon": "shopping_cart", "cat": TransactionCategory.SHOPPING, "range": (15000, 45000)},
        {"title": "شراء ملابس", "icon": "shopping_cart", "cat": TransactionCategory.SHOPPING, "range": (20000, 120000)},
        {"title": "هدايا عائلية", "icon": "person", "cat": TransactionCategory.OTHER, "range": (5000, 25000)},
        {"title": "اشتراك نت", "icon": "receipt_long", "cat": TransactionCategory.BILLS, "range": (15000, 35000)},
        {"title": "وجبات سريعة", "icon": "restaurant", "cat": TransactionCategory.FOOD, "range": (5000, 15000)},
    ]
    
    inflow_configs = [
        {"title": "راتب الشهر", "icon": "account_balance", "cat": TransactionCategory.OTHER, "range": (450000, 700000)},
        {"title": "تحويل وارد", "icon": "person", "cat": TransactionCategory.OTHER, "range": (20000, 100000)},
        {"title": "مكافأة عمل", "icon": "send", "cat": TransactionCategory.OTHER, "range": (30000, 80000)},
    ]
    
    now = datetime.utcnow()
    initial_transactions = []
    
    # Behavioral patterns
    rapid_dates = [now - timedelta(days=random.randint(1, 45)) for _ in range(8)]
    
    for i in range(num_txns):
        # 90% expenses to satisfy "seed more expense transactions" request
        is_expense = random.random() < 0.90
        
        if is_expense:
            config = random.choice(expense_configs)
            
            # High-Value Pattern for User 3 (10% of 2.1M = 210,000)
            if user_id == 3 and random.random() < 0.6:
                amount_val = random.randint(120000, 500000)
            else:
                amount_val = random.randint(config["range"][0], config["range"][1])
            
            amount_str = f"-{amount_val:,.0f}"
        else:
            config = random.choice(inflow_configs)
            amount_val = random.randint(config["range"][0], config["range"][1])
            amount_str = f"+{amount_val:,.0f}"

        # Temporal logic
        if user_id == 2 and random.random() < 0.5:
            txn_time = random.choice(rapid_dates)
        else:
            days_ago = random.randint(0, 90)
            txn_time = now - timedelta(days=days_ago, seconds=random.randint(0, 86400))
        
        display_time = txn_time.strftime("%Y-%m-%d %I:%M %p")

        initial_transactions.append(Transaction(
            user_id=user_id,
            title=config["title"],
            amount=amount_str,
            time=display_time,
            is_expense=is_expense,
            icon_name=config["icon"],
            category=config["cat"],
            created_at=txn_time
        ))

    db.add_all(initial_transactions)
    db.commit()
# ========== GOLD PRICES ==========
def get_gold_prices(db: Session):
    prices = db.query(GoldPrice).first()
    if not prices:
        prices = GoldPrice()
        db.add(prices)
        db.commit()
        db.refresh(prices)
    return prices

def update_gold_prices(db: Session, update: GoldPriceUpdate):
    prices = get_gold_prices(db)
    data = update.dict(exclude_unset=True)
    for key, value in data.items():
        setattr(prices, key, value)
    db.commit()
    db.refresh(prices)
    return prices

def simulate_gold_price_change(db: Session):
    """محاكاة تغير أسعار الذهب للـ WebSocket"""
    prices = get_gold_prices(db)
    change_24 = random.uniform(-200, 200)
    prices.karat_24 = max(50000, prices.karat_24 + change_24)
    prices.karat_21 = prices.karat_24 * 0.875
    prices.karat_18 = prices.karat_24 * 0.75
    db.commit()
    db.refresh(prices)
    return prices

def calculate_gold_price(db: Session, calc: GoldCalcRequest):
    prices = get_gold_prices(db)
    price_map = {"24": prices.karat_24, "21": prices.karat_21, "18": prices.karat_18}
    price_per_gram = price_map.get(calc.karat, prices.karat_24)
    return {
        "grams": calc.grams,
        "karat": calc.karat,
        "price_per_gram": price_per_gram,
        "total_price": calc.grams * price_per_gram
    }

# ========== CURRENCY RATES ==========
def get_currency_rates(db: Session):
    rates = db.query(CurrencyRate).all()
    if not rates:
        initial = [
            CurrencyRate(currency_name="دولار أمريكي", rate=535.00, change="+0.2%"),
            CurrencyRate(currency_name="ريال سعودي", rate=141.20, change="-0.05%"),
        ]
        for r in initial:
            db.add(r)
        db.commit()
        rates = db.query(CurrencyRate).all()
    return rates

def update_currency_rate(db: Session, currency_name: str, new_rate: float, change: str):
    rate = db.query(CurrencyRate).filter(CurrencyRate.currency_name == currency_name).first()
    if rate:
        rate.rate = new_rate
        rate.change = change
        db.commit()
        db.refresh(rate)
    return rate

def calculate_exchange(db: Session, req: ExchangeRequest):
    rates = get_currency_rates(db)
    rate_map = {r.currency_name: r.rate for r in rates}

    currency_names = {"USD": "دولار أمريكي", "SAR": "ريال سعودي"}
    target_name = currency_names.get(req.target_currency, "دولار أمريكي")
    rate = rate_map.get(target_name, 535.0)

    return {
        "amount_yer": req.amount_yer,
        "target_currency": req.target_currency,
        "converted_amount": round(req.amount_yer / rate, 2) if rate > 0 else 0,
        "rate": rate
    }

# ========== SAVINGS — STRICT MATH ENFORCEMENT ==========
def get_savings_balance(db: Session, user_id: int = 1):
    wallet = get_wallet(db, user_id)
    deposits = (
        db.query(func.sum(SavingsTransaction.amount))
        .filter(SavingsTransaction.user_id == user_id, SavingsTransaction.is_deposit == True)
        .scalar() or 0
    )
    withdrawals = (
        db.query(func.sum(SavingsTransaction.amount))
        .filter(SavingsTransaction.user_id == user_id, SavingsTransaction.is_deposit == False)
        .scalar() or 0
    )
    return {
        "total_savings": wallet.savings_amount,
        "total_deposits": deposits,
        "total_withdrawals": withdrawals
    }

def create_savings_transaction(db: Session, user_id: int, transaction: SavingsTransactionCreate):
    """Atomic savings operation with strict balance validation.

    The entire deposit/withdrawal + wallet update happens in a single
    db.commit() — SQLAlchemy's unit-of-work pattern ensures atomicity.
    If any step fails, nothing is committed.
    """
    wallet = get_wallet(db, user_id)

    if not transaction.is_deposit:
        # VALIDATION: withdrawal must not exceed savings
        if transaction.amount > wallet.savings_amount:
            raise ValueError("رصيد المدخرات غير كافٍ")
        # ATOMIC: move money savings → available
        wallet.savings_amount -= transaction.amount
        wallet.available_amount += transaction.amount
        
        # Create standard transaction for the ledger
        ledger_title = "سحب من الادخار"
        ledger_amount = f"+{transaction.amount:,.0f}"
        ledger_is_expense = False
    else:
        # VALIDATION: deposit must not exceed available balance
        if transaction.amount > wallet.available_amount:
            raise ValueError("الرصيد المتاح غير كافٍ")
        # ATOMIC: move money available → savings
        wallet.available_amount -= transaction.amount
        wallet.savings_amount += transaction.amount
        
        # Create standard transaction for the ledger
        ledger_title = "إيداع للادخار"
        ledger_amount = f"-{transaction.amount:,.0f}"
        ledger_is_expense = True

    # Recompute total (should always = available + savings)
    wallet.total_balance = wallet.available_amount + wallet.savings_amount

    db_trans = SavingsTransaction(
        amount=transaction.amount,
        is_deposit=transaction.is_deposit,
        user_id=user_id
    )
    db.add(db_trans)
    
    # Unified Ledger Sync
    unified_trans = Transaction(
        user_id=user_id,
        title=ledger_title,
        amount=ledger_amount,
        time="الآن",
        is_expense=ledger_is_expense,
        icon_name="savings"
    )
    db.add(unified_trans)
    
    db.commit()
    db.refresh(db_trans)
    db.refresh(wallet)
    return db_trans

# ========== EXPENSE ANALYSIS ==========
def get_expense_analysis(db: Session, user_id: int = 1):
    # 1. Strict Outflow Filtering: Exclude all inflow/deposit transactions
    transactions = db.query(Transaction).filter(
        Transaction.user_id == user_id, 
        Transaction.is_expense == True,
        Transaction.icon_name != "savings"
    ).all()

    # Enum-based aggregation map
    category_sums: dict[TransactionCategory, float] = {}
    total_expense = 0.0

    # 3. Dynamic Grouping: Map icon_name to a logical category Enum
    icon_to_cat = {
        "shopping_cart": TransactionCategory.SHOPPING,
        "receipt_long": TransactionCategory.BILLS,
        "restaurant": TransactionCategory.FOOD,
        "local_cafe": TransactionCategory.FOOD,
        "local_pharmacy": TransactionCategory.HEALTH,
        "home": TransactionCategory.RENT,
        "savings": TransactionCategory.SAVINGS
    }

    for txn in transactions:
        # Data Type Cleaning: Strip commas and signs, then cast to float
        try:
            clean_amount_str = txn.amount.replace(",", "").replace("-", "").replace("+", "").strip()
            amount_val = float(clean_amount_str)
        except ValueError:
            amount_val = 0.0
            
        # 2. Backward Compatibility & Normalization
        # Check if current txn.category is a legacy Arabic string and map it to Enum
        if txn.category in LEGACY_CATEGORY_MAP:
            cat_enum = LEGACY_CATEGORY_MAP[txn.category]
        elif txn.category in TransactionCategory.__members__.values():
            cat_enum = TransactionCategory(txn.category)
        else:
            # Fallback to icon mapping or OTHER
            cat_enum = icon_to_cat.get(txn.icon_name, TransactionCategory.OTHER)

        category_sums[cat_enum] = category_sums.get(cat_enum, 0.0) + amount_val
        total_expense += amount_val

    # UI Color mapping using Enum keys
    category_colors = {
        TransactionCategory.SHOPPING: {"start": "#E57373", "end": "#C62828"},
        TransactionCategory.BILLS: {"start": "#DCE775", "end": "#9E9D24"},
        TransactionCategory.FOOD: {"start": "#81C784", "end": "#388E3C"},
        TransactionCategory.HEALTH: {"start": "#4DB6AC", "end": "#00695C"},
        TransactionCategory.RENT: {"start": "#4FC3F7", "end": "#0277BD"},
        TransactionCategory.SAVINGS: {"start": "#BA68C8", "end": "#7B1FA2"},
        TransactionCategory.OTHER: {"start": "#FFB74D", "end": "#F57C00"},
    }
    default_color = {"start": "#64B5F6", "end": "#1976D2"}

    analysis_list = []
    mock_id = 1
    
    sorted_categories = sorted(category_sums.items(), key=lambda x: x[1], reverse=True)

    for cat_enum, amount in sorted_categories:
        percentage = (amount / total_expense * 100) if total_expense > 0 else 0.0
        colors = category_colors.get(cat_enum, default_color)
        
        analysis_list.append({
            "id": mock_id,
            "user_id": user_id,
            "category": CATEGORY_LABELS.get(cat_enum, CATEGORY_LABELS.get(TransactionCategory.OTHER, "أخرى")), # Display Arabic label to UI
            "amount": amount,
            "percentage": round(percentage, 2),
            "color_start": colors["start"],
            "color_end": colors["end"]
        })
        mock_id += 1

    return analysis_list

def get_financial_summary(db: Session, user_id: int = 1):
    from datetime import datetime, timedelta
    
    now = datetime.utcnow()
    # Define time periods: Current (last 30 days) vs Previous (30-60 days ago)
    # Using 30 days as a standard financial month approximation
    current_period_start = now - timedelta(days=30)
    previous_period_start = now - timedelta(days=60)
    
    # Exclude internal transfers (like savings deposits/withdrawals) from financial summary
    transactions = db.query(Transaction).filter(
        Transaction.user_id == user_id,
        Transaction.icon_name != "savings"
    ).all()
    
    curr_in = 0.0
    curr_out = 0.0
    prev_in = 0.0
    prev_out = 0.0
    
    for txn in transactions:
        try:
            # Safely strip string formatting and cast to float
            val = float(txn.amount.replace(",", "").replace("-", "").replace("+", "").strip())
        except ValueError:
            val = 0.0
            
        # Fallback to current time if created_at is missing to ensure it counts in current period
        txn_date = txn.created_at or now
        
        # Categorize into exact periods
        if txn_date >= current_period_start:
            if txn.is_expense:
                curr_out += val
            else:
                curr_in += val
        elif previous_period_start <= txn_date < current_period_start:
            if txn.is_expense:
                prev_out += val
            else:
                prev_in += val

    # Strict Percentage Formula: ((Current - Previous) / Previous) * 100
    # Includes Zero-Division Safety fallback.
    def calc_growth(curr: float, prev: float) -> float:
        if prev == 0:
            # If previous period was 0, but current is > 0, mathematically it's infinite growth.
            # We cap this logically at 100% for UI purposes. If both are 0, growth is 0%.
            return 100.0 if curr > 0 else 0.0
        return ((curr - prev) / prev) * 100.0

    inflow_growth = calc_growth(curr_in, prev_in)
    outflow_growth = calc_growth(curr_out, prev_out)
    
    return {
        "current_inflow": curr_in,
        "inflow_growth_percentage": round(inflow_growth, 2),
        "current_outflow": curr_out,
        "outflow_growth_percentage": round(outflow_growth, 2)
    }
