import React from 'react';
import { Container, Row, Col, Card } from 'react-bootstrap';
import { motion } from 'framer-motion';

const Achievements = () => {
    const achievements = [
        {
            title: "District Champions 2024",
            year: "2024",
            description: "Winner of the SMCC LIVE Inter-District Cricket Championship.",
            icon: "bi-trophy-fill",
            color: "text-warning"
        },
        {
            title: "Best Organized Council",
            year: "2023",
            description: "Awarded by the State Sports Authority for excellence in sports management.",
            icon: "bi-award-fill",
            color: "text-primary"
        },
        {
            title: "Fair Play Award",
            year: "2023",
            description: "Recognized for maintaining high standards of sportsmanship across all tournaments.",
            icon: "bi-shield-fill-check",
            color: "text-success"
        },
        {
            title: "Community Outreach",
            year: "2022",
            description: "Successfully trained over 500+ young cricketers under our development program.",
            icon: "bi-people-fill",
            color: "text-info"
        }
    ];

    return (
        <Container className="py-5">
            <motion.div
                initial={{ opacity: 0, y: 20 }}
                animate={{ opacity: 1, y: 0 }}
            >
                <div className="text-center mb-5">
                    <h1 className="fw-black premium-gradient-text text-uppercase mb-2">Our Achievements</h1>
                    <p className="text-muted">Celebrating years of excellence, passion, and sportsmanship.</p>
                </div>

                <Row className="gy-4">
                    {achievements.map((ach, idx) => (
                        <Col key={idx} md={6}>
                            <motion.div
                                whileHover={{ scale: 1.02, rotate: 1 }}
                                transition={{ duration: 0.3 }}
                            >
                                <Card className="glass-card border-0 shadow-lg overflow-hidden h-100">
                                    <Row className="g-0 h-100">
                                        <Col xs={4} className="bg-dark d-flex align-items-center justify-content-center p-4">
                                            <i className={`bi ${ach.icon} ${ach.color}`} style={{ fontSize: '4rem' }}></i>
                                        </Col>
                                        <Col xs={8}>
                                            <Card.Body className="p-4">
                                                <div className="d-flex justify-content-between align-items-start mb-2">
                                                    <h4 className="fw-black text-uppercase mb-0">{ach.title}</h4>
                                                    <span className="badge bg-primary rounded-pill px-3">{ach.year}</span>
                                                </div>
                                                <p className="text-muted mb-0">{ach.description}</p>
                                            </Card.Body>
                                        </Col>
                                    </Row>
                                </Card>
                            </motion.div>
                        </Col>
                    ))}
                </Row>

                <div className="mt-5 p-5 glass-card border-dashed text-center">
                    <h3 className="fw-black mb-3">MANY MORE TO COME</h3>
                    <p className="text-muted mb-0">We are committed to pushing boundaries and achieving new heights in the world of cricket.</p>
                </div>
            </motion.div>
        </Container>
    );
};

export default Achievements;
