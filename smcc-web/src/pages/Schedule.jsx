import React, { useEffect, useState } from 'react';
import axios from 'axios';
import { Container, Card, Row, Col, Badge, Spinner } from 'react-bootstrap';
import { motion } from 'framer-motion';
import API_URL from '../utils/api';
import { toCamelCase, formatTime } from '../utils/formatters';

const Schedule = () => {
    const [matches, setMatches] = useState([]);
    const [loading, setLoading] = useState(true);

    useEffect(() => {
        const fetchMatches = async () => {
            try {
                const res = await axios.get(`${API_URL}/api/matches`);
                // Filter upcoming matches
                const upcoming = res.data.filter(m => m.status === 'upcoming');
                setMatches(upcoming);
            } catch (err) {
                console.error("Error fetching matches", err);
            } finally {
                setLoading(false);
            }
        };
        fetchMatches();
    }, []);

    if (loading) return (
        <Container className="d-flex justify-content-center align-items-center" style={{ minHeight: '80vh' }}>
            <Spinner animation="grow" variant="primary" />
        </Container>
    );

    return (
        <Container className="py-5">
            <motion.div
                initial={{ opacity: 0, y: 20 }}
                animate={{ opacity: 1, y: 0 }}
            >
                <div className="text-center mb-5">
                    <h1 className="fw-black premium-gradient-text text-uppercase mb-2">Upcoming Schedule</h1>
                    <p className="text-muted">Don't miss out on the action. Mark your calendars!</p>
                </div>

                {matches.length === 0 ? (
                    <Card className="glass-card border-0 shadow-sm p-5 text-center">
                        <i className="bi bi-calendar-x fs-1 text-muted mb-3"></i>
                        <h4 className="text-muted">No upcoming matches scheduled yet.</h4>
                        <p className="text-muted small">Stay tuned for updates!</p>
                    </Card>
                ) : (
                    <Row className="gy-4">
                        {matches.map((match, idx) => (
                            <Col key={idx} md={6} lg={4}>
                                <motion.div whileHover={{ y: -5 }} transition={{ duration: 0.2 }}>
                                    <Card className="glass-card border-0 shadow-lg h-100 overflow-hidden">
                                        <div className="bg-primary bg-opacity-10 p-3 text-center border-bottom border-primary border-opacity-10">
                                            <div className="x-small fw-black text-primary text-uppercase mb-1">{match.series || 'SMCC LIVE'}</div>
                                            <div className="small fw-bold text-muted">
                                                <i className="bi bi-geo-alt-fill me-1"></i>{match.venue}
                                            </div>
                                        </div>
                                        <Card.Body className="p-4">
                                            <div className="d-flex justify-content-between align-items-center mb-4">
                                                <div className="text-center" style={{ width: '40%' }}>
                                                    <div className="fw-black fs-5 text-uppercase">{match.teamA}</div>
                                                </div>
                                                <div className="bg-primary text-white rounded-circle d-flex align-items-center justify-content-center shadow-sm" style={{ width: '35px', height: '35px', fontSize: '12px' }}>
                                                    <b>VS</b>
                                                </div>
                                                <div className="text-center" style={{ width: '40%' }}>
                                                    <div className="fw-black fs-5 text-uppercase">{match.teamB}</div>
                                                </div>
                                            </div>
                                            <div className="bg-light bg-opacity-50 rounded-4 p-3 border">
                                                <div className="d-flex align-items-center justify-content-between mb-2">
                                                    <span className="small text-muted fw-bold">DATE</span>
                                                    <span className="small fw-black">{new Date(match.date).toLocaleDateString([], { weekday: 'short', month: 'short', day: 'numeric' })}</span>
                                                </div>
                                                <div className="d-flex align-items-center justify-content-between">
                                                    <span className="small text-muted fw-bold">TIME</span>
                                                    <span className="small fw-black">{formatTime(match.date)}</span>
                                                </div>
                                            </div>
                                        </Card.Body>
                                        <div className="bg-dark text-white p-2 text-center x-small fw-black text-uppercase letter-spacing-1">
                                            {match.totalOvers} OVERS FORMAT
                                        </div>
                                    </Card>
                                </motion.div>
                            </Col>
                        ))}
                    </Row>
                )}
            </motion.div>
        </Container>
    );
};

export default Schedule;
