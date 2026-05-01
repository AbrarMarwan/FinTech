from sqlalchemy import Column, Integer, String, Float, Boolean, DateTime, ForeignKey
from sqlalchemy.sql import func
from database import Base
from constants import TransactionCategory


class User(Base):
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String(100), nullable=False)
    phone_number = Column(String(20), unique=True, nullable=True)


class Wallet(Base):
    __tablename__ = "wallets"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False, unique=True)
    # Numeric storage for financial data integrity — UI handles "YR" formatting
    total_balance = Column(Float, default=1250500.0)
    available_amount = Column(Float, default=980000.0)
    savings_amount = Column(Float, default=270500.0)
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())


class Transaction(Base):
    __tablename__ = "transactions"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    title = Column(String(200), nullable=False)
    amount = Column(String(50), nullable=False)
    time = Column(String(100), nullable=False)
    is_expense = Column(Boolean, default=True)
    icon_name = Column(String(50), default="shopping_cart")
    category = Column(String(100), default=TransactionCategory.OTHER)
    created_at = Column(DateTime(timezone=True), server_default=func.now())


class GoldPrice(Base):
    __tablename__ = "gold_prices"

    id = Column(Integer, primary_key=True, index=True)
    karat_24 = Column(Float, default=58450.0)
    karat_21 = Column(Float, default=51140.0)
    karat_18 = Column(Float, default=43830.0)
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())


class CurrencyRate(Base):
    __tablename__ = "currency_rates"

    id = Column(Integer, primary_key=True, index=True)
    currency_name = Column(String(100), nullable=False)
    rate = Column(Float, nullable=False)
    change = Column(String(20), default="+0.0%")
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())


class SavingsTransaction(Base):
    __tablename__ = "savings_transactions"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    amount = Column(Float, nullable=False)
    is_deposit = Column(Boolean, default=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())


class ExpenseAnalysis(Base):
    __tablename__ = "expense_analysis"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    category = Column(String(100), nullable=False)
    amount = Column(Float, nullable=False)
    percentage = Column(Float, default=0.0)
    color_start = Column(String(20), default="#64B5F6")
    color_end = Column(String(20), default="#1976D2")
