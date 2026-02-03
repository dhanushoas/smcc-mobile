import React, { useEffect } from 'react';
import { useNavigate, useLocation } from 'react-router-dom';

const GoogleAuth = () => {
    const navigate = useNavigate();
    const location = useLocation();

    useEffect(() => {
        const params = new URLSearchParams(location.search);
        const token = params.get('token');

        if (token) {
            localStorage.setItem('token', token);
            navigate('/admin'); // Redirect back to admin or home
        } else {
            navigate('/login');
        }
    }, [location, navigate]);

    return (
        <div className="d-flex justify-content-center align-items-center" style={{ minHeight: '80vh' }}>
            <div className="text-center">
                <h3>Authenticating...</h3>
                <div className="spinner-border text-primary" role="status"></div>
            </div>
        </div>
    );
};

export default GoogleAuth;
