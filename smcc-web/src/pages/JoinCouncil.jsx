import React from 'react';
import { Container, Row, Col, Card, Button } from 'react-bootstrap';
import { motion } from 'framer-motion';

const JoinCouncil = () => {
    return (
        <Container className="py-5">
            <motion.div
                initial={{ opacity: 0, y: 30 }}
                animate={{ opacity: 1, y: 0 }}
            >
                <div className="text-center mb-5">
                    <h1 className="fw-black premium-gradient-text text-uppercase mb-2">Join the Council</h1>
                    <p className="text-muted">Become a vital part of the SMCC LIVE ecosystem.</p>
                </div>

                <Row className="gy-4">
                    <Col lg={6}>
                        <Card className="glass-card border-0 shadow-lg h-100 overflow-hidden">
                            <div className="bg-primary bg-opacity-10 p-5 text-center">
                                <i className="bi bi-person-plus-fill fs-1 text-primary mb-3 d-block"></i>
                                <h3 className="fw-black text-uppercase letter-spacing-1">As a Player</h3>
                                <p className="text-muted">Register as an official player to participate in league matches, track your stats, and build your profile.</p>
                            </div>
                            <Card.Body className="p-4 p-md-5">
                                <ul className="list-unstyled d-grid gap-3 mb-5">
                                    <li className="d-flex align-items-start gap-2">
                                        <i className="bi bi-check-circle-fill text-success"></i>
                                        <span className="small text-muted fw-bold">Official player ID and profile</span>
                                    </li>
                                    <li className="d-flex align-items-start gap-2">
                                        <i className="bi bi-check-circle-fill text-success"></i>
                                        <span className="small text-muted fw-bold">Advanced career stats and rankings</span>
                                    </li>
                                    <li className="d-flex align-items-start gap-2">
                                        <i className="bi bi-check-circle-fill text-success"></i>
                                        <span className="small text-muted fw-bold">Eligibility for district selections</span>
                                    </li>
                                </ul>
                                <Button variant="primary" className="premium-btn w-100 py-3 rounded-pill fw-black shadow-sm border-0">REGISTER AS PLAYER</Button>
                            </Card.Body>
                        </Card>
                    </Col>

                    <Col lg={6}>
                        <Card className="glass-card border-0 shadow-lg h-100 overflow-hidden">
                            <div className="bg-dark p-5 text-center">
                                <i className="bi bi-shield-lock-fill fs-1 text-primary mb-3 d-block"></i>
                                <h3 className="fw-black text-uppercase text-white letter-spacing-1">As an Official</h3>
                                <p className="text-muted">Join as an umpire, scorer, or tournament organizer to help manage the league with professional tools.</p>
                            </div>
                            <Card.Body className="p-4 p-md-5">
                                <ul className="list-unstyled d-grid gap-3 mb-5">
                                    <li className="d-flex align-items-start gap-2">
                                        <i className="bi bi-check-circle-fill text-primary"></i>
                                        <span className="small text-muted fw-bold">Admin dashboard access</span>
                                    </li>
                                    <li className="d-flex align-items-start gap-2">
                                        <i className="bi bi-check-circle-fill text-primary"></i>
                                        <span className="small text-muted fw-bold">Professional training sessions</span>
                                    </li>
                                    <li className="d-flex align-items-start gap-2">
                                        <i className="bi bi-check-circle-fill text-primary"></i>
                                        <span className="small text-muted fw-bold">Be part of decision-making bodies</span>
                                    </li>
                                </ul>
                                <Button variant="outline-dark" className="w-100 py-3 rounded-pill fw-black shadow-sm border-2">APPLY FOR OFFICIAL ROLE</Button>
                            </Card.Body>
                        </Card>
                    </Col>
                </Row>
            </motion.div>
        </Container>
    );
};

export default JoinCouncil;
