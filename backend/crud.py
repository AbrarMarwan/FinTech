from sqlalchemy.orm import Session
from sqlalchemy import func
from datetime import datetime, timedelta
import random
import hashlib
from models import User, Wallet, Transaction, GoldPrice, CurrencyRate, SavingsTransaction, ExpenseAnalysis
from schemas import (
    TransactionCreate, GoldPriceUpdate, CurrencyRateBase,
    SavingsTransactionCreate, ExpenseAnalysisBase, ExchangeRequest, GoldCalcRequest
)
from constants import TransactionCategory, CATEGORY_LABELS, LEGACY_CATEGORY_MAP
from typing import List, Optional

                             
def get_users(db: Session):
    return db.query(User).all()

def get_user(db: Session, user_id: int):
    return db.query(User).filter(User.id == user_id).first()

def hash_password(password: str) -> str:
    return hashlib.sha256(password.encode("utf-8")).hexdigest()

def authenticate_user(db: Session, phone_number: str, password: str):
    user = db.query(User).filter(User.phone_number == phone_number).first()
    if not user or not user.password_hash:
        return None
    return user if user.password_hash == hash_password(password) else None

def create_authenticated_user(db: Session, name: str, phone_number: str, password: str):
    existing = db.query(User).filter(User.phone_number == phone_number).first()
    if existing:
        return None
    user = User(name=name, phone_number=phone_number, password_hash=hash_password(password))
    db.add(user)
    db.commit()
    db.refresh(user)
    get_wallet(db, user.id)
    return user

def seed_users(db: Session):
    seeded_password = hash_password("123456")
    users = db.query(User).all()
    changed = False
    for user in users:
        if not user.password_hash:
            user.password_hash = seeded_password
            changed = True
    if changed:
        db.commit()


def get_wallet(db: Session, user_id: int = 1):
    wallet = db.query(Wallet).filter(Wallet.user_id == user_id).first()
    if not wallet:
        wallet = Wallet(
            user_id=user_id,
            total_balance=0.0,
            available_amount=0.0,
            savings_amount=0.0,
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

                                    
def get_transactions(db: Session, user_id: int = 1, skip: int = 0, limit: int = 100):
    return (
        db.query(Transaction)
        .filter(Transaction.user_id == user_id)
        .order_by(Transaction.created_at.desc())
        .offset(skip)
        .limit(limit)
        .all()
    )

def _signed_amount(value: str) -> float:
    return float(value.replace(",", "").strip())

def _normalized_transaction_amount(transaction: TransactionCreate) -> str:
    raw = abs(_signed_amount(transaction.amount))
    if raw <= 0:
        raise ValueError("المبلغ يجب أن يكون أكبر من صفر")
    return f"{'-' if transaction.is_expense else '+'}{raw:g}"

def _apply_transaction_to_wallet(db: Session, user_id: int, delta: float):
    wallet = get_wallet(db, user_id)
    wallet.available_amount += delta
    wallet.total_balance += delta
    db.add(wallet)

def create_transaction(db: Session, user_id: int, transaction: TransactionCreate):
    normalized_amount = _normalized_transaction_amount(transaction)
    signed_amount = _signed_amount(normalized_amount)
    wallet = get_wallet(db, user_id)
    if signed_amount < 0 and abs(signed_amount) > wallet.available_amount:
        raise ValueError("الرصيد المتاح غير كافٍ")
    payload = transaction.dict()
    payload["amount"] = normalized_amount
    db_transaction = Transaction(user_id=user_id, **payload)
    db.add(db_transaction)
    _apply_transaction_to_wallet(db, user_id, signed_amount)
    db.commit()
    db.refresh(db_transaction)
    return db_transaction


def get_transaction(db: Session, transaction_id: int, user_id: int):
    return db.query(Transaction).filter(
        Transaction.id == transaction_id,
        Transaction.user_id == user_id
    ).first()

def update_transaction(db: Session, transaction_id: int, user_id: int, transaction: TransactionCreate):
    db_transaction = get_transaction(db, transaction_id, user_id)
    if not db_transaction:
        return None
    old_amount = _signed_amount(db_transaction.amount)
    normalized_amount = _normalized_transaction_amount(transaction)
    new_amount = _signed_amount(normalized_amount)
    wallet = get_wallet(db, user_id)
    projected_available = wallet.available_amount + (new_amount - old_amount)
    if projected_available < 0:
        raise ValueError("الرصيد المتاح غير كافٍ")
    payload = transaction.dict()
    payload["amount"] = normalized_amount
    for key, value in payload.items():
        setattr(db_transaction, key, value)
    _apply_transaction_to_wallet(db, user_id, new_amount - old_amount)
    db.commit()
    db.refresh(db_transaction)
    return db_transaction

def delete_transaction(db: Session, transaction_id: int, user_id: int):
    db_transaction = get_transaction(db, transaction_id, user_id)
    if not db_transaction:
        return False
    _apply_transaction_to_wallet(db, user_id, -_signed_amount(db_transaction.amount))
    db.delete(db_transaction)
    db.commit()
    return True

def seed_initial_transactions(db: Session, user_id: int = 1):
    target_count = 150
    current_count = db.query(Transaction).filter(Transaction.user_id == user_id).count()
    
    if current_count >= target_count:
        return
    
    num_txns = target_count - current_count
    
                                                   
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
    
                         
    rapid_dates = [now - timedelta(days=random.randint(1, 45)) for _ in range(8)]
    
    for i in range(num_txns):
                                                                          
        is_expense = random.random() < 0.90
        
        if is_expense:
            config = random.choice(expense_configs)
            
                                                                   
            if user_id == 3 and random.random() < 0.6:
                amount_val = random.randint(120000, 500000)
            else:
                amount_val = random.randint(config["range"][0], config["range"][1])
            
            amount_str = f"-{amount_val:,.0f}"
        else:
            config = random.choice(inflow_configs)
            amount_val = random.randint(config["range"][0], config["range"][1])
            amount_str = f"+{amount_val:,.0f}"

                        
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
    wallet = get_wallet(db, user_id)

    if not transaction.is_deposit:
                                                        
        if transaction.amount > wallet.savings_amount:
            raise ValueError("رصيد المدخرات غير كافٍ")
                                                
        wallet.savings_amount -= transaction.amount
        wallet.available_amount += transaction.amount
        
                                                    
        ledger_title = "سحب من الادخار"
        ledger_amount = f"+{transaction.amount:,.0f}"
        ledger_is_expense = False
    else:
                                                               
        if transaction.amount > wallet.available_amount:
            raise ValueError("الرصيد المتاح غير كافٍ")
                                                
        wallet.available_amount -= transaction.amount
        wallet.savings_amount += transaction.amount
        
                                                    
        ledger_title = "إيداع للادخار"
        ledger_amount = f"-{transaction.amount:,.0f}"
        ledger_is_expense = True

                                                           
    wallet.total_balance = wallet.available_amount + wallet.savings_amount

    db_trans = SavingsTransaction(
        amount=transaction.amount,
        is_deposit=transaction.is_deposit,
        user_id=user_id
    )
    db.add(db_trans)
    
                         
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

                                        
def get_expense_analysis(db: Session, user_id: int = 1):
                                                                          
    cutoff = datetime.utcnow() - timedelta(days=30)
    transactions = db.query(Transaction).filter(
        Transaction.user_id == user_id,
        Transaction.is_expense == True,
        Transaction.icon_name != "savings",
        Transaction.created_at >= cutoff
    ).all()

                                
    category_sums: dict[TransactionCategory, float] = {}
    total_expense = 0.0

                                                                   
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
                                                                        
        try:
            clean_amount_str = txn.amount.replace(",", "").replace("-", "").replace("+", "").strip()
            amount_val = float(clean_amount_str)
        except ValueError:
            amount_val = 0.0
            
                                                   
                                                                                    
        if txn.category in LEGACY_CATEGORY_MAP:
            cat_enum = LEGACY_CATEGORY_MAP[txn.category]
        elif txn.category in TransactionCategory.__members__.values():
            cat_enum = TransactionCategory(txn.category)
        else:
                                               
            cat_enum = icon_to_cat.get(txn.icon_name, TransactionCategory.OTHER)

        category_sums[cat_enum] = category_sums.get(cat_enum, 0.0) + amount_val
        total_expense += amount_val

                                      
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
            "category": CATEGORY_LABELS.get(cat_enum, CATEGORY_LABELS.get(TransactionCategory.OTHER, "أخرى")),                             
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
                                                                              
                                                               
    current_period_start = now - timedelta(days=30)
    previous_period_start = now - timedelta(days=60)
    
                                                                                           
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
                                                              
            val = float(txn.amount.replace(",", "").replace("-", "").replace("+", "").strip())
        except ValueError:
            val = 0.0
            
                                                                                                 
        txn_date = txn.created_at or now
        
                                       
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

                                                                        
                                             
    def calc_growth(curr: float, prev: float) -> float:
        if prev == 0:
                                                                                                
                                                                                         
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
