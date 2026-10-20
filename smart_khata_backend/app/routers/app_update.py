import os
from pathlib import Path
from fastapi import APIRouter, HTTPException, Request
from fastapi.responses import FileResponse, HTMLResponse
from pydantic import BaseModel

router = APIRouter(tags=["OTA App Updates"])

# Candidate APK locations
POSSIBLE_APK_PATHS = [
    Path(__file__).resolve().parent.parent.parent.parent / "smart_khata_app" / "build" / "app" / "outputs" / "flutter-apk" / "app-release.apk",
    Path(__file__).resolve().parent.parent.parent.parent / "smart_khata_app" / "build" / "app" / "outputs" / "flutter-apk" / "app-debug.apk",
    Path(__file__).resolve().parent.parent / "static" / "smart_khata.apk",
]

class AppVersionResponse(BaseModel):
    app_name: str = "Smart Khata"
    current_version: str = "1.0.1"
    version_code: int = 2
    download_url: str = "/api/app/download"
    release_notes_ur: str = "نیا ورژن دستیاب ہے! وائس کمانڈ میں نئی خصوصیات شامل کی گئی ہیں اور مائیک کا وقت درست کیا گیا ہے۔"
    release_notes_en: str = "New version with 17 Voice AI features, automatic mic silence turn-off, and customer khata enhancements."
    file_size_mb: float = 50.4
    is_critical: bool = False

def get_apk_file_and_size():
    for p in POSSIBLE_APK_PATHS:
        if p.exists():
            size_mb = round(p.stat().st_size / (1024 * 1024), 1)
            return p, size_mb
    return None, 50.4

@router.get("/api/app/version", response_model=AppVersionResponse)
async def get_app_version():
    """Returns the latest available mobile app version metadata for OTA checks."""
    _, size_mb = get_apk_file_and_size()
    return AppVersionResponse(
        current_version="1.0.1",
        version_code=2,
        download_url="/api/app/download",
        release_notes_ur="نیا ورژن دستیاب ہے! وائس کمانڈ میں نئی خصوصیات شامل کی گئی ہیں اور مائیک کا وقت درست کیا گیا ہے۔",
        release_notes_en="New version with 17 Voice AI features, automatic mic silence turn-off, and customer khata enhancements.",
        file_size_mb=size_mb,
        is_critical=False
    )

@router.get("/api/app/download")
@router.head("/api/app/download")
async def download_latest_apk():
    """Directly streams the latest compiled APK over Wi-Fi / Cellular data."""
    apk_path, _ = get_apk_file_and_size()
    if apk_path and apk_path.exists():
        return FileResponse(
            path=str(apk_path),
            media_type="application/vnd.android.package-archive",
            filename="smart_khata_latest.apk"
        )
    raise HTTPException(status_code=404, detail="APK file not found on server. Build the APK first.")

@router.get("/update", response_class=HTMLResponse)
@router.get("/download", response_class=HTMLResponse)
async def update_portal(request: Request):
    """Provides a mobile-friendly web portal to download or update the APK wirelessly."""
    apk_path, size_mb = get_apk_file_and_size()
    
    html = f"""<!DOCTYPE html>
<html lang="ur" dir="rtl">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Smart Khata - وائرلیس ایپ اپ ڈیٹ (Wireless App Update)</title>
    <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;600;700;800&family=Noto+Nastaliq+Urdu:wght@500;700&display=swap" rel="stylesheet">
    <style>
        :root {{
            --emerald: #0F5132;
            --emerald-hover: #0a3822;
            --sage: #7DA37D;
            --cream: #F7F3EB;
            --surface: #FFFFFF;
            --charcoal: #1C1C1C;
            --muted: #6B7280;
            --border: #E5E7EB;
            --chip-bg: #E6F2ED;
        }}
        * {{ box-sizing: border-box; margin: 0; padding: 0; }}
        body {{
            font-family: 'Inter', sans-serif;
            background-color: var(--cream);
            color: var(--charcoal);
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
            padding: 24px 16px;
        }}
        .card {{
            background: var(--surface);
            max-width: 520px;
            width: 100%;
            border-radius: 24px;
            box-shadow: 0 16px 40px rgba(15, 81, 50, 0.08);
            border: 1px solid var(--border);
            padding: 32px 28px;
            text-align: center;
        }}
        .badge-logo {{
            display: inline-flex;
            align-items: center;
            justify-content: center;
            width: 64px;
            height: 64px;
            background: var(--emerald);
            color: white;
            border-radius: 18px;
            font-size: 32px;
            margin-bottom: 20px;
            box-shadow: 0 8px 20px rgba(15, 81, 50, 0.25);
        }}
        h1 {{
            font-size: 26px;
            font-weight: 800;
            color: var(--charcoal);
            margin-bottom: 6px;
        }}
        .tagline {{
            color: var(--muted);
            font-size: 14px;
            margin-bottom: 22px;
        }}
        .version-row {{
            display: flex;
            justify-content: center;
            gap: 10px;
            margin-bottom: 24px;
        }}
        .pill {{
            background: var(--chip-bg);
            color: var(--emerald);
            font-weight: 700;
            font-size: 13px;
            padding: 6px 14px;
            border-radius: 20px;
        }}
        .pill-size {{
            background: #F3F4F6;
            color: var(--muted);
        }}
        .notes-box {{
            background: #FAFAFA;
            border: 1px solid var(--border);
            border-radius: 16px;
            padding: 16px 18px;
            text-align: right;
            margin-bottom: 24px;
            font-size: 13.5px;
            line-height: 1.6;
        }}
        .notes-box h3 {{
            color: var(--emerald);
            font-size: 14px;
            margin-bottom: 6px;
            display: flex;
            align-items: center;
            gap: 6px;
        }}
        .btn-download {{
            display: flex;
            align-items: center;
            justify-content: center;
            gap: 10px;
            background: var(--emerald);
            color: white;
            text-decoration: none;
            font-weight: 700;
            font-size: 16px;
            padding: 16px 24px;
            border-radius: 14px;
            transition: all 0.2s ease;
            box-shadow: 0 8px 20px rgba(15, 81, 50, 0.2);
            width: 100%;
        }}
        .btn-download:hover {{
            background: var(--emerald-hover);
            transform: translateY(-2px);
        }}
        .steps {{
            margin-top: 26px;
            text-align: right;
            border-top: 1px solid var(--border);
            padding-top: 20px;
        }}
        .steps h4 {{
            font-size: 13px;
            color: var(--muted);
            margin-bottom: 12px;
            text-transform: uppercase;
            letter-spacing: 0.5px;
        }}
        .step-item {{
            display: flex;
            align-items: flex-start;
            gap: 12px;
            margin-bottom: 10px;
            font-size: 13px;
            color: var(--charcoal);
        }}
        .step-num {{
            background: var(--emerald);
            color: white;
            width: 22px;
            height: 22px;
            border-radius: 50%;
            display: flex;
            align-items: center;
            justify-content: center;
            font-size: 11px;
            font-weight: bold;
            flex-shrink: 0;
            margin-top: 2px;
        }}
        .footer {{
            margin-top: 18px;
            font-size: 11.5px;
            color: var(--muted);
        }}
    </style>
</head>
<body>
    <div class="card">
        <div class="badge-logo">🏪</div>
        <h1>اسمارٹ کھاتہ ایپ اپ ڈیٹ</h1>
        <p class="tagline">Smart Khata Wireless Over-The-Air Update</p>
        
        <div class="version-row">
            <span class="pill">ورژن v1.0.1 (Build 2)</span>
            <span class="pill pill-size">سائز: {size_mb} MB</span>
        </div>

        <div class="notes-box">
            <h3>✨ نئے فیچرز اور تبدیلیاں:</h3>
            <p>• بغیر تار (وائرلیس) بیک اینڈ سرور سے خودکار اپ ڈیٹ</p>
            <p>• وائس کمانڈ خاموشی ڈیٹیکشن (مائیک 1.6 سیکنڈ بعد خود بند ہوتا ہے)</p>
            <p>• گاہکوں کا کھاتہ، ادھار اور بلنگ میں اردو وائس اسسٹنٹ</p>
            <p>• تمام سابقہ آف لائن کسٹمر ڈیٹا محفوظ رہے گا</p>
        </div>

        <a href="/api/app/download" class="btn-download" download>
            <span>📥</span>
            <span>ایپ ڈاؤن لوڈ کریں (Download APK)</span>
        </a>

        <div class="steps">
            <h4>تار کے بغیر انسٹال کرنے کا آسان طریقہ:</h4>
            <div class="step-item">
                <span class="step-num">1</span>
                <div>ڈاؤن لوڈ مکمل ہونے پر نوٹیفکیشن بار پر کلک کریں۔</div>
            </div>
            <div class="step-item">
                <span class="step-num">2</span>
                <div>اگر پوچھا جائے تو "Allow from this source" کو آن کریں۔</div>
            </div>
            <div class="step-item">
                <span class="step-num">3</span>
                <div><strong>"Update"</strong> پر کلک کریں۔ آپ کا تمام ریکارڈ بغیر کیبل محفوظ رہے گا!</div>
            </div>
        </div>

        <div class="footer">
            Final Year Project (FYP) • Kiryana AI Management System
        </div>
    </div>
</body>
</html>"""
    return HTMLResponse(content=html)
