import React from 'react';
import { Link } from 'react-router-dom';
import { Container, Row, Col } from 'react-bootstrap';
import { useApp } from '../AppContext';
import { motion } from 'framer-motion';

const Footer = () => {
    return (
        <footer className="py-5 mt-auto border-top bg-light bg-opacity-75 backdrop-blur">
            <Container>
                <Row className="gy-5">
                    <Col lg={4} className="text-center text-lg-start">
                        <div className="d-flex align-items-center justify-content-center justify-content-lg-start gap-2 mb-3">
                            <img src="/logo.png" alt="SMCC" height="45" className="rounded-circle shadow-sm border border-white" />
                            <span className="fw-black premium-gradient-text fs-4 letter-spacing-1">SMCC LIVE</span>
                        </div>
                        <p className="text-muted small mb-4 pe-lg-4">
                            S Mettur Cricket Council (SMCC) is dedicated to bringing professional-grade cricket scoring and live updates to our community. Experience cricket like never before.
                        </p>
                        <div className="d-flex justify-content-center justify-content-lg-start gap-3">
                            <motion.a whileHover={{ y: -3 }} href="#" className="social-icon bg-primary text-white"><i className="bi bi-facebook"></i></motion.a>
                            <motion.a whileHover={{ y: -3 }} href="#" className="social-icon bg-danger text-white"><i className="bi bi-instagram"></i></motion.a>
                            <motion.a whileHover={{ y: -3 }} href="#" className="social-icon bg-dark text-white"><i className="bi bi-twitter-x"></i></motion.a>
                            <motion.a whileHover={{ y: -3 }} href="#" className="social-icon bg-success text-white"><i className="bi bi-whatsapp"></i></motion.a>
                        </div>
                    </Col>

                    <Col lg={8}>
                        <Row className="gy-4">
                            <Col xs={6} md={4} className="text-center text-md-start">
                                <h6 className="fw-black text-uppercase small letter-spacing-2 mb-4 text-primary">Quick Links</h6>
                                <ul className="list-unstyled d-grid gap-2 small">
                                    <li><Link to="/" className="text-muted text-decoration-none hover-text-primary transition-all">Live Matches</Link></li>
                                    <li><Link to="/schedule" className="text-muted text-decoration-none hover-text-primary transition-all">Upcoming Schedule</Link></li>
                                    <li><Link to="/points-table" className="text-muted text-decoration-none hover-text-primary transition-all">Points Table</Link></li>
                                    <li><Link to="/achievements" className="text-muted text-decoration-none hover-text-primary transition-all">Achievements</Link></li>
                                </ul>
                            </Col>

                            <Col xs={6} md={4} className="text-center text-md-start">
                                <h6 className="fw-black text-uppercase small letter-spacing-2 mb-4 text-primary">Support</h6>
                                <ul className="list-unstyled d-grid gap-2 small">
                                    <li><Link to="/contact" className="text-muted text-decoration-none hover-text-primary transition-all">Contact Us</Link></li>
                                    <li><Link to="/feedback" className="text-muted text-decoration-none hover-text-primary transition-all">Share Feedback</Link></li>
                                    <li><Link to="/report" className="text-muted text-decoration-none hover-text-primary transition-all">Report Issues</Link></li>
                                    <li><Link to="/privacy" className="text-muted text-decoration-none hover-text-primary transition-all">Privacy Policy</Link></li>
                                </ul>
                            </Col>

                            <Col xs={12} md={4} className="text-center text-md-start">
                                <h6 className="fw-black text-uppercase small letter-spacing-2 mb-4 text-primary">Community</h6>
                                <ul className="list-unstyled d-grid gap-2 small">
                                    <li><Link to="/improvements" className="text-muted text-decoration-none hover-text-primary transition-all">Improvements</Link></li>
                                    <li><Link to="/profile" className="text-muted text-decoration-none hover-text-primary transition-all fw-black text-primary">
                                        <i className="bi bi-shield-lock-fill me-1"></i> Update
                                    </Link></li>
                                    <li><Link to="/join" className="text-muted text-decoration-none hover-text-primary transition-all">Join Council</Link></li>
                                    <li><Link to="/sponsorship" className="text-muted text-decoration-none hover-text-primary transition-all">Sponsorship</Link></li>
                                </ul>
                            </Col>
                        </Row>
                    </Col>
                </Row>

                <hr className="my-5 opacity-10" />

                <Row className="align-items-center gy-3">
                    <Col md={6} className="text-center text-md-start">
                        <p className="text-muted x-small mb-0 fw-bold">
                            &copy; {new Date().getFullYear()} SMCC LIVE. ALL RIGHTS RESERVED.
                        </p>
                    </Col>
                    <Col md={6} className="text-center text-md-end">
                        <p className="text-muted x-small mb-0">
                            DESIGNED & DEVELOPED BY <span className="text-primary fw-black letter-spacing-1">DHANUSH THANGARAJ</span>
                        </p>
                    </Col>
                </Row>
            </Container>
        </footer>
    );
};

export default Footer;
