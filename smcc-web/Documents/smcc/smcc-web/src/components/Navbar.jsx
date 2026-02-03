import React from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { Navbar as BsNavbar, Nav, Container, Button, Dropdown } from 'react-bootstrap';
import { useApp } from '../AppContext';

const Navbar = () => {
    const navigate = useNavigate();
    const token = localStorage.getItem('token');
    const { theme, toggleTheme, language, toggleLanguage, t } = useApp();

    const handleLogout = () => {
        localStorage.removeItem('token');
        navigate('/login');
    };

    return (
        <BsNavbar bg={theme === 'dark' ? 'dark' : 'white'} variant={theme === 'dark' ? 'dark' : 'light'} expand="lg" sticky="top" className="shadow-sm border-bottom">
            <Container>
                <BsNavbar.Brand as={Link} to="/" className="d-flex align-items-center gap-2">
                    <img src="/logo.png" alt="SMCC" style={{ height: '40px' }} />
                    <span className="fw-bold fs-4">SMCC LIVE</span>
                </BsNavbar.Brand>
                <BsNavbar.Toggle aria-controls="basic-navbar-nav" />
                <BsNavbar.Collapse id="basic-navbar-nav">
                    <Nav className="ms-auto align-items-center gap-2">
                        <Nav.Link as={Link} to="/" className="fw-semibold">{t('home')}</Nav.Link>

                        <Button variant={theme === 'dark' ? 'outline-light' : 'outline-dark'} size="sm" onClick={toggleTheme} className="rounded-pill px-3 py-1 d-flex align-items-center gap-2 border-2" title="Toggle Theme">
                            {theme === 'dark' ? (
                                <>
                                    <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" fill="currentColor" viewBox="0 0 16 16">
                                        <path d="M8 11a3 3 0 1 1 0-6 3 3 0 0 1 0 6zm0 1a4 4 0 1 0 0-8 4 4 0 0 0 0 8zM8 0a.5.5 0 0 1 .5.5v2a.5.5 0 0 1-1 0v-2A.5.5 0 0 1 8 0zm0 13a.5.5 0 0 1 .5.5v2a.5.5 0 0 1-1 0v-2A.5.5 0 0 1 8 13zm8-5a.5.5 0 0 1-.5.5h-2a.5.5 0 0 1 0-1h2a.5.5 0 0 1 .5.5zM3 8a.5.5 0 0 1-.5.5h-2a.5.5 0 0 1 0-1h2A.5.5 0 0 1 3 8zm10.657-5.657a.5.5 0 0 1 0 .707l-1.414 1.415a.5.5 0 1 1-.707-.708l1.414-1.414a.5.5 0 0 1 .707 0zm-9.193 9.193a.5.5 0 0 1 0 .707L3.05 13.657a.5.5 0 0 1-.707-.707l1.414-1.414a.5.5 0 0 1 .707 0zm9.193 2.121a.5.5 0 0 1-.707 0l-1.414-1.414a.5.5 0 0 1 .707-.707l1.414 1.414a.5.5 0 0 1 0 .707zM4.464 4.465a.5.5 0 0 1-.707 0L2.343 3.05a.5.5 0 1 1 .707-.707l1.414 1.414a.5.5 0 0 1 0 .708z" />
                                    </svg>
                                    <span className="small fw-bold text-uppercase">Light</span>
                                </>
                            ) : (
                                <>
                                    <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" fill="currentColor" viewBox="0 0 16 16">
                                        <path d="M6 .278a.768.768 0 0 1 .08.858 7.208 7.208 0 0 0-.878 3.46c0 4.021 3.278 7.277 7.318 7.277.527 0 1.04-.055 1.533-.16a.787.787 0 0 1 .81.316.733.733 0 0 1-.031.893A8.349 8.349 0 0 1 8.344 16C3.734 16 0 12.286 0 7.71 0 4.266 2.114 1.312 5.124.06A.752.752 0 0 1 6 .278z" />
                                    </svg>
                                    <span className="small fw-bold text-uppercase">Dark</span>
                                </>
                            )}
                        </Button>

                        <Nav.Link as={Link} to="/profile" className="fw-semibold">
                            {token ? (
                                <span className="d-flex align-items-center gap-1">
                                    <span style={{ fontSize: '1.2rem' }}>👤</span> {t('admin')}
                                </span>
                            ) : (
                                <span className="d-flex align-items-center gap-1">
                                    <span style={{ fontSize: '1.2rem' }}>👤</span> {t('login')}
                                </span>
                            )}
                        </Nav.Link>
                    </Nav>
                </BsNavbar.Collapse>
            </Container>
        </BsNavbar>
    );
};

export default Navbar;
