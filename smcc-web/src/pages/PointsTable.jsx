import React, { useEffect, useState } from 'react';
import axios from 'axios';
import { Container, Table, Card, Spinner, Badge } from 'react-bootstrap';
import { motion } from 'framer-motion';
import API_URL from '../utils/api';

const PointsTable = () => {
    const [stats, setStats] = useState([]);
    const [loading, setLoading] = useState(true);

    useEffect(() => {
        const calculatePoints = async () => {
            try {
                const res = await axios.get(`${API_URL}/api/matches`);
                const matches = res.data.filter(m => m.status === 'completed');

                const teamStats = {};

                matches.forEach(m => {
                    const innings = m.innings || [];
                    if (innings.length < 2) return;

                    const teams = [m.teamA, m.teamB];
                    teams.forEach(t => {
                        if (!teamStats[t]) {
                            teamStats[t] = { name: t, p: 0, w: 0, l: 0, d: 0, pts: 0, nrr: 0, runsScored: 0, oversFaced: 0, runsConceded: 0, oversBowled: 0 };
                        }
                        teamStats[t].p += 1;
                    });

                    const runsA = innings[0].runs;
                    const runsB = innings[1].runs;
                    const teamA = innings[0].team;
                    const teamB = innings[1].team;

                    if (runsA > runsB) {
                        teamStats[teamA].w += 1;
                        teamStats[teamA].pts += 2;
                        teamStats[teamB].l += 1;
                    } else if (runsB > runsA) {
                        teamStats[teamB].w += 1;
                        teamStats[teamB].pts += 2;
                        teamStats[teamA].l += 1;
                    } else {
                        teamStats[teamA].d += 1;
                        teamStats[teamA].pts += 1;
                        teamStats[teamB].d += 1;
                        teamStats[teamB].pts += 1;
                    }

                    // Simplistic NRR logic (could be improved with actual balls)
                    teamStats[teamA].runsScored += runsA;
                    teamStats[teamA].oversFaced += innings[0].overs;
                    teamStats[teamA].runsConceded += runsB;
                    teamStats[teamA].oversBowled += innings[1].overs;

                    teamStats[teamB].runsScored += runsB;
                    teamStats[teamB].oversFaced += innings[1].overs;
                    teamStats[teamB].runsConceded += runsA;
                    teamStats[teamB].oversBowled += innings[0].overs;
                });

                const sortedStats = Object.values(teamStats).map(t => {
                    const forRate = t.oversFaced > 0 ? t.runsScored / t.oversFaced : 0;
                    const againstRate = t.oversBowled > 0 ? t.runsConceded / t.oversBowled : 0;
                    return { ...t, nrr: (forRate - againstRate).toFixed(3) };
                }).sort((a, b) => b.pts - a.pts || b.nrr - a.nrr);

                setStats(sortedStats);
            } catch (err) {
                console.error("Error calculating points", err);
            } finally {
                setLoading(false);
            }
        };
        calculatePoints();
    }, []);

    if (loading) return (
        <Container className="d-flex justify-content-center align-items-center" style={{ minHeight: '80vh' }}>
            <Spinner animation="grow" variant="primary" />
        </Container>
    );

    return (
        <Container className="py-5">
            <motion.div
                initial={{ opacity: 0, scale: 0.98 }}
                animate={{ opacity: 1, scale: 1 }}
            >
                <div className="text-center mb-5">
                    <h1 className="fw-black premium-gradient-text text-uppercase mb-2">Points Table</h1>
                    <p className="text-muted small fw-bold">SMCC LIVE - SEASON 2026</p>
                </div>

                <Card className="glass-card border-0 shadow-lg overflow-hidden">
                    <div className="bg-dark text-white p-4 d-flex align-items-center gap-3">
                        <i className="bi bi-trophy-fill text-warning fs-3"></i>
                        <div>
                            <h5 className="mb-0 fw-black text-uppercase letter-spacing-1">Standings</h5>
                            <span className="x-small opacity-75 fw-bold">Updated in real-time after every match</span>
                        </div>
                    </div>
                    <Card.Body className="p-0">
                        <Table hover responsive className="mb-0 border-0">
                            <thead className="bg-light">
                                <tr className="text-muted x-small text-uppercase fw-black letter-spacing-1">
                                    <th className="ps-4 py-4">Pos</th>
                                    <th className="py-4">Team</th>
                                    <th className="text-center py-4">P</th>
                                    <th className="text-center py-4">W</th>
                                    <th className="text-center py-4">L</th>
                                    <th className="text-center py-4">D/NR</th>
                                    <th className="text-center py-4">NRR</th>
                                    <th className="text-center py-4 text-primary">Points</th>
                                </tr>
                            </thead>
                            <tbody>
                                {stats.length === 0 ? (
                                    <tr>
                                        <td colSpan={8} className="text-center py-5 text-muted fw-bold">
                                            No completed matches to calculate standings.
                                        </td>
                                    </tr>
                                ) : (
                                    stats.map((team, idx) => (
                                        <tr key={idx} className="align-middle">
                                            <td className="ps-4 py-4 fw-black fs-5">
                                                {idx === 0 ? <i className="bi bi-crown-fill text-warning me-2"></i> : idx + 1}
                                            </td>
                                            <td className="py-4 fw-black text-primary fs-5 text-uppercase">{team.name}</td>
                                            <td className="text-center py-4 fw-bold">{team.p}</td>
                                            <td className="text-center py-4 text-success fw-bold">{team.w}</td>
                                            <td className="text-center py-4 text-danger fw-bold">{team.l}</td>
                                            <td className="text-center py-4 text-muted">{team.d}</td>
                                            <td className="text-center py-4 fw-bold">{team.nrr}</td>
                                            <td className="text-center py-4">
                                                <Badge bg="primary" className="px-3 py-2 fs-6 shadow-sm">{team.pts}</Badge>
                                            </td>
                                        </tr>
                                    ))
                                )}
                            </tbody>
                        </Table>
                    </Card.Body>
                </Card>

                <div className="mt-4 p-4 border rounded-4 bg-light bg-opacity-50 small text-muted">
                    <p className="mb-0"><i className="bi bi-info-circle-fill me-2"></i> <strong>NRR Calculation:</strong> Net Run Rate is determined by (Runs Scored / Overs Faced) - (Runs Conceded / Overs Bowled).</p>
                </div>
            </motion.div>
        </Container>
    );
};

export default PointsTable;
