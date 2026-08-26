# 🚀 100% Free Cloud Deployment Guide for Smart Khata

This guide walks you through deploying your **Smart Khata** backend to the cloud completely **free of cost**, with zero credit card required.

---

## 1. 🗄️ Free Database: MongoDB Atlas (M0 Shared Cluster)
MongoDB Atlas offers a **512 MB free-forever cloud database** (M0 sandbox), which can comfortably store hundreds of thousands of retail transactions, products, and attendance records.

1. Go to [mongodb.com/cloud/atlas/register](https://www.mongodb.com/cloud/atlas/register) and create a free account.
2. Under Deployment, select **M0 (Free)**.
3. Choose the Cloud Provider & Region: **AWS / Singapore (`ap-southeast-1`)** or **Frankfurt** (lowest latency for Pakistan).
4. Under **Security & Network Access**:
   - Create a Database User (e.g. username `smartkhata`, choose a strong password).
   - Under **IP Access List**, click **"Add IP Address"** -> choose **"Allow Access from Anywhere (`0.0.0.0/0`)"** so Render backend can connect.
5. Click **Connect** -> **Drivers (Python)** -> Copy your connection string:
   ```
   mongodb+srv://smartkhata:<password>@cluster0.abcde.mongodb.net/?retryWrites=true&w=majority
   ```

---

## 2. ☁️ Free Backend Hosting: Render.com
Render provides a **free Python web service tier**.

1. Push this repository to **GitHub** (or ensure your repo is connected).
2. Go to [render.com](https://render.com) and sign in with GitHub.
3. Click **New +** -> **Web Service**.
4. Connect your `FYP` or `smart_khata_backend` repository.
5. Set the following settings:
   - **Name**: `smart-khata-api`
   - **Root Directory**: `smart_khata_backend`
   - **Runtime**: `Python 3`
   - **Region**: `Singapore`
   - **Build Command**: `pip install -r requirements.txt`
   - **Start Command**: `uvicorn app.main:app --host 0.0.0.0 --port $PORT`
   - **Instance Type**: `Free`
6. Under **Environment Variables**, add:
   - `MONGO_URI`: *Your MongoDB Atlas connection string from Step 1*
   - `DATABASE_NAME`: `smart_khata_db`
   - `SECRET_KEY`: *(Click generate or paste a random 64-char string)*
   - `ACCESS_TOKEN_EXPIRE_MINUTES`: `1440`
7. Click **Create Web Service**.
8. Once deployed, Render will provide your live HTTPS URL:
   ```
   https://smart-khata-api.onrender.com
   ```

---

## 3. 📱 Connect Your Flutter App
Once your Render backend is live:

1. Open the **Smart Khata** app on your phone or emulator.
2. On the **Sign In** screen, tap the **Server Connection** icon (top right corner ⚙️).
3. Paste your live Render URL with `/api`:
   ```
   https://smart-khata-api.onrender.com/api
   ```
4. Tap **Save Server**. The app will now communicate with your live cloud backend from anywhere in the world!

---

## 4. 📦 Generate Standalone Release APK for Android
To share the app with shopkeepers via WhatsApp or USB:

```powershell
cd smart_khata_app
flutter build apk --release
```
The output file will be saved at:
`smart_khata_app/build/app/outputs/flutter-apk/app-release.apk`
