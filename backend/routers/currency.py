from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from typing import List
from database import get_db
from schemas import CurrencyRateResponse, ExchangeRequest, ExchangeResponse
from crud import get_currency_rates, calculate_exchange

router = APIRouter(prefix="/currency", tags=["Currency"])

@router.get("/rates", response_model=List[CurrencyRateResponse])
def read_rates(db: Session = Depends(get_db)):
    return get_currency_rates(db)

@router.post("/exchange", response_model=ExchangeResponse)
def exchange(req: ExchangeRequest, db: Session = Depends(get_db)):
    result = calculate_exchange(db, req)
    return ExchangeResponse(**result)
