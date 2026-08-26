import uuid
from typing import List, Optional, Dict, Any
from app.database import get_database
from app.models.schemas import ProductCreate, ProductUpdate, SupplierCreate, utc_now_iso

async def create_product(data: ProductCreate) -> Dict[str, Any]:
    db = get_database()
    now = utc_now_iso()
    doc = data.model_dump()
    doc["_id"] = str(uuid.uuid4())
    doc["updated_at"] = now
    await db["products"].insert_one(doc)
    doc["id"] = doc["_id"]
    return doc

def _format_product(p: Dict[str, Any]) -> Dict[str, Any]:
    return {
        "id": str(p.get("_id", p.get("id", ""))),
        "name": str(p.get("name", "Product")),
        "urdu_name": str(p.get("urdu_name", "") or ""),
        "category": str(p.get("category", "General") or "General"),
        "unit": str(p.get("unit", "kg") or "kg"),
        "buying_price": float(p.get("buying_price", p.get("cost_price", 0.0)) or 0.0),
        "selling_price": float(p.get("selling_price", p.get("sale_price", 0.0)) or 0.0),
        "current_stock": float(p.get("current_stock", 0.0) or 0.0),
        "low_stock_threshold": float(p.get("low_stock_threshold", p.get("min_stock_alert", 5.0)) or 5.0),
        "supplier_id": p.get("supplier_id"),
        "barcode": p.get("barcode"),
        "updated_at": str(p.get("updated_at") or utc_now_iso()),
    }

async def get_products(
    search: Optional[str] = None,
    category: Optional[str] = None,
    low_stock_only: bool = False
) -> List[Dict[str, Any]]:
    db = get_database()
    query: Dict[str, Any] = {}

    if category:
        query["category"] = category
    
    if search:
        query["$or"] = [
            {"name": {"$regex": search, "$options": "i"}},
            {"urdu_name": {"$regex": search, "$options": "i"}}
        ]
    
    cursor = db["products"].find(query)
    products = await cursor.to_list(1000)
    formatted = [_format_product(p) for p in products]

    if low_stock_only:
        formatted = [p for p in formatted if p["current_stock"] <= p["low_stock_threshold"]]

    return formatted

async def get_product_by_id(product_id: str) -> Optional[Dict[str, Any]]:
    db = get_database()
    doc = await db["products"].find_one({"_id": product_id})
    if not doc:
        doc = await db["products"].find_one({"id": product_id})
    if doc:
        return _format_product(doc)
    return None

async def update_product(product_id: str, updates: ProductUpdate) -> Optional[Dict[str, Any]]:
    db = get_database()
    update_data = {k: v for k, v in updates.model_dump().items() if v is not None}
    if not update_data:
        return await get_product_by_id(product_id)
    
    update_data["updated_at"] = utc_now_iso()
    res = await db["products"].update_one({"_id": product_id}, {"$set": update_data})
    if res.matched_count == 0:
        return None
    return await get_product_by_id(product_id)

async def adjust_stock(product_id: str, quantity_change: float, reason: str) -> Dict[str, Any]:
    db = get_database()
    prod = await get_product_by_id(product_id)
    if not prod:
        raise ValueError(f"Product with ID '{product_id}' not found.")
    
    new_stock = prod.get("current_stock", 0.0) + quantity_change
    if new_stock < 0:
        raise ValueError(f"Stock cannot be negative. Current: {prod['current_stock']}, adjustment: {quantity_change}")
    
    now = utc_now_iso()
    await db["products"].update_one(
        {"_id": product_id},
        {"$set": {"current_stock": new_stock, "updated_at": now}}
    )
    # Log stock adjustment record
    await db["stock_adjustments"].insert_one({
        "_id": str(uuid.uuid4()),
        "product_id": product_id,
        "quantity_change": quantity_change,
        "new_stock": new_stock,
        "reason": reason,
        "timestamp": now
    })

    prod["current_stock"] = new_stock
    prod["updated_at"] = now
    return prod

# Supplier Service Functions
async def create_supplier(data: SupplierCreate) -> Dict[str, Any]:
    db = get_database()
    now = utc_now_iso()
    doc = data.model_dump()
    doc["_id"] = str(uuid.uuid4())
    doc["total_purchased"] = 0.0
    doc["total_paid"] = 0.0
    doc["balance_owed"] = 0.0
    doc["updated_at"] = now
    await db["suppliers"].insert_one(doc)
    doc["id"] = doc["_id"]
    return doc

async def get_suppliers() -> List[Dict[str, Any]]:
    db = get_database()
    cursor = db["suppliers"].find({})
    suppliers = await cursor.to_list(1000)
    for s in suppliers:
        s["id"] = s["_id"]
    return suppliers

async def get_supplier_by_id(supplier_id: str) -> Optional[Dict[str, Any]]:
    db = get_database()
    doc = await db["suppliers"].find_one({"_id": supplier_id})
    if doc:
        doc["id"] = doc["_id"]
    return doc

async def create_purchase_order(po_data) -> Dict[str, Any]:
    db = get_database()
    now = utc_now_iso()
    supplier = await get_supplier_by_id(po_data.supplier_id)
    if not supplier:
        raise ValueError(f"Supplier with ID '{po_data.supplier_id}' not found.")
    
    total_cost = 0.0
    processed_items = []

    for item in po_data.line_items:
        prod = await get_product_by_id(item.product_id)
        if not prod:
            raise ValueError(f"Product ID '{item.product_id}' not found.")
        line_cost = item.quantity * item.unit_cost
        total_cost += line_cost
        
        # Increase product stock
        await adjust_stock(item.product_id, item.quantity, reason=f"Purchase order from {supplier['name']}")
        processed_items.append({
            "product_id": item.product_id,
            "product_name": prod["name"],
            "quantity": item.quantity,
            "unit_cost": item.unit_cost,
            "line_cost": line_cost
        })

    amount_paid = po_data.amount_paid_now
    balance_increase = total_cost - amount_paid

    # Update supplier running totals
    await db["suppliers"].update_one(
        {"_id": po_data.supplier_id},
        {
            "$inc": {
                "total_purchased": total_cost,
                "total_paid": amount_paid,
                "balance_owed": balance_increase
            },
            "$set": {"updated_at": now}
        }
    )

    # If immediate payment made, log cashbook expense
    if amount_paid > 0:
        await db["expenses"].insert_one({
            "_id": str(uuid.uuid4()),
            "category": "supplier_payment",
            "amount": amount_paid,
            "note": f"Immediate payment for PO to supplier '{supplier['name']}'",
            "date": now
        })

    po_doc = {
        "_id": str(uuid.uuid4()),
        "supplier_id": po_data.supplier_id,
        "supplier_name": supplier["name"],
        "line_items": processed_items,
        "total_cost": total_cost,
        "amount_paid_now": amount_paid,
        "balance_added": balance_increase,
        "date": po_data.date or now
    }
    await db["purchase_orders"].insert_one(po_doc)
    po_doc["id"] = po_doc["_id"]
    return po_doc

async def delete_product(product_id: str) -> bool:
    db = get_database()
    res = await db["products"].delete_one({"_id": product_id})
    return res.deleted_count > 0

