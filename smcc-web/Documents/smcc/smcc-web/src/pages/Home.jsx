import React, { useEffect, useState } from 'react';
import axios from 'axios';
import { Link } from 'react-router-dom';
import { Container, Row, Col, Card, Badge, Spinner, Button } from 'react-bootstrap';
import { io } from 'socket.io-client';
import { useApp } from '../AppContext';

const API_URL = import.meta.env.VITE_API_URL || 'http://localhost:5000';
const socket = io(API_URL);

const Home = () => {
    const [matches, setMatches] = useState([]);
    const [loading, setLoading] = useState(true);
    const { t, language } = useApp();

    const calculateRRR = (match) => {
        if (!match.score?.target) return null;
        const runsNeeded = match.score.target - match.score.runs;
        const totalBalls = match.totalOvers * 6;
        const overs = match.score.overs || 0;
        const ballsBowled = (Math.floor(overs) * 6) + Math.round((overs * 10) % 10);
        const ballsRemaining = totalBalls - ballsBowled;
        if (ballsRemaining <= 0) return runsNeeded <= 0 ? '0.00' : '∞';
        return ((runsNeeded / ballsRemaining) * 6).toFixed(2);
    };

    const renderMatchCard = (match, colSize = 6) => {
        const getTeamScore = (teamName) => {
            const innings = match.innings?.find(inn => inn.team === teamName);
            if (!innings && match.score?.battingTeam !== teamName) return null;

            const runs = innings ? innings.runs : (match.score?.battingTeam === teamName ? match.score.runs : 0);
            const wickets = innings ? innings.wickets : (match.score?.battingTeam === teamName ? match.score.wickets : 0);
            const overs = innings ? innings.overs : (match.score?.battingTeam === teamName ? match.score.overs : 0);

            return (
                <div className="mt-1">
                    <div className="text-primary fs-3 fw-black">
                        {runs}/{wickets}
                    </div>
                    <div className="fs-6 text-muted fw-bold">({overs} {t('overs')})</div>
                </div>
            );
        };

        const rrr = calculateRRR(match);
        const isLive = match.status === 'live';

        return (
            <Col key={match._id || match.id} xs={12} lg={colSize}>
                <Card className={`h-100 shadow-sm border-0 position-relative overflow-hidden card-premium ${isLive ? 'border-start border-danger border-4' : ''}`}>
                    {isLive && (
                        <div className="position-absolute top-0 end-0 m-3 d-flex align-items-center gap-2">
                            <Badge bg="danger" className="px-3 py-2 animate-pulse shadow-sm">
                                ● {t('live').toUpperCase()}
                            </Badge>
                        </div>
                    )}

                    <Card.Body className="p-4 d-flex flex-column h-100">
                        <div className="mb-4">
                            <h5 className="fw-black m-0 text-dark text-uppercase letter-spacing-1">{match.title}</h5>
                            <div className="d-flex align-items-center gap-2 mt-1">
                                <span className="text-muted x-small fw-bold">
                                    {new Date(match.date).toLocaleDateString([], { weekday: 'short', day: 'numeric', month: 'short' })}{' '}
                                    {new Date(match.date).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit', hour12: true })}
                                </span>
                                <span className="text-muted opacity-50">|</span>
                                <span className="text-muted x-small fw-bold text-uppercase">{match.venue}</span>
                            </div>
                        </div>

                        <Row className="align-items-center text-center my-auto py-3">
                            <Col xs={5}>
                                <div className={`fw-black fs-5 text-truncate ${match.score?.battingTeam === match.teamA ? 'text-primary' : 'text-dark opacity-75'}`}>
                                    {match.teamA.toUpperCase()}
                                </div>
                                {getTeamScore(match.teamA)}
                            </Col>
                            <Col xs={2}>
                                <div className="bg-light rounded-circle d-flex align-items-center justify-content-center mx-auto shadow-sm" style={{ width: '40px', height: '40px' }}>
                                    <span className="text-muted fw-black x-small">VS</span>
                                </div>
                            </Col>
                            <Col xs={5}>
                                <div className={`fw-black fs-5 text-truncate ${match.score?.battingTeam === match.teamB ? 'text-primary' : 'text-dark opacity-75'}`}>
                                    {match.teamB.toUpperCase()}
                                </div>
                                {getTeamScore(match.teamB)}
                            </Col>
                        </Row>

                        <div className="mt-4 pt-3 border-top mt-auto">
                            {isLive && (
                                <>
                                    <div className="bg-light-subtle rounded-4 p-3 mb-3 border border-dashed border-primary border-opacity-25 shadow-sm">
                                        <div className="d-flex justify-content-between align-items-center mb-3 px-1">
                                            <small className="fw-black text-uppercase text-primary opacity-75 letter-spacing-1" style={{ fontSize: '10px' }}>{t('batting')}</small>
                                            <small className="fw-black text-uppercase text-success opacity-75 letter-spacing-1" style={{ fontSize: '10px' }}>{t('bowling')}</small>
                                        </div>
                                        <div className="d-flex justify-content-between align-items-start">
                                            <div className="text-start">
                                                {match.currentBatsmen?.map(b => (
                                                    <div key={b.name} className={`d-flex align-items-center gap-1 ${b.onStrike ? 'text-primary' : 'text-muted'}`}>
                                                        <span className="fw-black" style={{ fontSize: '13px' }}>
                                                            {b.onStrike ? '🏏 ' : ''}{b.name || '...'}
                                                        </span>
                                                        <span className="fw-bold ms-1" style={{ fontSize: '12px' }}>
                                                            {b.runs || 0}({b.balls || 0})
                                                        </span>
                                                    </div>
                                                ))}
                                            </div>
                                            <div className="text-end fw-black text-success" style={{ fontSize: '13px' }}>
                                                ⚾ {match.currentBowler || 'N/A'}
                                            </div>
                                        </div>
                                    </div>
                                    {match.score?.target && (
                                        <div className="alert alert-warning py-2 px-3 rounded-pill d-flex justify-content-between align-items-center border-0 shadow-sm mb-3">
                                            <span className="fw-black x-small text-uppercase">Target: <strong>{match.score.target}</strong></span>
                                            <span className="fw-black x-small text-uppercase">RRR: <strong>{rrr}</strong></span>
                                        </div>
                                    )}
                                </>
                            )}

                            {match.status === 'completed' && (
                                <div className="mb-3">
                                    <div className="alert alert-success py-3 px-4 border-0 rounded-4 shadow-sm text-center mb-0">
                                        <div className="d-flex align-items-center justify-content-center gap-2 mb-2">
                                            <span className="fs-5">🏆</span>
                                            <h6 className="fw-black mb-0 text-success text-uppercase letter-spacing-1">
                                                {match.innings && match.innings.length >= 2 ? (
                                                    match.innings[0].runs > match.innings[1].runs
                                                        ? `${match.innings[0].team} WON BY ${match.innings[0].runs - match.innings[1].runs} RUNS`
                                                        : match.innings[1].runs > match.innings[0].runs
                                                            ? `${match.innings[1].team} WON BY ${10 - match.innings[1].wickets} WICKETS`
                                                            : "MATCH DRAWN"
                                                ) : "MATCH COMPLETED"}
                                            </h6>
                                        </div>
                                        {match.manOfTheMatch && (
                                            <div className="bg-white rounded-pill px-3 py-1 d-inline-block shadow-sm border mt-1">
                                                <small className="fw-bold text-success text-uppercase" style={{ fontSize: '10px' }}>
                                                    🏅 MOM: {match.manOfTheMatch}
                                                </small>
                                            </div>
                                        )}
                                    </div>
                                </div>
                            )}

                            {match.status === 'upcoming' && (
                                <div className="text-center py-2 mb-3 bg-light rounded-pill border">
                                    <span className="fw-bold text-muted x-small text-uppercase">Match not started yet</span>
                                </div>
                            )}

                            <Button as={Link} to={`/match/${match._id || match.id}`} variant="outline-success" className="w-100 fw-black rounded-pill py-2 text-uppercase letter-spacing-1" style={{ fontSize: '11px' }}>
                                {t('full_scorecard')} <span className="ms-1">→</span>
                            </Button>
                        </div>
                    </Card.Body>
                </Card>
            </Col>
        );
    };


    const renderMatchesByDate = (filteredMatches) => {
        const groups = {};
        filteredMatches.forEach(m => {
            const dateKey = new Date(m.date).toDateString();
            if (!groups[dateKey]) groups[dateKey] = [];
            groups[dateKey].push(m);
        });

        return Object.keys(groups).map(dateKey => (
            <div key={dateKey} className="mb-4">
                <div className="mb-3 px-3 py-2 bg-light-subtle border-start border-primary border-4 rounded-end shadow-sm d-inline-block">
                    <h6 className="m-0 fw-black text-uppercase text-primary" style={{ letterSpacing: '1px', fontSize: '11px' }}>
                        📅 {new Date(dateKey).toLocaleDateString([], { weekday: 'long', day: '2-digit', month: 'long', year: 'numeric' })}
                    </h6>
                </div>
                <Row className="g-4">
                    {groups[dateKey].map(match => renderMatchCard(match, 12))}
                </Row>
            </div>
        ));
    };

    const fetchMatches = async () => {
        try {
            const res = await axios.get(`${API_URL}/api/matches`);
            setMatches(res.data || []);
        } catch (err) {
            console.error("Error fetching matches", err);
        } finally {
            setLoading(false);
        }
    };

    useEffect(() => {
        fetchMatches();
        socket.on('matchUpdate', (updatedMatch) => {
            setMatches(prevMatches => {
                const index = prevMatches.findIndex(m => m._id === updatedMatch._id || m.id === updatedMatch.id);
                if (index !== -1) {
                    const newMatches = [...prevMatches];
                    newMatches[index] = updatedMatch;
                    return newMatches;
                } else {
                    return [updatedMatch, ...prevMatches];
                }
            });
        });

        socket.on('matchDeleted', (matchId) => {
            setMatches(prevMatches => prevMatches.filter(m => m._id !== matchId && m.id !== matchId));
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
            <header className="text-center mb-5 mt-2">
                <img src="/logo.png" alt="SMCC Logo" className="mb-3 shadow-sm rounded-circle" style={{ width: '100px', height: 'auto' }} />
                <h1 className="display-5 fw-bold mb-1 text-primary">SMCC LIVE</h1>
                <p className="lead text-muted small">{t('real_time_updates')}</p>
            </header>

            {/* LIVE SECTION */}
            {matches.filter(m => m.status === 'live').length > 0 && (
                <div className="mb-5">
                    <div className="d-flex align-items-center gap-2 mb-4 border-bottom pb-2">
                        <span className="text-danger fs-4 animate-pulse">●</span>
                        <h2 className="fw-black m-0 text-uppercase letter-spacing-2 text-danger">{t('live')}</h2>
                    </div>
                    {renderMatchesByDate(matches.filter(m => m.status === 'live'))}
                </div>
            )}

            {/* COMPLETED SECTION */}
            {matches.filter(m => m.status === 'completed').length > 0 && (
                <div className="mb-5">
                    <div className="d-flex align-items-center gap-2 mb-4 border-bottom pb-2">
                        <span className="text-success fs-4">🏆</span>
                        <h2 className="fw-black m-0 text-uppercase letter-spacing-2 text-success">{t('completed')}</h2>
                    </div>
                    {renderMatchesByDate(matches.filter(m => m.status === 'completed'))}
                </div>
            )}

            {/* UPCOMING SECTION */}
            {matches.filter(m => m.status === 'upcoming').length > 0 && (
                <div className="mb-5">
                    <div className="d-flex align-items-center gap-2 mb-4 border-bottom pb-2">
                        <span className="text-primary fs-4">📅</span>
                        <h2 className="fw-black m-0 text-uppercase letter-spacing-2 text-primary">{t('upcoming')}</h2>
                    </div>
                    {renderMatchesByDate(matches.filter(m => m.status === 'upcoming'))}
                </div>
            )}

            {matches.length === 0 && (
                <div className="text-center py-5">
                    <h3 className="text-muted">No matches found</h3>
                </div>
            )}

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

        </Container>
    );
};

export default Home;
