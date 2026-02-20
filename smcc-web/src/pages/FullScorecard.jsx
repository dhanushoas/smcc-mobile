import React, { useEffect, useState } from 'react';
import { useParams, Link } from 'react-router-dom';
import axios from 'axios';
import { Container, Card, Table, Nav, Spinner, Button, Row, Col, Badge } from 'react-bootstrap';
import { io } from 'socket.io-client';
import { useApp } from '../AppContext';
import { jsPDF } from 'jspdf';
import { toCamelCase, formatTime } from '../utils/formatters';
import autoTable from 'jspdf-autotable';
import { toast } from 'react-hot-toast';
import { motion, AnimatePresence } from 'framer-motion';
import API_URL from '../utils/api';


const socket = io(API_URL);

const FullScorecard = () => {
    const { id } = useParams();
    const [match, setMatch] = useState(null);
    const [loading, setLoading] = useState(true);
    const [activeInnings, setActiveInnings] = useState(0);
    const [activeTab, setActiveTab] = useState('scorecard');
    const { t } = useApp();

    const fetchMatch = async () => {
        try {
            const res = await axios.get(`${API_URL}/api/matches/${id}`);
            setMatch(res.data);
            if (res.data.status === 'live' || res.data.status === 'completed') {
                const bTeam = res.data.score?.battingTeam;
                if (bTeam) {
                    const reversed = [...res.data.innings].map((inn, i) => ({ ...inn, idx: i })).reverse();
                    const activeInn = reversed.find(inn =>
                        inn.team?.trim().toLowerCase() === bTeam.trim().toLowerCase()
                    );
                    if (activeInn) setActiveInnings(activeInn.idx);
                    else setActiveInnings(res.data.innings.length - 1);
                } else {
                    setActiveInnings(res.data.innings.length - 1);
                }
            }
        } catch (err) {
            console.error("Error fetching match", err);
        } finally {
            setLoading(false);
        }
    };

    useEffect(() => {
        document.title = 'SMCC | Match Scorecard';
        fetchMatch();
        socket.on('matchUpdate', (updatedMatch) => {
            if (updatedMatch._id === id || updatedMatch.id === id) setMatch(updatedMatch);
        });
        return () => { socket.off('matchUpdate'); };
    }, [id]);

    const downloadPDF = () => {
        const doc = new jsPDF();
        doc.setFontSize(18);
        doc.setFont(undefined, 'bold');
        doc.text(`${match.teamA.toUpperCase()} VS ${match.teamB.toUpperCase()} - FULL SCORECARD`, 14, 20);
        doc.setFontSize(10);
        doc.setFont(undefined, 'normal');
        doc.text(`SERIES: ${(match.series || 'SMCC').toUpperCase()} | VENUE: ${match.venue.toUpperCase()} | DATE: ${new Date(match.date).toDateString().toUpperCase()} ${formatTime(match.date).toUpperCase()}`, 14, 30);

        (match.innings || []).forEach((inn, idx) => {
            if (idx >= 2 && inn.runs === 0 && inn.wickets === 0 && (!inn.batting || inn.batting.length === 0)) {
                return;
            }

            let startY = doc.lastAutoTable ? doc.lastAutoTable.finalY + 15 : 40;

            if (idx === 2) {
                // Force super over cleanly onto page 2
                doc.addPage();
                startY = 20;
            } else if (idx !== 2 && startY > 260) {
                // Emergency break if content is way too long
                doc.addPage();
                startY = 20;
            }

            const getOrdinal = (n) => { const s = ["th", "st", "nd", "rd"]; const v = n % 100; return n + (s[(v - 20) % 10] || s[v] || s[0]); };
            const title = `${inn.team.toUpperCase()} ${getOrdinal(idx + 1).toUpperCase()} INNINGS${idx >= 2 ? ' (SUPER OVER)' : ''}`;
            doc.setFontSize(14);
            doc.setFont(undefined, 'bold');
            doc.text(`${title}: ${inn.runs}/${inn.wickets} (${inn.overs} OV)`, 14, startY);
            doc.setFont(undefined, 'normal');

            const battingData = (inn.batting || []).map(b => [b.player.toUpperCase(), b.status.toUpperCase(), b.runs, b.balls, b.fours, b.sixes, b.strikeRate]);
            const extras = inn.extras || { total: 0, wides: 0, noBalls: 0, byes: 0, legByes: 0 };

            if (battingData.length > 0 || extras.total > 0) {
                autoTable(doc, {
                    startY: startY + 8,
                    head: [['Batter', 'Status', 'R', 'B', '4s', '6s', 'SR']],
                    body: [
                        ...battingData,
                        ['Extras', '', extras.total, `(wd ${extras.wides}, nb ${extras.noBalls}, b ${extras.byes}, lb ${extras.legByes})`, '', '', '']
                    ],
                    theme: 'grid',
                    headStyles: { fillColor: [0, 146, 112] }
                });
            }

            const breakdown = [
                `Dots: ${inn.dots || 0}`, `1s: ${inn.ones || 0}`, `2s: ${inn.twos || 0}`,
                `3s: ${inn.threes || 0}`, `4s: ${inn.fours || 0}`, `6s: ${inn.sixes || 0}`
            ].join(' | ');
            doc.setFontSize(9);
            doc.setTextColor(100);
            doc.setFont(undefined, 'bold');
            doc.text(`HIT BREAKDOWN: `, 14, doc.lastAutoTable.finalY + 8);
            doc.setFont(undefined, 'normal');
            doc.text(breakdown, 45, doc.lastAutoTable.finalY + 8);

            const bowlingTeamIdx = idx % 2 === 0 ? idx + 1 : idx - 1;
            const bowlingInn = match.innings[bowlingTeamIdx];
            if (bowlingInn && bowlingInn.bowling && bowlingInn.bowling.length > 0) {
                autoTable(doc, {
                    startY: doc.lastAutoTable ? doc.lastAutoTable.finalY + 16 : startY + 16,
                    head: [['Bowler', 'O', 'M', 'R', 'W', 'WD', 'NB', 'ECO']],
                    body: bowlingInn.bowling.map(b => [b.player.toUpperCase(), b.overs, b.maidens, b.runs, b.wickets, b.wides || 0, b.noBalls || 0, b.economy]),
                    theme: 'grid',
                    headStyles: { fillColor: [34, 34, 34] }
                });
            }

            // Fall of Wickets
            if (inn.fallOfWickets && inn.fallOfWickets.length > 0) {
                doc.setFontSize(10);
                doc.setTextColor(150, 0, 0);
                doc.setFont(undefined, 'bold');
                doc.text("FALL OF WICKETS", 14, doc.lastAutoTable ? doc.lastAutoTable.finalY + 14 : startY + 14);
                doc.setFont(undefined, 'normal');
                autoTable(doc, {
                    startY: doc.lastAutoTable ? doc.lastAutoTable.finalY + 18 : startY + 18,
                    head: [['Wkt', 'Score', 'Over', 'Player']],
                    body: inn.fallOfWickets.map(f => [f.wicket, f.runs, f.overs, f.player.toUpperCase()]),
                    theme: 'plain',
                    styles: { fontSize: 9 }
                });
            }

            // Did not bat
            const battingTeamName = inn.team;
            const squad = battingTeamName === match.teamA ? match.teamASquad : match.teamBSquad;
            if (squad && squad.length > 0) {
                const battedPlayers = (inn.batting || []).map(b => b.player);
                const yetToBat = squad.filter(p => p && p.trim() !== '' && !battedPlayers.includes(p));
                if (yetToBat.length > 0) {
                    const didNotBatY = doc.lastAutoTable ? doc.lastAutoTable.finalY + 12 : startY + 12;
                    doc.setFontSize(9);
                    doc.setTextColor(100);
                    doc.setFont(undefined, 'bold');
                    doc.text(`DID NOT BAT: `, 14, didNotBatY);
                    doc.setFont(undefined, 'normal');
                    const textLines = doc.splitTextToSize(`${yetToBat.map(p => p.toUpperCase()).join(', ')}`, 150);
                    doc.text(textLines, 40, didNotBatY);
                    if (doc.lastAutoTable) {
                        doc.lastAutoTable.finalY = didNotBatY + (textLines.length * 4);
                    }
                }
            }
        });

        if (match.status === 'completed') {
            const winnerString = (() => {
                const innings = match.innings || [];
                if (innings.length < 2) return null;
                let inn1, inn2;
                if (innings.length >= 4) {
                    const lastIdx = innings.length - 1;
                    inn2 = innings[lastIdx];
                    inn1 = innings[lastIdx - 1];
                } else {
                    inn1 = innings[0];
                    inn2 = innings[1];
                }
                if (inn1.runs > inn2.runs) {
                    const diff = inn1.runs - inn2.runs;
                    if (innings.length > 2) return `${inn1.team.toUpperCase()} WON (SUPER OVER)`;
                    return `${inn1.team.toUpperCase()} WON BY ${diff} ${diff === 1 ? 'RUN' : 'RUNS'}`;
                } else if (inn2.runs > inn1.runs) {
                    const wicketsRemaining = (innings.length > 2 ? 2 : 10) - inn2.wickets;
                    if (innings.length > 2) return `${inn2.team.toUpperCase()} WON (SUPER OVER)`;
                    return `${inn2.team.toUpperCase()} WON BY ${wicketsRemaining} ${wicketsRemaining === 1 ? 'WICKET' : 'WICKETS'}`;
                } else if (inn1.runs === inn2.runs && inn1.runs > 0) {
                    return "MATCH TIED";
                }
                return null;
            })();

            if (winnerString) {
                doc.addPage();
                doc.setFontSize(16);
                doc.setTextColor(0, 146, 112);
                doc.setFont(undefined, 'bold');
                doc.text("MATCH RESULT", 105, 100, { align: 'center' });
                doc.setFontSize(22);
                doc.text(winnerString.toUpperCase(), 105, 120, { align: 'center' });

                if (match.manOfTheMatch) {
                    doc.setFontSize(14);
                    doc.setTextColor(100);
                    doc.text(`MAN OF THE MATCH: ${match.manOfTheMatch.toUpperCase()}`, 105, 140, { align: 'center' });
                }
            }
        }

        const timestamp = new Date().toISOString().replace(/[:.]/g, '-').slice(0, 16).replace('T', '_');
        doc.save(`${match.teamA}_vs_${match.teamB}_${timestamp}.pdf`);
    };

    if (loading) return (
        <Container className="d-flex justify-content-center align-items-center" style={{ minHeight: '80vh' }}>
            <Spinner animation="grow" variant="primary" />
        </Container>
    );

    if (!match) return <Container className="py-5 text-center"><h3>Match not found</h3></Container>;

    return (
        <Container fluid="lg" className="py-4 py-md-5">
            <motion.div
                initial={{ opacity: 0, scale: 0.98 }}
                animate={{ opacity: 1, scale: 1 }}
                transition={{ duration: 0.4 }}
            >
                <Card className="glass-card border-0 shadow-lg overflow-hidden">
                    <div className="bg-primary bg-opacity-10 px-4 py-5 d-flex flex-column flex-md-row align-items-center justify-content-between gap-4">
                        <div className="d-flex align-items-center gap-4">
                            <motion.div
                                animate={{ rotate: [0, -10, 10, 0] }}
                                transition={{ repeat: Infinity, duration: 4 }}
                            >
                                <img
                                    src="/logo.png"
                                    alt="SMCC"
                                    height="70"
                                    className="rounded-circle border border-3 border-white shadow-lg"
                                />
                            </motion.div>
                            <div>
                                <h2 className="fw-black mb-1 premium-gradient-text letter-spacing-1">{t('full_scorecard')}</h2>
                                <div className="d-flex align-items-center gap-2 text-muted fw-bold small text-uppercase">
                                    <i className="bi bi-shield-check text-primary"></i>
                                    <span>{match.series || 'SMCC Premier League'}</span>
                                </div>
                            </div>
                        </div>
                        <div className="d-flex gap-3 w-100 w-md-auto">
                            {['completed', 'abandoned', 'cancelled'].includes(match.status) && (
                                <Button variant="primary" size="lg" onClick={downloadPDF} className="premium-btn px-4 shadow-sm border-0">
                                    <i className="bi bi-file-earmark-pdf-fill me-2"></i> Export PDF
                                </Button>
                            )}
                        </div>
                    </div>

                    <Card.Body className="p-0">
                        <div className="p-4 p-md-5 border-bottom bg-light bg-opacity-50">
                            <Row className="align-items-center text-center text-md-start">
                                <Col md={8}>
                                    <h2 className="fw-black mb-2 text-uppercase letter-spacing-1">{match.teamA} vs {match.teamB}</h2>
                                    <div className="d-flex flex-wrap justify-content-center justify-content-md-start gap-4 text-muted small">
                                        <div className="d-flex align-items-center gap-2">
                                            <i className="bi bi-geo-alt-fill text-primary"></i>
                                            <span>{match.venue}</span>
                                        </div>
                                        <div className="d-flex align-items-center gap-2">
                                            <i className="bi bi-calendar-event-fill text-primary"></i>
                                            <span>{new Date(match.date).toLocaleDateString([], { weekday: 'short', month: 'short', day: 'numeric' })}</span>
                                        </div>
                                        <div className="d-flex align-items-center gap-2">
                                            <i className="bi bi-stopwatch-fill text-primary"></i>
                                            <span>{match.totalOvers} Overs Format</span>
                                        </div>
                                    </div>
                                </Col>
                                <Col md={4} className="mt-4 mt-md-0 text-md-end">
                                    {match.status === 'completed' && (
                                        <div className="bg-success bg-opacity-10 p-3 rounded-4 border border-success border-opacity-20">
                                            <div className="fw-bold text-success small mb-1">FINAL RESULT</div>
                                            <div className="fw-black text-success">
                                                {match.innings && match.innings.length >= 2 ? (() => {
                                                    const innings = match.innings;
                                                    let inn1, inn2;
                                                    if (innings.length >= 4) {
                                                        const lastIdx = innings.length - 1;
                                                        inn2 = innings[lastIdx];
                                                        inn1 = innings[lastIdx - 1];
                                                    } else {
                                                        inn1 = innings[0];
                                                        inn2 = innings[1];
                                                    }
                                                    if (inn1.runs > inn2.runs) {
                                                        const diff = inn1.runs - inn2.runs;
                                                        if (innings.length > 2) return `${inn1.team.toUpperCase()} WON (SUPER OVER)`;
                                                        return `${inn1.team.toUpperCase()} WON BY ${diff} ${diff === 1 ? 'RUN' : 'RUNS'}`;
                                                    }
                                                    if (inn2.runs > inn1.runs) {
                                                        const wicketsRemaining = (innings.length > 2 ? 2 : 10) - inn2.wickets;
                                                        if (innings.length > 2) return `${inn2.team.toUpperCase()} WON (SUPER OVER)`;
                                                        return `${inn2.team.toUpperCase()} WON BY ${wicketsRemaining} ${wicketsRemaining === 1 ? 'WICKET' : 'WICKETS'}`;
                                                    }

                                                    // Add Boundary Count Check for Super Over Tie
                                                    if (innings.length > 2) {
                                                        const countBoundaries = (inn) => (inn.batting || []).reduce((acc, p) => acc + (p.fours || 0) + (p.sixes || 0), 0);

                                                        const b1 = countBoundaries(inn1);
                                                        const b2 = countBoundaries(inn2);

                                                        if (b1 > b2) return `${inn1.team.toUpperCase()} WON ON BOUNDARY COUNT (${b1}-${b2})`;
                                                        if (b2 > b1) return `${inn2.team.toUpperCase()} WON ON BOUNDARY COUNT (${b2}-${b1})`;
                                                        return "MATCH TIED (SUPER OVER DRAW)";
                                                    }
                                                    return "MATCH DRAWN";
                                                })() : "COMPLETED"}
                                            </div>
                                        </div>
                                    )}
                                </Col>
                            </Row>
                        </div>

                        <Nav variant="tabs" className="px-4 border-bottom bg-white border-0">
                            <Nav.Item>
                                <Nav.Link
                                    className={`px-4 py-3 border-0 rounded-0 fw-bold ${activeTab === 'scorecard' ? 'active text-primary border-bottom border-primary border-3' : 'text-muted'}`}
                                    onClick={() => setActiveTab('scorecard')}
                                    style={{ borderBottom: activeTab === 'scorecard' ? '3px solid var(--primary) !important' : '' }}
                                >
                                    Scorecard
                                </Nav.Link>
                            </Nav.Item>
                            <Nav.Item>
                                <Nav.Link
                                    className={`px-4 py-3 border-0 rounded-0 fw-bold ${activeTab === 'info' ? 'active text-primary border-bottom border-primary border-3' : 'text-muted'}`}
                                    onClick={() => setActiveTab('info')}
                                    style={{ borderBottom: activeTab === 'info' ? '3px solid var(--primary) !important' : '' }}
                                >
                                    Match Info
                                </Nav.Link>
                            </Nav.Item>
                        </Nav>

                        <div className="p-4 p-md-5">
                            <AnimatePresence mode="wait">
                                {activeTab === 'scorecard' ? (
                                    <motion.div
                                        key="scorecard"
                                        initial={{ opacity: 0, x: -10 }}
                                        animate={{ opacity: 1, x: 0 }}
                                        exit={{ opacity: 0, x: 10 }}
                                    >
                                        {match.innings && match.innings.length > 0 ? (
                                            <>
                                                <div className="bg-light p-3 rounded-4 mb-4 border shadow-inner">
                                                    <div className="fw-black text-uppercase x-small text-muted letter-spacing-2 mb-3 px-1">Match Phases</div>
                                                    <div className="d-flex flex-wrap gap-2">
                                                        {match.innings.map((inn, idx) => {
                                                            // Hide empty ghost innings (abandoned/glitched middle innings)
                                                            if (idx >= 2 && inn.runs === 0 && inn.wickets === 0 && (!inn.batting || inn.batting.length === 0)) return null;

                                                            const getOrdinal = (n) => { const s = ["th", "st", "nd", "rd"]; const v = n % 100; return n + (s[(v - 20) % 10] || s[v] || s[0]); };
                                                            const phaseLabel = `${getOrdinal(idx + 1)} Innings${idx >= 2 ? ' (SO)' : ''}`;
                                                            return (
                                                                <Button
                                                                    key={idx}
                                                                    variant={activeInnings === idx ? 'primary' : 'white'}
                                                                    className={`flex-fill py-2 px-3 transition-all border shadow-sm ${activeInnings === idx ? 'bg-primary text-white border-primary shadow-lg' : 'text-primary bg-white border-primary border-opacity-10'}`}
                                                                    onClick={() => setActiveInnings(idx)}
                                                                    style={{ minWidth: '140px' }}
                                                                >
                                                                    <div className="d-flex flex-column align-items-center">
                                                                        <span className="fw-black text-uppercase x-small letter-spacing-1">{inn.team}</span>
                                                                        <span className="fw-bold x-small opacity-75" style={{ fontSize: '0.65rem' }}>{phaseLabel}</span>
                                                                        <span className="fw-black mt-1" style={{ fontSize: '0.85rem' }}>{inn.runs}/{inn.wickets} <small className="opacity-75">({inn.overs} ov)</small></span>
                                                                    </div>
                                                                </Button>
                                                            );
                                                        })}
                                                    </div>
                                                </div>

                                                <div className="mb-4 d-flex align-items-center justify-content-between flex-wrap gap-3">
                                                    <div className="d-flex flex-column">
                                                        <h3 className="fw-black text-uppercase premium-gradient-text mb-1">
                                                            {match.innings[activeInnings].team} {(() => {
                                                                const n = activeInnings + 1; const s = ["th", "st", "nd", "rd"]; const v = n % 100; return n + (s[(v - 20) % 10] || s[v] || s[0]);
                                                            })()} Innings {activeInnings >= 2 ? '(Super Over)' : ''}
                                                        </h3>
                                                        <div className="text-muted small fw-bold text-uppercase letter-spacing-1">
                                                            {activeInnings < 2 ? `(Total ${match.totalOvers} overs)` : `(Total 1 over)`}
                                                        </div>
                                                    </div>
                                                    {activeInnings % 2 !== 0 && match.innings[activeInnings - 1] && (
                                                        <div className="d-flex flex-column align-items-end">
                                                            <div className="text-muted x-small fw-black text-uppercase mb-1">Target Score</div>
                                                            <Badge bg="danger" className="px-3 py-2 fs-5 shadow-sm border border-white border-opacity-25">
                                                                T: {match.score?.target || (match.innings[activeInnings - 1].runs + 1)} runs from {activeInnings >= 2 ? '1' : match.totalOvers} ovs
                                                            </Badge>
                                                        </div>
                                                    )}
                                                </div>

                                                {match.innings[activeInnings] ? (
                                                    <>
                                                        <div className="border rounded-4 overflow-hidden shadow-sm bg-white mb-5">
                                                            <Table hover responsive className="mb-0 border-0">
                                                                <thead className="bg-dark text-white">
                                                                    <tr>
                                                                        <th className="ps-4 py-3 x-small text-uppercase letter-spacing-1">Batting</th>
                                                                        <th className="py-3 x-small text-uppercase letter-spacing-1">Status</th>
                                                                        <th className="text-center py-3 x-small text-uppercase letter-spacing-1">R</th>
                                                                        <th className="text-center py-3 x-small text-uppercase letter-spacing-1">B</th>
                                                                        <th className="text-center py-3 x-small text-uppercase letter-spacing-1">4s</th>
                                                                        <th className="text-center py-3 x-small text-uppercase letter-spacing-1">6s</th>
                                                                        <th className="text-center py-3 x-small text-uppercase letter-spacing-1">SR</th>
                                                                    </tr>
                                                                </thead>
                                                                <tbody>
                                                                    {(match.innings[activeInnings].batting || []).map((b, idx) => (
                                                                        <tr key={idx} className="align-middle">
                                                                            <td className="ps-4 fw-black text-primary fs-6">{toCamelCase(b.player)}</td>
                                                                            <td className="text-muted fw-bold small">{b.status}</td>
                                                                            <td className="text-center fw-black fs-5">{b.runs}</td>
                                                                            <td className="text-center fw-bold">{b.balls}</td>
                                                                            <td className="text-center fw-bold">{b.fours}</td>
                                                                            <td className="text-center fw-bold">{b.sixes}</td>
                                                                            <td className="text-center text-muted fw-black small">{b.strikeRate}</td>
                                                                        </tr>
                                                                    ))}
                                                                    <tr className="bg-light bg-opacity-50">
                                                                        <td colSpan={2} className="ps-4 text-muted fw-bold">EXTRAS</td>
                                                                        <td colSpan={5} className="ps-3 fw-black fs-5">
                                                                            {match.innings[activeInnings].extras?.total || 0}
                                                                            <small className="ms-3 text-muted fw-bold">
                                                                                (b {match.innings[activeInnings].extras?.byes || 0},
                                                                                lb {match.innings[activeInnings].extras?.legByes || 0},
                                                                                w {match.innings[activeInnings].extras?.wides || 0},
                                                                                nb {match.innings[activeInnings].extras?.noBalls || 0})
                                                                            </small>
                                                                        </td>
                                                                    </tr>
                                                                    <tr className="bg-primary bg-opacity-10 border-top border-primary border-opacity-25">
                                                                        <td colSpan={2} className="ps-4 fw-black fs-4 py-4 text-uppercase text-primary">Total</td>
                                                                        <td colSpan={5} className="ps-3 py-4">
                                                                            <div className="d-flex align-items-baseline gap-3">
                                                                                <span className="fw-black fs-2 text-primary">{match.innings[activeInnings].runs}/{match.innings[activeInnings].wickets}</span>
                                                                                <span className="text-muted fs-5 fw-bold">({match.innings[activeInnings].overs} Ov)</span>
                                                                                <span className="small fw-black text-muted ms-auto pe-4">RR: {(match.innings[activeInnings].runs / (Math.floor(match.innings[activeInnings].overs) + (match.innings[activeInnings].overs % 1) / 0.6 || 1)).toFixed(2)}</span>
                                                                            </div>
                                                                        </td>
                                                                    </tr>
                                                                    {(() => {
                                                                        const currentInnings = match.innings[activeInnings];
                                                                        const battingTeamName = currentInnings.team;
                                                                        const squad = battingTeamName === match.teamA ? match.teamASquad : match.teamBSquad;
                                                                        if (!squad || squad.length === 0) return null;

                                                                        const battedPlayers = (currentInnings.batting || []).map(b => b.player);
                                                                        const yetToBat = squad.filter(p => p && p.trim() !== '' && !battedPlayers.includes(p));
                                                                        if (yetToBat.length === 0) return null;

                                                                        return (
                                                                            <tr className="bg-light">
                                                                                <td colSpan={7} className="ps-4 py-3">
                                                                                    <div className="d-flex align-items-center gap-2">
                                                                                        <span className="x-small fw-black text-uppercase text-muted">Did not bat:</span>
                                                                                        <span className="small fw-bold text-dark">
                                                                                            {yetToBat.map(p => toCamelCase(p)).join(', ')}
                                                                                        </span>
                                                                                    </div>
                                                                                </td>
                                                                            </tr>
                                                                        );
                                                                    })()}
                                                                </tbody>
                                                            </Table>
                                                        </div>

                                                        <div className="border rounded-4 overflow-hidden shadow-sm bg-white">
                                                            <div className="bg-dark text-white px-4 py-3 fw-black text-uppercase letter-spacing-1 d-flex align-items-center gap-2">
                                                                <i className="bi bi-bullseye text-primary"></i>
                                                                Bowling Summary: {(() => {
                                                                    const currentInn = match.innings[activeInnings];
                                                                    // Bowling team is the one NOT batting
                                                                    if (currentInn.team === match.teamA) return match.teamB;
                                                                    return match.teamA;
                                                                })()}
                                                            </div>
                                                            <Table hover responsive className="mb-0">
                                                                <thead className="bg-light">
                                                                    <tr>
                                                                        <th className="ps-4 py-3 text-muted x-small text-uppercase">Bowling</th>
                                                                        <th className="text-center py-3 text-muted x-small text-uppercase">O</th>
                                                                        <th className="text-center py-3 text-muted x-small text-uppercase">M</th>
                                                                        <th className="text-center py-3 text-muted x-small text-uppercase">R</th>
                                                                        <th className="text-center py-3 text-muted x-small text-uppercase">W</th>
                                                                        <th className="text-center py-3 text-muted x-small text-uppercase">ECON</th>
                                                                        <th className="text-center py-3 text-muted x-small text-uppercase">0s</th>
                                                                        <th className="text-center py-3 text-muted x-small text-uppercase">WD</th>
                                                                        <th className="text-center py-3 text-muted x-small text-uppercase">NB</th>
                                                                    </tr>
                                                                </thead>
                                                                <tbody>
                                                                    {(() => {
                                                                        let bowlingTeamIdx;
                                                                        if (activeInnings >= 2) {
                                                                            // Super Over: Co-located data. Batting & Bowling in SAME innings object.
                                                                            bowlingTeamIdx = activeInnings;
                                                                        } else {
                                                                            // Main Match: Split data. Batting in 0, Bowling in 1.
                                                                            bowlingTeamIdx = activeInnings % 2 === 0 ? activeInnings + 1 : activeInnings - 1;
                                                                        }
                                                                        const bowlingInnings = match.innings[bowlingTeamIdx];
                                                                        if (!bowlingInnings || !bowlingInnings.bowling) return (
                                                                            <tr><td colSpan={6} className="text-center py-4 text-muted fw-bold">No bowling data for this innings yet</td></tr>
                                                                        );
                                                                        return bowlingInnings.bowling.map((bowler, idx) => (
                                                                            <tr key={idx} className="align-middle">
                                                                                <td className="ps-4 fw-black text-primary">{toCamelCase(bowler.player)}</td>
                                                                                <td className="text-center fw-bold">{bowler.overs}</td>
                                                                                <td className="text-center">{bowler.maidens || 0}</td>
                                                                                <td className="text-center fw-black">{bowler.runs}</td>
                                                                                <td className="text-center fw-black text-danger fs-5">{bowler.wickets}</td>
                                                                                <td className="text-center text-muted fw-bold">{bowler.economy}</td>
                                                                                <td className="text-center">{bowler.dots || 0}</td>
                                                                                <td className="text-center">{bowler.wides || 0}</td>
                                                                                <td className="text-center">{bowler.noBalls || 0}</td>
                                                                            </tr>
                                                                        ));
                                                                    })()}
                                                                </tbody>
                                                            </Table>
                                                        </div>

                                                        {match.innings[activeInnings].fallOfWickets && match.innings[activeInnings].fallOfWickets.length > 0 && (
                                                            <div className="bg-light p-4 rounded-4 border-dashed mt-4">
                                                                <h6 className="fw-black text-uppercase x-small text-muted letter-spacing-1 mb-3">Fall of Wickets</h6>
                                                                <div className="small fw-bold text-dark" style={{ lineHeight: '1.8' }}>
                                                                    {match.innings[activeInnings].fallOfWickets.map((fow, i) => (
                                                                        <span key={i}>
                                                                            {fow.wicket}-{fow.runs} ({toCamelCase(fow.player)}, {fow.overs} ov)
                                                                            {i < match.innings[activeInnings].fallOfWickets.length - 1 ? <span className="text-muted mx-2">|</span> : ''}
                                                                        </span>
                                                                    ))}
                                                                </div>
                                                            </div>
                                                        )}
                                                    </>
                                                ) : (
                                                    <div className="text-center py-5 glass-card border-dashed">
                                                        <p className="text-muted fw-bold">Innings data not initialized</p>
                                                    </div>
                                                )}
                                            </>
                                        ) : (
                                            <div className="text-center py-5 glass-card border-dashed">
                                                <i className="bi bi-info-circle fs-1 text-muted opacity-25 d-block mb-3"></i>
                                                <span className="text-muted fw-bold text-uppercase letter-spacing-1">No innings data available yet for this match.</span>
                                            </div>
                                        )}
                                    </motion.div>
                                ) : (
                                    <motion.div
                                        key="info"
                                        initial={{ opacity: 0, y: 10 }}
                                        animate={{ opacity: 1, y: 0 }}
                                        exit={{ opacity: 0, y: -10 }}
                                    >
                                        <Row className="gy-4">
                                            <Col md={6}>
                                                <h6 className="fw-bold text-primary mb-3">MATCH DETAILS</h6>
                                                <div className="bg-light p-4 rounded-4">
                                                    <div className="d-flex justify-content-between mb-3 border-bottom pb-2">
                                                        <span className="text-muted">Series</span>
                                                        <span className="fw-bold">{match.series || 'SMCC LIVE'}</span>
                                                    </div>
                                                    <div className="d-flex justify-content-between mb-3 border-bottom pb-2">
                                                        <span className="text-muted">Venue</span>
                                                        <span className="fw-bold">{match.venue}</span>
                                                    </div>
                                                    <div className="d-flex justify-content-between mb-3 border-bottom pb-2">
                                                        <span className="text-muted">Match Type</span>
                                                        <span className="fw-bold">{match.totalOvers} Overs</span>
                                                    </div>
                                                    <div className="d-flex justify-content-between mb-3 border-bottom pb-2">
                                                        <span className="text-muted">Date</span>
                                                        <span className="fw-bold">{new Date(match.date).toLocaleDateString()}</span>
                                                    </div>
                                                    <div className="d-flex justify-content-between">
                                                        <span className="text-muted">Time</span>
                                                        <span className="fw-bold">{formatTime(match.date)}</span>
                                                    </div>
                                                </div>
                                            </Col>
                                            <Col md={6}>
                                                <h6 className="fw-bold text-primary mb-3">TOURNAMENT RULES</h6>
                                                <div className="bg-dark text-white p-4 rounded-4 shadow-sm">
                                                    <ul className="small mb-0 list-unstyled" style={{ lineHeight: '1.6' }}>
                                                        <li><i className="bi bi-check-circle-fill text-success me-2"></i>Pure Bowling Format</li>
                                                        <li><i className="bi bi-check-circle-fill text-success me-2"></i>Free Hit on all No Balls</li>
                                                        <li className="mt-2 fw-bold text-info"><i className="bi bi-star-fill me-2"></i>SUPER OVER RULES:</li>
                                                        <li className="ms-4 opacity-75">1. Chasing team from main match always bats first in SO 1.</li>
                                                        <li className="ms-4 opacity-75">2. If SO is tied, team batting 2nd in previous SO bats 1st in next.</li>
                                                        <li className="ms-4 opacity-75">3. 1 Over (6 balls) and 2 Wickets per side in SO.</li>
                                                        <li className="ms-4 opacity-75">4. Dismissed batters in previous SO cannot play again.</li>
                                                        <li className="mt-2"><i className="bi bi-check-circle-fill text-success me-2"></i>Umpire Decision is Final</li>
                                                    </ul>
                                                </div>
                                            </Col>
                                        </Row>
                                    </motion.div>
                                )}
                            </AnimatePresence>
                        </div >
                    </Card.Body >
                </Card >
            </motion.div >
        </Container >
    );
};

export default FullScorecard;
