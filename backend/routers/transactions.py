from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from typing import List
from database import get_db
from schemas import TransactionResponse, TransactionCreate
from crud import get_transactions, create_transaction

router = APIRouter(prefix="/transactions", tags=["Transactions"])

@router.get("/", response_model=List[TransactionResponse])
def read_transactions(user_id: int = 1, skip: int = 0, limit: int = 100, db: Session = Depends(get_db)):
    return get_transactions(db, user_id=user_id, skip=skip, limit=limit)

@router.post("/", response_model=TransactionResponse)
def add_transaction(transaction: TransactionCreate, user_id: int = 1, db: Session = Depends(get_db)):
    # Localized import to strictly prevent circular module dependencies during app startup
    from routers.analysis import invalidate_user_insights_cache
    
    db_transaction = create_transaction(db, user_id, transaction)
    
    # Invalidate cache so the AI immediately picks up the new transaction on next load
    invalidate_user_insights_cache(user_id)
    
    return db_transaction
