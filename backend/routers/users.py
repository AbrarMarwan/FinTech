from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from typing import List
from database import get_db
from schemas import UserResponse, UserCreate, LoginRequest, AuthResponse, UserUpdate
from crud import get_users, get_user, authenticate_user, create_authenticated_user
from models import User

router = APIRouter(prefix="/users", tags=["Users"])

@router.get("/", response_model=List[UserResponse])
def list_users(db: Session = Depends(get_db)):
    return get_users(db)

@router.get("/{user_id}", response_model=UserResponse)
def read_user(user_id: int, db: Session = Depends(get_db)):
    user = get_user(db, user_id)
    if not user:
        raise HTTPException(status_code=404, detail="المستخدم غير موجود")
    return user

@router.post("/", response_model=UserResponse)
def create_user(user: UserCreate, db: Session = Depends(get_db)):
    db_user = create_authenticated_user(db, user.name, user.phone_number or "", user.password)
    if not db_user:
        raise HTTPException(status_code=409, detail="رقم الهاتف مستخدم بالفعل")
    return db_user

@router.post("/login", response_model=AuthResponse)
def login(user: LoginRequest, db: Session = Depends(get_db)):
    db_user = authenticate_user(db, user.phone_number, user.password)
    if not db_user:
        raise HTTPException(status_code=401, detail="رقم الهاتف أو كلمة المرور غير صحيحة")
    return {"user": db_user, "message": "تم تسجيل الدخول بنجاح"}

@router.put("/{user_id}", response_model=UserResponse)
def edit_user(user_id: int, user: UserUpdate, db: Session = Depends(get_db)):
    db_user = get_user(db, user_id)
    if not db_user:
        raise HTTPException(status_code=404, detail="المستخدم غير موجود")
    db_user.name = user.name
    db_user.phone_number = user.phone_number
    db.commit()
    db.refresh(db_user)
    return db_user

@router.delete("/{user_id}")
def remove_user(user_id: int, db: Session = Depends(get_db)):
    db_user = get_user(db, user_id)
    if not db_user:
        raise HTTPException(status_code=404, detail="المستخدم غير موجود")
    db.delete(db_user)
    db.commit()
    return {"message": "تم حذف المستخدم"}
