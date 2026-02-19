import React, { useState } from 'react';
import { Container, Row, Col, Card, Form, Button } from 'react-bootstrap';
import { motion } from 'framer-motion';
import { toast } from 'react-hot-toast';
import axios from 'axios';
import API_URL from '../utils/api';

const Contact = () => {
    const [formData, setFormData] = useState({ name: '', email: '', subject: '', message: '' });

    const handleSubmit = async (e) => {
        e.preventDefault();
        try {
            await axios.post(`${API_URL}/api/misc/submit`, {
                type: 'contact',
                ...formData
            });
            toast.success("Message sent successfully! We'll get back to you soon.");
            setFormData({ name: '', email: '', subject: '', message: '' });
        } catch (err) {
            toast.error("Failed to send message. Please try again.");
        }
    };

    return (
        <Container className="py-5">
            <motion.div
                initial={{ opacity: 0, y: 20 }}
                animate={{ opacity: 1, y: 0 }}
            >
                <div className="text-center mb-5">
                    <h1 className="fw-black premium-gradient-text text-uppercase mb-2">Contact Us</h1>
                    <p className="text-muted">Have a question or want to get in touch? We're here to help.</p>
                </div>

                <Row className="gy-5">
                    <Col lg={4}>
                        <div className="d-grid gap-4">
                            <Card className="glass-card border-0 shadow-sm p-4 text-center">
                                <div className="bg-primary bg-opacity-10 d-inline-flex p-3 rounded-circle mb-3 mx-auto">
                                    <i className="bi bi-geo-alt-fill fs-3 text-primary"></i>
                                </div>
                                <h5 className="fw-black text-uppercase small letter-spacing-1">Location</h5>
                                <p className="text-muted small mb-0">Mettur, Salem District<br />Tamil Nadu, India</p>
                            </Card>
                            <Card className="glass-card border-0 shadow-sm p-4 text-center">
                                <div className="bg-success bg-opacity-10 d-inline-flex p-3 rounded-circle mb-3 mx-auto">
                                    <i className="bi bi-envelope-fill fs-3 text-success"></i>
                                </div>
                                <h5 className="fw-black text-uppercase small letter-spacing-1">Email</h5>
                                <p className="text-muted small mb-0">contact@smcc-mettur.org<br />support@smcc-mettur.org</p>
                            </Card>
                            <Card className="glass-card border-0 shadow-sm p-4 text-center">
                                <div className="bg-info bg-opacity-10 d-inline-flex p-3 rounded-circle mb-3 mx-auto">
                                    <i className="bi bi-telephone-fill fs-3 text-info"></i>
                                </div>
                                <h5 className="fw-black text-uppercase small letter-spacing-1">Phone</h5>
                                <p className="text-muted small mb-0">+91 98765 43210<br />+91 87654 32109</p>
                            </Card>
                        </div>
                    </Col>

                    <Col lg={8}>
                        <Card className="glass-card border-0 shadow-lg p-4 p-md-5">
                            <Form onSubmit={handleSubmit}>
                                <Row className="gy-4">
                                    <Col md={6}>
                                        <Form.Group>
                                            <Form.Label className="small fw-bold text-muted">YOUR NAME</Form.Label>
                                            <Form.Control
                                                type="text"
                                                placeholder="John Doe"
                                                className="rounded-pill px-4 border-2"
                                                required
                                                value={formData.name}
                                                onChange={(e) => setFormData({ ...formData, name: e.target.value })}
                                            />
                                        </Form.Group>
                                    </Col>
                                    <Col md={6}>
                                        <Form.Group>
                                            <Form.Label className="small fw-bold text-muted">EMAIL ADDRESS</Form.Label>
                                            <Form.Control
                                                type="email"
                                                placeholder="john@example.com"
                                                className="rounded-pill px-4 border-2"
                                                required
                                                value={formData.email}
                                                onChange={(e) => setFormData({ ...formData, email: e.target.value })}
                                            />
                                        </Form.Group>
                                    </Col>
                                    <Col xs={12}>
                                        <Form.Group>
                                            <Form.Label className="small fw-bold text-muted">SUBJECT</Form.Label>
                                            <Form.Control
                                                type="text"
                                                placeholder="Inquiry about memberships"
                                                className="rounded-pill px-4 border-2"
                                                required
                                                value={formData.subject}
                                                onChange={(e) => setFormData({ ...formData, subject: e.target.value })}
                                            />
                                        </Form.Group>
                                    </Col>
                                    <Col xs={12}>
                                        <Form.Group>
                                            <Form.Label className="small fw-bold text-muted">MESSAGE</Form.Label>
                                            <Form.Control
                                                as="textarea"
                                                rows={5}
                                                placeholder="Type your message here..."
                                                className="rounded-4 px-4 py-3 border-2"
                                                required
                                                value={formData.message}
                                                onChange={(e) => setFormData({ ...formData, message: e.target.value })}
                                            />
                                        </Form.Group>
                                    </Col>
                                    <Col xs={12} className="text-end">
                                        <motion.div whileHover={{ scale: 1.02 }} whileTap={{ scale: 0.98 }}>
                                            <Button variant="primary" type="submit" className="premium-btn px-5 py-3 shadow-sm border-0">
                                                <i className="bi bi-send-fill me-2"></i> Send Message
                                            </Button>
                                        </motion.div>
                                    </Col>
                                </Row>
                            </Form>
                        </Card>
                    </Col>
                </Row>
            </motion.div>
        </Container>
    );
};

export default Contact;
