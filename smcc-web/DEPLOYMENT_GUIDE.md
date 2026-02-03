# SMCC Full Stack Deployment Guide

This guide details how to deploy your **Mobile App, Web App, and Backend API** so they work on ANY network (4G/5G/Wi-Fi) globally.

## 1. Database Setup (Aiven MySQL)
You need a cloud database to store matches and users.
1. Sign up at [Aiven.io](https://aiven.io/).
2. Create a new **MySQL** Service (Free Tier is available).
3. Once running, copy the **Service URI** (Connection String).
   - It looks like: `mysql://avnadmin:password@host:port/defaultdb?ssl-mode=REQUIRED`

## 2. Backend Deployment (Render)
To make your API accessible publicly:
1. Sign up at [Render.com](https://render.com/).
2. Click **New +** -> **Web Service**.
3. Select your GitHub repo: `smcc-backend`.
4. **Settings**:
   - **Environment**: Node
   - **Build Command**: `npm install`
   - **Start Command**: `node server.js`
5. **Environment Variables** (Add these):
   - `DATABASE_URL`: (Paste your Aiven MySQL URI from Step 1)
   - `JWT_SECRET`: (Enter a random secret key, e.g., `mysecretkey123`)
   - `FRONTEND_URL`: `https://smcc-web.vercel.app` (You will get this URL in Step 3, come back to update later)
   - `PORT`: `10000`
6. Click **Deploy**.
7. Copy your new **Backend URL** (e.g., `https://smcc-backend.onrender.com`).

## 3. Web App Deployment (Vercel)
To host your admin dashboard and scorecard website:
1. Sign up at [Vercel.com](https://vercel.com/).
2. Click **Add New** -> **Project**.
3. Import your GitHub repo: `smcc-web`.
4. **Environment Variables**:
   - Key: `VITE_API_URL`
   - Value: (Paste your Render Backend URL from Step 2, e.g., `https://smcc-backend.onrender.com`)
   *(Do not add a trailing slash)*
5. Click **Deploy**.
6. You now have a live website URL (e.g., `https://smcc-web.vercel.app`).
   - *Go back to Render Dashboard and update `FRONTEND_URL` with this link!*

## 4. Mobile App Setup (Universal Access)
To connect your mobile app to the cloud backend:
1. **Get the APK**:
   - Go to [GitHub Actions - smcc-mobile](https://github.com/dhanushoas/smcc-mobile/actions).
   - Download the latest `app-release.apk` artifact.
2. **Configure App**:
   - Install and open the app.
   - Go to **Profile**.
   - Click the **Gear Icon ⚙️** (top right of login screen).
   - Enter your **Render Backend URL**: `https://smcc-backend.onrender.com`
   - Click **Save**.
3. **Login**:
   - Username: `Admin`
   - Password: `Admin@321` (or whatever you set in your DB).

## Summary
- **Database**: Aiven (Stores Data)
- **Backend**: Render (Connects App to DB)
- **Web**: Vercel (Admin Dashboard)
- **Mobile**: Your Phone (Connects to Render via Settings)

🚀 **Now your app works on 4G, 5G, and any Wi-Fi in the world!**
