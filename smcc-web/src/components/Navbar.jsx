import React from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { Navbar as BsNavbar, Nav, Container, Button } from 'react-bootstrap';
import { useApp } from '../AppContext';
import { motion } from 'framer-motion';

const Navbar = () => {
    const navigate = useNavigate();
    const { t } = useApp();

    return (
        <BsNavbar expand="lg" className="nav-glass py-3 shadow-sm">
            <Container>
                <BsNavbar.Brand as={Link} to="/" className="d-flex align-items-center gap-2">
                    <motion.div
                        whileHover={{ rotate: 360 }}
                        transition={{ duration: 0.5 }}
                    >
                        <img
                            src="/logo.png"
                            alt="SMCC"
                            style={{ height: '45px', width: '45px' }}
                            className="rounded-circle shadow-sm border border-2 border-primary"
                        />
                    </motion.div>
                    <span className="fw-black fs-3 premium-gradient-text letter-spacing-1">SMCC LIVE</span>
                </BsNavbar.Brand>

                <BsNavbar.Toggle aria-controls="basic-navbar-nav" className="border-0 shadow-none">
                    <span className="navbar-toggler-icon"></span>
                </BsNavbar.Toggle>

                <BsNavbar.Collapse id="basic-navbar-nav">
                    <Nav className="ms-auto align-items-center gap-2 mt-3 mt-lg-0">
                        <Nav.Link as={Link} to="/" className="fw-bold px-3 py-2 rounded-pill hover-bg-light transition-all">
                            <i className="bi bi-house-door-fill me-1"></i> {t('home')}
                        </Nav.Link>
                    </Nav>
                </BsNavbar.Collapse>
            </Container>
        </BsNavbar>
    );
};

export default Navbar;
