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
        # Search by English name or Urdu name substring match
        query["$or"] = [
            {"name": {"$regex": search, "$options": "i"}},
            {"urdu_name": {"$regex": search, "$options": "i"}}
        ]
    
    cursor = db["products"].find(query)
    products = await cursor.to_list(1000)

    for p in products:
        p["id"] = p["_id"]
        if "selling_price" not in p and "sale_price" in p:
            p["selling_price"] = p["sale_price"]
        if "buying_price" not in p and "cost_price" in p:
            p["buying_price"] = p["cost_price"]
        if "low_stock_threshold" not in p and "min_stock_alert" in p:
            p["low_stock_threshold"] = p["min_stock_alert"]
        if "updated_at" not in p:
            p["updated_at"] = utc_now_iso()

    if low_stock_only:
        products = [p for p in products if p.get("current_stock", 0) <= p.get("low_stock_threshold", 5)]

    return products

async def get_product_by_id(product_id: str) -> Optional[Dict[str, Any]]:
    db = get_database()
    doc = await db["products"].find_one({"_id": product_id})
    if doc:
        doc["id"] = doc["_id"]
        if "selling_price" not in doc and "sale_price" in doc:
            doc["selling_price"] = doc["sale_price"]
        if "buying_price" not in doc and "cost_price" in doc:
            doc["buying_price"] = doc["cost_price"]
        if "low_stock_threshold" not in doc and "min_stock_alert" in doc:
            doc["low_stock_threshold"] = doc["min_stock_alert"]
        if "updated_at" not in doc:
            doc["updated_at"] = utc_now_iso()
    return doc

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

