import React, { useEffect, useState } from 'react';
import { useParams, Link } from 'react-router-dom';
import axios from 'axios';
import { Container, Card, Table, Nav, Spinner, Button, Row, Col } from 'react-bootstrap';
import { io } from 'socket.io-client';
import { useApp } from '../AppContext';
import jsPDF from 'jspdf';
import autoTable from 'jspdf-autotable';

const API_URL = import.meta.env.VITE_API_URL || 'http://localhost:5000';
const socket = io(API_URL);

const FullScorecard = () => {
    const { id } = useParams();
    const [match, setMatch] = useState(null);
    const [loading, setLoading] = useState(true);
    const [activeInnings, setActiveInnings] = useState(0);
    const [activeTab, setActiveTab] = useState('scorecard'); // 'scorecard' or 'info'
    const { t, theme, language } = useApp();

    const downloadPDF = () => {
        const doc = new jsPDF();
        doc.setFontSize(18);
        doc.text(`${match.teamA} vs ${match.teamB} - Full Scorecard`, 14, 20);
        doc.setFontSize(10);
        doc.text(`Series: ${match.series || 'SMCC'} | Venue: ${match.venue} | Date: ${new Date(match.date).toDateString()}`, 14, 30);

        match.innings.forEach((inn, idx) => {
            const startY = doc.lastAutoTable ? doc.lastAutoTable.finalY + 15 : 40;
            doc.setFontSize(14);
            doc.text(`${inn.team} Innings: ${inn.runs}/${inn.wickets} (${inn.overs} Ov)`, 14, startY);

            autoTable(doc, {
                startY: startY + 5,
                head: [['Batter', 'Status', 'R', 'B', '4s', '6s', 'SR']],
                body: [
                    ...inn.batting.map(b => [b.player, b.status, b.runs, b.balls, b.fours, b.sixes, b.strikeRate]),
                    ['Extras', '', inn.extras.total, `(wd ${inn.extras.wides}, nb ${inn.extras.noBalls}, b ${inn.extras.byes}, lb ${inn.extras.legByes})`, '', '', '']
                ],
                theme: 'grid',
                headStyles: { fillColor: [0, 146, 112] }
            });

            // Run Breakdown
            const breakdown = [
                `Dots: ${inn.dots || 0}`, `1s: ${inn.ones || 0}`, `2s: ${inn.twos || 0}`,
                `3s: ${inn.threes || 0}`, `4s: ${inn.fours || 0}`, `6s: ${inn.sixes || 0}`
            ].join(' | ');
            doc.setFontSize(9);
            doc.setTextColor(100);
            doc.text(`Hit Breakdown: ${breakdown}`, 14, doc.lastAutoTable.finalY + 7);

            // Bowling Team
            const bowlingTeam = idx === 0 ? match.innings[1]?.bowling : match.innings[0]?.bowling;
            if (bowlingTeam) {
                autoTable(doc, {
                    startY: doc.lastAutoTable.finalY + 12,
                    head: [['Bowler', 'O', 'M', 'R', 'W', 'WD', 'NB', 'ECO']],
                    body: bowlingTeam.map(b => [b.player, b.overs, b.maidens, b.runs, b.wickets, b.wides || 0, b.noBalls || 0, b.economy]),
                    theme: 'grid',
                    headStyles: { fillColor: [34, 34, 34] }
                });
            }
        });

        if (match.manOfTheMatch) {
            doc.setFontSize(12);
            doc.text(`Man of the Match: ${match.manOfTheMatch}`, 14, doc.lastAutoTable.finalY + 15);
        }

        const timestamp = new Date().toISOString().replace(/[:.]/g, '-').slice(0, 16).replace('T', '_');
        doc.save(`${match.teamA}_vs_${match.teamB}_${timestamp}.pdf`);
    };

    const fetchMatch = async () => {
        try {
            const res = await axios.get(`${API_URL}/api/matches/${id}`);
            setMatch(res.data);
            if (res.data.status === 'live') {
                const idx = res.data.innings.findIndex(inn => inn.team === res.data.score.battingTeam);
                if (idx !== -1) setActiveInnings(idx);
            }
        } catch (err) {
            console.error("Error fetching match", err);
        } finally {
            setLoading(false);
        }
    };

    useEffect(() => {
        fetchMatch();
        socket.on('matchUpdate', (updatedMatch) => {
            if (updatedMatch._id === id || updatedMatch.id === id) setMatch(updatedMatch);
        });
        return () => { socket.off('matchUpdate'); };
    }, [id]);

    if (loading) return (
        <Container className="d-flex justify-content-center align-items-center" style={{ minHeight: '60vh' }}>
            <Spinner animation="border" variant="success" />
        </Container>
    );

    if (!match) return <Container className="py-5 text-center"><h3>Match not found</h3></Container>;

    const renderBattingTable = (innings) => (
        <Table hover responsive className={`mb-0 cric-table ${theme === 'dark' ? 'table-dark' : ''}`}>
            <thead>
                <tr>
                    <th className="ps-4">{t('batter')}</th>
                    <th></th>
                    <th className="text-center">{t('runs')}</th>
                    <th className="text-center">{t('balls')}</th>
                    <th className="text-center">{t('fours')}</th>
                    <th className="text-center">{t('sixes')}</th>
                    <th className="text-center">{t('sr')}</th>
                </tr>
            </thead>
            <tbody>
                {innings.batting.map((b, idx) => (
                    <tr key={idx}>
                        <td className="ps-4 fw-bold player-name">{b.player}</td>
                        <td className="text-muted small">{b.status}</td>
                        <td className="text-center fw-bold">{b.runs}</td>
                        <td className="text-center">{b.balls}</td>
                        <td className="text-center">{b.fours}</td>
                        <td className="text-center">{b.sixes}</td>
                        <td className="text-center text-muted small">{b.strikeRate}</td>
                    </tr>
                ))}
                <tr className="extras-row">
                    <td colSpan={2} className="ps-4 text-muted">{t('extras')}</td>
                    <td colSpan={5} className="fw-bold ps-2">
                        {innings.extras.total} <small className="text-muted fw-normal">(wd {innings.extras.wides}, nb {innings.extras.noBalls}, b {innings.extras.byes}, lb {innings.extras.legByes})</small>
                    </td>
                </tr>
                <tr className="total-row border-bottom-0">
                    <td colSpan={2} className="ps-4 fw-bold fs-5">{t('total')}</td>
                    <td colSpan={5} className="ps-2 fw-black fs-5">
                        {innings.runs}/{innings.wickets} <small className="text-muted">({innings.overs} {t('overs')})</small>
                    </td>
                </tr>
                <tr className="breakdown-row bg-white border-top">
                    <td colSpan={7} className="ps-4 py-2 border-0">
                        <div className="d-flex gap-3 small text-muted text-uppercase fw-bold letter-spacing-1 overflow-auto">
                            <span className="text-nowrap">Dots: <span className="text-dark">{innings.dots || 0}</span></span>
                            <span className="text-nowrap">1s: <span className="text-dark">{innings.ones || 0}</span></span>
                            <span className="text-nowrap">2s: <span className="text-dark">{innings.twos || 0}</span></span>
                            <span className="text-nowrap">3s: <span className="text-dark">{innings.threes || 0}</span></span>
                            <span className="text-nowrap text-primary">4s: <span className="text-dark">{innings.fours || 0}</span></span>
                            <span className="text-nowrap text-success">6s: <span className="text-dark">{innings.sixes || 0}</span></span>
                        </div>
                    </td>
                </tr>
                {(innings.fallOfWickets || innings.fow) && ((innings.fallOfWickets || innings.fow).length > 0) && (
                    <tr className="fow-row bg-light border-top">
                        <td colSpan={7} className="ps-4 py-2 border-0">
                            <div className="small fw-bold text-muted text-uppercase">Fall of Wickets</div>
                            <div className="d-flex flex-wrap gap-2 small text-dark mt-1">
                                {(innings.fallOfWickets || innings.fow).map((f, i) => (
                                    <span key={i} className="badge bg-white text-dark border fw-bold">
                                        {f.wicket}-{f.runs} ({f.player}, {f.overs} ov)
                                    </span>
                                ))}
                            </div>
                        </td>
                    </tr>
                )}
            </tbody>
        </Table>
    );

    const renderBowlingTable = (inningsIdx) => {
        const bowlingTeamIdx = inningsIdx === 0 ? 1 : 0;
        const bowlingInnings = match.innings[bowlingTeamIdx];
        if (!bowlingInnings || !bowlingInnings.bowling) return null;

        return (
            <Table hover responsive className={`mb-0 cric-table mt-4 border-top ${theme === 'dark' ? 'table-dark' : ''}`}>
                <thead>
                    <tr>
                        <th className="ps-4">{t('bowler')}</th>
                        <th className="text-center">{t('overs')}</th>
                        <th className="text-center">{t('maidens')}</th>
                        <th className="text-center">{t('runs')}</th>
                        <th className="text-center">{t('wickets')}</th>
                        <th className="text-center">WD</th>
                        <th className="text-center">NB</th>
                        <th className="text-center">{t('eco')}</th>
                    </tr>
                </thead>
                <tbody>
                    {bowlingInnings.bowling.map((bowler, idx) => (
                        <tr key={idx}>
                            <td className="ps-4 fw-bold">{bowler.player}</td>
                            <td className="text-center">{bowler.overs}</td>
                            <td className="text-center">{bowler.maidens}</td>
                            <td className="text-center fw-bold">{bowler.runs}</td>
                            <td className="text-center fw-bold text-danger">{bowler.wickets}</td>
                            <td className="text-center">{bowler.wides || 0}</td>
                            <td className="text-center">{bowler.noBalls || 0}</td>
                            <td className="text-center text-muted small">{bowler.economy}</td>
                        </tr>
                    ))}
                </tbody>
            </Table>
        );
    };

    return (
        <Container className="py-4 scorecard-page">
            <Card className="border-0 shadow-sm overflow-hidden mb-4">
                <div className="bg-cric-dark text-white px-4 py-3 d-flex align-items-center justify-content-between">
                    <div className="d-flex align-items-center">
                        <img src="/logo.png" alt="SMCC" height="30" className="me-3" />
                        <span className="fw-bold fs-5">{t('full_scorecard')}</span>
                    </div>
                    <div className="d-flex gap-2">
                        <Button variant="outline-light" size="sm" onClick={downloadPDF} className="fw-bold">📄 PDF</Button>
                        <Button as={Link} to="/" variant="link" className="text-white text-decoration-none p-0 ps-2">✕ Close</Button>
                    </div>
                </div>

                <Card.Body className="p-0">
                    <div className="p-4 border-bottom">
                        <h4 className="fw-black mb-1 text-uppercase letter-spacing-1">{match.teamA.toUpperCase()} vs {match.teamB.toUpperCase()}</h4>
                        <div className="text-muted small mb-0 d-flex flex-wrap gap-3">
                            <span>{t('series')}: <strong className="text-dark">{match.series || 'SMCC'}</strong></span>
                            <span>{t('venue')}: <strong className="text-dark">{match.venue}</strong></span>
                            <span>{t('date')}: <strong className="text-dark">{new Date(match.date).toLocaleDateString([], { weekday: 'short', month: 'short', day: 'numeric' })}</strong></span>
                        </div>
                    </div>

                    <Nav className="tab-menu px-4 border-bottom">
                        <Nav.Link className={activeTab === 'scorecard' ? 'active' : ''} onClick={() => setActiveTab('scorecard')}>{t('full_scorecard')}</Nav.Link>
                        <Nav.Link as={Link} to="/">{t('live')}</Nav.Link>
                        <Nav.Link className={activeTab === 'info' ? 'active' : ''} onClick={() => setActiveTab('info')}>{t('match_info')}</Nav.Link>
                    </Nav>

                    <div className="p-4">
                        {activeTab === 'scorecard' ? (
                            <>
                                {match.status === 'completed' && (
                                    <div className="result-alert mb-4">
                                        {match.manOfTheMatch ? `${t('man_of_the_match')}: ${match.manOfTheMatch}` : t('completed')}
                                    </div>
                                )}

                                <div className="innings-list">
                                    {match.innings.map((inn, idx) => (
                                        <div key={idx} className="innings-card mb-4 border rounded">
                                            <div
                                                className={`innings-summary p-3 d-flex justify-content-between align-items-center ${activeInnings === idx ? 'bg-success text-white' : ''}`}
                                                onClick={() => setActiveInnings(idx)}
                                                style={{ cursor: 'pointer' }}
                                            >
                                                <div className="fw-bold fs-6">{inn.team}</div>
                                                <div className="fw-black fs-6">{inn.runs}/{inn.wickets} <small>({inn.overs})</small></div>
                                            </div>
                                            {activeInnings === idx && (
                                                <div className="innings-detail">
                                                    {renderBattingTable(inn)}
                                                    {renderBowlingTable(idx)}
                                                </div>
                                            )}
                                        </div>
                                    ))}
                                </div>
                            </>
                        ) : (
                            <div className="match-info-content">
                                <div className="mb-4">
                                    <h6 className="fw-bold text-uppercase text-muted border-bottom pb-2 mb-3">{t('match_info')}</h6>
                                    <Row className="gy-2">
                                        <Col xs={4} className="text-muted">{t('series')}</Col><Col xs={8} className="fw-bold">{match.series || 'SMCC Premier League'}</Col>
                                        <Col xs={4} className="text-muted">{t('venue')}</Col><Col xs={8} className="fw-bold">{match.venue}</Col>
                                        <Col xs={4} className="text-muted">{t('date')}</Col><Col xs={8} className="fw-bold">{new Date(match.date).toLocaleDateString()}</Col>
                                        <Col xs={4} className="text-muted">{t('total_overs')}</Col><Col xs={8} className="fw-bold text-success">{match.totalOvers} Overs</Col>
                                    </Row>
                                </div>
                                <div>
                                    <h6 className="fw-bold text-uppercase text-muted border-bottom pb-2 mb-3">📋 ICC Match Rules & Format</h6>
                                    <div className="bg-light p-3 rounded-3 small text-muted">
                                        <ul className="ps-3 mb-0" style={{ lineHeight: '1.8' }}>

                                            <li><strong>Extras:</strong>
                                                <ul className="ps-3 mt-1">
                                                    <li><strong>Wide Ball:</strong> 1 Run + Re-bowl. Strict adjudication on leg-side deliveries.</li>
                                                    <li><strong>No Ball:</strong> 1 Run + Re-bowl + <strong>Free Hit</strong> for the next delivery.</li>
                                                </ul>
                                            </li>
                                            <li><strong>Dismissals:</strong> Bowled, Caught, Run Out, Stumped, Hit Wicket (No LBW).</li>
                                            <li><strong>Tie Breaker:</strong> In the event of a tie, a <strong>Super Over</strong> will be played.</li>
                                            <li><strong>Substitutes:</strong> Concussion substitute allowed if validated by match referee.</li>
                                            <li><strong>Umpire Decision:</strong> Umpire decision is final, no more arguments.</li>
                                        </ul>
                                    </div>
                                </div>
                            </div>
                        )}
                    </div>
                </Card.Body>
            </Card>

            <style>{`
                .scorecard-page { max-width: 900px; }
                .bg-cric-dark { background-color: var(--cric-dark); }
                .fw-black { font-weight: 900; }
                .tab-menu .nav-link { 
                    color: var(--text-color); 
                    padding: 1rem 1.5rem; 
                    border-bottom: 3px solid transparent;
                    font-weight: bold;
                    border-radius: 0;
                }
                .tab-menu .nav-link.active { 
                    color: var(--cric-green); 
                    border-bottom-color: var(--cric-green); 
                }
                .result-alert { font-size: 0.9rem; color: var(--cric-green); font-weight: bold; border-bottom: 1px solid var(--border-color); padding-bottom: 10px; }
                .innings-summary.bg-success { background: var(--cric-green) !important; }
                .cric-table thead th { background: var(--light); color: var(--text-color); font-size: 11px; text-transform: uppercase; padding: 10px 15px; border: none; }
                .player-name { color: #1a73e8; }
                .total-row { background: var(--light); }
            `}</style>
        </Container >
    );
};

export default FullScorecard;
