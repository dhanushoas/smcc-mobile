import React, { useState } from 'react';
import { Container, Card, Form, Button, Row, Col } from 'react-bootstrap';
import { motion } from 'framer-motion';
import { toast } from 'react-hot-toast';
import axios from 'axios';
import API_URL from '../utils/api';

const Improvements = () => {
    const [formData, setFormData] = useState({ category: 'Live Scoring Experience', title: '', message: '' });

    const handleSubmit = async (e) => {
        e.preventDefault();
        try {
            await axios.post(`${API_URL}/api/misc/submit`, {
                type: 'improvement',
                subject: formData.title,
                message: formData.message,
                data: { category: formData.category }
            });
            toast.success("Thank you for your suggestion! We'll review it for our next update.");
            setFormData({ category: 'Live Scoring Experience', title: '', message: '' });
        } catch (err) {
            toast.error("Failed to submit suggestion.");
        }
    };

    return (
        <Container className="py-5" style={{ maxWidth: '850px' }}>
            <motion.div
                initial={{ opacity: 0, scale: 0.98 }}
                animate={{ opacity: 1, scale: 1 }}
            >
                <div className="text-center mb-5">
                    <h1 className="fw-black premium-gradient-text text-uppercase mb-2">Platform Improvements</h1>
                    <p className="text-muted">Have an idea to make SMCC LIVE better? We're all ears.</p>
                </div>

                <Row className="gy-4 mb-5 text-center">
                    <Col md={4}>
                        <div className="p-3">
                            <i className="bi bi-lightning-charge-fill fs-2 text-warning mb-2 d-block"></i>
                            <h6 className="fw-black text-uppercase small">Suggest Features</h6>
                        </div>
                    </Col>
                    <Col md={4}>
                        <div className="p-3">
                            <i className="bi bi-brush-fill fs-2 text-primary mb-2 d-block"></i>
                            <h6 className="fw-black text-uppercase small">UI/UX Ideas</h6>
                        </div>
                    </Col>
                    <Col md={4}>
                        <div className="p-3">
                            <i className="bi bi-graph-up-arrow fs-2 text-success mb-2 d-block"></i>
                            <h6 className="fw-black text-uppercase small">Stat Insights</h6>
                        </div>
                    </Col>
                </Row>

                <Card className="glass-card border-0 shadow-lg p-4 p-md-5">
                    <Form onSubmit={handleSubmit}>
                        <Form.Group className="mb-4">
                            <Form.Label className="small fw-bold text-muted">IDEA CATEGORY</Form.Label>
                            <Form.Select
                                className="rounded-pill px-4 border-2 shadow-none py-2"
                                value={formData.category}
                                onChange={(e) => setFormData({ ...formData, category: e.target.value })}
                            >
                                <option>Live Scoring Experience</option>
                                <option>Admin Dashboard Tools</option>
                                <option>Member Portal Features</option>
                                <option>Mobile Performance</option>
                                <option>Other</option>
                            </Form.Select>
                        </Form.Group>

                        <Form.Group className="mb-4">
                            <Form.Label className="small fw-bold text-muted">TITLE OF YOUR SUGGESTION</Form.Label>
                            <Form.Control
                                type="text"
                                placeholder="Short descriptive title"
                                className="rounded-pill px-4 border-2"
                                required
                                value={formData.title}
                                onChange={(e) => setFormData({ ...formData, title: e.target.value })}
                            />
                        </Form.Group>

                        <Form.Group className="mb-5">
                            <Form.Label className="small fw-bold text-muted">THE VISION</Form.Label>
                            <Form.Control
                                as="textarea"
                                rows={6}
                                placeholder="Describe your idea and how it would benefit the community..."
                                className="rounded-4 px-4 py-3 border-2"
                                required
                                value={formData.message}
                                onChange={(e) => setFormData({ ...formData, message: e.target.value })}
                            />
                        </Form.Group>

                        <Button variant="primary" type="submit" className="premium-btn w-100 py-3 rounded-pill fw-black text-uppercase shadow border-0">
                            Submit Suggestion
                        </Button>
                    </Form>
                </Card>
            </motion.div>
        </Container>
    );
};

export default Improvements;
