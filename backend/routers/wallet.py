from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from database import get_db
from schemas import WalletResponse
from crud import get_wallet, update_wallet_balance

router = APIRouter(prefix="/wallet", tags=["Wallet"])

@router.get("/", response_model=WalletResponse)
def read_wallet(user_id: int = 1, db: Session = Depends(get_db)):
    return get_wallet(db, user_id)

@router.put("/update", response_model=WalletResponse)
def update_wallet(user_id: int = 1, total: float = 0, available: float = 0, savings: float = 0, db: Session = Depends(get_db)):
    return update_wallet_balance(db, user_id, total, available, savings)
