import uuid
from typing import List, Optional, Dict, Any
from app.database import get_database
from app.models.schemas import EmployeeCreate, AttendanceMark, utc_now_iso
from app.auth.security import hash_password

async def create_employee(data: EmployeeCreate) -> Dict[str, Any]:
    db = get_database()
    now = utc_now_iso()

    user_account_id = None
    if data.create_login and data.username and data.password:
        # Check username availability
        existing_user = await db["users"].find_one({"username": data.username})
        if existing_user:
            raise ValueError(f"Username '{data.username}' is already taken.")
        
        user_id = str(uuid.uuid4())
        await db["users"].insert_one({
            "_id": user_id,
            "username": data.username,
            "hashed_password": hash_password(data.password),
            "name": data.name,
            "role": "employee"
        })
        user_account_id = user_id

    emp_id = str(uuid.uuid4())
    emp_doc = {
        "_id": emp_id,
        "name": data.name,
        "role_title": data.role_title,
        "salary_type": data.salary_type.lower(), # monthly or daily
        "salary_rate": data.salary_rate,
        "phone": data.phone,
        "casual_leave_quota": data.casual_leave_quota,
        "sick_leave_quota": data.sick_leave_quota,
        "leaves_taken": 0,
        "active": True,
        "user_account_id": user_account_id,
        "updated_at": now
    }
    await db["employees"].insert_one(emp_doc)
    emp_doc["id"] = emp_id
    emp_doc["remaining_casual_leaves"] = data.casual_leave_quota
    emp_doc["remaining_sick_leaves"] = data.sick_leave_quota
    return emp_doc

async def get_employees(active_only: bool = False) -> List[Dict[str, Any]]:
    db = get_database()
    query = {"active": True} if active_only else {}
    cursor = db["employees"].find(query)
    employees = await cursor.to_list(1000)
    for e in employees:
        e["id"] = str(e.get("_id", e.get("id", "")))
        e["role_title"] = e.get("role_title") or e.get("role") or "Helper"
        e["salary_type"] = e.get("salary_type") or "monthly"
        e["salary_rate"] = float(e.get("salary_rate") or e.get("monthly_salary") or 20000.0)
        e["updated_at"] = str(e.get("updated_at") or utc_now_iso())
        c_quota = e.get("casual_leave_quota", 12)
        s_quota = e.get("sick_leave_quota", 8)
        taken = e.get("leaves_taken", 0)
        e["casual_leave_quota"] = c_quota
        e["sick_leave_quota"] = s_quota
        e["leaves_taken"] = taken
        e["remaining_casual_leaves"] = max(0, c_quota - taken)
        e["remaining_sick_leaves"] = max(0, s_quota)
    return employees

async def get_employee_by_id(employee_id: str) -> Optional[Dict[str, Any]]:
    db = get_database()
    doc = await db["employees"].find_one({"_id": employee_id})
    if not doc:
        doc = await db["employees"].find_one({"id": employee_id})
    if doc:
        doc["id"] = str(doc.get("_id", doc.get("id", "")))
        doc["role_title"] = doc.get("role_title") or doc.get("role") or "Helper"
        doc["salary_type"] = doc.get("salary_type") or "monthly"
        doc["salary_rate"] = float(doc.get("salary_rate") or doc.get("monthly_salary") or 20000.0)
        doc["updated_at"] = str(doc.get("updated_at") or utc_now_iso())
        c_quota = doc.get("casual_leave_quota", 12)
        s_quota = doc.get("sick_leave_quota", 8)
        taken = doc.get("leaves_taken", 0)
        doc["casual_leave_quota"] = c_quota
        doc["sick_leave_quota"] = s_quota
        doc["leaves_taken"] = taken
        doc["remaining_casual_leaves"] = max(0, c_quota - taken)
        doc["remaining_sick_leaves"] = max(0, s_quota)
    return doc


# Leave Request System
async def create_leave_request(data) -> Dict[str, Any]:
    db = get_database()
    emp = await get_employee_by_id(data.employee_id)
    if not emp:
        raise ValueError(f"Employee '{data.employee_id}' not found.")
    
    from datetime import datetime
    try:
        d1 = datetime.strptime(data.start_date, "%Y-%m-%d")
        d2 = datetime.strptime(data.end_date, "%Y-%m-%d")
        days = max(1, (d2 - d1).days + 1)
    except Exception:
        days = 1

    req_id = str(uuid.uuid4())
    now = utc_now_iso()
    doc = {
        "_id": req_id,
        "employee_id": data.employee_id,
        "employee_name": emp["name"],
        "leave_type": data.leave_type.lower(),
        "start_date": data.start_date,
        "end_date": data.end_date,
        "days_requested": days,
        "status": "approved", # Auto-approve for business operations
        "reason": data.reason,
        "created_at": now
    }
    await db["leave_requests"].insert_one(doc)

    # Increment leaves taken on employee record
    await db["employees"].update_one(
        {"_id": data.employee_id},
        {"$inc": {"leaves_taken": days}, "$set": {"updated_at": now}}
    )

    doc["id"] = req_id
    return doc

async def get_employee_leave_requests(employee_id: str) -> List[Dict[str, Any]]:
    db = get_database()
    cursor = db["leave_requests"].find({"employee_id": employee_id})
    records = await cursor.to_list(1000)
    for r in records:
        r["id"] = r["_id"]
    return records


# Attendance Upsert Logic
async def mark_attendance(data: AttendanceMark) -> Dict[str, Any]:
    db = get_database()
    now = utc_now_iso()

    emp = await get_employee_by_id(data.employee_id)
    if not emp:
        # Fallback: check if employee exists in employees list
        all_emps = await get_employees()
        emp = next((e for e in all_emps if e.get("id") == data.employee_id or e.get("_id") == data.employee_id), None)
        if not emp:
            raise ValueError(f"Employee with ID '{data.employee_id}' not found.")

    valid_statuses = ["present", "absent", "half_day", "leave"]
    status_clean = data.status.lower()
    if status_clean not in valid_statuses:
        status_clean = "present"

    # Upsert on (employee_id, date)
    query = {"employee_id": data.employee_id, "date": data.date}
    update = {
        "$set": {
            "employee_id": data.employee_id,
            "date": data.date,
            "status": status_clean,
            "updated_at": now
        }
    }
    
    await db["attendance"].update_one(query, update, upsert=True)
    
    doc = await db["attendance"].find_one(query)
    doc_id = str(doc.get("_id", uuid.uuid4())) if doc else str(uuid.uuid4())
    return {
        "id": doc_id,
        "employee_id": data.employee_id,
        "date": data.date,
        "status": status_clean,
        "updated_at": now
    }

async def get_attendance_for_date(date_str: str) -> List[Dict[str, Any]]:
    db = get_database()
    cursor = db["attendance"].find({"date": date_str})
    records = await cursor.to_list(1000)
    cleaned = []
    for r in records:
        cleaned.append({
            "id": str(r.get("_id", r.get("id", ""))),
            "employee_id": str(r.get("employee_id", "")),
            "date": str(r.get("date", date_str)),
            "status": str(r.get("status", "present")),
            "updated_at": str(r.get("updated_at") or utc_now_iso())
        })
    return cleaned
