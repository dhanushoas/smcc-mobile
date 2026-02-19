import React, { useState, useEffect } from 'react';
import axios from 'axios';
import { useNavigate } from 'react-router-dom';
import { Container, Row, Col, Card, Form, Button, Alert } from 'react-bootstrap';
import { motion } from 'framer-motion';
import API_URL from '../utils/api';


const Profile = () => {
    const [token, setToken] = useState(localStorage.getItem('token'));
    const [formData, setFormData] = useState({ username: '', password: '' });
    const [error, setError] = useState('');
    const navigate = useNavigate();

    useEffect(() => {
        document.title = 'SMCC | Profile';
    }, []);

    const { username, password } = formData;

    const onChange = e => setFormData({ ...formData, [e.target.name]: e.target.value });

    const onSubmit = async e => {
        e.preventDefault();
        setError('');
        try {
            const res = await axios.post(`${API_URL}/api/auth/login`, formData);
            localStorage.setItem('token', res.data.token);
            if (res.data.user?.id) localStorage.setItem('userId', res.data.user.id);
            setToken(res.data.token);
            setError('');
        } catch (err) {
            const msg = err.response?.data?.msg || 'Login failed';
            const type = err.response?.data?.type;
            setError({ msg, type });
        }
    };

    const handleResetSession = async () => {
        try {
            await axios.post(`${API_URL}/api/auth/reset-session`, formData);
            onSubmit({ preventDefault: () => { } });
        } catch (err) {
            setError({ msg: 'Reset failed. Check credentials.' });
        }
    };

    const handleLogout = async () => {
        const userId = localStorage.getItem('userId');
        if (userId) {
            try { await axios.post(`${API_URL}/api/auth/logout`, { userId }); } catch (e) { }
        }
        localStorage.removeItem('token');
        localStorage.removeItem('userId');
        setToken(null);
        navigate('/');
    };

    return (
        <Container className="d-flex justify-content-center align-items-center" style={{ minHeight: '85vh' }}>
            <motion.div
                initial={{ opacity: 0, y: 20 }}
                animate={{ opacity: 1, y: 0 }}
                className="w-100"
                style={{ maxWidth: '450px' }}
            >
                <Card className="glass-card border-0 shadow-lg p-3">
                    <Card.Body className="p-4 p-md-5 text-center">
                        <div className="mb-4">
                            <motion.div
                                initial={{ scale: 0 }}
                                animate={{ scale: 1 }}
                                className="bg-primary bg-opacity-10 d-inline-flex p-4 rounded-circle mb-3"
                            >
                                <i className="bi bi-shield-lock-fill fs-1 text-primary"></i>
                            </motion.div>
                            <h2 className="fw-black premium-gradient-text mb-2">
                                {token ? 'Admin Access' : 'Administrator'}
                            </h2>
                            <p className="text-muted small">
                                {token ? 'Welcome back! Your dashboard is ready.' : 'Secure gateway for match officials'}
                            </p>
                        </div>

                        {token ? (
                            <div className="d-grid gap-3 pt-3">
                                <Button
                                    variant="primary"
                                    size="lg"
                                    className="rounded-pill fw-bold py-3 shadow-sm d-flex align-items-center justify-content-center gap-2"
                                    onClick={() => navigate('/admin')}
                                >
                                    <i className="bi bi-speedometer2"></i>
                                    Go to Dashboard
                                </Button>
                                <Button
                                    variant="outline-danger"
                                    className="rounded-pill fw-bold border-2"
                                    onClick={handleLogout}
                                >
                                    Sign Out
                                </Button>
                            </div>
                        ) : (
                            <>
                                {error && (
                                    <Alert variant={error.type === 'ALREADY_LOGGED_IN' ? 'warning' : 'danger'} className="py-3 shadow-sm text-start rounded-4 border-0 mb-4">
                                        <div className="d-flex gap-2">
                                            <i className={`bi ${error.type === 'ALREADY_LOGGED_IN' ? 'bi-exclamation-triangle' : 'bi-x-circle'}-fill`}></i>
                                            <span className="small fw-bold">{error.msg}</span>
                                        </div>
                                        {error.type === 'ALREADY_LOGGED_IN' && (
                                            <Button variant="warning" size="sm" className="mt-2 w-100 fw-black text-uppercase rounded-pill" onClick={handleResetSession}>
                                                Reset Session
                                            </Button>
                                        )}
                                    </Alert>
                                )}
                                <Form onSubmit={onSubmit} className="text-start">
                                    <Form.Group className="mb-4">
                                        <Form.Label className="small fw-bold ps-2 opacity-75">USERNAME</Form.Label>
                                        <Form.Control
                                            type="text"
                                            name="username"
                                            value={username}
                                            onChange={onChange}
                                            required
                                            className="rounded-pill py-2 px-4 border-2"
                                            placeholder="Admin user"
                                        />
                                    </Form.Group>
                                    <Form.Group className="mb-4">
                                        <Form.Label className="small fw-bold ps-2 opacity-75">PASSWORD</Form.Label>
                                        <Form.Control
                                            type="password"
                                            name="password"
                                            value={password}
                                            onChange={onChange}
                                            required
                                            className="rounded-pill py-2 px-4 border-2"
                                            placeholder="••••••••"
                                        />
                                    </Form.Group>
                                    <motion.div whileHover={{ scale: 1.02 }} whileTap={{ scale: 0.98 }}>
                                        <Button variant="primary" type="submit" className="w-100 py-3 rounded-pill fw-bold shadow-sm border-0">
                                            Authorize Access
                                        </Button>
                                    </motion.div>
                                </Form>
                            </>
                        )}

                        {!token && (
                            <div className="mt-5 pt-3 border-top text-center">
                                <p className="text-muted x-small mb-0">
                                    Viewer access does not require authentication.<br />
                                    &copy; 2026 S Mettur Cricket Council
                                </p>
                            </div>
                        )}
                    </Card.Body>
                </Card>
            </motion.div>
        </Container>
    );
};

export default Profile;
