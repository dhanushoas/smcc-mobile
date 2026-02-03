# ☁️ How to Host Your SMCC App (Free)

This guide will help you put your Cricket App on the internet so **anyone, anywhere** can use it from any network.

---

## 1️⃣ Database (The Brain)
You need a cloud database to store matches, scores, and users.
**Use Railway (Recommended)**
1. Go to [Railway.app](https://railway.app/).
2. Click **Start a New Project** -> **Provision MySQL**.
3. Click on the created MySQL service -> **Connect**.
4. Copy the **MySQL Connection URL** (e.g., `mysql://root:password@roundhouse.proxy.rlwy.net:12345/railway`).
   - *Save this for later.*

---

## 2️⃣ Backend (The Server)
Host the logic (Node.js) on **Render**.
1. Go to [Render Dashboard](https://dashboard.render.com/).
2. Click **New +** -> **Web Service**.
3. Connect your GitHub repository: `dhanushoas/smcc-backend`.
4. **Configuration**:
   - **Name**: `smcc-backend`
   - **Environment**: `Node`
   - **Build Command**: `npm install`
   - **Start Command**: `node server.js`
5. **Environment Variables** (Scroll down):
   Add specific keys:
   - `DATABASE_URL`: (Paste your Railway Connection URL from Step 1)
   - `JWT_SECRET`: `smccsecretkey123` (or any random text)
   - `PORT`: `10000`
6. Click **Deploy Web Service**.
7. **Copy Your URL**: Once live, copy the URL (e.g., `https://smcc-backend.onrender.com`).

---

## 3️⃣ Frontend (The Website)
Host the website on **Vercel**.
1. Go to [Vercel](https://vercel.com/).
2. Click **Add New** -> **Project**.
3. Import `dhanushoas/smcc-web`.
4. **Environment Variables**:
   - `VITE_API_URL`: (Paste your **Render Backend URL**, e.g., `https://smcc-backend.onrender.com`)
   *Important: Do NOT put a slash `/` at the end.*
5. Click **Deploy**.
6. Your website is now live! 🌍

---

## 4️⃣ Mobile App (The App)
Connect your Android app to the cloud.
1. **Download APK**:
   - Go to [GitHub Actions](https://github.com/dhanushoas/smcc-mobile/actions).
   - Download the latest `app-release.zip` and install the APK.
2. **Setup**:
   - Open App -> Login Screen.
   - Click the **Gear Icon (⚙️)** (Top Right).
   - Enter your **Render Backend URL** (e.g., `https://smcc-backend.onrender.com`).
   - Click **Save**.
3. **Login**:
   - Username: `Admin`
   - Password: `Admin@321`

✅ **Success!** Your app now works on 4G, 5G, Wi-Fi, and anywhere in the world.
