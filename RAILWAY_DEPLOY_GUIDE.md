# 🚂 Deploying Smart Khata Backend on Railway

**Railway** is significantly faster and more reliable than Render for this project because:
* ⚡ **Zero Cold Starts (No Sleep Lag)**: Unlike Render's free tier (which sleeps after 15 mins and takes ~50s to wake up), Railway stays awake 24/7.
* 📦 **1-Click Built-in MongoDB**: You can provision a live MongoDB database directly inside Railway without needing an external MongoDB Atlas account.
* 🚀 **Instant Audio/Voice Response**: Fast sub-second response times for Whisper voice commands and order processing.

---

## 🛠️ Step-by-Step Deployment (Takes ~3 Minutes)

### Step 1: Create a Railway Account
1. Go to [railway.app](https://railway.app) and click **"Login with GitHub"**.

---

### Step 2: Provision MongoDB Database (1-Click)
1. On your Railway Dashboard, click **"New Project"**.
2. Select **"Provision MongoDB"**.
3. Railway will instantly create a high-performance MongoDB instance.
4. Click on the MongoDB card -> Go to the **"Variables"** or **"Connect"** tab -> Copy the **`MONGO_URL`** (e.g. `mongodb://mongo:password@containers.railway.app:port`).

---

### Step 3: Deploy the FastAPI Backend
1. In the same project canvas, click **"+ New"** -> **"GitHub Repo"**.
2. Select your repository: **`AbdulRehman732/Smartkhata`**.
3. Click on the new service card and go to **Settings**:
   - Under **Root Directory**, set: `/smart_khata_backend`
   - Under **Build**, Railway will automatically detect the [Dockerfile](file:///c:/Users/aar25/Desktop/FYP/smart_khata_backend/Dockerfile) or [railway.json](file:///c:/Users/aar25/Desktop/FYP/smart_khata_backend/railway.json).
4. Go to the **"Variables"** tab and add the following Environment Variables:
   * **`MONGO_URI`**: *(Paste the `MONGO_URL` from Step 2, or your MongoDB Atlas URI)*
   * **`DATABASE_NAME`**: `smart_khata_db`
   * **`SECRET_KEY`**: *(Click "Add Reference" or paste a random string like `smart_khata_railway_secret_2026`)*
   * **`ACCESS_TOKEN_EXPIRE_MINUTES`**: `1440`
5. Go to the **"Networking"** or **"Settings"** tab -> Click **"Generate Domain"** under Public Networking.
6. Railway will give you a live HTTPS URL, for example:
   ```
   https://smart-khata-production.up.railway.app
   ```

---

### Step 4: Verify Deployment & Connect Flutter App
1. Test your live backend by visiting in browser:
   ```
   https://smart-khata-production.up.railway.app/docs
   ```
   *(You will see the Swagger UI interactive API documentation!)*

2. Open the **Smart Khata** Android App -> Tap the **⚙️ Server Connection** icon on the Login Screen.
3. Paste your Railway API URL with `/api`:
   ```
   https://smart-khata-production.up.railway.app/api
   ```
4. Tap **"Save Server"**. Your app is now connected to your Railway backend!
