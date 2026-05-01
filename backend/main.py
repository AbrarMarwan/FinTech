from dotenv import load_dotenv
load_dotenv()  # Load .env before any router imports

from fastapi import FastAPI, WebSocket, WebSocketDisconnect
from fastapi.middleware.cors import CORSMiddleware
from contextlib import asynccontextmanager
import asyncio
import json
import uvicorn

from database import engine, Base
from routers import wallet, transactions, gold, currency, savings, analysis, users
from crud import simulate_gold_price_change, seed_users
from database import SessionLocal

# إنشاء الجداول
Base.metadata.create_all(bind=engine)

# WebSocket connections manager
class ConnectionManager:
    def __init__(self):
        self.active_connections: list[WebSocket] = []

    async def connect(self, websocket: WebSocket):
        await websocket.accept()
        self.active_connections.append(websocket)

    def disconnect(self, websocket: WebSocket):
        self.active_connections.remove(websocket)

    async def broadcast(self, message: str):
        for connection in self.active_connections:
            try:
                await connection.send_text(message)
            except:
                pass

manager = ConnectionManager()

# مهمة تحديث أسعار الذهب تلقائياً
async def gold_price_updater():
    while True:
        await asyncio.sleep(5)  # تحديث كل 5 ثواني
        db = SessionLocal()
        try:
            prices = simulate_gold_price_change(db)
            data = {
                "type": "gold_update",
                "data": {
                    "karat_24": prices.karat_24,
                    "karat_21": prices.karat_21,
                    "karat_18": prices.karat_18,
                }
            }
            await manager.broadcast(json.dumps(data, ensure_ascii=False))
        finally:
            db.close()

@asynccontextmanager
async def lifespan(app: FastAPI):
    # Startup: seed users + wallets, then start background tasks
    db = SessionLocal()
    try:
        seed_users(db)
    finally:
        db.close()
    asyncio.create_task(gold_price_updater())
    yield
    # Shutdown
    pass

app = FastAPI(
    title="Mali Wallet API",
    description="API Backend لمحفظة Mali Wallet",
    version="1.0.0",
    lifespan=lifespan
)

# CORS للسماح لـ Flutter بالاتصال
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# تسجيل الـ Routers
app.include_router(wallet.router)
app.include_router(transactions.router)
app.include_router(gold.router)
app.include_router(currency.router)
app.include_router(savings.router)
app.include_router(analysis.router)
app.include_router(users.router)

@app.get("/")
def root():
    return {"message": "Mali Wallet API is running!", "status": "active"}

@app.get("/health")
def health_check():
    return {"status": "healthy"}

# WebSocket endpoint لأسعار الذهب الفورية
@app.websocket("/ws/gold")
async def websocket_gold(websocket: WebSocket):
    await manager.connect(websocket)
    # إرسال السعر الحالي فور الاتصال
    db = SessionLocal()
    try:
        from crud import get_gold_prices
        prices = get_gold_prices(db)
        await websocket.send_text(json.dumps({
            "type": "gold_update",
            "data": {
                "karat_24": prices.karat_24,
                "karat_21": prices.karat_21,
                "karat_18": prices.karat_18,
            }
        }, ensure_ascii=False))
    finally:
        db.close()

    try:
        while True:
            # انتظار رسائل من العميل (ping/pong)
            data = await websocket.receive_text()
            if data == "ping":
                await websocket.send_text(json.dumps({"type": "pong"}))
    except WebSocketDisconnect:
        manager.disconnect(websocket)

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8000)
