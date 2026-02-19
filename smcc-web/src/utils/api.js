let API_URL = import.meta.env.VITE_API_URL || 'http://localhost:5000';

// Configuration
const PROD_BACKEND = 'smcc-backend.onrender.com';
const CONNECT_TO_PROD = import.meta.env.VITE_CONNECT_TO_PROD === 'true';

// Strip all existing protocols and clean URL
if (API_URL.includes('://')) {
    const parts = API_URL.split('://');
    API_URL = parts[parts.length - 1];
}
API_URL = API_URL.replace(/\/+$/, '');

// Environment detection
const isLocal = typeof window !== 'undefined' &&
    (window.location.hostname === 'localhost' || window.location.hostname === '127.0.0.1');

const isProduction = typeof window !== 'undefined' &&
    (window.location.hostname.includes('vercel.app') || window.location.hostname.includes('onrender.com'));

// Failsafe & Direct Override
// 1. If we are in production but API is still localhost -> use Prod
// 2. If we explicitly want to connect to Prod even while local -> use Prod
if ((isProduction || CONNECT_TO_PROD) && (API_URL.includes('localhost') || API_URL.includes('127.0.0.1'))) {
    API_URL = PROD_BACKEND;
}

// Enforce protocol
if (API_URL.includes('localhost') || API_URL.includes('127.0.0.1')) {
    API_URL = 'http://' + API_URL;
} else {
    API_URL = 'https://' + API_URL;
}

console.log(`SMCC API initialized at: ${API_URL} (${CONNECT_TO_PROD ? 'PRODUCTION OVERRIDE' : 'STANDARD'})`);

export default API_URL;

