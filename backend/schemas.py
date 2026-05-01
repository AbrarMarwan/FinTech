from pydantic import BaseModel
from typing import List, Optional
from datetime import datetime
from constants import TransactionCategory

# --- User Schemas ---
class UserBase(BaseModel):
    name: str
    phone_number: Optional[str] = None

class UserCreate(UserBase):
    pass

class UserResponse(UserBase):
    id: int

    class Config:
        from_attributes = True

# --- Wallet Schemas ---
class WalletBase(BaseModel):
    # Raw numeric values — frontend handles "YR" formatting locally
    total_balance: float
    available_amount: float
    savings_amount: float

class WalletResponse(WalletBase):
    id: int
    user_id: int
    updated_at: Optional[datetime] = None

    class Config:
        from_attributes = True
# --- Transaction Schemas ---
class TransactionBase(BaseModel):
    title: str
    amount: str
    time: str
    is_expense: bool = True
    icon_name: str = "shopping_cart"
    category: str = TransactionCategory.OTHER

class TransactionCreate(TransactionBase):
    pass

class TransactionResponse(TransactionBase):
    id: int
    user_id: int
    created_at: Optional[datetime] = None

    class Config:
        from_attributes = True

# --- Gold Price Schemas ---
class GoldPriceBase(BaseModel):
    karat_24: float
    karat_21: float
    karat_18: float

class GoldPriceResponse(GoldPriceBase):
    id: int
    updated_at: Optional[datetime] = None

    class Config:
        from_attributes = True

class GoldPriceUpdate(BaseModel):
    karat_24: Optional[float] = None
    karat_21: Optional[float] = None
    karat_18: Optional[float] = None

# --- Currency Rate Schemas ---
class CurrencyRateBase(BaseModel):
    currency_name: str
    rate: float
    change: str = "+0.0%"

class CurrencyRateResponse(CurrencyRateBase):
    id: int
    updated_at: Optional[datetime] = None

    class Config:
        from_attributes = True

# --- Savings Schemas ---
class SavingsTransactionBase(BaseModel):
    amount: float
    is_deposit: bool = True

class SavingsTransactionCreate(SavingsTransactionBase):
    pass

class SavingsTransactionResponse(SavingsTransactionBase):
    id: int
    user_id: int
    created_at: Optional[datetime] = None

    class Config:
        from_attributes = True

class SavingsBalance(BaseModel):
    total_savings: float
    total_deposits: float
    total_withdrawals: float

# --- Expense Analysis Schemas ---
class ExpenseAnalysisBase(BaseModel):
    category: str
    amount: float
    percentage: float = 0.0
    color_start: str = "#64B5F6"
    color_end: str = "#1976D2"

class ExpenseAnalysisResponse(ExpenseAnalysisBase):
    id: int
    user_id: int

    class Config:
        from_attributes = True

# --- Financial Summary Schemas ---
class FinancialSummaryResponse(BaseModel):
    current_inflow: float
    inflow_growth_percentage: float
    current_outflow: float
    outflow_growth_percentage: float

# --- Insights Schemas ---
class InsightsResponse(BaseModel):
    insight_text: str
    recommendation_text: str

# --- Exchange Calculator ---
class ExchangeRequest(BaseModel):
    amount_yer: float
    target_currency: str  # "USD" or "SAR"

class ExchangeResponse(BaseModel):
    amount_yer: float
    target_currency: str
    converted_amount: float
    rate: float

# --- Gold Calculator ---
class GoldCalcRequest(BaseModel):
    grams: float
    karat: str = "24"  # "24", "21", "18"

class GoldCalcResponse(BaseModel):
    grams: float
    karat: str
    price_per_gram: float
    total_price: float
