import io
import pytest  # type: ignore
from httpx import AsyncClient  # type: ignore

@pytest.mark.asyncio
async def test_ai_intent_classification_and_ledger_mutation(client: AsyncClient, owner_headers):
    await client.post("/api/products", json={
        "name": "Basmati Rice 5kg",
        "urdu_name": "چاول 5 کلو",
        "category": "Grains",
        "unit": "kg",
        "buying_price": 1000.0,
        "selling_price": 1200.0,
        "current_stock": 25.0
    }, headers=owner_headers)

    c_res = await client.post("/api/customers", json={
        "name": "Muhammad Ali",
        "phone": "03119876543"
    }, headers=owner_headers)
    cust_id = c_res.json()["id"]

    await client.post("/api/orders", json={
        "line_items": [{"product_id": (await client.get("/api/products", headers=owner_headers)).json()[0]["id"], "quantity": 1.0}],
        "payment_method": "credit",
        "customer_id": cust_id
    }, headers=owner_headers)

    cust_check = await client.get(f"/api/customers/{cust_id}", headers=owner_headers)
    assert cust_check.json()["balance_due"] == 1200.0

    # 1. Keyword Collision Safeguard Test: "restock" vs "stock"
    res_restock = await client.post("/api/ai/intent", json={"text": "what should I restock list today"}, headers=owner_headers)
    assert res_restock.status_code == 200
    assert res_restock.json()["intent"] == "restock_list"

    # 2. Stock query in Urdu ("chawal ka stock check karo")
    res_stock = await client.post("/api/ai/intent", json={"text": "chawal ka stock check karo"}, headers=owner_headers)
    assert res_stock.status_code == 200
    assert res_stock.json()["intent"] == "check_stock"
    assert "Basmati Rice 5kg" in res_stock.json()["reply"]

    # 3. Customer balance query ("Muhammad Ali ka balance kitna hai")
    res_balance = await client.post("/api/ai/intent", json={"text": "Muhammad Ali ka balance kitna hai"}, headers=owner_headers)
    assert res_balance.status_code == 200
    assert res_balance.json()["intent"] == "customer_balance"

    # 4. VOICE ACTION (Text): Record payment via natural language ("Muhammad Ali ne 500 rupay jamah karwaye")
    res_action = await client.post("/api/ai/intent", json={"text": "Muhammad Ali ne 500 rupay jamah karwaye"}, headers=owner_headers)
    assert res_action.status_code == 200
    assert res_action.json()["intent"] == "record_payment"
    assert "700" in res_action.json()["reply"]

    # Verify Customer Ledger balance updated from 1200.0 -> 700.0
    cust_updated = await client.get(f"/api/customers/{cust_id}", headers=owner_headers)
    assert cust_updated.json()["balance_due"] == 700.0

    # 6. WhatsApp Reminder Generation
    res_wa = await client.post("/api/ai/intent", json={"text": "Muhammad Ali ko WhatsApp per reminder bhejo"}, headers=owner_headers)
    assert res_wa.status_code == 200
    assert res_wa.json()["intent"] == "whatsapp_reminder"
    assert "whatsapp_url" in res_wa.json()
    assert "wa.me" in res_wa.json()["whatsapp_url"]

    # 7. Daily Business Summary
    res_summary = await client.post("/api/ai/intent", json={"text": "aaj ki sale kitni hui"}, headers=owner_headers)
    assert res_summary.status_code == 200
    assert res_summary.json()["intent"] == "daily_summary"

    # 8. Store Expense Recording
    res_exp = await client.post("/api/ai/intent", json={"text": "Bijli ka bill 2000 rupay ada kiya"}, headers=owner_headers)
    assert res_exp.status_code == 200
    assert res_exp.json()["intent"] == "add_expense"

    # 9. Supplier Payment
    res_sup = await client.post("/api/ai/intent", json={"text": "Supplier Farooq ko 5000 rupay diye"}, headers=owner_headers)
    assert res_sup.status_code == 200
    assert res_sup.json()["intent"] == "supplier_payment"

    # 10. Voice Sale (Credit / Udhaar)
    res_sale = await client.post("/api/ai/intent", json={"text": "Muhammad Ali ko 2 kilo chawal udhaar becho"}, headers=owner_headers)
    assert res_sale.status_code == 200
    assert res_sale.json()["intent"] == "record_sale"

    # 11. Add New Customer
    res_new_cust = await client.post("/api/ai/intent", json={"text": "Naya customer Tariq Mahmood 03001234567 shamil karo"}, headers=owner_headers)
    assert res_new_cust.status_code == 200
    assert res_new_cust.json()["intent"] == "add_customer"

