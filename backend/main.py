from dotenv import load_dotenv
load_dotenv()                                       

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

               
Base.metadata.create_all(bind=engine)

def ensure_schema():
    with engine.begin() as connection:
        columns = connection.exec_driver_sql("PRAGMA table_info(users)").fetchall()
        names = {row[1] for row in columns}
        if "password_hash" not in names:
            connection.exec_driver_sql("ALTER TABLE users ADD COLUMN password_hash VARCHAR(128)")

ensure_schema()

                               
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

                                 
async def gold_price_updater():
    while True:
        await asyncio.sleep(5)                    
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
                                                                
    db = SessionLocal()
    try:
        seed_users(db)
    finally:
        db.close()
    asyncio.create_task(gold_price_updater())
    yield
              
    pass

app = FastAPI(
    title="Mali Wallet API",
    description="API Backend لمحفظة Mali Wallet",
    version="1.0.0",
    lifespan=lifespan
)

                                 
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

                   
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

                                         
@app.websocket("/ws/gold")
async def websocket_gold(websocket: WebSocket):
    await manager.connect(websocket)
                                    
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
                                                
            data = await websocket.receive_text()
            if data == "ping":
                await websocket.send_text(json.dumps({"type": "pong"}))
    except WebSocketDisconnect:
        manager.disconnect(websocket)

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8000)
