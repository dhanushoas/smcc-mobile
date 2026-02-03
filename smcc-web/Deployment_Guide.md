# 🌍 Global Deployment Guide: Aiven + Render + GitHub

Follow this guide to make your Cricket App accessible from **Any Mobile Device on Any Network** (4G/5G/Wi-Fi).

---

## 🚀 Step 1: Create Database (Aiven)
We need a cloud database to store matches and scores.

1. **Sign Up**: Go to [Aiven.io](https://aiven.io/) and sign up (Free tier available).
2. **Create Service**:
   - Click **Create Service**.
   - Select **MySQL**.
   - Select **Free Plan** (or Hobbyist).
   - Choose a region (e.g., Google Cloud - India or nearby).
   - Click **Create Service**.
3. **Get Connection URL**:
   - Wait for the service to start (Running green light).
   - In the **Overview** tab, find the **Service URI** (it looks like `mysql://user:password@host:port/defaultdb?ssl-mode=REQUIRED`).
   - **Copy** this URI key. You will need it for Render.

---

## 💻 Step 2: Push Code to GitHub
Your code works locally; now sends it to the cloud repository.

1. **Backend Repo**:
   - You already pushed this! ✅
   - Link: `https://github.com/dhanushoas/smcc-backend`

2. **Mobile Repo**:
   - You already pushed this! ✅
   - Link: `https://github.com/dhanushoas/smcc-mobile`

---

## ☁️ Step 3: Host Backend (Render)
Render will run your Node.js server online.

1. **Sign Up**: Go to [Render.com](https://render.com/) and log in with GitHub.
2. **New Web Service**:
   - Click **New +** -> **Web Service**.
   - Select "Build and deploy from a Git repository".
   - Connect your **`smcc-backend`** repository.
3. **Configure**:
   - **Name**: `smcc-backend`
   - **Environment**: Node
   - **Build Command**: `npm install`
   - **Start Command**: `node server.js`
4. **Environment Variables** (Important!):
   - Scroll down to "Environment Variables" -> Click "Add Environment Variable".
   - **Key**: `DATABASE_URL`
   - **Value**: (Paste the **Aiven Service URI** you copied in Step 1).
   - Add another variable:
     - **Key**: `JWT_SECRET`
     - **Value**: `smcc_secret_key_123` (or anything you like).
5. **Deploy**:
   - Click **Create Web Service**.
   - Wait for the deployment logs to say "Server started on port...".
6. **Copy URL**:
   - At the top left, you will see your public URL (e.g., `https://smcc-backend-xyz.onrender.com`).
   - **Copy this URL**. This is your global access point!

---

## 📱 Step 4: Connect Mobile App
Now, tell your mobile app to talk to the Render Cloud instead of your laptop.

1. **Download App**:
   - Go to your [Mobile GitHub Actions](https://github.com/dhanushoas/smcc-mobile/actions).
   - Download the latest `app-release.apk`.
   - Install it on your phone.
2. **Configure**:
   - Open the App.
   - Go to **Profile**.
   - Click the **Gear Icon (⚙️)** (top right).
   - **Paste your Render URL** (from Step 3, e.g., `https://smcc-backend-xyz.onrender.com`).
     - *Note: Ensure it starts with `https://`*
   - Click **Save**.
3. **Login**:
   - Use `Admin` / `Admin@321`.

---

## 🎉 Success!
- **Your Database** is on Aiven (Cloud).
- **Your Backend** is on Render (Cloud).
- **Your App** is on your phone.

You can now match score from the cricket ground using 4G, and anyone in the world can see the updates! 🏏
