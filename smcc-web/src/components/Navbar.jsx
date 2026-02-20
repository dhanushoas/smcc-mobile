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
                    <div className="position-relative">
                        <motion.div
                            whileHover={{ scale: 1.1, rotate: 15 }}
                            transition={{ type: "spring", stiffness: 400, damping: 10 }}
                        >
                            <img
                                src="/logo.png"
                                alt="SMCC"
                                style={{ height: '45px', width: '45px' }}
                                className="rounded-circle shadow-sm border border-2 border-primary"
                            />
                        </motion.div>
                        <motion.div
                            className="position-absolute"
                            style={{ bottom: -2, right: -2 }}
                            animate={{
                                y: [0, -8, 0],
                                rotate: [0, 360]
                            }}
                            transition={{
                                duration: 2,
                                repeat: Infinity,
                                ease: "easeInOut"
                            }}
                        >
                            <span className="fs-6">🏏</span>
                        </motion.div>
                    </div>
                    <div className="d-flex align-items-center gap-1">
                        <span className="fw-black fs-4 premium-gradient-text letter-spacing-1 d-none d-md-block">S METTUR CRICKET COUNCIL</span>
                        <span className="fw-black fs-3 premium-gradient-text letter-spacing-1 d-md-none">SMCC</span>
                        <motion.span
                            animate={{ opacity: [1, 0.5, 1], scale: [1, 1.2, 1] }}
                            transition={{ duration: 1.5, repeat: Infinity }}
                            className="badge bg-danger p-1 rounded-circle mb-3"
                            style={{ width: '8px', height: '8px' }}
                        ></motion.span>
                    </div>
                </BsNavbar.Brand>

                <BsNavbar.Toggle aria-controls="basic-navbar-nav" className="border-0 shadow-none">
                    <span className="navbar-toggler-icon"></span>
                </BsNavbar.Toggle>

                <BsNavbar.Collapse id="basic-navbar-nav">
                    <Nav className="ms-auto align-items-center gap-2 mt-3 mt-lg-0">
                        <Nav.Link as={Link} to="/" className="fw-bold px-3 py-2 rounded-pill hover-bg-light transition-all">
                            <i className="bi bi-house-door-fill me-1"></i> {t('home')}
                        </Nav.Link>
                        <Nav.Link href="https://www.cricbuzz.com" target="_blank" className="fw-bold px-3 py-2 rounded-pill hover-bg-light transition-all text-success">
                            <i className="bi bi-lightning-fill me-1"></i> CRICBUZZ
                        </Nav.Link>
                        <Nav.Link href="https://www.espncricinfo.com" target="_blank" className="fw-bold px-3 py-2 rounded-pill hover-bg-light transition-all text-primary">
                            <i className="bi bi-globe me-1"></i> ESPN LIVE
                        </Nav.Link>
                    </Nav>
                </BsNavbar.Collapse>
            </Container>
        </BsNavbar>
    );
};

export default Navbar;
