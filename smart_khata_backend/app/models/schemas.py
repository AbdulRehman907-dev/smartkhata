from typing import List, Optional, Any, Union, Dict
from pydantic import BaseModel, Field
from datetime import datetime, timezone

def utc_now_iso():
    return datetime.now(timezone.utc).isoformat()

# User & Auth
class UserRegister(BaseModel):
    username: str
    password: str
    name: str
    role: str = "owner" # owner or employee
    employee_id: Optional[str] = None
    store_name: Optional[str] = None
    store_type: Optional[str] = "Kiryana / General Store"
    phone: Optional[str] = None
    city: Optional[str] = "Sahiwal"

class UserLogin(BaseModel):
    username: str
    password: str

class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    role: str
    username: str
    name: str
    store_name: Optional[str] = "Smart Khata Store"

# Product & Stock
class ProductCreate(BaseModel):
    name: str
    urdu_name: Optional[str] = None
    category: str
    unit: str # kg, litre, piece, box, etc.
    buying_price: float
    selling_price: float
    current_stock: float = 0.0
    low_stock_threshold: float = 5.0
    supplier_id: Optional[str] = None

class ProductUpdate(BaseModel):
    name: Optional[str] = None
    urdu_name: Optional[str] = None
    category: Optional[str] = None
    unit: Optional[str] = None
    buying_price: Optional[float] = None
    selling_price: Optional[float] = None
    current_stock: Optional[float] = None
    low_stock_threshold: Optional[float] = None
    supplier_id: Optional[str] = None

class StockAdjustment(BaseModel):
    product_id: str
    quantity_change: float # + for add, - for spoilage/reduction
    reason: str = "manual_correction"

class ProductResponse(ProductCreate):
    id: str
    updated_at: str

# Supplier & Purchase Orders
class SupplierCreate(BaseModel):
    name: str
    phone: str
    address: Optional[str] = ""
    notes: Optional[str] = ""

class SupplierResponse(SupplierCreate):
    id: str
    total_purchased: float = 0.0
    total_paid: float = 0.0
    balance_owed: float = 0.0
    updated_at: str

class POLineItem(BaseModel):
    product_id: str
    quantity: float
    unit_cost: float

class PurchaseOrderCreate(BaseModel):
    supplier_id: str
    line_items: List[POLineItem]
    amount_paid_now: float = 0.0
    date: Optional[str] = None

# Customer & Khata
class CustomerCreate(BaseModel):
    name: str
    phone: str
    address: Optional[str] = ""
    type: str = "regular" # regular, farmer, business

class CustomerResponse(CustomerCreate):
    id: str
    balance_due: float = 0.0
    updated_at: str

class CustomerPayment(BaseModel):
    customer_id: str
    amount: float
    payment_method: str = "cash" # cash, jazzcash, easypaisa, nayapay, bank
    note: Optional[str] = "Khata payment received"
    date: Optional[str] = None

# Orders & Sales
class OrderLineItem(BaseModel):
    product_id: str
    quantity: float

class OrderCreate(BaseModel):
    line_items: List[OrderLineItem]
    discount: float = 0.0
    payment_method: str # cash, jazzcash, easypaisa, nayapay, bank, credit, partial
    amount_paid_now: float = 0.0
    customer_id: Optional[str] = None
    client_id: Optional[str] = None

class OrderResponse(BaseModel):
    id: str
    line_items: List[dict]
    subtotal: float
    discount: float
    total_amount: float
    payment_method: str
    amount_paid_now: float
    amount_added_to_khata: float
    customer_id: Optional[str] = None
    customer_name: Optional[str] = None
    created_at: str
    client_id: Optional[str] = None

# Employees, Attendance, Payroll
class EmployeeCreate(BaseModel):
    name: str
    role_title: str
    salary_type: str # monthly, daily
    salary_rate: float
    phone: str
    casual_leave_quota: int = 12
    sick_leave_quota: int = 8
    create_login: bool = False
    username: Optional[str] = None
    password: Optional[str] = None

class EmployeeResponse(BaseModel):
    id: str
    name: str
    role_title: str
    salary_type: str
    salary_rate: float
    phone: str
    casual_leave_quota: int = 12
    sick_leave_quota: int = 8
    leaves_taken: int = 0
    remaining_casual_leaves: int = 12
    remaining_sick_leaves: int = 8
    active: bool = True
    user_account_id: Optional[str] = None
    updated_at: str

class LeaveRequestCreate(BaseModel):
    employee_id: str
    leave_type: str # casual, sick
    start_date: str # YYYY-MM-DD
    end_date: str # YYYY-MM-DD
    reason: str

class LeaveRequestResponse(BaseModel):
    id: str
    employee_id: str
    employee_name: str
    leave_type: str
    start_date: str
    end_date: str
    days_requested: int
    status: str # pending, approved, rejected
    reason: str
    created_at: str

class AttendanceMark(BaseModel):
    employee_id: str
    date: str # YYYY-MM-DD
    status: str # present, absent, half_day, leave

class AttendanceResponse(AttendanceMark):
    id: str
    updated_at: str

class PayrollRunRequest(BaseModel):
    month: str # YYYY-MM

class EmployeePayrollLine(BaseModel):
    employee_id: str
    employee_name: str
    salary_type: str
    salary_rate: float
    days_worked: float
    leave_days: float
    absence_days: float
    half_days: float
    calculated_salary: float

class PayrollRunResponse(BaseModel):
    id: str
    month: str
    lines: List[EmployeePayrollLine]
    total_payout: float
    paid: bool = False
    paid_at: Optional[str] = None
    created_at: str

# CashBook & Expenses
class ExpenseCreate(BaseModel):
    category: str # rent, utilities, salary, supplier_payment, misc
    amount: float
    payment_method: str = "cash" # cash, jazzcash, easypaisa, nayapay, bank
    note: str
    date: Optional[str] = None

class ExpenseResponse(ExpenseCreate):
    id: str

class CashBookEntry(BaseModel):
    type: str # inflow, outflow
    category: str
    description: str
    amount: float
    payment_method: str
    date: str
    running_balance: float

class CashBookLedgerResponse(BaseModel):
    entries: List[CashBookEntry]
    total_inflow: float
    total_outflow: float
    running_balance: float
    wallet_balances: Dict[str, float] # cash, jazzcash, easypaisa, nayapay, bank balances

# Financial Summary & Dashboard
class DashboardResponse(BaseModel):
    today_revenue: float
    today_profit: float
    cash_collected: float
    order_count: int
    total_products: int
    low_stock_count: int
    pending_khata_count: int
    pending_khata_total: float
    employees_present_today: int
    wallet_balances: Dict[str, float]

class FinancialReportResponse(BaseModel):
    start_date: str
    end_date: str
    total_revenue: float
    cost_of_goods_sold: float
    gross_profit: float
    total_expenses: float
    net_profit: float
    wallet_balances: Dict[str, float]

# Restock Forecast
class ForecastItem(BaseModel):
    product_id: str
    product_name: str
    current_stock: float
    low_stock_threshold: float
    historical_days_with_sales: int
    avg_daily_sales: float
    predicted_7day_demand: float
    needs_restock: bool
    suggested_reorder_qty: float
    method_used: str

class ForecastResponse(BaseModel):
    forecasts: List[ForecastItem]
    generated_at: str

# AI Voice Intent
class VoiceIntentRequest(BaseModel):
    text: str
    context: Optional[dict] = None

class VoiceIntentResponse(BaseModel):
    intent: str
    entities: dict
    reply: str
    raw_text: str
    needs_confirmation: Optional[bool] = False
    confirm_message: Optional[str] = None
    whatsapp_url: Optional[str] = None
    follow_up_prompt: Optional[str] = None

# Offline Sync & Backup
class SyncPullResponse(BaseModel):
    products: List[dict]
    suppliers: List[dict]
    customers: List[dict]
    employees: List[dict]
    server_timestamp: str

class SyncPushPayload(BaseModel):
    orders: List[OrderCreate] = []
    attendance: List[AttendanceMark] = []

class SyncPushItemResult(BaseModel):
    client_id: Optional[str] = None
    entity_type: str
    status: str
    message: str
    data: Optional[dict] = None

class SyncPushResponse(BaseModel):
    results: List[SyncPushItemResult]

class BackupExportData(BaseModel):
    version: str = "1.0"
    exported_at: str
    products: List[dict]
    suppliers: List[dict]
    customers: List[dict]
    orders: List[dict]
    employees: List[dict]
    attendance: List[dict]
    expenses: List[dict]
