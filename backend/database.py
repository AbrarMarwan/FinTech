from sqlalchemy import create_engine
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker
import os

# مسار قاعدة البيانات
DATABASE_DIR = os.path.join(os.path.dirname(os.path.dirname(__file__)), "database")
os.makedirs(DATABASE_DIR, exist_ok=True)

SQLALCHEMY_DATABASE_URL = f"sqlite:///{DATABASE_DIR}/mali_wallet.db"

engine = create_engine(
    SQLALCHEMY_DATABASE_URL, 
    connect_args={"check_same_thread": False}
)

SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

Base = declarative_base()

# Dependency للحصول على session
def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
