import uuid
from typing import List, Optional, Dict, Any
from app.database import get_database
from app.models.schemas import CustomerCreate, CustomerUpdate, CustomerPayment, utc_now_iso

def _format_customer(c: Dict[str, Any]) -> Dict[str, Any]:
    return {
        "id": str(c.get("_id", c.get("id", ""))),
        "name": str(c.get("name", "Customer")),
        "phone": str(c.get("phone", "") or ""),
        "address": str(c.get("address", "") or ""),
        "type": str(c.get("type", "regular") or "regular"),
        "balance_due": float(c.get("balance_due", 0.0) or 0.0),
        "updated_at": str(c.get("updated_at") or utc_now_iso()),
    }

async def create_customer(data: CustomerCreate) -> Dict[str, Any]:
    db = get_database()
    now = utc_now_iso()
    doc = data.model_dump()
    doc["_id"] = str(uuid.uuid4())
    doc["balance_due"] = float(doc.pop("opening_balance", 0.0) or 0.0)
    doc["updated_at"] = now
    await db["customers"].insert_one(doc)
    return _format_customer(doc)

async def get_customers() -> List[Dict[str, Any]]:
    db = get_database()
    cursor = db["customers"].find({})
    customers = await cursor.to_list(1000)
    return [_format_customer(c) for c in customers]

async def get_customer_by_id(customer_id: str) -> Optional[Dict[str, Any]]:
    db = get_database()
    doc = await db["customers"].find_one({"_id": customer_id})
    if not doc:
        doc = await db["customers"].find_one({"id": customer_id})
    if not doc:
        return None
    return _format_customer(doc)

async def record_customer_payment(data: CustomerPayment) -> Dict[str, Any]:
    db = get_database()
    now = utc_now_iso()
    customer = await get_customer_by_id(data.customer_id)
    if not customer:
        raise ValueError(f"Customer with ID '{data.customer_id}' not found.")
    
    if data.amount <= 0:
        raise ValueError("Payment amount must be greater than zero.")

    payment_date = data.date or now
    payment_doc = {
        "_id": str(uuid.uuid4()),
        "customer_id": data.customer_id,
        "amount": data.amount,
        "note": data.note or "Khata payment received",
        "date": payment_date
    }
    await db["customer_payments"].insert_one(payment_doc)

    # Reduce balance_due
    new_balance = customer.get("balance_due", 0.0) - data.amount
    await db["customers"].update_one(
        {"_id": data.customer_id},
        {
            "$inc": {"balance_due": -data.amount},
            "$set": {"updated_at": now}
        }
    )

    payment_doc["id"] = payment_doc["_id"]
    payment_doc["new_balance_due"] = new_balance
    return payment_doc

async def get_customer_transaction_history(customer_id: str) -> List[Dict[str, Any]]:
    db = get_database()
    customer = await get_customer_by_id(customer_id)
    if not customer:
        raise ValueError(f"Customer with ID '{customer_id}' not found.")

    history: List[Dict[str, Any]] = []

    # Fetch orders for this customer where amount_added_to_khata > 0
    order_cursor = db["orders"].find({"customer_id": customer_id, "amount_added_to_khata": {"$gt": 0}})
    orders = await order_cursor.to_list(1000)

    for o in orders:
        history.append({
            "type": "sale_credit",
            "id": o["_id"],
            "date": o.get("created_at", ""),
            "amount": o.get("amount_added_to_khata", 0.0),
            "description": f"Credit Sale (Order #{str(o['_id'])[:8]})",
            "payment_method": o.get("payment_method"),
            "total_order_amount": o.get("total_amount")
        })

    # Fetch customer payments
    pay_cursor = db["customer_payments"].find({"customer_id": customer_id})
    payments = await pay_cursor.to_list(1000)

    for p in payments:
        history.append({
            "type": "payment_received",
            "id": p["_id"],
            "date": p.get("date", ""),
            "amount": p.get("amount", 0.0),
            "description": f"Payment: {p.get('note', 'Khata payment')}"
        })

    # Sort interleaved history newest-first
    history.sort(key=lambda x: x.get("date", ""), reverse=True)
    return history

async def update_customer(customer_id: str, updates: CustomerUpdate) -> Optional[Dict[str, Any]]:
    db = get_database()
    update_data = {k: v for k, v in updates.model_dump().items() if v is not None}
    if not update_data:
        return await get_customer_by_id(customer_id)
    
    update_data["updated_at"] = utc_now_iso()
    res = await db["customers"].update_one({"_id": customer_id}, {"$set": update_data})
    if res.matched_count == 0:
        return None
    return await get_customer_by_id(customer_id)

async def delete_customer(customer_id: str) -> bool:
    db = get_database()
    res = await db["customers"].delete_one({"_id": customer_id})
    return res.deleted_count > 0
