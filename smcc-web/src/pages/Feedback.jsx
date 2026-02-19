import React, { useState } from 'react';
import { Container, Card, Form, Button, Row, Col } from 'react-bootstrap';
import { motion } from 'framer-motion';
import { toast } from 'react-hot-toast';
import axios from 'axios';
import API_URL from '../utils/api';

const Feedback = () => {
    const [rating, setRating] = useState(5);
    const [formData, setFormData] = useState({ name: '', category: 'Web Experience', message: '' });

    const handleSubmit = async (e) => {
        e.preventDefault();
        try {
            await axios.post(`${API_URL}/api/misc/submit`, {
                type: 'feedback',
                name: formData.name,
                message: formData.message,
                data: { rating, category: formData.category }
            });
            toast.success("Thank you for your valuable feedback!");
            setFormData({ name: '', category: 'Web Experience', message: '' });
            setRating(5);
        } catch (err) {
            toast.error("Failed to submit feedback.");
        }
    };

    return (
        <Container className="py-5" style={{ maxWidth: '800px' }}>
            <motion.div
                initial={{ opacity: 0, scale: 0.95 }}
                animate={{ opacity: 1, scale: 1 }}
            >
                <div className="text-center mb-5">
                    <h1 className="fw-black premium-gradient-text text-uppercase mb-2">Share Feedback</h1>
                    <p className="text-muted">Your feedback helps us provide a better experience for everyone.</p>
                </div>

                <Card className="glass-card border-0 shadow-lg p-4 p-md-5">
                    <Form onSubmit={handleSubmit}>
                        <div className="text-center mb-5">
                            <h6 className="fw-black text-muted text-uppercase small mb-4">How was your experience?</h6>
                            <div className="d-flex justify-content-center gap-3">
                                {[1, 2, 3, 4, 5].map((star) => (
                                    <motion.i
                                        key={star}
                                        whileHover={{ scale: 1.2 }}
                                        whileTap={{ scale: 0.9 }}
                                        onClick={() => setRating(star)}
                                        className={`bi bi-star${star <= rating ? '-fill' : ''} fs-1`}
                                        style={{ color: star <= rating ? '#ffc107' : '#dee2e6', cursor: 'pointer' }}
                                    ></motion.i>
                                ))}
                            </div>
                        </div>

                        <Row className="gy-4">
                            <Col md={6}>
                                <Form.Group>
                                    <Form.Label className="small fw-bold text-muted">NAME</Form.Label>
                                    <Form.Control
                                        type="text"
                                        placeholder="Your Name"
                                        className="rounded-pill px-4 border-2"
                                        value={formData.name}
                                        onChange={(e) => setFormData({ ...formData, name: e.target.value })}
                                    />
                                </Form.Group>
                            </Col>
                            <Col md={6}>
                                <Form.Group>
                                    <Form.Label className="small fw-bold text-muted">CATEGORY</Form.Label>
                                    <Form.Select
                                        className="rounded-pill px-4 border-2 shadow-none"
                                        value={formData.category}
                                        onChange={(e) => setFormData({ ...formData, category: e.target.value })}
                                    >
                                        <option>Web Experience</option>
                                        <option>Live Scoring Quality</option>
                                        <option>Tournament Organization</option>
                                        <option>Other</option>
                                    </Form.Select>
                                </Form.Group>
                            </Col>
                            <Col xs={12}>
                                <Form.Group>
                                    <Form.Label className="small fw-bold text-muted">COMMENTS</Form.Label>
                                    <Form.Control
                                        as="textarea"
                                        rows={4}
                                        placeholder="Tell us what you loved or what we can improve..."
                                        className="rounded-4 px-4 py-3 border-2"
                                        required
                                        value={formData.message}
                                        onChange={(e) => setFormData({ ...formData, message: e.target.value })}
                                    />
                                </Form.Group>
                            </Col>
                            <Col xs={12} className="text-center pt-3">
                                <motion.div whileHover={{ scale: 1.02 }} whileTap={{ scale: 0.98 }}>
                                    <Button variant="primary" type="submit" className="premium-btn px-5 py-3 shadow-sm border-0 w-100">
                                        Submit Feedback
                                    </Button>
                                </motion.div>
                            </Col>
                        </Row>
                    </Form>
                </Card>
            </motion.div>
        </Container>
    );
};

export default Feedback;
