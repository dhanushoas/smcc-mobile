import React, { useEffect, useState } from 'react';
import axios from 'axios';
import { Link } from 'react-router-dom';
import { Container, Row, Col, Card, Badge, Spinner, Button, OverlayTrigger, Tooltip } from 'react-bootstrap';
import { io } from 'socket.io-client';
import { useApp } from '../AppContext';
import { toCamelCase } from '../utils/formatters';
import { toast } from 'react-hot-toast';

let API_URL = import.meta.env.VITE_API_URL || 'http://localhost:5000';

// Strip all existing protocols and clean URL
if (API_URL.includes('://')) {
    const parts = API_URL.split('://');
    API_URL = parts[parts.length - 1];
}
API_URL = API_URL.replace(/\/+$/, '');

// Enforce correct protocol
if (API_URL.includes('localhost') || API_URL.includes('127.0.0.1')) {
    API_URL = 'http://' + API_URL;
} else {
    API_URL = 'https://' + API_URL;
}

// Global fail-safe check based on current environment
if (typeof window !== 'undefined' && window.location.hostname.includes('onrender.com')) {
    if (API_URL.includes('localhost')) {
        API_URL = 'https://smcc-backend.onrender.com';
    }
}

console.log("Cric-Live API URL:", API_URL);
const socket = io(API_URL);

const Home = () => {
    const [matches, setMatches] = useState([]);
    const [loading, setLoading] = useState(true);
    const { t, language } = useApp();

    const [showBlast, setShowBlast] = useState(false);
    const [blastValue, setBlastValue] = useState(0);

    const renderMatchesByDate = (filteredMatches) => {
        const groups = {};
        filteredMatches.forEach(m => {
            const dateKey = new Date(m.date).toDateString();
            if (!groups[dateKey]) groups[dateKey] = [];
            groups[dateKey].push(m);
        });

        return Object.keys(groups).map(dateKey => (
            <div key={dateKey} className="mb-4">
                <div className="mb-3 px-3 py-2 bg-light border-start border-primary border-4 rounded-end shadow-sm d-inline-block">
                    <h6 className="m-0 fw-black text-uppercase text-primary" style={{ letterSpacing: '1px' }}>
                        📅 {new Date(dateKey).toLocaleDateString([], { weekday: 'long', day: '2-digit', month: 'long', year: 'numeric' })}
                    </h6>
                </div>
                <Row className="g-4">
                    {groups[dateKey].map(match => renderMatchCard(match, 12))}
                </Row>
            </div>
        ));
    };

    const renderMatchCard = (match, colSize = 6) => {
        const getTeamScore = (teamName) => {
            const innings = match.innings?.find(inn => inn.team === teamName);
            if (!innings) return null;
            return (
                <div className="text-primary fs-3 fw-bold mt-1">
                    {innings.runs}/{innings.wickets}
                    <div className="fs-6 text-muted fw-normal">({innings.overs} {t('overs')})</div>
                </div>
            );
        };

        return (
            <Col key={match._id || match.id} xs={12} lg={colSize}>
                <Card className="h-100 shadow-sm border-0 position-relative overflow-hidden">
                    {match.status === 'live' && (
                        <Badge bg="danger" className="position-absolute top-0 end-0 m-3 px-3 py-2 animate-pulse">
                            ● {t('live')}
                        </Badge>
                    )}

                    <Card.Body className="p-4">
                        <div className="mb-3">
                            <h5 className="fw-bold m-0">{match.title}</h5>
                            <small className="text-muted">
                                {new Date(match.date).toLocaleDateString([], { weekday: 'short', day: 'numeric', month: 'short' })}{' '}
                                {new Date(match.date).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit', hour12: true })} | {match.venue}
                            </small>
                        </div>

                        <Row className="align-items-center text-center my-4">
                            <Col xs={5}>
                                <div className="fw-bold fs-5 text-truncate">{match.teamA.toUpperCase()}</div>
                                {getTeamScore(match.teamA)}
                            </Col>
                            <Col xs={2} className="text-muted small fw-bold">VS</Col>
                            <Col xs={5}>
                                <div className="fw-bold fs-5 text-truncate">{match.teamB.toUpperCase()}</div>
                                {getTeamScore(match.teamB)}
                            </Col>
                        </Row>

                        <div className="mt-4 pt-3 border-top text-center">
                            {match.status === 'live' && (
                                <div className="alert alert-info py-3 mb-0 border-0 rounded-4 shadow-sm mt-3">
                                    {match.score?.target && (
                                        <div className="mb-2 fw-bold text-danger border-bottom pb-1">
                                            🎯 {t('targets')}: {match.score.target} | {(() => {
                                                const runsNeeded = match.score.target - match.score.runs;
                                                const totalBalls = (match.totalOvers || 20) * 6;
                                                const currentOvers = match.score.overs || 0;
                                                const ballsBowled = (Math.floor(currentOvers) * 6) + Math.round((currentOvers % 1) * 10);
                                                const ballsRemaining = Math.max(0, totalBalls - ballsBowled);
                                                return `${runsNeeded} ${t('runs_needed')} ${t('from')} ${ballsRemaining} ${t('balls_rem')}`;
                                            })()}
                                        </div>
                                    )}

                                    {/* INNINGS BREAK DISPLAY */}
                                    {match.status === 'live' && match.score?.target && (!match.currentBatsmen || match.currentBatsmen.length === 0) && (
                                        <div className="alert alert-warning py-2 mb-2 border-0 rounded-4 shadow-sm fw-bold animate-bounce mt-2">
                                            ⏸️ {t('innings_break')}
                                        </div>
                                    )}
                                    <div className="d-flex justify-content-between align-items-center mb-2 px-2">
                                        <small className="fw-bold text-uppercase opacity-75">{t('batting')}</small>
                                        <small className="fw-bold text-uppercase opacity-75">{t('bowling')}</small>
                                    </div>
                                    <div className="d-flex justify-content-between">
                                        <div className="text-start">
                                            {match.currentBatsmen?.map(b => (
                                                <div key={b.name} className={`fw-bold small ${b.onStrike ? 'text-primary' : ''}`}>
                                                    {b.onStrike ? '🏏 ' : ''}{toCamelCase(b.name)}: {b.runs}({b.balls})
                                                </div>
                                            ))}
                                        </div>
                                        <div className="text-end fw-bold">
                                            ⚾ {toCamelCase(match.currentBowler) || 'N/A'}
                                        </div>
                                    </div>
                                </div>
                            )}
                            {/* LIVE TOSS DISPLAY */}
                            {match.status === 'upcoming' && match.toss?.winner && (
                                <div className="alert alert-warning py-2 mb-0 border-0 rounded-4 shadow-sm mt-3 text-center">
                                    <small className="fw-bold text-dark">
                                        🪙 Toss won by <span className="text-primary">{match.toss.winner}</span> elected to {match.toss.decision}
                                    </small>
                                </div>
                            )}
                            {match.status === 'completed' && (
                                <div className="mt-3">
                                    <div className="alert alert-success py-3 mb-0 border-0 rounded-4 shadow-sm">
                                        <div className="d-flex align-items-center justify-content-center gap-2 mb-1">
                                            <span className="fs-4">🏆</span>
                                            <h5 className="fw-black mb-0 text-success text-uppercase" style={{ letterSpacing: '1px' }}>
                                                {match.innings && match.innings.length >= 2 ? (
                                                    match.innings[0].runs > match.innings[1].runs
                                                        ? `${match.innings[0].team} WON`
                                                        : match.innings[1].runs > match.innings[0].runs
                                                            ? `${match.innings[1].team} WON`
                                                            : "MATCH DRAWN"
                                                ) : "MATCH COMPLETED"}
                                            </h5>
                                        </div>
                                        {match.innings && match.innings.length >= 2 && (
                                            <div className="small fw-bold text-muted mb-2">
                                                {match.innings[0].runs > match.innings[1].runs
                                                    ? `By ${match.innings[0].runs - match.innings[1].runs} runs`
                                                    : match.innings[1].runs > match.innings[0].runs
                                                        ? `By ${10 - match.innings[1].wickets} wickets`
                                                        : ""}
                                            </div>
                                        )}
                                        {match.manOfTheMatch && (
                                            <div className="bg-white rounded-pill px-3 py-1 d-inline-block shadow-sm border">
                                                <small className="fw-bold text-success">
                                                    🌟 MOM: {toCamelCase(match.manOfTheMatch)}
                                                </small>
                                            </div>
                                        )}
                                    </div>
                                </div>
                            )}
                            <div className="mt-3">
                                <Button as={Link} to={`/match/${match._id || match.id}`} variant="outline-success" size="sm" className="w-100 fw-bold rounded-pill">
                                    {t('full_scorecard')} →
                                </Button>
                            </div>
                        </div>
                    </Card.Body>
                </Card>
            </Col>
        );
    };

    const fetchMatches = async () => {
        try {
            const res = await axios.get(`${API_URL}/api/matches`);
            setMatches(Array.isArray(res.data) ? res.data : []);
        } catch (err) {
            const serverError = err.response?.data?.error || err.response?.data?.msg || err.message;
            console.error("Error fetching matches:", serverError);
            setMatches([]);
        } finally {
            setLoading(false);
        }
    };

    useEffect(() => {
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
                        setShowBlast(true);
                        setTimeout(() => setShowBlast(false), 2000);
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
        <Container className="d-flex justify-content-center align-items-center" style={{ minHeight: '60vh' }}>
            <Spinner animation="border" variant="success" />
        </Container>
    );

    return (
        <Container className="py-5">
            <header className="text-center mb-5 mt-2 position-relative">
                <Button
                    variant="outline-light"
                    size="sm"
                    className="position-absolute top-0 end-0 m-2 text-muted border-0"
                    onClick={() => { toast.success('Refreshing...'); fetchMatches(); }}
                >
                    ↻
                </Button>
                <img src="/logo.png" alt="SMCC Logo" className="mb-3 shadow-sm rounded-circle" style={{ width: '100px', height: 'auto' }} />
                <h1 className="display-5 fw-bold mb-1 text-primary">SMCC LIVE</h1>
                <p className="lead text-muted small">{t('real_time_updates')}</p>
            </header>

            {/* LIVE SECTION */}
            <div className="mb-5">
                <div className="d-flex align-items-center gap-2 mb-4 border-bottom pb-2">
                    <span className="text-danger fs-4 animate-pulse">●</span>
                    <h2 className="fw-black m-0 text-uppercase letter-spacing-2 text-danger">{t('live')}</h2>
                </div>
                {Array.isArray(matches) && matches.filter(m => m.status === 'live' || (m.status === 'upcoming' && m.toss?.winner)).length > 0 ? (
                    renderMatchesByDate(matches.filter(m => m.status === 'live' || (m.status === 'upcoming' && m.toss?.winner)))
                ) : (
                    <div className="text-muted py-4 text-center border rounded-4 bg-white shadow-sm mb-4">No Live matches</div>
                )}
            </div>

            {/* COMPLETED SECTION */}
            <div className="mb-5">
                <div className="d-flex align-items-center gap-2 mb-4 border-bottom pb-2">
                    <span className="text-success fs-4">🏆</span>
                    <h2 className="fw-black m-0 text-uppercase letter-spacing-2 text-success">{t('completed')}</h2>
                </div>
                {Array.isArray(matches) && matches.filter(m => m.status === 'completed').length > 0 ? (
                    renderMatchesByDate(matches.filter(m => m.status === 'completed'))
                ) : (
                    <div className="text-muted py-4 text-center border rounded-4 bg-white shadow-sm mb-4">No Completed matches</div>
                )}
            </div>

            {/* UPCOMING SECTION */}
            <div className="mb-5">
                <div className="d-flex align-items-center gap-2 mb-4 border-bottom pb-2">
                    <span className="text-primary fs-4">📅</span>
                    <h2 className="fw-black m-0 text-uppercase letter-spacing-2 text-primary">{t('upcoming')}</h2>
                </div>
                {Array.isArray(matches) && matches.filter(m => m.status === 'upcoming' && !m.toss?.winner).length > 0 ? (
                    renderMatchesByDate(matches.filter(m => m.status === 'upcoming' && !m.toss?.winner))
                ) : (
                    <div className="text-muted py-4 text-center border rounded-4 bg-white shadow-sm mb-4">No Upcoming matches</div>
                )}
            </div>

            {matches.length === 0 && (
                <Row className="justify-content-center mt-5">
                    <Col md={6}>
                        <Card className="text-center py-5 border-0 shadow-sm rounded-4">
                            <Card.Body>
                                <div className="fs-1 mb-3">🏏</div>
                                <h3 className="fw-bold">{t('no_matches')}</h3>
                                <p className="text-muted">{t('check_back')}</p>
                            </Card.Body>
                        </Card>
                    </Col>
                </Row>
            )}

            {showBlast && (
                <div className="blast-overlay">
                    <div className="blast-text" style={{ color: blastValue === 6 ? '#28a745' : '#ffc107' }}>
                        {blastValue}
                    </div>
                    <div className="blast-label">{blastValue === 6 ? 'SIX!' : 'FOUR!'}</div>
                </div>
            )}

        </Container>
    );
};

export default Home;
