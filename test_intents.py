import json
import urllib.request

# 1. Login to get token
login_req = urllib.request.Request(
    "http://127.0.0.1:8000/api/auth/login",
    data=json.dumps({"username": "admin", "password": "admin123"}).encode("utf-8"),
    headers={"Content-Type": "application/json"}
)
with urllib.request.urlopen(login_req) as resp:
    login_data = json.loads(resp.read().decode("utf-8"))
    token = login_data["access_token"]

def test_intent(text):
    req = urllib.request.Request(
        "http://127.0.0.1:8000/api/ai/intent",
        data=json.dumps({"text": text}).encode("utf-8"),
        headers={
            "Content-Type": "application/json",
            "Authorization": f"Bearer {token}"
        }
    )
    with urllib.request.urlopen(req) as resp:
        res = json.loads(resp.read().decode("utf-8"))
        print(f"\n--- Testing: {text} ---")
        print("Intent:", res.get("intent"))
        print("Reply:", res.get("reply"))
        print("Entities:", res.get("entities"))

test_intent("محمد علی کے کھاتے میں 600 جمع کرو")
test_intent("علی کے پیسے بتاؤ")
