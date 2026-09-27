from contextlib import asynccontextmanager
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from app.routers import (
    auth, inventory, suppliers, customers, orders,
    employees, attendance, payroll, cashbook, reports,
    forecast, restock, ai, sync, invoice, backup
)
from app.models.schemas import utc_now_iso


@asynccontextmanager
async def lifespan(app: FastAPI):
    # Startup seeding logic
    from app.database import get_database, set_mock_db
    from app.auth.security import hash_password
    import uuid

    try:
        db = get_database()
        existing_owner = await db["users"].find_one({"username": "admin"})
    except Exception as e:
        print(f"Database connection error ({e}), switching to In-Memory store.")
        set_mock_db(True)
        db = get_database()
        existing_owner = await db["users"].find_one({"username": "admin"})
    if not existing_owner:
        await db["users"].insert_one({
            "_id": str(uuid.uuid4()),
            "username": "admin",
            "hashed_password": hash_password("admin123"),
            "name": "Tariq Kiryana Owner",
            "role": "owner",
            "employee_id": None
        })

    # Seed Employee / Staff Account if not exists
    existing_staff = await db["users"].find_one({"username": "staff"})
    if not existing_staff:
        await db["users"].insert_one({
            "_id": str(uuid.uuid4()),
            "username": "staff",
            "hashed_password": hash_password("staff123"),
            "name": "Ali Cashier",
            "role": "employee",
            "employee_id": "EMP-101"
        })

    # Seed Sample Kiryana Products if empty
    prod_count = await db["products"].count_documents({})
    if prod_count == 0:
        await db["products"].insert_many([
            {
                "_id": str(uuid.uuid4()),
                "id": "prod-001",
                "name": "Basmati Rice (Super Kernal)",
                "urdu_name": "چاول super kernel",
                "category": "Grains",
                "selling_price": 320.0,
                "buying_price": 280.0,
                "current_stock": 50.0,
                "unit": "kg",
                "low_stock_threshold": 10.0,
                "supplier_id": None,
                "updated_at": utc_now_iso()
            },
            {
                "_id": str(uuid.uuid4()),
                "id": "prod-002",
                "name": "Chakki Atta (Wheat Flour)",
                "urdu_name": "گندم کا آٹا",
                "category": "Flour",
                "selling_price": 140.0,
                "buying_price": 120.0,
                "current_stock": 100.0,
                "unit": "kg",
                "low_stock_threshold": 15.0,
                "supplier_id": None,
                "updated_at": utc_now_iso()
            },
            {
                "_id": str(uuid.uuid4()),
                "id": "prod-003",
                "name": "White Sugar",
                "urdu_name": "چینی",
                "category": "Grocery",
                "selling_price": 150.0,
                "buying_price": 135.0,
                "current_stock": 80.0,
                "unit": "kg",
                "low_stock_threshold": 20.0,
                "supplier_id": None,
                "updated_at": utc_now_iso()
            },
            {
                "_id": str(uuid.uuid4()),
                "id": "prod-004",
                "name": "Cooking Oil (1 Litre)",
                "urdu_name": "کھانا پکانے کا تیل",
                "category": "Grocery",
                "selling_price": 470.0,
                "buying_price": 420.0,
                "current_stock": 40.0,
                "unit": "litre",
                "low_stock_threshold": 10.0,
                "supplier_id": None,
                "updated_at": utc_now_iso()
            },
            {
                "_id": str(uuid.uuid4()),
                "id": "prod-005",
                "name": "Desi Ghee (500g)",
                "urdu_name": "دیسی گھی",
                "category": "Dairy",
                "selling_price": 650.0,
                "buying_price": 580.0,
                "current_stock": 25.0,
                "unit": "piece",
                "low_stock_threshold": 8.0,
                "supplier_id": None,
                "updated_at": utc_now_iso()
            }
        ])

    # Seed Sample Customers if empty
    cust_count = await db["customers"].count_documents({})
    if cust_count == 0:
        await db["customers"].insert_many([
            {
                "_id": str(uuid.uuid4()),
                "id": "cust-001",
                "name": "Muhammad Ali",
                "phone": "03001234567",
                "address": "House 12, Block A",
                "balance_due": 1200.0,
                "credit_limit": 5000.0
            },
            {
                "_id": str(uuid.uuid4()),
                "id": "cust-002",
                "name": "Tariq Mahmood",
                "phone": "03129876543",
                "address": "Shop 4, Main Bazaar",
                "balance_due": 0.0,
                "credit_limit": 10000.0
            }
        ])

    # Seed Sample Employees if empty
    emp_count = await db["employees"].count_documents({})
    if emp_count == 0:
        await db["employees"].insert_many([
            {
                "_id": str(uuid.uuid4()),
                "id": "EMP-101",
                "name": "Ali Cashier",
                "role_title": "Cashier",
                "salary_type": "monthly",
                "salary_rate": 25000.0,
                "phone": "03211112233",
                "casual_leave_quota": 12,
                "sick_leave_quota": 8,
                "leaves_taken": 0,
                "active": True,
                "user_account_id": None,
                "updated_at": utc_now_iso()
            },
            {
                "_id": str(uuid.uuid4()),
                "id": "EMP-102",
                "name": "Bilal Helper",
                "role_title": "Helper",
                "salary_type": "daily",
                "salary_rate": 800.0,
                "phone": "03329988776",
                "casual_leave_quota": 12,
                "sick_leave_quota": 8,
                "leaves_taken": 0,
                "active": True,
                "user_account_id": None,
                "updated_at": utc_now_iso()
            }
        ])
    yield

app = FastAPI(
    title="Smart Khata API",
    description="AI-Powered Shop Management Backend for Pakistani Kiryana Stores",
    version="1.0.0",
    lifespan=lifespan
)

# Enable CORS for Flutter mobile client and Web
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Include Routers
app.include_router(auth.router)
app.include_router(inventory.router)
app.include_router(suppliers.router)
app.include_router(customers.router)
app.include_router(orders.router)
app.include_router(employees.router)
app.include_router(attendance.router)
app.include_router(payroll.router)
app.include_router(cashbook.router)
app.include_router(reports.router)
app.include_router(forecast.router)
app.include_router(restock.router)
app.include_router(ai.router)
app.include_router(sync.router)
app.include_router(invoice.router)
app.include_router(backup.router)

@app.get("/")
async def root():
    return {
        "status": "online",
        "app": "Smart Khata API",
        "version": "1.0.0",
        "docs_url": "/docs"
    }
