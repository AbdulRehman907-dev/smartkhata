from typing import List, Optional
from fastapi import APIRouter, HTTPException, Depends, Query  # type: ignore
from app.models.schemas import ProductCreate, ProductUpdate, StockAdjustment, ProductResponse
from app.auth.dependencies import get_current_user, require_owner, require_employee_or_owner
from app.services.inventory_service import (
    create_product, get_products, get_product_by_id, update_product, adjust_stock, delete_product
)

router = APIRouter(prefix="/api/products", tags=["Inventory"])

@router.post("", response_model=ProductResponse)
async def add_product(
    data: ProductCreate,
    current_user: dict = Depends(require_employee_or_owner)
):
    try:
        return await create_product(data)
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))

@router.get("", response_model=List[ProductResponse])
async def list_products(
    search: Optional[str] = Query(None, description="Search by English or Urdu name"),
    category: Optional[str] = Query(None),
    low_stock_only: bool = Query(False),
    current_user: dict = Depends(require_employee_or_owner)
):
    return await get_products(search=search, category=category, low_stock_only=low_stock_only)

@router.get("/{product_id}", response_model=ProductResponse)
async def get_product(
    product_id: str,
    current_user: dict = Depends(require_employee_or_owner)
):
    prod = await get_product_by_id(product_id)
    if not prod:
        raise HTTPException(status_code=404, detail="Product not found.")
    return prod

@router.put("/{product_id}", response_model=ProductResponse)
async def edit_product(
    product_id: str,
    updates: ProductUpdate,
    current_user: dict = Depends(require_employee_or_owner)
):
    prod = await update_product(product_id, updates)
    if not prod:
        raise HTTPException(status_code=404, detail="Product not found.")
    return prod

@router.post("/adjust-stock", response_model=ProductResponse)
async def adjust_product_stock(
    data: StockAdjustment,
    current_user: dict = Depends(require_employee_or_owner)
):
    try:
        return await adjust_stock(data.product_id, data.quantity_change, data.reason)
    except ValueError as ve:
        raise HTTPException(status_code=400, detail=str(ve))
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.delete("/{product_id}")
async def remove_product(
    product_id: str,
    current_user: dict = Depends(require_employee_or_owner)
):
    success = await delete_product(product_id)
    if not success:
        raise HTTPException(status_code=404, detail="Product not found.")
    return {"message": "Product deleted successfully", "id": product_id}
