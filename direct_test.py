import os
import sys
from pathlib import Path

# Ensure smart_khata_backend is on sys.path
backend_dir = Path(__file__).resolve().parent / "smart_khata_backend"
if str(backend_dir) not in sys.path:
    sys.path.insert(0, str(backend_dir))

if getattr(sys.stdout, "encoding", None) != "utf-8":
    reconfigure_stdout = getattr(sys.stdout, "reconfigure", None)
    if callable(reconfigure_stdout):
        try:
            reconfigure_stdout(encoding="utf-8")
        except Exception:
            pass

import asyncio
from app.services.ai_service import classify_and_execute_intent
from app.database import get_database

async def main():
    # Ensure sample customers exist for standalone test
    db = get_database()
    if await db["customers"].count_documents({}) == 0:
        await db["customers"].insert_many([
            {
                "id": "cust-001",
                "name": "Muhammad Ali",
                "phone": "03001234567",
                "balance_due": 1200.0,
                "credit_limit": 5000.0,
            },
            {
                "id": "cust-002",
                "name": "Tariq Mahmood",
                "phone": "03129876543",
                "balance_due": 0.0,
                "credit_limit": 10000.0,
            }
        ])

    print("--- Directly calling ai_service ---")
    res1 = await classify_and_execute_intent("محمد علی کے کھاتے میں 600 جمع کرو")
    print("Intent 1:", res1.get("intent"))
    print("Reply 1:", res1.get("reply"))
    print("Entities 1:", res1.get("entities"))

    res2 = await classify_and_execute_intent("علی کے پیسے بتاؤ")
    print("\nIntent 2:", res2.get("intent"))
    print("Reply 2:", res2.get("reply"))
    print("Entities 2:", res2.get("entities"))

asyncio.run(main())
