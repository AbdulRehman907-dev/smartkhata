from typing import List
from fastapi import APIRouter, HTTPException, Depends  # type: ignore
from app.models.schemas import CustomerCreate, CustomerUpdate, CustomerResponse, CustomerPayment
from app.auth.dependencies import require_employee_or_owner
from app.services.customer_service import (
    create_customer, get_customers, get_customer_by_id, update_customer, delete_customer,
    record_customer_payment, get_customer_transaction_history
)

router = APIRouter(prefix="/api/customers", tags=["Customers & Khata"])

@router.post("", response_model=CustomerResponse)
async def add_customer(
    data: CustomerCreate,
    current_user: dict = Depends(require_employee_or_owner)
):
    return await create_customer(data)

@router.get("", response_model=List[CustomerResponse])
async def list_customers(
    current_user: dict = Depends(require_employee_or_owner)
):
    return await get_customers()

@router.get("/{customer_id}", response_model=CustomerResponse)
async def get_customer(
    customer_id: str,
    current_user: dict = Depends(require_employee_or_owner)
):
    cust = await get_customer_by_id(customer_id)
    if not cust:
        raise HTTPException(status_code=404, detail="Customer not found.")
    return cust

@router.put("/{customer_id}", response_model=CustomerResponse)
async def edit_customer(
    customer_id: str,
    updates: CustomerUpdate,
    current_user: dict = Depends(require_employee_or_owner)
):
    cust = await update_customer(customer_id, updates)
    if not cust:
        raise HTTPException(status_code=404, detail="Customer not found.")
    return cust

@router.delete("/{customer_id}")
async def remove_customer(
    customer_id: str,
    current_user: dict = Depends(require_employee_or_owner)
):
    success = await delete_customer(customer_id)
    if not success:
        raise HTTPException(status_code=404, detail="Customer not found.")
    return {"message": "Customer deleted successfully", "id": customer_id}

@router.post("/payments")
async def add_customer_payment(
    data: CustomerPayment,
    current_user: dict = Depends(require_employee_or_owner)
):
    try:
        return await record_customer_payment(data)
    except ValueError as ve:
        raise HTTPException(status_code=400, detail=str(ve))
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/{customer_id}/history")
async def get_customer_history(
    customer_id: str,
    current_user: dict = Depends(require_employee_or_owner)
):
    try:
        return await get_customer_transaction_history(customer_id)
    except ValueError as ve:
        raise HTTPException(status_code=404, detail=str(ve))
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))