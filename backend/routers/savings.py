from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from database import get_db
from schemas import SavingsTransactionResponse, SavingsTransactionCreate, SavingsBalance
from crud import get_savings_balance, create_savings_transaction

router = APIRouter(prefix="/savings", tags=["Savings"])

@router.get("/balance", response_model=SavingsBalance)
def read_balance(user_id: int = 1, db: Session = Depends(get_db)):
    return get_savings_balance(db, user_id)

@router.post("/transaction", response_model=SavingsTransactionResponse)
def add_transaction(transaction: SavingsTransactionCreate, user_id: int = 1, db: Session = Depends(get_db)):
    try:
        return create_savings_transaction(db, user_id, transaction)
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
