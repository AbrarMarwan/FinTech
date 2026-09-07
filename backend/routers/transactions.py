from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from typing import List
from database import get_db
from schemas import TransactionResponse, TransactionCreate
from crud import get_transactions, create_transaction, update_transaction, delete_transaction

router = APIRouter(prefix="/transactions", tags=["Transactions"])

@router.get("/", response_model=List[TransactionResponse])
def read_transactions(user_id: int = 1, skip: int = 0, limit: int = 100, db: Session = Depends(get_db)):
    return get_transactions(db, user_id=user_id, skip=skip, limit=limit)

@router.post("/", response_model=TransactionResponse)
def add_transaction(transaction: TransactionCreate, user_id: int = 1, db: Session = Depends(get_db)):
    try:
        return create_transaction(db, user_id, transaction)
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc))

@router.put("/{transaction_id}", response_model=TransactionResponse)
def edit_transaction(transaction_id: int, transaction: TransactionCreate, user_id: int = 1, db: Session = Depends(get_db)):
    try:
        result = update_transaction(db, transaction_id, user_id, transaction)
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc))
    if not result:
        raise HTTPException(status_code=404, detail="المعاملة غير موجودة")
    return result

@router.delete("/{transaction_id}")
def remove_transaction(transaction_id: int, user_id: int = 1, db: Session = Depends(get_db)):
    if not delete_transaction(db, transaction_id, user_id):
        raise HTTPException(status_code=404, detail="المعاملة غير موجودة")
    return {"message": "تم حذف المعاملة"}
