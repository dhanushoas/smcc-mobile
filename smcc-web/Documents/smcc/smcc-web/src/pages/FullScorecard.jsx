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
                <tr className="bg-light">
                    <th className="ps-4 py-3 text-uppercase small fw-black text-muted letter-spacing-1">{t('batter')}</th>
                    <th className="py-3"></th>
                    <th className="text-center py-3 text-uppercase small fw-black text-muted letter-spacing-1">{t('runs')}</th>
                    <th className="text-center py-3 text-uppercase small fw-black text-muted letter-spacing-1">{t('balls')}</th>
                    <th className="text-center py-3 text-uppercase small fw-black text-muted letter-spacing-1">4s</th>
                    <th className="text-center py-3 text-uppercase small fw-black text-muted letter-spacing-1">6s</th>
                    <th className="text-center py-3 text-uppercase small fw-black text-muted letter-spacing-1">SR</th>
                </tr>
            </thead>
            <tbody>
                {innings.batting.map((b, idx) => (
                    <tr key={idx} className="align-middle">
                        <td className="ps-4 fw-bold text-dark">{b.player}</td>
                        <td className="text-muted small italic">{b.status}</td>
                        <td className="text-center fw-black text-primary fs-5">{b.runs}</td>
                        <td className="text-center fw-bold">{b.balls}</td>
                        <td className="text-center">{b.fours}</td>
                        <td className="text-center">{b.sixes}</td>
                        <td className="text-center text-muted small fw-bold">{b.strikeRate}</td>
                    </tr>
                ))}
                <tr className="bg-light bg-opacity-50">
                    <td colSpan={2} className="ps-4 py-3 text-muted fw-bold small text-uppercase letter-spacing-1">{t('extras')}</td>
                    <td colSpan={5} className="fw-bold ps-2 py-3">
                        {innings.extras.total} <small className="text-muted fw-normal ms-2">(wd {innings.extras.wides}, nb {innings.extras.noBalls}, b {innings.extras.byes}, lb {innings.extras.legByes})</small>
                    </td>
                </tr>
                <tr className="border-top-0">
                    <td colSpan={2} className="ps-4 py-3 fw-black text-uppercase letter-spacing-1 text-muted small">{t('total')}</td>
                    <td colSpan={5} className="ps-2 py-3 fw-black fs-4 text-primary">
                        {innings.runs}/{innings.wickets} <small className="text-muted fs-6 fw-bold">({innings.overs} {t('overs')})</small>
                    </td>
                </tr>
                <tr className="bg-white">
                    <td colSpan={7} className="ps-4 py-3 border-0">
                        <div className="d-flex gap-4 small text-muted text-uppercase fw-black letter-spacing-1 overflow-auto pb-1">
                            <span className="text-nowrap opacity-75">Dots: <span className="text-dark">{innings.dots || 0}</span></span>
                            <span className="text-nowrap opacity-75">1s: <span className="text-dark">{innings.ones || 0}</span></span>
                            <span className="text-nowrap opacity-75">2s: <span className="text-dark">{innings.twos || 0}</span></span>
                            <span className="text-nowrap opacity-75">3s: <span className="text-dark">{innings.threes || 0}</span></span>
                            <span className="text-nowrap text-primary">4s: <span className="text-dark">{innings.fours || 0}</span></span>
                            <span className="text-nowrap text-success">6s: <span className="text-dark">{innings.sixes || 0}</span></span>
                        </div>
                    </td>
                </tr>
            </tbody>
        </Table>
    );

    const renderBowlingTable = (inningsIdx) => {
        const bowlingTeamIdx = inningsIdx === 0 ? 1 : 0;
        const bowlingInnings = match.innings[bowlingTeamIdx];
        if (!bowlingInnings || !bowlingInnings.bowling) return null;

        return (
            <Table hover responsive className={`mb-0 cric-table mt-4 border-top border-4 border-success ${theme === 'dark' ? 'table-dark' : ''}`}>
                <thead className="bg-success bg-opacity-10">
                    <tr>
                        <th className="ps-4 py-3 text-uppercase small fw-black text-success letter-spacing-1">{t('bowler')}</th>
                        <th className="text-center py-3 text-uppercase small fw-black text-success letter-spacing-1">{t('overs')}</th>
                        <th className="text-center py-3 text-uppercase small fw-black text-success letter-spacing-1">M</th>
                        <th className="text-center py-3 text-uppercase small fw-black text-success letter-spacing-1">R</th>
                        <th className="text-center py-3 text-uppercase small fw-black text-success letter-spacing-1">W</th>
                        <th className="text-center py-3 text-uppercase small fw-black text-success letter-spacing-1">WD</th>
                        <th className="text-center py-3 text-uppercase small fw-black text-success letter-spacing-1">NB</th>
                        <th className="text-center py-3 text-uppercase small fw-black text-success letter-spacing-1">Eco</th>
                    </tr>
                </thead>
                <tbody>
                    {bowlingInnings.bowling.map((bowler, idx) => (
                        <tr key={idx} className="align-middle">
                            <td className="ps-4 fw-bold text-dark">{bowler.player}</td>
                            <td className="text-center fw-bold">{bowler.overs}</td>
                            <td className="text-center">{bowler.maidens}</td>
                            <td className="text-center fw-bold">{bowler.runs}</td>
                            <td className="text-center fw-black text-danger fs-5">{bowler.wickets}</td>
                            <td className="text-center">{bowler.wides || 0}</td>
                            <td className="text-center">{bowler.noBalls || 0}</td>
                            <td className="text-center text-muted small fw-bold">{bowler.economy}</td>
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
                    <div className="p-4 border-bottom bg-light bg-opacity-10">
                        <h4 className="fw-black mb-1 text-uppercase letter-spacing-1 text-primary">{match.teamA.toUpperCase()} vs {match.teamB.toUpperCase()}</h4>
                        <div className="text-muted small mb-0 d-flex flex-wrap gap-4">
                            <span className="d-flex align-items-center gap-1"><span className="opacity-50">🏆</span> {t('series')}: <strong className="text-dark">{match.series || 'SMCC'}</strong></span>
                            <span className="d-flex align-items-center gap-1"><span className="opacity-50">📍</span> {t('venue')}: <strong className="text-dark">{match.venue}</strong></span>
                            <span className="d-flex align-items-center gap-1"><span className="opacity-50">📅</span> {t('date')}: <strong className="text-dark">{new Date(match.date).toLocaleDateString([], { weekday: 'long', month: 'long', day: 'numeric', year: 'numeric' })}</strong></span>
                        </div>
                    </div>

                    <Nav className="tab-menu px-4 border-bottom">
                        <Nav.Link className={activeTab === 'scorecard' ? 'active' : ''} onClick={() => setActiveTab('scorecard')}>{t('full_scorecard')}</Nav.Link>
                        <Nav.Link as={Link} to="/">{t('live')}</Nav.Link>
                        <Nav.Link className={activeTab === 'info' ? 'active' : ''} onClick={() => setActiveTab('info')}>{t('match_info')}</Nav.Link>
                    </Nav>

                    <div className="p-4 bg-white bg-opacity-50">
                        {activeTab === 'scorecard' ? (
                            <>
                                {match.status === 'completed' && (
                                    <div className="mb-4 text-center">
                                        <div className="alert alert-success border-0 shadow-sm py-3 px-4 rounded-4 d-inline-block">
                                            <h5 className="fw-black text-success m-0 text-uppercase letter-spacing-1">
                                                {match.innings && match.innings.length >= 2 ? (
                                                    match.innings[0].runs > match.innings[1].runs
                                                        ? `${match.innings[0].team} WON BY ${match.innings[0].runs - match.innings[1].runs} RUNS`
                                                        : match.innings[1].runs > match.innings[0].runs
                                                            ? `${match.innings[1].team} WON BY ${10 - match.innings[1].wickets} WICKETS`
                                                            : "MATCH DRAWN"
                                                ) : "MATCH COMPLETED"}
                                            </h5>
                                            {match.manOfTheMatch && (
                                                <div className="mt-2 fw-bold text-success opacity-75 small">
                                                    🏅 {t('man_of_the_match').toUpperCase()}: {match.manOfTheMatch}
                                                </div>
                                            )}
                                        </div>
                                    </div>
                                )}

                                <div className="innings-list">
                                    {match.innings.map((inn, idx) => (
                                        <div key={idx} className="innings-card">
                                            <div
                                                className={`innings-summary d-flex justify-content-between align-items-center ${activeInnings === idx ? 'active' : ''}`}
                                                onClick={() => setActiveInnings(idx)}
                                                style={{ cursor: 'pointer' }}
                                            >
                                                <div className="d-flex align-items-center gap-3">
                                                    <div className={`rounded-circle bg-white bg-opacity-25 d-flex align-items-center justify-content-center fw-bold`} style={{ width: '30px', height: '30px', fontSize: '12px' }}>{idx + 1}</div>
                                                    <div className="fw-black text-uppercase letter-spacing-1">{inn.team}</div>
                                                </div>
                                                <div className="fw-black fs-5">{inn.runs}/{inn.wickets} <small className="fw-bold opacity-75">({inn.overs})</small></div>
                                            </div>
                                            {activeInnings === idx && (
                                                <div className="innings-detail bg-white">
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
                                <Row className="g-4">
                                    <Col lg={5}>
                                        <div className="match-info-card shadow-sm h-100">
                                            <h5 className="fw-black text-uppercase text-primary border-bottom pb-3 mb-4 letter-spacing-1">{t('match_details')}</h5>
                                            <div className="d-flex flex-column gap-3">
                                                <div className="d-flex justify-content-between align-items-center border-bottom pb-2">
                                                    <span className="text-muted fw-bold small text-uppercase">{t('series')}</span>
                                                    <span className="fw-black text-dark">{match.series || 'SMCC Premier League'}</span>
                                                </div>
                                                <div className="d-flex justify-content-between align-items-center border-bottom pb-2">
                                                    <span className="text-muted fw-bold small text-uppercase">{t('venue')}</span>
                                                    <span className="fw-black text-dark">{match.venue}</span>
                                                </div>
                                                <div className="d-flex justify-content-between align-items-center border-bottom pb-2">
                                                    <span className="text-muted fw-bold small text-uppercase">{t('date')}</span>
                                                    <span className="fw-black text-dark">{new Date(match.date).toLocaleDateString()}</span>
                                                </div>
                                                <div className="d-flex justify-content-between align-items-center border-bottom pb-2">
                                                    <span className="text-muted fw-bold small text-uppercase">{t('time')}</span>
                                                    <span className="fw-black text-dark">{new Date(match.date).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}</span>
                                                </div>
                                                <div className="d-flex justify-content-between align-items-center border-bottom pb-2">
                                                    <span className="text-muted fw-bold small text-uppercase">{t('total_overs')}</span>
                                                    <span className="fw-black text-success">{match.totalOvers} Overs</span>
                                                </div>
                                                {match.toss?.winner && (
                                                    <div className="mt-2 p-3 bg-warning bg-opacity-10 rounded-3 border border-warning border-opacity-25">
                                                        <small className="fw-black text-warning text-uppercase d-block mb-1">Toss Information</small>
                                                        <div className="fw-bold text-dark small">
                                                            🪙 {match.toss.winner} won the toss and elected to {match.toss.decision} first.
                                                        </div>
                                                    </div>
                                                )}
                                            </div>
                                        </div>
                                    </Col>
                                    <Col lg={7}>
                                        <div className="match-info-card shadow-sm h-100">
                                            <h5 className="fw-black text-uppercase text-primary border-bottom pb-3 mb-4 letter-spacing-1">📋 ICC Match Rules & Format</h5>
                                            <ul className="rules-list">
                                                <li><strong>Match Format:</strong> T20 International Standard ({match.totalOvers} Overs per side).</li>
                                                <li><strong>Powerplay (P1):</strong> Overs 1-6 are mandatory Powerplay (Max 2 fielders outside 30-yard circle).</li>
                                                <li><strong>Bowling Limits:</strong> Maximum <strong>{(match.totalOvers * 0.2).toFixed(0)} Overs</strong> per bowler.</li>
                                                <li><strong>Pure Bowling Action:</strong> Elbow extension must not exceed 15 degrees (ICC Regulations).</li>
                                                <li><strong>Wide Ball:</strong> 1 Run + Re-bowl. Strict adjudication on leg-side deliveries.</li>
                                                <li><strong>No Ball:</strong> 1 Run + Re-bowl + <strong>Free Hit</strong> for the next delivery.</li>
                                                <li><strong>Dismissals:</strong> All standard modes apply (Bowled, Caught, LBW, Run Out, Stumped, Hit Wicket).</li>
                                                <li><strong>Tie Breaker:</strong> In the event of a tie, a <strong>Super Over</strong> will be played to decide winner.</li>
                                                <li><strong>Substitutes:</strong> Concussion substitute allowed if validated by match referee.</li>
                                            </ul>
                                        </div>
                                    </Col>
                                </Row>
                            </div>
                        )}
                    </div>
                </Card.Body>
            </Card>

            <style>{`
                .scorecard-page { max-width: 1000px; }
                .bg-cric-dark { background: linear-gradient(135deg, #1e3c72 0%, #2a5298 100%); }
                .fw-black { font-weight: 900; }
                .letter-spacing-1 { letter-spacing: 1px; }
                .letter-spacing-2 { letter-spacing: 2px; }
                
                .card { border-radius: 20px; box-shadow: 0 10px 40px rgba(0,0,0,0.08) !important; }
                
                .tab-menu .nav-link { 
                    color: #64748b; 
                    padding: 1.25rem 2rem; 
                    border-bottom: 4px solid transparent;
                    font-weight: 800;
                    border-radius: 0;
                    transition: all 0.3s ease;
                    text-transform: uppercase;
                    font-size: 13px;
                }
                .tab-menu .nav-link:hover { color: #1e3c72; }
                .tab-menu .nav-link.active { 
                    color: #009270; 
                    border-bottom-color: #009270; 
                }
                
                .innings-card { border: 1px solid #edf2f7; border-radius: 15px; overflow: hidden; margin-bottom: 25px; transition: transform 0.2s ease; }
                .innings-card:hover { transform: translateY(-2px); }
                
                .innings-summary { 
                    padding: 1.2rem 1.5rem; 
                    background: #f8fafc;
                    transition: all 0.3s ease;
                }
                .innings-summary.active { 
                    background: linear-gradient(90deg, #009270 0%, #00b894 100%) !important;
                    color: white !important;
                }
                
                .cric-table thead th { 
                    background: #f1f5f9; 
                    color: #475569; 
                    font-size: 10px; 
                    text-transform: uppercase; 
                    padding: 12px 15px; 
                    border: none;
                    letter-spacing: 0.5px;
                }
                [data-theme='dark'] .cric-table thead th {
                    background: #1e293b;
                    color: #94a3b8;
                }

                .player-name { color: #1e3c72; font-size: 14px; }
                [data-theme='dark'] .player-name { color: #60a5fa; }
                
                .extras-row { background: rgba(0,0,0,0.02); }
                .total-row { background: #f8fafc; }
                [data-theme='dark'] .total-row { background: #1e293b; }
                
                .breakdown-row { background: white; }
                [data-theme='dark'] .breakdown-row { background: #0f172a; }
                
                .match-info-card { background: #f8fafc; border-radius: 12px; padding: 25px; border: 1px solid #e2e8f0; }
                [data-theme='dark'] .match-info-card { background: #1e293b; border-color: #334155; }
                
                .rules-list { list-style: none; padding-left: 0; }
                .rules-list li { position: relative; padding-left: 25px; margin-bottom: 12px; font-size: 13px; color: #64748b; }
                .rules-list li::before { content: "✓"; position: absolute; left: 0; color: #009270; font-weight: bold; }
                [data-theme='dark'] .rules-list li { color: #94a3b8; }
            `}</style>
        </Container >
    );
};

export default FullScorecard;
