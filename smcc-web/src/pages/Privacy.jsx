import React from 'react';
import { Container, Card } from 'react-bootstrap';
import { motion } from 'framer-motion';

const Privacy = () => {
    return (
        <Container className="py-5" style={{ maxWidth: '900px' }}>
            <motion.div
                initial={{ opacity: 0 }}
                animate={{ opacity: 1 }}
            >
                <div className="text-center mb-5">
                    <h1 className="fw-black premium-gradient-text text-uppercase mb-2">Privacy Policy</h1>
                    <p className="text-muted small fw-bold">LAST UPDATED: FEBRUARY 2026</p>
                </div>

                <Card className="glass-card border-0 shadow-lg p-4 p-md-5">
                    <div className="d-grid gap-5">
                        <section>
                            <h4 className="fw-black text-primary text-uppercase letter-spacing-1 mb-3">1. Data Collection</h4>
                            <p className="text-muted">
                                We collect information you provide directly to us when you create an account, participate in tournaments, or communicate with us. This includes your name, email, and performance stats.
                            </p>
                        </section>

                        <section>
                            <h4 className="fw-black text-primary text-uppercase letter-spacing-1 mb-3">2. Use of Information</h4>
                            <p className="text-muted">
                                We use the information we collect to operate, maintain, and provide the features of the SMCC platform, including live scoring, rankings, and community updates.
                            </p>
                        </section>

                        <section>
                            <h4 className="fw-black text-primary text-uppercase letter-spacing-1 mb-3">3. Data Sharing</h4>
                            <p className="text-muted">
                                SMCC does not sell your personal data. Player stats and match performances are public by nature as part of the sports platform experience.
                            </p>
                        </section>

                        <section>
                            <h4 className="fw-black text-primary text-uppercase letter-spacing-1 mb-3">4. Security</h4>
                            <p className="text-muted">
                                We implement industry-standard security measures to protect your data. However, no method of transmission over the Internet is 100% secure.
                            </p>
                        </section>

                        <div className="text-center pt-4 border-top">
                            <p className="text-muted small mb-0">For any privacy-related queries, please contact <span className="text-primary fw-bold">privacy@smcc-mettur.org</span></p>
                        </div>
                    </div>
                </Card>
            </motion.div>
        </Container>
    );
};

export default Privacy;
