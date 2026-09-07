from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from database import get_db
from schemas import GoldPriceResponse, GoldPriceUpdate, GoldCalcRequest, GoldCalcResponse
from crud import get_gold_prices, update_gold_prices, simulate_gold_price_change, calculate_gold_price

router = APIRouter(prefix="/gold", tags=["Gold Prices"])

@router.get("/prices", response_model=GoldPriceResponse)
def read_gold_prices(db: Session = Depends(get_db)):
    return get_gold_prices(db)

@router.put("/prices", response_model=GoldPriceResponse)
def update_prices(update: GoldPriceUpdate, db: Session = Depends(get_db)):
    return update_gold_prices(db, update)

@router.post("/calculate", response_model=GoldCalcResponse)
def calc_gold(calc: GoldCalcRequest, db: Session = Depends(get_db)):
    result = calculate_gold_price(db, calc)
    return GoldCalcResponse(**result)
