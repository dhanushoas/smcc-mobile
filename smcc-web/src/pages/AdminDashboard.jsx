import React, { useEffect, useState } from 'react';
import axios from 'axios';
import { useNavigate } from 'react-router-dom';
import { Container, Row, Col, Card, Button, Form, Table, Badge, ListGroup, Modal, Spinner, Alert } from 'react-bootstrap';
import { Toaster, toast } from 'react-hot-toast';
import { io } from 'socket.io-client';
import { jsPDF } from 'jspdf';
import 'jspdf-autotable';

const API_URL = import.meta.env.VITE_API_URL || 'http://localhost:5000';
const socket = io(API_URL);

const AdminDashboard = () => {
    const [matches, setMatches] = useState([]);
    const [selectedMatch, setSelectedMatch] = useState(null);
    const [isCreating, setIsCreating] = useState(false);
    const navigate = useNavigate();

    const [createForm, setCreateForm] = useState({
        title: '', teamA: '', teamB: '', status: 'upcoming',
        date: new Date().toISOString().split('T')[0],
        time: '09:00', venue: '', totalOvers: 20
    });

    const [striker, setStriker] = useState('');
    const [nonStriker, setNonStriker] = useState('');
    const [bowler, setBowler] = useState('');
    const [scorecardData, setScorecardData] = useState([]);

    // Modals State
    const [showStartModal, setShowStartModal] = useState(false);
    const [showBowlerModal, setShowBowlerModal] = useState(false);
    const [showBatsmanModal, setShowBatsmanModal] = useState(false);
    const [batsmanModalType, setBatsmanModalType] = useState('wicket');
    const [showRunOutModal, setShowRunOutModal] = useState(false);
    const [runOutOutType, setRunOutOutType] = useState('striker');

    const [showWicketModal, setShowWicketModal] = useState(false);
    const [wicketDetails, setWicketDetails] = useState({
        type: 'caught',
        fielder: '',
        runs: 0,
        crossed: false
    });

    const [modalData, setModalData] = useState({
        s: '', ns: '', b: '', nextB: '', nextS: ''
    });

    const [isUpdating, setIsUpdating] = useState(false);
    const [showSquadModal, setShowSquadModal] = useState(false);
    const [showTossModal, setShowTossModal] = useState(false);
    const [squadA, setSquadA] = useState(Array(11).fill(''));
    const [squadB, setSquadB] = useState(Array(11).fill(''));
    const [tossData, setTossData] = useState({ winner: '', decision: 'bat' });

    const capitalizeName = (name) => {
        if (!name) return '';
        // Remove numbers and special characters, allow only letters and spaces
        const cleaned = name.replace(/[^a-zA-Z\s]/g, '');
        return cleaned.charAt(0).toUpperCase() + cleaned.slice(1);
    };

    const handleSquadChange = (team, index, value) => {
        const val = capitalizeName(value);
        if (team === 'A') {
            const newSquad = [...squadA];
            newSquad[index] = val;
            setSquadA(newSquad);
        } else {
            const newSquad = [...squadB];
            newSquad[index] = val;
            setSquadB(newSquad);
        }
    };

    const validateSquads = () => {
        const fullA = squadA.filter(p => p.trim() !== '');
        const fullB = squadB.filter(p => p.trim() !== '');

        if (fullA.length < 11 || fullB.length < 11) {
            toast.error("Please fill all 11 player names for both teams!");
            return false;
        }

        // Check for duplicates in Team A
        if (new Set(fullA).size !== fullA.length) {
            toast.error("Duplicate names found in Team A squad!");
            return false;
        }

        // Check for duplicates in Team B
        if (new Set(fullB).size !== fullB.length) {
            toast.error("Duplicate names found in Team B squad!");
            return false;
        }

        // Check for cross-team duplicates
        const overlap = fullA.filter(p => fullB.includes(p));
        if (overlap.length > 0) {
            toast.error(`Players cannot play for both teams: ${overlap.join(", ")}`);
            return false;
        }

        return true;
    };

    const calculateWinner = (matchData) => {
        if (!matchData || matchData.status !== 'completed') return null;
        const innings = matchData.innings || [];
        if (innings.length < 2) return "Match Completed";

        const inn1 = innings[0];
        const inn2 = innings[1];

        if (inn1.runs > inn2.runs) {
            return `${inn1.team} won by ${inn1.runs - inn2.runs} runs`;
        } else if (inn2.runs >= inn1.runs) {
            const wicketsRemaining = 10 - inn2.wickets;
            return `${inn2.team} won by ${wicketsRemaining} wickets`;
        }
        return "Match Drawn";
    };

    const handleDownloadPDF = () => {
        if (!selectedMatch) return;
        const doc = new jsPDF();
        const pageWidth = doc.internal.pageSize.getWidth();

        // Header
        doc.setFontSize(22);
        doc.setTextColor(30, 60, 114);
        doc.text("SMCC CRICKET SCORECARD", pageWidth / 2, 20, { align: 'center' });

        doc.setFontSize(14);
        doc.setTextColor(100);
        doc.text(`${selectedMatch.teamA} VS ${selectedMatch.teamB}`, pageWidth / 2, 30, { align: 'center' });

        doc.setFontSize(10);
        doc.text(`Series: ${selectedMatch.title || 'SMCC Tournament'}`, pageWidth / 2, 38, { align: 'center' });
        doc.text(`Venue: ${selectedMatch.venue || 'TBD'}`, pageWidth / 2, 44, { align: 'center' });
        doc.text(`Date & Time: ${new Date(selectedMatch.date).toLocaleDateString()} ${selectedMatch.time || ''}`, pageWidth / 2, 50, { align: 'center' });
        doc.text(`Exported on: ${new Date().toLocaleString()}`, pageWidth / 2, 56, { align: 'center' });

        const result = calculateWinner(selectedMatch);
        if (result) {
            doc.setFontSize(14);
            doc.setTextColor(0, 146, 112);
            doc.text(result.toUpperCase(), pageWidth / 2, 68, { align: 'center' });
            if (selectedMatch.manOfTheMatch) {
                doc.setFontSize(12);
                doc.text(`MAN OF THE MATCH: ${selectedMatch.manOfTheMatch.toUpperCase()}`, pageWidth / 2, 76, { align: 'center' });
            }
        }

        let currentY = result ? 85 : 65;

        (selectedMatch.innings || []).forEach((inn, idx) => {
            doc.setFontSize(14);
            doc.setTextColor(30, 60, 114);
            doc.text(`${inn.team} Innings: ${inn.runs}/${inn.wickets} (${inn.overs} Ov)`, 14, currentY);
            currentY += 5;

            // Batting Table
            doc.autoTable({
                startY: currentY,
                head: [['Batter', 'Status', 'R', 'B', '4s', '6s', 'SR']],
                body: (inn.batting || []).map(b => [b.player, b.status, b.runs, b.balls, b.fours, b.sixes, b.strikeRate]),
                theme: 'striped',
                headStyles: { fillColor: [30, 60, 114] }
            });
            currentY = doc.lastAutoTable.finalY + 10;

            // Bowling Table
            doc.autoTable({
                startY: currentY,
                head: [['Bowler', 'O', 'M', 'R', 'W', 'Eco']],
                body: (inn.bowling || []).map(b => [b.player, b.overs, b.maidens, b.runs, b.wickets, b.economy]),
                theme: 'grid',
                headStyles: { fillColor: [0, 146, 112] }
            });
            currentY = doc.lastAutoTable.finalY + 15;

            if (currentY > 250 && idx < (selectedMatch.innings || []).length - 1) {
                doc.addPage();
                currentY = 20;
            }
        });

        doc.save(`${selectedMatch.teamA}_vs_${selectedMatch.teamB}_Scorecard.pdf`);
    };

    const undoLastBall = async () => {
        if (!selectedMatch || !selectedMatch.history || selectedMatch.history.length === 0) {
            toast.error("Nothing to undo!");
            return;
        }

        if (!window.confirm("Undo last ball? This ensures accurate calculations.")) return;

        const previousState = selectedMatch.history[selectedMatch.history.length - 1];

        // Optimistic UI Update
        setSelectedMatch(previousState);
        setScorecardData(previousState.innings);
        syncLocalPlayers(previousState);

        try {
            await axios.put(`${API_URL}/api/matches/${previousState._id || previousState.id}`, previousState, config);
            toast.success("Undo successful!");
        } catch (err) {
            toast.error("Undo failed on server");
            fetchMatches(); // Revert to server state
        }
    };

    const handleSquadSave = async () => {
        if (!validateSquads()) return;

        if (isCreating) {
            setShowSquadModal(false);
            toast.success("Squads ready for new match!");
        } else if (selectedMatch) {
            // Save to DB immediately for existing match
            try {
                await handleUpdate('manual', {
                    ...selectedMatch,
                    teamASquad: squadA,
                    teamBSquad: squadB
                });
                setShowSquadModal(false);
                toast.success("Squads updated!");
            } catch (err) {
                toast.error("Failed to save squads");
            }
        }
    };

    const activeToken = localStorage.getItem('token');
    const config = { headers: { 'x-auth-token': activeToken } };

    const fetchMatches = async () => {
        try {
            const res = await axios.get(`${API_URL}/api/matches`);
            setMatches(res.data);
        } catch (err) {
            console.error(err);
            toast.error("Failed to load matches");
        }
    };

    useEffect(() => {
        if (!activeToken) navigate('/login');
        fetchMatches();

        socket.on('matchUpdate', (updatedMatch) => {
            setMatches(prevMatches => {
                const index = prevMatches.findIndex(m => m._id === updatedMatch._id || m.id === updatedMatch.id);
                if (index !== -1) {
                    const newMatches = [...prevMatches];
                    newMatches[index] = updatedMatch;
                    return newMatches;
                }
                return [updatedMatch, ...prevMatches];
            });

            if (selectedMatch && (selectedMatch._id === updatedMatch._id || selectedMatch.id === updatedMatch.id)) {
                syncLocalPlayers(updatedMatch);
                setSelectedMatch(updatedMatch);
                setScorecardData(updatedMatch.innings);
            }
        });

        socket.on('matchDeleted', (matchId) => {
            setMatches(prev => prev.filter(m => m._id !== matchId && m.id !== matchId));
            if (selectedMatch?._id === matchId || selectedMatch?.id === matchId) setSelectedMatch(null);
        });

        return () => {
            socket.off('matchUpdate');
            socket.off('matchDeleted');
        };
    }, [navigate, activeToken, selectedMatch]);

    const syncLocalPlayers = (match) => {
        if (match.currentBatsmen && match.currentBatsmen.length >= 1) {
            setStriker(match.currentBatsmen.find(b => b.onStrike)?.name || '');
            setNonStriker(match.currentBatsmen.find(b => !b.onStrike)?.name || '');
        }
        setBowler(match.currentBowler || '');

        // Sync squads if they exist
        if (match.teamASquad && match.teamASquad.length === 11) setSquadA(match.teamASquad);
        else setSquadA(Array(11).fill(''));

        if (match.teamBSquad && match.teamBSquad.length === 11) setSquadB(match.teamBSquad);
        else setSquadB(Array(11).fill(''));
    };

    const handleEdit = (match) => {
        setSelectedMatch(match);
        setIsCreating(false);
        syncLocalPlayers(match);

        if (!match.innings || match.innings.length === 0) {
            const inningsTemplate = [
                {
                    team: match.teamA, runs: 0, wickets: 0, overs: 0,
                    batting: [], bowling: [],
                    extras: { total: 0, wides: 0, noBalls: 0, byes: 0, legByes: 0 }
                },
                {
                    team: match.teamB, runs: 0, wickets: 0, overs: 0,
                    batting: [], bowling: [],
                    extras: { total: 0, wides: 0, noBalls: 0, byes: 0, legByes: 0 }
                }
            ];
            setScorecardData(inningsTemplate);
        } else {
            setScorecardData(match.innings);
        }
    };

    const handleUpdate = async (type, value, params = {}) => {
        // --- Prevent Editing if Match Completed ---
        if (selectedMatch.status === 'completed') {
            toast.error("Match is completed! No further edits allowed.");
            return;
        }
        // ------------------------------------------

        setIsUpdating(true);
        // Deep copy for safety and history
        let updatedMatch = JSON.parse(JSON.stringify(selectedMatch));

        // --- History Logging (Mobile Parity) ---
        if (['runs', 'extra', 'wicket', 'retire', 'new_batsman', 'new_bowler', 'swap_strike'].includes(type) && type !== 'init') {
            if (!updatedMatch.history) updatedMatch.history = [];
            // Push the *current* (before update) state to history
            const currentState = JSON.parse(JSON.stringify(selectedMatch));
            updatedMatch.history.push(currentState);
            if (updatedMatch.history.length > 20) updatedMatch.history.shift(); // Keep last 20
        }
        // ---------------------------------------

        if (type === 'manual') {
            updatedMatch = value;
        } else {
            // Safety: Ensure innings structure exists and has 2 teams
            if (!updatedMatch.innings || updatedMatch.innings.length < 2) {
                const template = [
                    { team: updatedMatch.teamA, runs: 0, wickets: 0, overs: 0, batting: [], bowling: [], extras: { total: 0, wides: 0, noBalls: 0 } },
                    { team: updatedMatch.teamB, runs: 0, wickets: 0, overs: 0, batting: [], bowling: [], extras: { total: 0, wides: 0, noBalls: 0 } }
                ];
                updatedMatch.innings = template;
                setScorecardData(template); // Fix local state too
            }

            let battingTeam = updatedMatch.score.battingTeam || updatedMatch.teamA;

            // Determine index. If team names don't match, fallback to 0/1 safely
            let battingTeamIdx = 0;
            if (battingTeam === updatedMatch.teamB) battingTeamIdx = 1;

            let bowlingTeamIdx = battingTeamIdx === 0 ? 1 : 0;

            let currentInnings = updatedMatch.innings[battingTeamIdx];
            let currentBowling = updatedMatch.innings[bowlingTeamIdx];

            // Double safety if for some reason index is out of bounds (e.g. malformed innings array)
            if (!currentInnings) {
                currentInnings = updatedMatch.innings[0];
                currentBowling = updatedMatch.innings[1];
            }

            if (type === 'init') {
                const { s, ns, b } = value;
                const battingSquad = battingTeam === updatedMatch.teamA ? updatedMatch.teamASquad : updatedMatch.teamBSquad;
                const bowlingSquad = battingTeam === updatedMatch.teamA ? updatedMatch.teamBSquad : updatedMatch.teamASquad;

                if (battingSquad && (!battingSquad.includes(s) || !battingSquad.includes(ns))) {
                    toast.error("One or more batsmen are not in the squad!");
                    return;
                }
                if (bowlingSquad && !bowlingSquad.includes(b)) {
                    toast.error("Bowler is not in the squad!");
                    return;
                }

                // Ensure arrays exist
                if (!currentInnings.batting) currentInnings.batting = [];
                if (!currentBowling.bowling) currentBowling.bowling = [];

                if (!currentInnings.batting.find(p => p.player === s)) {
                    currentInnings.batting.push({ player: s, status: 'not out', runs: 0, balls: 0, fours: 0, sixes: 0, strikeRate: 0 });
                }
                if (!currentInnings.batting.find(p => p.player === ns)) {
                    currentInnings.batting.push({ player: ns, status: 'not out', runs: 0, balls: 0, fours: 0, sixes: 0, strikeRate: 0 });
                }
                if (!currentBowling.bowling.find(p => p.player === b)) {
                    currentBowling.bowling.push({ player: b, overs: 0, maidens: 0, runs: 0, wickets: 0, economy: 0 });
                }
                updatedMatch.currentBatsmen = [
                    { name: s, onStrike: true, runs: 0, balls: 0 },
                    { name: ns, onStrike: false, runs: 0, balls: 0 }
                ];
                updatedMatch.currentBowler = b;
                updatedMatch.status = 'live';
                if (!updatedMatch.score.battingTeam) updatedMatch.score.battingTeam = updatedMatch.teamA;

                setStriker(s); setNonStriker(ns); setBowler(b);
            } else {
                // Fallback: If state is empty, try to get from current match object
                let localStriker = striker || updatedMatch.currentBatsmen?.find(b => b.onStrike)?.name || '';
                let localNonStriker = nonStriker || updatedMatch.currentBatsmen?.find(b => !b.onStrike)?.name || '';
                let localBowler = bowler || updatedMatch.currentBowler || '';

                let sIdx = currentInnings.batting.findIndex(p => p.player === localStriker);

                // Auto-fix: If player exists in currentBatsmen but not in innings list (shouldn't happen but safe to handle)
                if (sIdx === -1 && localStriker) {
                    currentInnings.batting.push({ player: localStriker, status: 'not out', runs: 0, balls: 0, fours: 0, sixes: 0, strikeRate: 0 });
                    sIdx = currentInnings.batting.length - 1;
                }

                let bIdx = currentBowling.bowling.findIndex(p => p.player === localBowler);
                if (bIdx === -1 && localBowler) {
                    currentBowling.bowling.push({ player: localBowler, overs: 0, maidens: 0, runs: 0, wickets: 0, economy: 0 });
                    bIdx = currentBowling.bowling.length - 1;
                }

                if ((!localStriker || !localBowler || sIdx === -1 || bIdx === -1) && type !== 'new_bowler') {
                    // Allow new_bowler to proceed even if striker is missing (edge case)
                    console.error("Missing State:", { localStriker, localBowler, sIdx, bIdx });
                    toast.error("Batsman or Bowler missing! Please check Match Info.");
                    return;
                }

                let ballCounts = true;

                if (type === 'runs') {
                    currentInnings.batting[sIdx].runs += value;
                    currentInnings.batting[sIdx].balls += 1;
                    if (value === 4) currentInnings.batting[sIdx].fours += 1;
                    if (value === 6) currentInnings.batting[sIdx].sixes += 1;

                    // Team breakdown
                    if (value === 0) currentInnings.dots = (currentInnings.dots || 0) + 1;
                    else if (value === 1) currentInnings.ones = (currentInnings.ones || 0) + 1;
                    else if (value === 2) currentInnings.twos = (currentInnings.twos || 0) + 1;
                    else if (value === 3) currentInnings.threes = (currentInnings.threes || 0) + 1;
                    else if (value === 4) currentInnings.fours = (currentInnings.fours || 0) + 1;
                    else if (value === 6) currentInnings.sixes = (currentInnings.sixes || 0) + 1;

                    currentBowling.bowling[bIdx].runs += value;
                    currentInnings.runs += value;
                    if (value % 2 !== 0) {
                        const temp = localStriker; localStriker = localNonStriker; localNonStriker = temp;
                    }
                } else if (type === 'swap_strike') {
                    const temp = localStriker; localStriker = localNonStriker; localNonStriker = temp;
                    ballCounts = false;
                } else if (type === 'extra') {
                    const amount = params?.amount || 1;
                    currentInnings.runs += amount;
                    currentBowling.bowling[bIdx].runs += amount;
                    if (value === 'w') {
                        currentInnings.extras.wides += amount;
                        currentBowling.bowling[bIdx].wides = (currentBowling.bowling[bIdx].wides || 0) + amount;
                        ballCounts = false;
                    }
                    else if (value === 'nb') {
                        currentInnings.extras.noBalls += amount;
                        currentBowling.bowling[bIdx].noBalls = (currentBowling.bowling[bIdx].noBalls || 0) + amount;
                        ballCounts = false;
                    }
                    else if (value === 'b') { currentInnings.extras.byes = (currentInnings.extras.byes || 0) + amount; }
                    else if (value === 'lb') { currentInnings.extras.legByes = (currentInnings.extras.legByes || 0) + amount; }
                    currentInnings.extras.total += amount;
                } else if (type === 'run_out_striker' || type === 'run_out_nonstriker') {
                    const isStrikerOut = type === 'run_out_striker';
                    const outPlayer = isStrikerOut ? localStriker : localNonStriker;
                    const pIdx = currentInnings.batting.findIndex(p => p.player === outPlayer);

                    if (pIdx !== -1) {
                        currentInnings.wickets += 1;
                        currentInnings.batting[pIdx].status = 'run out';
                        currentInnings.batting[sIdx].balls += 1; // Ball still counts

                        // We need a new batsman
                        setRunOutOutType(isStrikerOut ? 'striker' : 'non-striker');
                        setBatsmanModalType('wicket');
                        setShowBatsmanModal(true);
                        return; // Modal will handle the replacement
                    }
                } else if (type === 'wicket_with_replacement' || type === 'retired_with_replacement') {
                    const newName = value;
                    const battingSquad = battingTeam === updatedMatch.teamA ? updatedMatch.teamASquad : updatedMatch.teamBSquad;
                    if (battingSquad && !battingSquad.includes(newName)) {
                        toast.error("Player is not in the squad!");
                        return;
                    }
                    const isStrikerReplacement = runOutOutType === 'striker';

                    // Identify which player index was out
                    const outPlayerName = isStrikerReplacement ? localStriker : localNonStriker;
                    const outIdx = currentInnings.batting.findIndex(p => p.player === outPlayerName);

                    if (type === 'wicket_with_replacement') {
                        // Regular Wicket or Run Out confirmed
                        if (currentInnings.batting[outIdx]?.status === 'not out' || currentInnings.batting[outIdx]?.status === 'run out') {
                            currentInnings.wickets += 1;

                            const wDetail = params.wicketDetails || { type: 'bowled' };
                            let outStatus = '';
                            if (wDetail.type === 'caught') outStatus = `c ${wDetail.fielder} b ${localBowler}`;
                            else if (wDetail.type === 'bowled') outStatus = `b ${localBowler}`;
                            else if (wDetail.type === 'lbw') outStatus = `lbw b ${localBowler}`;
                            else if (wDetail.type === 'stumped') outStatus = `st ${wDetail.fielder} b ${localBowler}`;
                            else if (wDetail.type === 'run out') outStatus = `run out (${wDetail.fielder})`;
                            else if (wDetail.type === 'hit wicket') outStatus = `hit wicket b ${localBowler}`;
                            else outStatus = 'out';

                            currentInnings.batting[outIdx].status = outStatus;

                            if (wDetail.type !== 'run out') {
                                currentBowling.bowling[bIdx].wickets += 1;
                            }

                            if (!currentInnings.fallOfWickets) currentInnings.fallOfWickets = [];
                            currentInnings.fallOfWickets.push({
                                wicket: currentInnings.wickets,
                                runs: currentInnings.runs,
                                overs: currentInnings.overs,
                                player: outPlayerName
                            });

                            if (wDetail.type === 'run out') {
                                const completedRuns = parseInt(params.runs || 0);
                                currentInnings.runs += completedRuns;
                                currentBowling.bowling[bIdx].runs += completedRuns;
                                currentInnings.batting[sIdx].runs += completedRuns;
                                currentInnings.batting[sIdx].balls += 1;

                                // Team breakdown for run out runs
                                if (completedRuns === 1) currentInnings.ones = (currentInnings.ones || 0) + 1;
                                else if (completedRuns === 2) currentInnings.twos = (currentInnings.twos || 0) + 1;
                                else if (completedRuns === 3) currentInnings.threes = (currentInnings.threes || 0) + 1;
                                else if (completedRuns === 0) currentInnings.dots = (currentInnings.dots || 0) + 1;

                                if (params.crossed) {
                                    // Cross happened before run out
                                    const temp = localStriker; localStriker = localNonStriker; localNonStriker = temp;
                                }
                            } else {
                                currentInnings.batting[sIdx].balls += 1; // Ball still counts for non-run-out wickets
                            }
                        }
                    } else {
                        currentInnings.batting[outIdx].status = 'retired hurt';
                        currentInnings.batting[outIdx].balls += 1;
                    }

                    if (isStrikerReplacement) localStriker = newName;
                    else localNonStriker = newName;

                    if (!currentInnings.batting.find(p => p.player === newName)) {
                        currentInnings.batting.push({ player: newName, status: 'not out', runs: 0, balls: 0, fours: 0, sixes: 0, strikeRate: 0 });
                    }
                    setRunOutOutType('striker'); // Reset for regular wickets
                } else if (type === 'new_bowler') {
                    if (localBowler === value) {
                        toast.error("A bowler cannot bowl two overs in a row!");
                        return;
                    }
                    const bowlingSquad = battingTeam === updatedMatch.teamA ? updatedMatch.teamBSquad : updatedMatch.teamASquad;
                    if (bowlingSquad && !bowlingSquad.includes(value)) {
                        toast.error("Bowler is not in the squad!");
                        return;
                    }
                    localBowler = value;
                    if (!currentBowling.bowling.find(p => p.player === value)) {
                        currentBowling.bowling.push({ player: value, overs: 0, maidens: 0, runs: 0, wickets: 0, economy: 0, wides: 0, noBalls: 0 });
                    }
                }

                if (ballCounts && type !== 'wicket_with_replacement' && type !== 'retired_with_replacement' && type !== 'new_bowler') {
                    let currentOvers = currentInnings.overs;
                    let overFull = Math.floor(currentOvers);
                    let ballCount = Math.round((currentOvers * 10) % 10) + 1;

                    let bOvers = currentBowling.bowling[bIdx].overs;
                    let bOverFull = Math.floor(bOvers);
                    let bBallCount = Math.round((bOvers * 10) % 10) + 1;

                    if (ballCount >= 6) {
                        ballCount = 0; overFull += 1;
                        bBallCount = 0; bOverFull += 1;
                        const temp = localStriker; localStriker = localNonStriker; localNonStriker = temp;
                        if (overFull < updatedMatch.totalOvers) { setShowBowlerModal(true); }
                    } else {
                        if (bBallCount >= 6) { bBallCount = 0; bOverFull += 1; }
                    }
                    currentInnings.overs = parseFloat(`${overFull}.${ballCount}`);
                    currentBowling.bowling[bIdx].overs = parseFloat(`${bOverFull}.${bBallCount}`);
                }

                currentInnings.batting.forEach(p => { if (p.balls > 0) p.strikeRate = parseFloat(((p.runs / p.balls) * 100).toFixed(2)); });
                currentBowling.bowling.forEach(p => {
                    let totalBalls = (Math.floor(p.overs) * 6) + (Math.round((p.overs * 10) % 10));
                    if (totalBalls > 0) p.economy = parseFloat(((p.runs / totalBalls) * 6).toFixed(2));
                });

                const isAllOut = currentInnings.wickets >= 10;
                const isOversCompleted = currentInnings.overs >= updatedMatch.totalOvers;
                const targetChased = updatedMatch.score.target && currentInnings.runs >= updatedMatch.score.target;

                if (isAllOut || isOversCompleted || targetChased) {
                    if (!updatedMatch.score.target) {
                        updatedMatch.score.target = currentInnings.runs + 1;
                        const nextTeam = updatedMatch.score.battingTeam === updatedMatch.teamA ? updatedMatch.teamB : updatedMatch.teamA;
                        if (window.confirm(`${currentInnings.team} innings over. Start ${nextTeam} innings?`)) {
                            updatedMatch.score.battingTeam = nextTeam;
                            updatedMatch.score.runs = 0; updatedMatch.score.wickets = 0; updatedMatch.score.overs = 0;
                            localStriker = ''; localNonStriker = ''; localBowler = '';
                            setStriker(''); setNonStriker(''); setBowler('');
                            setModalData({ s: '', ns: '', b: '', nextB: '', nextS: '' });
                            setSelectedMatch({ ...updatedMatch });
                            setShowStartModal(true);
                        }
                    } else {
                        updatedMatch.status = 'completed';
                        const mom = calculateMOM(updatedMatch);
                        if (mom) updatedMatch.manOfTheMatch = mom;
                    }
                }

                updatedMatch.score.runs = currentInnings.runs;
                updatedMatch.score.wickets = currentInnings.wickets;
                updatedMatch.score.overs = currentInnings.overs;
                updatedMatch.currentBowler = localBowler;
                updatedMatch.currentBatsmen = [
                    { name: localStriker, onStrike: true, runs: currentInnings.batting.find(p => p.player === localStriker)?.runs || 0, balls: currentInnings.batting.find(p => p.player === localStriker)?.balls || 0 },
                    { name: localNonStriker, onStrike: false, runs: currentInnings.batting.find(p => p.player === localNonStriker)?.runs || 0, balls: currentInnings.batting.find(p => p.player === localNonStriker)?.balls || 0 }
                ];

                setStriker(localStriker); setNonStriker(localNonStriker); setBowler(localBowler);
            }
        }

        try {
            const res = await axios.put(`${API_URL}/api/matches/${selectedMatch._id || selectedMatch.id}`, updatedMatch, config);

            // Resilience: Prepare new state
            let newMatchState = res.data;

            // If backend didn't return history (e.g. schema outdated), preserve local history
            if ((!newMatchState.history || newMatchState.history.length === 0) && updatedMatch.history && updatedMatch.history.length > 0) {
                newMatchState.history = updatedMatch.history;
            }

            setSelectedMatch(newMatchState);
            setScorecardData(newMatchState.innings);
            // toast.success("Score Updated!", { id: 'score-toast' }); // Lower noise like mobile
        } catch (err) {
            toast.error("Sync failed");
        } finally {
            setIsUpdating(false);
        }
    };

    const calculateMOM = (match) => {
        const inn1 = match.innings[0];
        const inn2 = match.innings[1];
        if (!inn1 || !inn2) return null;
        let winningTeam = null;
        if (inn1.runs > inn2.runs) winningTeam = inn1.team;
        else if (inn2.runs > inn1.runs) winningTeam = inn2.team;
        else return null;
        const winnerInn = match.innings.find(i => i.team === winningTeam);
        const loserInn = match.innings.find(i => i.team !== winningTeam);
        let candidates = {};
        winnerInn?.batting.forEach(p => { candidates[p.player] = { runs: p.runs, wickets: 0 }; });
        loserInn?.bowling.forEach(p => {
            if (!candidates[p.player]) candidates[p.player] = { runs: 0, wickets: 0 };
            candidates[p.player].wickets = p.wickets;
        });
        let best = null; let max = -1;
        Object.keys(candidates).forEach(name => {
            const score = candidates[name].runs + (candidates[name].wickets * 25);
            if (score > max) { max = score; best = name; }
        });
        return best;
    };

    const handleCreateSubmit = async (e) => {
        e.preventDefault();
        try {
            if (createForm.teamA === createForm.teamB) {
                toast.error("Team A and Team B cannot be the same!");
                return;
            }
            if (!validateSquads()) return;
            await axios.post(`${API_URL}/api/matches`, {
                ...createForm,
                teamASquad: squadA,
                teamBSquad: squadB,
                date: `${createForm.date}T${createForm.time}`,
                title: createForm.title || `${createForm.teamA} vs ${createForm.teamB}`
            }, config);
            toast.success("Match created!");
            fetchMatches(); setIsCreating(false);
        } catch (err) { toast.error("Error creating match"); }
    };

    const handleDelete = async (e, id) => {
        e.stopPropagation();
        if (window.confirm("Delete this match?")) {
            try {
                await axios.delete(`${API_URL}/api/matches/${id}`, config);
                toast.success('Deleted'); fetchMatches();
                if (selectedMatch?._id === id || selectedMatch?.id === id) setSelectedMatch(null);
            } catch (err) { toast.error("Failed"); }
        }
    };

    const getOversInBalls = (overs) => {
        return (Math.floor(overs) * 6) + Math.round((overs * 10) % 10);
    };

    const crr = (selectedMatch?.score?.overs > 0) ? (selectedMatch?.score?.runs / selectedMatch?.score?.overs).toFixed(2) : '0.00';

    const calculateRRR = () => {
        if (!selectedMatch?.score?.target) return null;
        const runsNeeded = selectedMatch.score.target - selectedMatch.score.runs;
        const totalBalls = selectedMatch.totalOvers * 6;
        const ballsBowled = getOversInBalls(selectedMatch.score.overs);
        const ballsRemaining = totalBalls - ballsBowled;
        if (ballsRemaining <= 0) return runsNeeded <= 0 ? '0.00' : '∞';
        return ((runsNeeded / ballsRemaining) * 6).toFixed(2);
    };
    const rrr = calculateRRR();

    return (
        <Container className="py-4">
            <Toaster position="top-right" />

            {/* SQUAD MODAL */}
            <Modal show={showSquadModal} onHide={() => setShowSquadModal(false)} size="xl" backdrop="static">
                <Modal.Header closeButton><Modal.Title>Manage Squads (11 Players Each)</Modal.Title></Modal.Header>
                <Modal.Body>
                    <Row>
                        <Col md={6}>
                            <h5 className="text-center text-primary fw-bold mb-3">{createForm.teamA || selectedMatch?.teamA || 'Team A'}</h5>
                            {squadA.map((p, i) => (
                                <Form.Control key={i} className="mb-2" placeholder={`Player ${i + 1}`} value={p} onChange={e => handleSquadChange('A', i, e.target.value)} />
                            ))}
                        </Col>
                        <Col md={6}>
                            <h5 className="text-center text-danger fw-bold mb-3">{createForm.teamB || selectedMatch?.teamB || 'Team B'}</h5>
                            {squadB.map((p, i) => (
                                <Form.Control key={i} className="mb-2" placeholder={`Player ${i + 1}`} value={p} onChange={e => handleSquadChange('B', i, e.target.value)} />
                            ))}
                        </Col>
                    </Row>
                </Modal.Body>
                <Modal.Footer>
                    <Button variant="success" onClick={handleSquadSave}>Save Squads</Button>
                </Modal.Footer>
            </Modal>

            {/* TOSS MODAL */}
            <Modal show={showTossModal} onHide={() => setShowTossModal(false)} centered backdrop="static">
                <Modal.Header><Modal.Title>🪙 Coin Toss</Modal.Title></Modal.Header>
                <Modal.Body>
                    <Form.Group className="mb-3">
                        <Form.Label>Winner</Form.Label>
                        <Form.Select value={tossData.winner} onChange={e => setTossData({ ...tossData, winner: e.target.value })}>
                            <option value="">Select Winner</option>
                            <option value={selectedMatch?.teamA}>{selectedMatch?.teamA}</option>
                            <option value={selectedMatch?.teamB}>{selectedMatch?.teamB}</option>
                        </Form.Select>
                    </Form.Group>
                    <Form.Group>
                        <Form.Label>Decision</Form.Label>
                        <Form.Select value={tossData.decision} onChange={e => setTossData({ ...tossData, decision: e.target.value })}>
                            <option value="bat">Bat</option>
                            <option value="bowl">Bowl</option>
                        </Form.Select>
                    </Form.Group>
                </Modal.Body>
                <Modal.Footer>
                    <Button variant="primary" onClick={() => {
                        if (!tossData.winner) return toast.error("Select a winner");
                        const battingTeam = tossData.decision === 'bat' ? tossData.winner : (tossData.winner === selectedMatch.teamA ? selectedMatch.teamB : selectedMatch.teamA);
                        handleUpdate('manual', {
                            ...selectedMatch,
                            toss: tossData,
                            score: { ...selectedMatch.score, battingTeam } // Auto set batting team
                        });
                        setShowTossModal(false);
                    }}>Confirm Toss</Button>
                </Modal.Footer>
            </Modal>

            <Modal show={showStartModal} onHide={() => setShowStartModal(false)} centered backdrop="static" contentClassName="border-0 shadow-lg rounded-4 overflow-hidden">
                <Modal.Header className="bg-primary text-white border-0 py-3 px-4"><Modal.Title className="fw-black">🚀 START MATCH</Modal.Title></Modal.Header>
                <Modal.Body className="p-4 bg-light">
                    <Form.Group className="mb-3">
                        <Form.Label className="fw-bold small text-uppercase text-muted">Striker</Form.Label>
                        <Form.Select size="lg" className="rounded-3 border-0 shadow-sm" value={modalData.s} onChange={e => setModalData({ ...modalData, s: e.target.value })}>
                            <option value="">Select Striker</option>
                            {(selectedMatch?.score?.battingTeam === selectedMatch?.teamA ? squadA : squadB).map((p, i) => <option key={i} value={p}>{p}</option>)}
                        </Form.Select>
                    </Form.Group>
                    <Form.Group className="mb-3">
                        <Form.Label className="fw-bold small text-uppercase text-muted">Non-Striker</Form.Label>
                        <Form.Select size="lg" className="rounded-3 border-0 shadow-sm" value={modalData.ns} onChange={e => setModalData({ ...modalData, ns: e.target.value })}>
                            <option value="">Select Non-Striker</option>
                            {(selectedMatch?.score?.battingTeam === selectedMatch?.teamA ? squadA : squadB).map((p, i) => <option key={i} value={p}>{p}</option>)}
                        </Form.Select>
                    </Form.Group>
                    <Form.Group className="mb-3">
                        <Form.Label className="fw-bold small text-uppercase text-muted">Bowler</Form.Label>
                        <Form.Select size="lg" className="rounded-3 border-0 shadow-sm" value={modalData.b} onChange={e => setModalData({ ...modalData, b: e.target.value })}>
                            <option value="">Select Bowler</option>
                            {(selectedMatch?.score?.battingTeam === selectedMatch?.teamA ? squadB : squadA).map((p, i) => <option key={i} value={p}>{p}</option>)}
                        </Form.Select>
                    </Form.Group>
                </Modal.Body>
                <Modal.Footer className="border-0 bg-light pb-4 px-4">
                    <Button variant="primary" size="lg" className="w-100 fw-black rounded-pill shadow" disabled={isUpdating} onClick={() => {
                        if (!modalData.s || !modalData.ns || !modalData.b) return toast.error("Select all players!");
                        if (modalData.s === modalData.ns) return toast.error("Striker and Non-Striker cannot be the same!");
                        handleUpdate('init', modalData);
                        setShowStartModal(false);
                    }}>
                        {isUpdating ? <Spinner animation="border" size="sm" /> : "LET'S PLAY"}
                    </Button>
                </Modal.Footer>
            </Modal>

            <Modal show={showBowlerModal} onHide={() => setShowBowlerModal(false)} centered backdrop="static" contentClassName="border-0 shadow-lg rounded-4 overflow-hidden">
                <Modal.Header className="bg-dark text-white border-0 py-3 px-4"><Modal.Title className="fw-black">⚾ NEXT BOWLER</Modal.Title></Modal.Header>
                <Modal.Body className="p-4 bg-light">
                    <Form.Group>
                        <Form.Label className="fw-bold small text-uppercase text-muted">Next Bowler Name:</Form.Label>
                        <Form.Select size="lg" className="rounded-3 border-0 shadow-sm" value={modalData.nextB} onChange={e => setModalData({ ...modalData, nextB: e.target.value })}>
                            <option value="">Select Bowler</option>
                            {(selectedMatch?.score?.battingTeam === selectedMatch?.teamA ? squadB : squadA).map((p, i) => <option key={i} value={p}>{p}</option>)}
                        </Form.Select>
                    </Form.Group>
                </Modal.Body>
                <Modal.Footer className="border-0 bg-light pb-4 px-4"><Button variant="primary" size="lg" className="w-100 fw-black rounded-pill shadow" onClick={() => { handleUpdate('new_bowler', modalData.nextB); setShowBowlerModal(false); setModalData({ ...modalData, nextB: '' }); }}>START OVER</Button></Modal.Footer>
            </Modal>

            <Modal show={showBatsmanModal} onHide={() => setShowBatsmanModal(false)} centered backdrop="static" contentClassName="border-0 shadow-lg rounded-4 overflow-hidden">
                <Modal.Header className={`${batsmanModalType === 'wicket' ? 'bg-danger' : 'bg-info'} text-white border-0 py-3 px-4`}>
                    <Modal.Title className="fw-black">{batsmanModalType === 'wicket' ? '🏏 WICKET! NEW BATSMAN' : '🏥 RETIRED! NEW BATSMAN'}</Modal.Title>
                </Modal.Header>
                <Modal.Body className="p-4 bg-light">
                    <Form.Group>
                        <Form.Label className="fw-bold small text-uppercase text-muted">Select New Batsman:</Form.Label>
                        <Form.Select size="lg" className="rounded-3 border-0 shadow-sm" value={modalData.nextS} onChange={e => setModalData({ ...modalData, nextS: e.target.value })}>
                            <option value="">Select Batsman</option>
                            {(selectedMatch?.score?.battingTeam === selectedMatch?.teamA ? squadA : squadB).map((p, i) => <option key={i} value={p}>{p}</option>)}
                        </Form.Select>
                    </Form.Group>
                </Modal.Body>
                <Modal.Footer className="border-0 bg-light pb-4 px-4">
                    <Button variant={batsmanModalType === 'wicket' ? 'danger' : 'info'} size="lg" className="w-100 fw-black rounded-pill shadow" onClick={() => {
                        if (!modalData.nextS) return toast.error("Select a player!");
                        const currentOther = selectedMatch.currentBatsmen.find(b => b.name !== (runOutOutType === 'striker' ? striker : nonStriker))?.name;
                        if (modalData.nextS === currentOther) return toast.error("Player already on field!");
                        handleUpdate(batsmanModalType === 'wicket' ? 'wicket_with_replacement' : 'retired_with_replacement', modalData.nextS, { wicketDetails });
                        setShowBatsmanModal(false); setModalData({ ...modalData, nextS: '' });
                    }}>SUBMIT</Button>
                </Modal.Footer>
            </Modal>

            <Modal show={showRunOutModal} onHide={() => setShowRunOutModal(false)} centered backdrop="static" contentClassName="border-0 shadow-lg rounded-4 overflow-hidden">
                <Modal.Header className="bg-warning text-dark border-0 py-3 px-4"><Modal.Title className="fw-black text-uppercase small">🏃 Run Out! Who is out?</Modal.Title></Modal.Header>
                <Modal.Body className="p-4 bg-light d-grid gap-3">
                    <Button variant="outline-danger" size="lg" className="fw-black py-3 rounded-3 shadow-sm border-2" onClick={() => { setRunOutOutType('striker'); setShowWicketModal(true); setWicketDetails({ ...wicketDetails, type: 'run out' }); setShowRunOutModal(false); }}>STRIKER: {striker}</Button>
                    <Button variant="outline-danger" size="lg" className="fw-black py-3 rounded-3 shadow-sm border-2" onClick={() => { setRunOutOutType('non-striker'); setShowWicketModal(true); setWicketDetails({ ...wicketDetails, type: 'run out' }); setShowRunOutModal(false); }}>NON-STRIKER: {nonStriker}</Button>
                </Modal.Body>
            </Modal>

            <Modal show={showWicketModal} onHide={() => setShowWicketModal(false)} centered backdrop="static" contentClassName="border-0 shadow-lg rounded-4 overflow-hidden">
                <Modal.Header className="bg-danger text-white border-0 py-3 px-4"><Modal.Title className="fw-black">☝️ WICKET DETAILS</Modal.Title></Modal.Header>
                <Modal.Body className="p-4 bg-light">
                    <Form.Group className="mb-3">
                        <Form.Label className="fw-bold small text-uppercase text-muted">Wicket Type</Form.Label>
                        <Form.Select size="lg" className="rounded-3 border-0 shadow-sm" value={wicketDetails.type} onChange={e => setWicketDetails({ ...wicketDetails, type: e.target.value })}>
                            <option value="caught">Caught</option>
                            <option value="bowled">Bowled</option>
                            <option value="lbw">LBW</option>
                            <option value="run out">Run Out</option>
                            <option value="stumped">Stumped</option>
                            <option value="hit wicket">Hit Wicket</option>
                            <option value="retired hurt">Retired Hurt</option>
                        </Form.Select>
                    </Form.Group>
                    {(wicketDetails.type === 'caught' || wicketDetails.type === 'run out' || wicketDetails.type === 'stumped') && (
                        <Form.Group className="mb-3">
                            <Form.Label className="fw-bold small text-uppercase text-muted">Fielder Name</Form.Label>
                            <Form.Select size="lg" className="rounded-3 border-0 shadow-sm" value={wicketDetails.fielder} onChange={e => setWicketDetails({ ...wicketDetails, fielder: e.target.value })}>
                                <option value="">Select Fielder</option>
                                {(selectedMatch?.score?.battingTeam === selectedMatch?.teamA ? squadB : squadA).map((p, i) => <option key={i} value={p}>{p}</option>)}
                            </Form.Select>
                        </Form.Group>
                    )}
                    {wicketDetails.type === 'run out' && (
                        <>
                            <Form.Group className="mb-3 d-flex align-items-center justify-content-between">
                                <Form.Label className="fw-bold small text-uppercase text-muted m-0">Batters Crossed?</Form.Label>
                                <Form.Check type="switch" checked={wicketDetails.crossed} onChange={e => setWicketDetails({ ...wicketDetails, crossed: e.target.checked })} />
                            </Form.Group>
                            <Form.Group className="mb-3">
                                <Form.Label className="fw-bold small text-uppercase text-muted">Runs Completed</Form.Label>
                                <Form.Select size="lg" className="rounded-3 border-0 shadow-sm" value={wicketDetails.runs} onChange={e => setWicketDetails({ ...wicketDetails, runs: parseInt(e.target.value) })}>
                                    {[0, 1, 2, 3].map(r => <option key={r} value={r}>{r}</option>)}
                                </Form.Select>
                            </Form.Group>
                        </>
                    )}
                </Modal.Body>
                <Modal.Footer className="border-0 bg-light pb-4 px-4">
                    <Button variant="danger" size="lg" className="w-100 fw-black rounded-pill shadow" onClick={() => {
                        handleUpdate('wicket', 0, { wicketDetails, ...wicketDetails });
                        setShowWicketModal(false);
                        setBatsmanModalType('wicket');
                        setShowBatsmanModal(true);
                    }}>CONTINUE</Button>
                </Modal.Footer>
            </Modal>

            <div className="d-flex justify-content-between align-items-center mb-4">
                <div className="d-flex gap-2 align-items-center">
                    <Button variant="outline-primary" className="rounded-pill shadow-sm" onClick={() => navigate('/')}>
                        Home
                    </Button>
                    <h2 className="fw-bold text-gradient m-0">Admin Panel</h2>
                </div>
                <Button variant="primary" className="shadow-sm px-4" onClick={() => { setIsCreating(true); setSelectedMatch(null); }}>+ New Match</Button>
            </div>

            <Row>
                <Col lg={4} className="mb-4">
                    <Card className="shadow-sm border-0">
                        <Card.Header className="bg-white fw-bold d-flex justify-content-between"><span>Matches</span><Badge bg="secondary">{matches.length}</Badge></Card.Header>
                        <ListGroup variant="flush" className="overflow-auto" style={{ maxHeight: '75vh' }}>
                            {matches.map(m => (
                                <ListGroup.Item key={m._id || m.id} className="d-flex justify-content-between align-items-center py-3 border-start border-4 p-0 pointer-event" style={{ borderLeftColor: m.status === 'live' ? '#ff4b2b' : '#333' }}>
                                    <div className={`flex-grow-1 p-3 ${selectedMatch?._id === m._id || selectedMatch?.id === m.id ? 'bg-primary text-white' : ''}`} style={{ cursor: 'pointer' }} onClick={() => handleEdit(m)}>
                                        <div className="fw-bold fs-6">{m.teamA.toUpperCase()} vs {m.teamB.toUpperCase()}</div>
                                        <small className={selectedMatch?._id === m._id || selectedMatch?.id === m.id ? 'text-white-50' : 'text-muted'}>{m.status.toUpperCase()} | {new Date(m.date).toLocaleDateString()}</small>
                                    </div>
                                    <Button variant="link" className="text-danger px-3" onClick={(e) => handleDelete(e, m._id || m.id)}>
                                        <span className="fs-4">×</span>
                                    </Button>
                                </ListGroup.Item>
                            ))}
                        </ListGroup>
                    </Card>
                </Col>

                <Col lg={8}>
                    {isCreating ? (
                        <Card className="shadow-lg border-0"><Card.Body className="p-4"><h4 className="mb-4 fw-bold">New Match</h4><Form onSubmit={handleCreateSubmit}><Row className="g-3"><Col md={12}><Form.Group><Form.Label className="small fw-bold">Title</Form.Label><Form.Control value={createForm.title} onChange={e => setCreateForm({ ...createForm, title: e.target.value })} /></Form.Group></Col><Col md={6}><Form.Group><Form.Label className="small fw-bold">Team A</Form.Label><Form.Control required value={createForm.teamA} onChange={e => setCreateForm({ ...createForm, teamA: e.target.value })} /></Form.Group></Col><Col md={6}><Form.Group><Form.Label className="small fw-bold">Team B</Form.Label><Form.Control required value={createForm.teamB} onChange={e => setCreateForm({ ...createForm, teamB: e.target.value })} /></Form.Group></Col><Col md={6}><Form.Group><Form.Label className="small fw-bold">Overs</Form.Label><Form.Control type="number" required value={createForm.totalOvers} onChange={e => setCreateForm({ ...createForm, totalOvers: e.target.value })} /></Form.Group></Col><Col md={6}><Form.Group><Form.Label className="small fw-bold">Venue</Form.Label><Form.Control value={createForm.venue} onChange={e => setCreateForm({ ...createForm, venue: e.target.value })} /></Form.Group></Col><Col md={6}><Form.Group><Form.Label className="small fw-bold">Date</Form.Label><Form.Control type="date" value={createForm.date} onChange={e => setCreateForm({ ...createForm, date: e.target.value })} /></Form.Group></Col><Col md={6}><Form.Group><Form.Label className="small fw-bold">Time</Form.Label><Form.Control type="time" value={createForm.time} onChange={e => setCreateForm({ ...createForm, time: e.target.value })} /></Form.Group></Col></Row><div className="mt-4 d-flex gap-2"><Button variant="outline-primary" onClick={() => setShowSquadModal(true)}>MANAGE SQUADS (11)</Button><Button variant="primary" type="submit">Create</Button><Button variant="light" onClick={() => setIsCreating(false)}>Cancel</Button></div></Form></Card.Body></Card>
                    ) : selectedMatch ? (
                        <Card className="shadow-lg border-0 overflow-hidden">
                            <Card.Header className="bg-dark text-white d-flex justify-content-between align-items-center py-3 px-4"><h5 className="m-0 fw-bold">{selectedMatch.teamA.toUpperCase()} vs {selectedMatch.teamB.toUpperCase()}</h5><Badge bg={selectedMatch.status === 'live' ? 'danger' : 'info'}>{selectedMatch.status.toUpperCase()}</Badge></Card.Header>
                            <Card.Body className="p-4">
                                <div className="text-center mb-4 bg-light rounded-4 p-4 border"><div className="display-3 fw-bold text-primary">{selectedMatch.score.runs}/{selectedMatch.score.wickets}</div><div className="lead fw-bold">{selectedMatch.score.overs} / {selectedMatch.totalOvers} Overs</div><div className="mt-3"><Badge bg="white" text="dark" className="border px-3 py-2 me-2">CRR: {crr}</Badge>{rrr && <Badge bg="info" text="white" className="px-3 py-2 me-2">RRR: {rrr}</Badge>}{selectedMatch.score.target && <Badge bg="warning" text="dark" className="px-3 py-2">TARGET: {selectedMatch.score.target}</Badge>}</div></div>
                                <div className="d-flex gap-2 mb-4 justify-content-center flex-wrap">
                                    <Button variant="outline-dark" size="lg" className="px-3 fw-bold" onClick={() => setShowSquadModal(true)}>👥 SQUADS</Button>
                                    {(selectedMatch.status === 'upcoming' || (selectedMatch.status === 'live' && !selectedMatch.toss?.winner)) && <Button variant="warning" size="lg" className="px-5 fw-bold" onClick={() => {
                                        // Allow 15 min buffer
                                        const now = new Date();
                                        const scheduled = new Date(selectedMatch.date);
                                        const bufferTime = new Date(now.getTime() + 15 * 60000);

                                        if (bufferTime < scheduled) {
                                            toast.error(`Wait! Match starts at ${scheduled.toLocaleTimeString()}`, { icon: '⏳', style: { borderRadius: '10px', background: '#333', color: '#fff' } });
                                            return;
                                        }
                                        setShowTossModal(true);
                                    }}>🪙 CONDUCT TOSS</Button>}
                                    {selectedMatch.status === 'upcoming' && selectedMatch.toss?.winner && <Button variant="success" size="lg" className="px-5 fw-bold" onClick={() => {
                                        // Allow 15 min buffer
                                        const now = new Date();
                                        const scheduled = new Date(selectedMatch.date);
                                        const bufferTime = new Date(now.getTime() + 15 * 60000);

                                        if (bufferTime < scheduled) {
                                            toast.error(`Wait! Match starts at ${scheduled.toLocaleTimeString()}`, { icon: '⏳', style: { borderRadius: '10px', background: '#333', color: '#fff' } });
                                            return;
                                        }
                                        if (!validateSquads()) return;
                                        if (squadA.filter(p => p).length < 11 || squadB.filter(p => p).length < 11) {
                                            toast.error("Both teams must have 11 players!");
                                            return;
                                        }
                                        setShowStartModal(true);
                                    }}>1st Innings Start</Button>}
                                    {selectedMatch.status === 'live' && selectedMatch.score.target && (!selectedMatch.currentBatsmen || selectedMatch.currentBatsmen.length === 0) && (
                                        <Button variant="success" size="lg" className="px-5 fw-bold" onClick={() => {
                                            setModalData({ s: '', ns: '', b: '', nextB: '', nextS: '' });
                                            setShowStartModal(true);
                                        }}>2nd Innings Start</Button>
                                    )}
                                    {selectedMatch.status === 'live' && (<>{[0, 1, 2, 3, 4, 6].map(r => (<Button key={r} disabled={isUpdating} variant="outline-primary" size="lg" className="px-3 fw-bold" onClick={() => handleUpdate('runs', r)}>{r}</Button>))}<Button variant="danger" size="lg" className="px-3 fw-bold" disabled={isUpdating} onClick={() => { setWicketDetails({ type: 'caught', fielder: '' }); setShowWicketModal(true); }}>OUT</Button>
                                        <Button variant="dark" size="lg" className="px-3 fw-bold ms-2" disabled={isUpdating || !selectedMatch.history || selectedMatch.history.length === 0} onClick={undoLastBall}>UNDO</Button>
                                        <Button variant="warning" size="lg" className="px-3 fw-bold" onClick={() => setShowRunOutModal(true)}>RUN OUT</Button>
                                        <Button variant="outline-success" size="lg" className="px-3 fw-bold" onClick={() => setShowBowlerModal(true)}>⚾ CHANGE BOWLER</Button>
                                        <Button variant="info" size="lg" className="px-3 fw-bold text-white" onClick={() => { setBatsmanModalType('retired'); setShowBatsmanModal(true); }}>RETIRE</Button><Button variant="warning" size="lg" className="px-2 fw-bold" onClick={() => handleUpdate('extra', 'w')}>WD</Button><Button variant="warning" size="lg" className="px-2 fw-bold" onClick={() => handleUpdate('extra', 'nb')}>NB</Button></>)}
                                    {selectedMatch.status === 'completed' && (
                                        <div className="text-center w-100 mb-3">
                                            <Alert variant="success" className="py-3 shadow-sm border-0 rounded-4">
                                                <h4 className="fw-black mb-1">{calculateWinner(selectedMatch)?.toUpperCase()}</h4>
                                                {selectedMatch.manOfTheMatch && <div className="fw-bold text-success">🏆 MAN OF THE MATCH: {selectedMatch.manOfTheMatch}</div>}
                                            </Alert>
                                            <div className="d-flex gap-2 justify-content-center">
                                                <Button variant="outline-primary" size="lg" className="px-4 fw-bold" onClick={handleDownloadPDF}>📥 DOWNLOAD PDF</Button>
                                                <Button variant="danger" size="lg" className="px-4 fw-bold" onClick={(e) => handleDelete(e, selectedMatch._id || selectedMatch.id)}>DELETE MATCH</Button>
                                            </div>
                                        </div>
                                    )}
                                </div>
                                {selectedMatch.status === 'live' && (
                                    <Row className="g-3 mb-4">
                                        <Col md={6}>
                                            <Card className="border-0 bg-info bg-opacity-10 shadow-sm">
                                                <Card.Body className="py-3 px-4">
                                                    <div className="d-flex justify-content-between align-items-center mb-2">
                                                        <small className="text-info fw-bold text-uppercase d-block mb-1">Batting</small>
                                                        <Button variant="link" size="sm" className="text-info p-0 text-decoration-none fw-bold" onClick={() => handleUpdate('swap_strike')}>
                                                            ⇄ SWAP STRIKE
                                                        </Button>
                                                    </div>
                                                    <div className="d-flex justify-content-between">
                                                        <div>
                                                            <div className="fw-bold fs-5">🏏 {striker || '...'}*</div>
                                                            <div className="text-secondary small">{nonStriker || '...'}</div>
                                                        </div>
                                                        <div className="text-end">
                                                            {selectedMatch.currentBatsmen?.map(b => (
                                                                <div key={b.name} className={`small fw-bold ${b.onStrike ? 'text-primary' : 'text-muted'}`}>
                                                                    {b.runs}({b.balls})
                                                                </div>
                                                            ))}
                                                        </div>
                                                    </div>
                                                </Card.Body>
                                            </Card>
                                        </Col>
                                        <Col md={6}>
                                            <Card className="border-0 bg-success bg-opacity-10 shadow-sm">
                                                <Card.Body className="py-3 px-4">
                                                    <small className="text-success fw-bold text-uppercase d-block mb-1">Bowling</small>
                                                    <div className="d-flex justify-content-between align-items-center">
                                                        <div className="fw-bold fs-5">⚾ {bowler || '...'}</div>
                                                        <div className="text-end text-success fw-bold">
                                                            {scorecardData.find(inn => inn.team !== selectedMatch.score.battingTeam)?.bowling.find(p => p.player === bowler) ? (b => `${b.overs} ov | ${b.runs} r | ${b.wickets} w`)(scorecardData.find(inn => inn.team !== selectedMatch.score.battingTeam).bowling.find(p => p.player === bowler)) : '0 ov'}
                                                        </div>
                                                    </div>
                                                </Card.Body>
                                            </Card>
                                        </Col>
                                    </Row>
                                )}
                                {selectedMatch.toss?.winner && (
                                    <Alert variant="warning" className="text-center fw-bold">
                                        🪙 Toss won by {selectedMatch.toss.winner} and elected to {selectedMatch.toss.decision} first.
                                    </Alert>
                                )}
                                <details>
                                    <summary className="btn btn-sm btn-link text-decoration-none fw-bold p-0 text-muted">🔧 Correction Panel (Manual Overrides)</summary>
                                    <Card className="mt-2 border-0 bg-light p-3">
                                        <Row className="g-3">
                                            <Col md={4}><Form.Label className="small fw-bold">Runs</Form.Label><Form.Control size="sm" type="number" min="0" disabled={selectedMatch.status === 'completed'} value={selectedMatch.score.runs} onChange={e => handleUpdate('manual', { ...selectedMatch, score: { ...selectedMatch.score, runs: Math.max(0, parseInt(e.target.value) || 0) } })} /></Col>
                                            <Col md={4}><Form.Label className="small fw-bold">Wickets</Form.Label><Form.Control size="sm" type="number" min="0" max="10" disabled={selectedMatch.status === 'completed'} value={selectedMatch.score.wickets} onChange={e => handleUpdate('manual', { ...selectedMatch, score: { ...selectedMatch.score, wickets: Math.min(10, Math.max(0, parseInt(e.target.value) || 0)) } })} /></Col>
                                            <Col md={4}><Form.Label className="small fw-bold">Overs</Form.Label><Form.Control size="sm" type="number" step="0.1" min="0" max={selectedMatch.totalOvers} disabled={selectedMatch.status === 'completed'} value={selectedMatch.score.overs} onChange={e => handleUpdate('manual', { ...selectedMatch, score: { ...selectedMatch.score, overs: Math.min(selectedMatch.totalOvers, Math.max(0, parseFloat(e.target.value) || 0)) } })} /></Col>

                                            <Col md={4}>
                                                <Form.Label className="small fw-bold">Striker</Form.Label>
                                                <Form.Select size="sm" disabled={selectedMatch.status === 'completed'} value={striker} onChange={e => { setStriker(e.target.value); handleUpdate('manual', { ...selectedMatch, currentBatsmen: selectedMatch.currentBatsmen.map((b, i) => i === 0 ? { ...b, name: e.target.value } : b) }); }}>
                                                    <option value="">Select</option>
                                                    {(selectedMatch.score.battingTeam === selectedMatch.teamA ? squadA : squadB).map(p => <option key={p} value={p}>{p}</option>)}
                                                </Form.Select>
                                            </Col>
                                            <Col md={4}>
                                                <Form.Label className="small fw-bold">Non-Striker</Form.Label>
                                                <Form.Select size="sm" disabled={selectedMatch.status === 'completed'} value={nonStriker} onChange={e => { setNonStriker(e.target.value); handleUpdate('manual', { ...selectedMatch, currentBatsmen: selectedMatch.currentBatsmen.map((b, i) => i === 1 ? { ...b, name: e.target.value } : b) }); }}>
                                                    <option value="">Select</option>
                                                    {(selectedMatch.score.battingTeam === selectedMatch.teamA ? squadA : squadB).map(p => <option key={p} value={p}>{p}</option>)}
                                                </Form.Select>
                                            </Col>
                                            <Col md={4}>
                                                <Form.Label className="small fw-bold">Bowler</Form.Label>
                                                <Form.Select size="sm" value={bowler} onChange={e => { setBowler(e.target.value); handleUpdate('manual', { ...selectedMatch, currentBowler: e.target.value }); }}>
                                                    <option value="">Select</option>
                                                    {(selectedMatch.score.battingTeam === selectedMatch.teamA ? squadB : squadA).map(p => <option key={p} value={p}>{p}</option>)}
                                                </Form.Select>
                                            </Col>

                                            <Col md={6}>
                                                <Form.Label className="small fw-bold">Batting Team</Form.Label>
                                                <Form.Select size="sm" value={selectedMatch.score.battingTeam} onChange={e => {
                                                    const nextTeam = e.target.value;
                                                    if (nextTeam !== selectedMatch.score.battingTeam) {
                                                        setStriker(''); setNonStriker(''); setBowler('');
                                                        handleUpdate('manual', {
                                                            ...selectedMatch,
                                                            score: { ...selectedMatch.score, battingTeam: nextTeam },
                                                            currentBatsmen: [],
                                                            currentBowler: null
                                                        });
                                                    }
                                                }}>
                                                    <option value={selectedMatch.teamA}>{selectedMatch.teamA}</option>
                                                    <option value={selectedMatch.teamB}>{selectedMatch.teamB}</option>
                                                </Form.Select>
                                            </Col>
                                            <Col md={6}><Form.Label className="small fw-bold">Status</Form.Label><Form.Select size="sm" value={selectedMatch.status} onChange={e => handleUpdate('manual', { ...selectedMatch, status: e.target.value })}><option value="upcoming">Upcoming</option><option value="live">Live</option><option value="completed">Completed</option></Form.Select></Col>
                                        </Row>
                                    </Card>
                                </details>
                            </Card.Body>
                        </Card>
                    ) : (<div className="text-center py-5 bg-white rounded-4 shadow-sm d-flex flex-column align-items-center border"><Spinner animation="grow" variant="primary" className="mb-4" /><h4>Ready to Score?</h4><p className="text-muted">Select a match to start updates.</p></div>)}
                </Col>
            </Row>
            <style>{`.fw-black { font-weight: 900; } .text-gradient { background: linear-gradient(45deg, #1e3c72, #2a5298); -webkit-background-clip: text; -webkit-text-fill-color: transparent; }`}</style>
        </Container>
    );
};

export default AdminDashboard;
