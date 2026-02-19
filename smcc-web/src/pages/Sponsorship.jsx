import React from 'react';
import { Container, Row, Col, Card, Button } from 'react-bootstrap';
import { motion } from 'framer-motion';

const Sponsorship = () => {
    return (
        <Container className="py-5">
            <motion.div
                initial={{ opacity: 0, scale: 0.98 }}
                animate={{ opacity: 1, scale: 1 }}
            >
                <div className="text-center mb-5">
                    <h1 className="fw-black premium-gradient-text text-uppercase mb-2">Partner with SMCC</h1>
                    <p className="text-muted">Empowering local cricket through strategic partnerships and sponsorships.</p>
                </div>

                <Card className="glass-card border-0 shadow-lg p-4 p-md-5 mb-5 text-center bg-primary bg-opacity-10">
                    <h2 className="fw-black text-uppercase mb-3">Why Sponsor Us?</h2>
                    <p className="text-muted mx-auto" style={{ maxWidth: '700px' }}>
                        Partnering with SMCC LIVE offers your brand unparalleled visibility among local sports enthusiasts and the wider community. Be part of our growth story.
                    </p>
                </Card>

                <Row className="gy-4">
                    {[
                        { title: "Tournament Title Sponsor", features: ["Logo on all match graphics", "Trophy branding", "Social media mentions"], icon: "bi-star-fill", color: "text-warning" },
                        { title: "Team Kit Partner", features: ["Logo on player jerseys", "Live stream presence", "Match day banners"], icon: "bi-suit-club-fill", color: "text-primary" },
                        { title: "Digital Platform Partner", features: ["Website banner ads", "App integration", "Data insights branding"], icon: "bi-phone-fill", color: "text-info" }
                    ].map((plan, idx) => (
                        <Col key={idx} lg={4}>
                            <motion.div whileHover={{ y: -10 }}>
                                <Card className="glass-card border-0 shadow-lg h-100 p-4">
                                    <div className={`mb-4 ${plan.color}`}>
                                        <i className={`bi ${plan.icon}`} style={{ fontSize: '3rem' }}></i>
                                    </div>
                                    <h5 className="fw-black text-uppercase mb-4">{plan.title}</h5>
                                    <ul className="list-unstyled d-grid gap-3 mb-5 flex-grow-1">
                                        {plan.features.map((f, i) => (
                                            <li key={i} className="small text-muted fw-bold">
                                                <i className="bi bi-dot me-1"></i> {f}
                                            </li>
                                        ))}
                                    </ul>
                                    <Button variant="outline-primary" className="rounded-pill fw-black text-uppercase py-2 border-2">Inquire Now</Button>
                                </Card>
                            </motion.div>
                        </Col>
                    ))}
                </Row>

                <div className="mt-5 text-center">
                    <p className="text-muted mb-4">Interested in a custom sponsorship package?</p>
                    <Button variant="primary" className="premium-btn px-5 py-3 rounded-pill fw-black shadow-lg border-0">DOWNLOAD SPONSORSHIP BROCHURE</Button>
                </div>
            </motion.div>
        </Container>
    );
};

export default Sponsorship;
