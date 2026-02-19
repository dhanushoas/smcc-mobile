import React, { useState } from 'react';
import { Container, Card, Form, Button, Alert } from 'react-bootstrap';
import { motion } from 'framer-motion';
import { toast } from 'react-hot-toast';
import axios from 'axios';
import API_URL from '../utils/api';

const Report = () => {
    const [formData, setFormData] = useState({ type: 'Technical Bug / App Glitch', matchInfo: '', message: '', evidence: '' });

    const handleSubmit = async (e) => {
        e.preventDefault();
        try {
            await axios.post(`${API_URL}/api/misc/submit`, {
                type: 'report',
                subject: formData.type,
                message: formData.message,
                data: { matchInfo: formData.matchInfo, evidence: formData.evidence }
            });
            toast.success("Incident/Issue reported. Our team will investigate immediately.");
            setFormData({ type: 'Technical Bug / App Glitch', matchInfo: '', message: '', evidence: '' });
        } catch (err) {
            toast.error("Failed to submit report.");
        }
    };

    return (
        <Container className="py-5" style={{ maxWidth: '800px' }}>
            <motion.div
                initial={{ opacity: 0, x: -20 }}
                animate={{ opacity: 1, x: 0 }}
            >
                <div className="text-center mb-5">
                    <h1 className="fw-black text-danger text-uppercase mb-2">Report an Issue</h1>
                    <p className="text-muted">Encountered a bug or an incident? Help us maintain the standards of SMCC.</p>
                </div>

                <Alert variant="warning" className="border-0 shadow-sm rounded-4 p-4 mb-5">
                    <div className="d-flex gap-3">
                        <i className="bi bi-exclamation-triangle-fill fs-3 text-warning"></i>
                        <div>
                            <h6 className="fw-black mb-1">Confidential Reporting</h6>
                            <p className="small mb-0 opacity-75">All reports are strictly confidential. We take bugs and misconduct reports very seriously to maintain a healthy sports ecosystem.</p>
                        </div>
                    </div>
                </Alert>

                <Card className="glass-card border-0 shadow-lg p-4 p-md-5">
                    <Form onSubmit={handleSubmit}>
                        <Form.Group className="mb-4">
                            <Form.Label className="small fw-bold text-muted">REPORT TYPE</Form.Label>
                            <Form.Select
                                className="rounded-pill px-4 border-2 shadow-none py-2"
                                value={formData.type}
                                onChange={(e) => setFormData({ ...formData, type: e.target.value })}
                            >
                                <option>Technical Bug / App Glitch</option>
                                <option>Incorrect Score Entry</option>
                                <option>Unsportsmanlike Conduct</option>
                                <option>Umpiring Dispute</option>
                                <option>Other</option>
                            </Form.Select>
                        </Form.Group>

                        <Form.Group className="mb-4">
                            <Form.Label className="small fw-bold text-muted">MATCH DETAILS (IF APPLICABLE)</Form.Label>
                            <Form.Control
                                type="text"
                                placeholder="e.g., Team A vs Team B on Feb 10"
                                className="rounded-pill px-4 border-2"
                                value={formData.matchInfo}
                                onChange={(e) => setFormData({ ...formData, matchInfo: e.target.value })}
                            />
                        </Form.Group>

                        <Form.Group className="mb-4">
                            <Form.Label className="small fw-bold text-muted">DETAILED DESCRIPTION</Form.Label>
                            <Form.Control
                                as="textarea"
                                rows={5}
                                placeholder="Explain the issue in detail..."
                                className="rounded-4 px-4 py-3 border-2"
                                required
                                value={formData.message}
                                onChange={(e) => setFormData({ ...formData, message: e.target.value })}
                            />
                        </Form.Group>

                        <Form.Group className="mb-5">
                            <Form.Label className="small fw-bold text-muted">ATTACH EVIDENCE (LINK)</Form.Label>
                            <Form.Control
                                type="url"
                                placeholder="GDD/Image Link (Optional)"
                                className="rounded-pill px-4 border-2"
                                value={formData.evidence}
                                onChange={(e) => setFormData({ ...formData, evidence: e.target.value })}
                            />
                        </Form.Group>

                        <motion.div whileHover={{ scale: 1.01 }} whileTap={{ scale: 0.99 }}>
                            <Button variant="danger" type="submit" className="w-100 py-3 rounded-pill fw-black text-uppercase letter-spacing-1 shadow">
                                Submit Incident Report
                            </Button>
                        </motion.div>
                    </Form>
                </Card>
            </motion.div>
        </Container>
    );
};

export default Report;
