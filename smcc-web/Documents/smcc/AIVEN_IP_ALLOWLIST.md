# Grant Access to Render on Aiven

You found the **Outbound IP Addresses** for Render! This is great.
Now you need to tell Aiven (your database host) to accept connections coming from these IPs.

### Steps:
1. Log in to your [Aiven Console](https://console.aiven.io/).
2. Click on your MySQL service (**smcc-dhanushkrock-d32b**).
3. In the sidebar (or tabs), look for **Network** or **Allowed IP Addresses**.
4. Click **Add IP Address** / **Add Network**.
5. Add these two ranges:
   - `74.220.48.0/24`
   - `74.220.56.0/24`
6. Click **Save**.

### Why?
By default, databases block strangers. These rules tell your database: *"It's okay, these connections are coming from my backend server on Render."*

### Troubleshooting
If it still fails, you can temporarily add `0.0.0.0/0` to allow ALL connections (for testing only), but adding the specific IPs above is much safer!
