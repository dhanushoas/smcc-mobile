import React, { useEffect, useState } from 'react';
import axios from 'axios';
import { Link } from 'react-router-dom';
import { Container, Row, Col, Card, Badge, Spinner, Button } from 'react-bootstrap';
import { io } from 'socket.io-client';
import { useApp } from '../AppContext';
import { toCamelCase, formatTime } from '../utils/formatters';
import { toast } from 'react-hot-toast';
import { motion, AnimatePresence } from 'framer-motion';
import API_URL from '../utils/api';


const socket = io(API_URL);

const Home = () => {
    const [matches, setMatches] = useState([]);
    const [loading, setLoading] = useState(true);
    const { t, language } = useApp();

    const [blastValue, setBlastValue] = useState(0);
    const [blastMatchId, setBlastMatchId] = useState(null);

    const renderMatchesByDate = (filteredMatches) => {
        const groups = {};
        filteredMatches.forEach(m => {
            const dateKey = new Date(m.date).toDateString();
            if (!groups[dateKey]) groups[dateKey] = [];
            groups[dateKey].push(m);
        });

        return Object.keys(groups).map(dateKey => (
            <motion.div
                key={dateKey}
                className="mb-5"
                initial={{ opacity: 0, y: 20 }}
                animate={{ opacity: 1, y: 0 }}
                transition={{ duration: 0.5 }}
            >
                <div className="mb-4 d-flex align-items-center">
                    <div className="px-3 py-1 bg-primary text-white rounded-pill shadow-sm d-inline-flex align-items-center gap-2">
                        <i className="bi bi-calendar3"></i>
                        <small className="fw-bold text-uppercase" style={{ letterSpacing: '1px' }}>
                            {new Date(dateKey).toLocaleDateString([], { weekday: 'long', day: '2-digit', month: 'long' })}
                        </small>
                    </div>
                    <div className="flex-grow-1 ms-3 border-bottom opacity-25"></div>
                </div>
                <Row className="g-4">
                    {groups[dateKey].map(match => renderMatchCard(match, 12))}
                </Row>
            </motion.div>
        ));
    };

    const renderMatchCard = (match, colSize = 6) => {
        const getTeamScore = (teamName) => {
            const isBatting = match.status === 'live' && match.score?.battingTeam?.toLowerCase() === teamName.toLowerCase();
            const innings = match.innings?.find(inn => inn.team?.toLowerCase() === teamName.toLowerCase());

            if (!innings && !isBatting) return <div className="text-muted small opacity-50 mt-2">Yet to bat</div>;

            const runs = isBatting ? (match.score?.runs || 0) : (innings?.runs || 0);
            const wickets = isBatting ? (match.score?.wickets || 0) : (innings?.wickets || 0);
            const overs = isBatting ? (match.score?.overs || 0) : (innings?.overs || 0);

            return (
                <div className="mt-2">
                    <div className="score-text text-primary">
                        {runs}/{wickets}
                    </div>
                    <div className="small opacity-75">({overs} ov)</div>
                </div>
            );
        };

        return (
            <Col key={match._id || match.id} xs={12} lg={colSize}>
                <motion.div
                    whileHover={{ scale: 1.01 }}
                    whileTap={{ scale: 0.99 }}
                    layout
                >
                    <Card className="glass-card h-100 border-0 overflow-hidden">
                        {match.status === 'live' && (
                            <div className="position-absolute top-0 end-0 m-3 z-3">
                                <Badge className="badge-live px-3 py-2 animate-pulse d-flex align-items-center gap-2">
                                    <span className="dot bg-white rounded-circle" style={{ width: 6, height: 6 }}></span>
                                    {t('live').toUpperCase()}
                                </Badge>
                            </div>
                        )}

                        <AnimatePresence>
                            {blastMatchId === (match._id || match.id) && (
                                <motion.div
                                    initial={{ opacity: 0 }}
                                    animate={{ opacity: 1 }}
                                    exit={{ opacity: 0 }}
                                    className="blast-overlay rounded-4"
                                >
                                    <motion.div
                                        initial={{ scale: 0.5, y: 50 }}
                                        animate={{ scale: 1, y: 0 }}
                                        exit={{ scale: 1.2, opacity: 0 }}
                                        className="blast-text"
                                        style={{ color: blastValue === 6 ? '#10b981' : '#f59e0b' }}
                                    >
                                        {blastValue}
                                    </motion.div>
                                    <motion.div
                                        initial={{ opacity: 0, y: 10 }}
                                        animate={{ opacity: 1, y: 0 }}
                                        className="blast-label"
                                    >
                                        {blastValue === 6 ? 'SIX!' : 'FOUR!'}
                                    </motion.div>
                                </motion.div>
                            )}
                        </AnimatePresence>

                        <Card.Body className="p-4 p-md-5">
                            <div className="text-center mb-4">
                                <h4 className="fw-black m-0 mb-2 letter-spacing-1">{match.title}</h4>
                                <div className="d-flex justify-content-center align-items-center gap-3 text-muted">
                                    <div className="d-flex align-items-center gap-1 small fw-bold">
                                        <i className="bi bi-geo-alt-fill text-primary"></i>
                                        <span>{match.venue.toUpperCase()}</span>
                                    </div>
                                    <div className="d-flex align-items-center gap-1 small fw-bold">
                                        <i className="bi bi-clock-fill text-primary"></i>
                                        <span>{formatTime(match.date)}</span>
                                    </div>
                                </div>
                            </div>

                            <Row className="align-items-center text-center gy-4">
                                <Col xs={5}>
                                    <div className="team-name fs-5 text-truncate mb-2 text-uppercase fw-black">{match.teamA}</div>
                                    {getTeamScore(match.teamA)}
                                </Col>
                                <Col xs={2}>
                                    <div className="d-flex flex-column align-items-center">
                                        <div className="bg-primary bg-opacity-10 text-primary border border-primary border-opacity-25 rounded-circle p-2 shadow-sm mb-1" style={{ width: '40px', height: '40px', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                                            <span className="fw-black x-small">VS</span>
                                        </div>
                                    </div>
                                </Col>
                                <Col xs={5}>
                                    <div className="team-name fs-5 text-truncate mb-2 text-uppercase fw-black">{match.teamB}</div>
                                    {getTeamScore(match.teamB)}
                                </Col>
                            </Row>

                            <div className="mt-5">
                                {match.status === 'live' && (
                                    <motion.div
                                        initial={{ opacity: 0, y: 10 }}
                                        animate={{ opacity: 1, y: 0 }}
                                        className="bg-primary bg-opacity-10 p-4 rounded-4 border border-primary border-opacity-20 shadow-sm"
                                    >
                                        {match.score?.target && (
                                            <div className="mb-4 text-center border-bottom border-primary border-opacity-10 pb-3">
                                                <div className="text-danger fw-black fs-5 d-flex align-items-center justify-content-center gap-2">
                                                    <i className="bi bi-flag-fill"></i>
                                                    <span>TARGET: {match.score.target}</span>
                                                </div>
                                                {(() => {
                                                    const currentRuns = match.score.runs || 0;
                                                    const currentOvers = match.score.overs || 0;
                                                    if (currentRuns === 0 && currentOvers === 0) return null;

                                                    const runsNeeded = Math.max(0, match.score.target - currentRuns);
                                                    const totalBalls = match.totalOvers * 6;
                                                    const ballsBowled = (Math.floor(currentOvers) * 6) + Math.round((currentOvers % 1) * 10);
                                                    const ballsRemaining = Math.max(0, totalBalls - ballsBowled);
                                                    return (
                                                        <div className="small fw-black text-muted text-uppercase mt-2 letter-spacing-1">
                                                            {runsNeeded} runs needed from {ballsRemaining} balls
                                                        </div>
                                                    );
                                                })()}
                                            </div>
                                        )}

                                        {(!match.currentBatsmen || match.currentBatsmen.length === 0) ? (
                                            <div className="py-4 text-center w-100">
                                                <div className="text-muted fw-black text-uppercase letter-spacing-2 animate-pulse">
                                                    ☕ Innings Break
                                                </div>
                                            </div>
                                        ) : (
                                            <div className="d-flex justify-content-between align-items-center w-100">
                                                <div className="flex-grow-1">
                                                    {match.currentBatsmen.map(b => (
                                                        <div key={b.name} className={`d-flex align-items-center gap-2 mb-2 ${b.onStrike ? 'text-primary fw-black' : 'text-muted fw-bold small'}`}>
                                                            {b.onStrike && <motion.i animate={{ scale: [1, 1.2, 1] }} transition={{ repeat: Infinity }} className="bi bi-lightning-fill"></motion.i>}
                                                            <span>{toCamelCase(b.name)}</span>
                                                            <span className="ms-auto text-dark">{b.runs}*({b.balls})</span>
                                                        </div>
                                                    ))}
                                                </div>
                                                <div className="ms-4 ps-4 border-start border-primary border-opacity-10 text-end">
                                                    <div className="x-small fw-black text-muted text-uppercase mb-1" style={{ letterSpacing: '1px' }}>Bowling</div>
                                                    <div className="fw-black text-primary d-flex align-items-center gap-2 justify-content-end">
                                                        <span className="small text-uppercase">{toCamelCase(match.currentBowler) || 'N/A'}</span>
                                                        <i className="bi bi-circle-fill" style={{ fontSize: '8px' }}></i>
                                                    </div>
                                                </div>
                                            </div>
                                        )}

                                        {match.score?.thisOver && match.score.thisOver.length > 0 && (
                                            <div className="mt-4 pt-4 border-top border-primary border-opacity-10">
                                                <div className="d-flex align-items-center gap-2 mb-3">
                                                    <span className="x-small fw-black text-muted text-uppercase letter-spacing-2">THIS OVER</span>
                                                    <div className="flex-grow-1 border-bottom border-primary border-opacity-10 opacity-25"></div>
                                                </div>
                                                <div className="d-flex gap-2 flex-wrap">
                                                    {match.score.thisOver.map((ball, idx) => {
                                                        const isWicket = ['W', 'OUT'].includes(ball.toString().toUpperCase());
                                                        const isFour = ball.toString() === '4';
                                                        const isSix = ball.toString() === '6';
                                                        const isExtra = ['WD', 'NB'].includes(ball.toString().toUpperCase());

                                                        return (
                                                            <motion.div
                                                                key={idx}
                                                                initial={{ scale: 0 }}
                                                                animate={{ scale: 1 }}
                                                                className={`
                                                                    rounded-circle d-flex align-items-center justify-content-center fw-black
                                                                    ${isWicket ? 'bg-danger text-white shadow-danger' :
                                                                        isSix ? 'bg-success text-white shadow-success' :
                                                                            isFour ? 'bg-warning text-dark shadow-warning' :
                                                                                isExtra ? 'bg-info bg-opacity-25 text-info border border-info border-opacity-50' :
                                                                                    'bg-white border text-dark'}
                                                                `}
                                                                style={{
                                                                    width: '32px',
                                                                    height: '32px',
                                                                    fontSize: '13px',
                                                                    boxShadow: (isWicket || isSix || isFour) ? '0 4px 12px rgba(0,0,0,0.1)' : 'none'
                                                                }}
                                                            >
                                                                {ball}
                                                            </motion.div>
                                                        );
                                                    })}
                                                </div>
                                            </div>
                                        )}
                                    </motion.div>
                                )}


                                {match.status === 'upcoming' && match.toss?.winner && (
                                    <div className="alert bg-warning bg-opacity-10 border-warning border-opacity-25 rounded-4 shadow-sm mb-0 p-3 text-center">
                                        <div className="fw-black d-flex align-items-center justify-content-center gap-2 text-dark">
                                            <i className="bi bi-coin text-warning fs-4"></i>
                                            <span>TOSS: <span className="text-primary">{match.toss.winner.toUpperCase()}</span> WON & ELECTED TO {match.toss.decision.toUpperCase()}</span>
                                        </div>
                                    </div>
                                )}

                                {match.status === 'completed' && (
                                    <div className="bg-success bg-opacity-10 p-4 rounded-4 border border-success border-opacity-20 text-center shadow-sm">
                                        <div className="d-flex align-items-center justify-content-center gap-2 mb-2">
                                            <i className="bi bi-trophy-fill text-success fs-3"></i>
                                            <h4 className="fw-black mb-0 text-success text-uppercase letter-spacing-1">
                                                {match.innings && match.innings.length >= 2 ? (
                                                    match.innings[0].runs > match.innings[1].runs
                                                        ? `${match.innings[0].team} WON`
                                                        : match.innings[1].runs > match.innings[0].runs
                                                            ? `${match.innings[1].team} WON`
                                                            : "MATCH DRAWN"
                                                ) : "MATCH COMPLETED"}
                                            </h4>
                                        </div>
                                        {match.manOfTheMatch && (
                                            <div className="mt-3">
                                                <Badge bg="success" className="rounded-pill px-4 py-2 border-0 shadow-sm fw-black">
                                                    <i className="bi bi-star-fill me-2"></i>
                                                    MOM: {toCamelCase(match.manOfTheMatch)}
                                                </Badge>
                                            </div>
                                        )}
                                    </div>
                                )}

                                {['completed', 'abandoned', 'cancelled'].includes(match.status) && (
                                    <div className="mt-4">
                                        <Button
                                            as={Link}
                                            to={`/match/${match._id || match.id}`}
                                            variant="outline-primary"
                                            className="premium-btn w-100 border-2 py-3 d-flex align-items-center justify-content-center gap-3"
                                        >
                                            <span className="letter-spacing-1">Full Scorecard</span>
                                            <i className="bi bi-chevron-right fs-5"></i>
                                        </Button>
                                    </div>
                                )}
                            </div>
                        </Card.Body>
                    </Card>
                </motion.div>
            </Col>
        );
    };

    const fetchMatches = async () => {
        try {
            const res = await axios.get(`${API_URL}/api/matches`);
            setMatches(Array.isArray(res.data) ? res.data : []);
        } catch (err) {
            console.error("Error fetching matches:", err);
            setMatches([]);
        } finally {
            setLoading(false);
        }
    };

    useEffect(() => {
        document.title = 'SMCC LIVE | Real-time Cricket';
        fetchMatches();
        socket.on('matchUpdate', (updatedMatch) => {
            setMatches(prevMatches => {
                const matchesArr = Array.isArray(prevMatches) ? prevMatches : [];
                const index = matchesArr.findIndex(m => m._id === updatedMatch._id || m.id === updatedMatch.id);
                if (index !== -1) {
                    const oldMatch = matchesArr[index];
                    const oldRuns = oldMatch.score?.runs || 0;
                    const newRuns = updatedMatch.score?.runs || 0;
                    const diff = newRuns - oldRuns;

                    if ((diff === 4 || diff === 6) && updatedMatch.status === 'live') {
                        setBlastValue(diff);
                        setBlastMatchId(updatedMatch._id || updatedMatch.id);
                        setTimeout(() => setBlastMatchId(null), 2500);
                    }

                    const newMatches = [...matchesArr];
                    newMatches[index] = updatedMatch;
                    return newMatches;
                } else {
                    return [updatedMatch, ...matchesArr];
                }
            });
        });

        socket.on('matchDeleted', (matchId) => {
            setMatches(prevMatches => (Array.isArray(prevMatches) ? prevMatches : []).filter(m => m._id !== matchId && m.id !== matchId));
        });

        return () => {
            socket.off('matchUpdate');
            socket.off('matchDeleted');
        };
    }, []);

    if (loading) return (
        <Container className="d-flex justify-content-center align-items-center" style={{ minHeight: '80vh' }}>
            <motion.div
                animate={{ rotate: 360 }}
                transition={{ duration: 1, repeat: Infinity, ease: "linear" }}
            >
                <Spinner animation="border" variant="primary" style={{ width: '3rem', height: '3rem' }} />
            </motion.div>
        </Container>
    );

    return (
        <Container fluid="lg" className="py-5 px-3 px-md-4">
            <header className="text-center mb-5 position-relative">
                <motion.div
                    initial={{ scale: 0 }}
                    animate={{ scale: 1 }}
                    transition={{ type: "spring", stiffness: 260, damping: 20 }}
                >
                    <img src="/logo.png" alt="SMCC Logo" className="mb-4 shadow-lg rounded-circle border border-4 border-white" style={{ width: '120px', height: 'auto' }} />
                </motion.div>
                <motion.h1
                    initial={{ opacity: 0, y: -20 }}
                    animate={{ opacity: 1, y: 0 }}
                    className="display-3 fw-black mb-1 premium-gradient-text"
                >
                    SMCC LIVE
                </motion.h1>
                <motion.p
                    initial={{ opacity: 0 }}
                    animate={{ opacity: 1 }}
                    transition={{ delay: 0.3 }}
                    className="lead text-muted fw-black d-flex align-items-center justify-content-center gap-3 mt-3"
                >
                    <motion.span
                        animate={{ scale: [1, 1.5, 1] }}
                        transition={{ repeat: Infinity, duration: 2 }}
                        className="dot bg-danger rounded-circle"
                        style={{ width: 12, height: 12 }}
                    ></motion.span>
                    <span className="text-uppercase letter-spacing-2 fs-5">{t('real_time_intelligence') || 'Real-time Cricket Intelligence'}</span>
                </motion.p>
            </header>

            {/* LIVE SECTION */}
            <div className="mb-5">
                <div className="mb-4">
                    <h2 className="fw-black m-0 text-uppercase letter-spacing-2 text-danger">Live Matches</h2>
                </div>
                {Array.isArray(matches) && matches.filter(m => m.status === 'live' || (m.status === 'upcoming' && m.toss?.winner)).length > 0 ? (
                    renderMatchesByDate(matches.filter(m => m.status === 'live' || (m.status === 'upcoming' && m.toss?.winner)))
                ) : (
                    <motion.div
                        initial={{ opacity: 0 }}
                        animate={{ opacity: 1 }}
                        className="text-center py-5 glass-card mb-5 border-dashed"
                    >
                        <i className="bi bi-cup-hot fs-1 text-muted opacity-25 d-block mb-3"></i>
                        <span className="text-muted fw-medium small">No matches currently in progress</span>
                    </motion.div>
                )}
            </div>

            {/* COMPLETED SECTION */}
            <div className="mb-5">
                <div className="d-flex align-items-center gap-3 mb-4">
                    <div className="bg-success p-2 rounded-3 shadow-sm d-flex align-items-center justify-content-center text-white">
                        <i className="bi bi-check-circle-fill fs-4"></i>
                    </div>
                    <div>
                        <h2 className="fw-black m-0 text-uppercase letter-spacing-2 text-success">Recently Completed</h2>
                        <small className="text-muted">Final results and highlights</small>
                    </div>
                </div>
                {Array.isArray(matches) && matches.filter(m => m.status === 'completed').length > 0 ? (
                    renderMatchesByDate(matches.filter(m => m.status === 'completed'))
                ) : (
                    <div className="text-center py-5 glass-card mb-5 opacity-75">
                        <span className="text-muted small">No recently completed matches found</span>
                    </div>
                )}
            </div>

            {/* UPCOMING SECTION */}
            <div className="mb-5">
                <div className="d-flex align-items-center gap-3 mb-4">
                    <div className="bg-primary p-2 rounded-3 shadow-sm d-flex align-items-center justify-content-center text-white">
                        <i className="bi bi-calendar-event-fill fs-4"></i>
                    </div>
                    <div>
                        <h2 className="fw-black m-0 text-uppercase letter-spacing-2 text-primary">Scheduled Matches</h2>
                        <small className="text-muted">Gear up for upcoming action</small>
                    </div>
                </div>
                {Array.isArray(matches) && matches.filter(m => m.status === 'upcoming' && !m.toss?.winner).length > 0 ? (
                    renderMatchesByDate(matches.filter(m => m.status === 'upcoming' && !m.toss?.winner))
                ) : (
                    <div className="text-center py-5 glass-card mb-5 opacity-75">
                        <span className="text-muted small">No scheduled matches at the moment</span>
                    </div>
                )}
            </div>

            {matches.length === 0 && (
                <motion.div
                    initial={{ scale: 0.9, opacity: 0 }}
                    animate={{ scale: 1, opacity: 1 }}
                    className="text-center py-5"
                >
                    <div className="fs-1 mb-3">🏏</div>
                    <h3 className="fw-bold">Welcome to SMCC</h3>
                    <p className="text-muted">We're getting ready for the next tournament!</p>
                </motion.div>
            )}

        </Container>
    );
};

export default Home;
