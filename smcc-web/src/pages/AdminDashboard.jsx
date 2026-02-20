import React, { useEffect, useState, useRef } from 'react';
import axios from 'axios';
import { useNavigate } from 'react-router-dom';
import { Container, Row, Col, Card, Button, Form, Table, Badge, ListGroup, Modal, Spinner, Alert } from 'react-bootstrap';
import { Toaster, toast } from 'react-hot-toast';
import { io } from 'socket.io-client';
import { motion, AnimatePresence } from 'framer-motion';
import { jsPDF } from 'jspdf';
import { toCamelCase, formatTime } from '../utils/formatters';
import 'jspdf-autotable';
import API_URL from '../utils/api';
import { useApp } from '../AppContext';


const socket = io(API_URL);

const AdminDashboard = () => {
    const [matches, setMatches] = useState([]);
    const [selectedMatch, setSelectedMatch] = useState(null);
    const matchRef = useRef(null);

    useEffect(() => {
        matchRef.current = selectedMatch;
    }, [selectedMatch]);
    const [isCreating, setIsCreating] = useState(false);
    const navigate = useNavigate();
    const { t } = useApp();


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
        crossed: false,
        whomOut: 'striker',
        ballType: 'normal'
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

    const [showSuperOverModal, setShowSuperOverModal] = useState(false);
    const [superOverBattingTeam, setSuperOverBattingTeam] = useState('');


    const handleSquadChange = (team, index, value) => {
        const val = toCamelCase(value);
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
            toast.error("Both teams must have exactly 11 players!");
            return false;
        }

        const nameRegex = /^[A-Za-z]+( [A-Za-z]+)?$/;

        // Validate Team A
        const seenA = new Set();
        for (let i = 0; i < squadA.length; i++) {
            const name = squadA[i].trim();
            if (!nameRegex.test(name)) {
                toast.error(`Team A Spot ${i + 1}: Invalid name. Use letters and only one space.`);
                return false;
            }
            if (seenA.has(name)) {
                toast.error(`Team A Spot ${i + 1}: Duplicate player '${name}' found!`);
                return false;
            }
            seenA.add(name);
        }

        // Validate Team B
        const seenB = new Set();
        for (let i = 0; i < squadB.length; i++) {
            const name = squadB[i].trim();
            if (!nameRegex.test(name)) {
                toast.error(`Team B Spot ${i + 1}: Invalid name. Use letters and only one space.`);
                return false;
            }
            if (seenB.has(name)) {
                toast.error(`Team B Spot ${i + 1}: Duplicate player '${name}' found!`);
                return false;
            }
            seenB.add(name);
        }

        // Check for cross-team duplicates
        const overlap = [...seenA].filter(p => seenB.has(p));
        if (overlap.length > 0) {
            toast.error(`Player '${overlap[0]}' cannot play for both teams!`);
            return false;
        }

        return true;
    };

    const calculateWinner = (matchData, force = false) => {
        if (!matchData || (matchData.status !== 'completed' && !force)) return null;
        const innings = matchData.innings || [];
        if (innings.length < 2) return "Match Completed";

        // Logic: Winner is determined by the LAST pair of innings if tied previously
        // or by the main match if not tied.

        let inn1, inn2;
        if (innings.length >= 4) {
            // Super Over happened
            // Find the last pair of Super Over innings
            const lastIdx = innings.length - 1;
            inn2 = innings[lastIdx];
            inn1 = innings[lastIdx - 1];
        } else {
            inn1 = innings[0];
            inn2 = innings[1];
        }

        if (inn1.runs > inn2.runs) {
            const diff = inn1.runs - inn2.runs;
            if (innings.length > 2) return `${inn1.team} won (Super Over)`;
            return `${inn1.team} won by ${diff} ${diff === 1 ? 'run' : 'runs'}`;
        } else if (inn2.runs > inn1.runs) {
            const wicketsRemaining = (innings.length > 2 ? 2 : 10) - inn2.wickets;
            if (innings.length > 2) return `${inn2.team} won (Super Over)`;
            return `${inn2.team} won by ${wicketsRemaining} ${wicketsRemaining === 1 ? 'wicket' : 'wickets'}`;
        } else if (inn2.runs === inn1.runs && inn1.runs > 0) {
            return "Match Tied";
        }
        return "Match Completed";
    };

    const getAvailableBatsmen = (teamType = 'batting') => {
        if (!selectedMatch) return [];
        const isTeamA = selectedMatch.score.battingTeam === selectedMatch.teamA;
        const targetTeam = teamType === 'batting' ? (isTeamA ? 'A' : 'B') : (isTeamA ? 'B' : 'A');
        const squad = targetTeam === 'A' ? squadA : squadB;

        if (teamType === 'bowling') return squad.filter(p => p.trim() !== '');

        // Determine correct innings index
        const reversed = [...selectedMatch.innings].map((inn, i) => ({ ...inn, idx: i })).reverse();
        const bInn = reversed.find(inn => inn.team === selectedMatch.score.battingTeam);
        const currentInn = bInn ? selectedMatch.innings[bInn.idx] : null;
        if (!currentInn) return squad.filter(p => p.trim() !== '');

        return squad.filter(p => {
            if (p.trim() === '') return false;
            if (p === striker || p === nonStriker) return false;
            const playerStats = currentInn.batting.find(b => b.player === p);
            if (playerStats) {
                // Allow 'retired hurt' players to return, but filter out those who are out or tactical retires
                if (playerStats.status === 'retired hurt') return true;
                return false;
            }
            return true;
        });
    };

    const handleDownloadPDF = () => {
        if (!selectedMatch) return;
        if (!['completed', 'abandoned', 'cancelled'].includes(selectedMatch.status)) {
            toast.error("PDF Scorecard is only available after match completion!");
            return;
        }
        const doc = new jsPDF();
        const pageWidth = doc.internal.pageSize.getWidth();

        // Header
        doc.setFontSize(22);
        doc.setTextColor(30, 60, 114);
        doc.setFont(undefined, 'bold');
        doc.text("SMCC CRICKET SCORECARD", pageWidth / 2, 20, { align: 'center' });
        doc.setFont(undefined, 'normal');

        doc.setFontSize(14);
        doc.setTextColor(100);
        doc.setFont(undefined, 'bold');
        doc.text(`${selectedMatch.teamA} VS ${selectedMatch.teamB}`, pageWidth / 2, 30, { align: 'center' });
        doc.setFont(undefined, 'normal');

        doc.setFontSize(10);
        doc.text(`SERIES: ${(selectedMatch.title || 'SMCC LIVE').toUpperCase()}`, pageWidth / 2, 38, { align: 'center' });
        doc.text(`VENUE: ${(selectedMatch.venue || 'TBD').toUpperCase()}`, pageWidth / 2, 44, { align: 'center' });
        doc.text(`DATE & TIME: ${new Date(selectedMatch.date).toLocaleDateString().toUpperCase()} ${formatTime(selectedMatch.date).toUpperCase()}`, pageWidth / 2, 50, { align: 'center' });
        doc.text(`EXPORTED ON: ${new Date().toLocaleString().toUpperCase()}`, pageWidth / 2, 56, { align: 'center' });

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
            if (idx >= 2 && inn.runs === 0 && inn.wickets === 0 && (!inn.batting || inn.batting.length === 0)) {
                return;
            }

            if (idx === 2) {
                doc.addPage();
                currentY = 20;
            } else if (idx !== 2 && currentY > 260) {
                doc.addPage();
                currentY = 20;
            }

            const bowlingInnIdx = idx % 2 === 0 ? idx + 1 : idx - 1;
            const bowlingInn = selectedMatch.innings[bowlingInnIdx];

            doc.setFontSize(14);
            doc.setTextColor(30, 60, 114);
            doc.setFont(undefined, 'bold');
            const getOrdinal = (n) => { const s = ["th", "st", "nd", "rd"]; const v = n % 100; return n + (s[(v - 20) % 10] || s[v] || s[0]); };
            const titleStr = `${inn.team} ${getOrdinal(idx + 1).toUpperCase()} INNINGS${idx >= 2 ? ' (SUPER OVER)' : ''}`;
            doc.text(`${titleStr.toUpperCase()}: ${inn.runs}/${inn.wickets} (${inn.overs} OV)`, 14, currentY);
            doc.setFont(undefined, 'normal');
            currentY += 8;

            // Batting Table
            const battingData = (inn.batting || []).map(b => [b.player.toUpperCase(), b.status.toUpperCase(), b.runs, b.balls, b.fours, b.sixes, b.strikeRate]);
            if (battingData.length > 0) {
                doc.autoTable({
                    startY: currentY,
                    head: [['Batter', 'Status', 'R', 'B', '4s', '6s', 'SR']],
                    body: battingData,
                    theme: 'striped',
                    headStyles: { fillColor: [30, 60, 114] }
                });
                currentY = doc.lastAutoTable.finalY + 10;
            }

            // Bowling Table
            if (bowlingInn && bowlingInn.bowling && bowlingInn.bowling.length > 0) {
                doc.autoTable({
                    startY: currentY,
                    head: [['Bowler', 'O', 'M', 'R', 'W', 'Eco']],
                    body: bowlingInn.bowling.map(b => [b.player.toUpperCase(), b.overs, b.maidens, b.runs, b.wickets, b.economy]),
                    theme: 'grid',
                    headStyles: { fillColor: [0, 146, 112] }
                });
                currentY = doc.lastAutoTable.finalY + 5;
            }

            // Extras
            const ex = inn.extras || { total: 0, wides: 0, noBalls: 0, byes: 0, legByes: 0 };
            doc.setFontSize(10);
            doc.setTextColor(50);
            doc.setFont(undefined, 'bold');
            doc.text(`EXTRAS: `, 14, currentY + 3);
            doc.setFont(undefined, 'normal');
            doc.text(`${ex.total} (W ${ex.wides}, NB ${ex.noBalls}, B ${ex.byes}, LB ${ex.legByes})`, 33, currentY + 3);
            currentY += 13;

            if (inn.fallOfWickets && inn.fallOfWickets.length > 0) {
                doc.setFontSize(10);
                doc.setTextColor(150, 0, 0);
                doc.setFont(undefined, 'bold');
                doc.text("FALL OF WICKETS", 14, currentY);
                doc.setFont(undefined, 'normal');
                currentY += 4;
                doc.autoTable({
                    startY: currentY,
                    head: [['Wkt', 'Score', 'Over', 'Player']],
                    body: inn.fallOfWickets.map(f => [f.wicket, f.runs, f.overs, f.player.toUpperCase()]),
                    theme: 'plain',
                    styles: { fontSize: 9 }
                });
                currentY = doc.lastAutoTable.finalY + 10;
            }

            // Did Not Bat
            const squad = inn.team === selectedMatch.teamA ? squadA : squadB;
            if (squad && squad.length > 0) {
                const battedPlayers = (inn.batting || []).map(b => b.player);
                const yetToBat = squad.filter(p => p && p.trim() !== '' && !battedPlayers.includes(p));
                if (yetToBat.length > 0) {
                    doc.setFontSize(9);
                    doc.setTextColor(100);
                    doc.setFont(undefined, 'bold');
                    doc.text(`DID NOT BAT: `, 14, currentY + 2);
                    doc.setFont(undefined, 'normal');
                    const textLines = doc.splitTextToSize(`${yetToBat.map(p => p.toUpperCase()).join(', ')}`, 150);
                    doc.text(textLines, 38, currentY + 2);
                    currentY += 10 + (textLines.length * 4);
                }
            }

            // Team Summary info
            doc.setFontSize(10);
            doc.setTextColor(0);
            doc.setFont(undefined, 'bold');
            doc.text(`TOTAL: ${inn.runs}/${inn.wickets} in ${inn.overs} Overs | Boundaries: 4s: ${inn.fours || 0}, 6s: ${inn.sixes || 0}`, 14, currentY);
            doc.setFont(undefined, 'normal');
            currentY += 15;
        });

        if (selectedMatch.status === 'completed') {
            const winnerString = calculateWinner(selectedMatch);
            if (winnerString) {
                doc.addPage();
                doc.setFontSize(16);
                doc.setTextColor(0, 146, 112);
                doc.setFont(undefined, 'bold');
                doc.text("MATCH RESULT", 105, 100, { align: 'center' });
                doc.setFontSize(22);
                doc.text(winnerString.toUpperCase(), 105, 120, { align: 'center' });

                if (selectedMatch.manOfTheMatch) {
                    doc.setFontSize(14);
                    doc.setTextColor(100);
                    doc.text(`MAN OF THE MATCH: ${selectedMatch.manOfTheMatch.toUpperCase()}`, 105, 140, { align: 'center' });
                }
            }
        }

        doc.save(`${selectedMatch.teamA}_vs_${selectedMatch.teamB}_Scorecard.pdf`);
    };

    const undoLastBall = async () => {
        if (!selectedMatch || !selectedMatch.history || selectedMatch.history.length === 0) {
            toast.error("Nothing to undo!");
            return;
        }

        // Using toast for confirmation to avoid window.confirm
        const proceed = true; // For now assuming true or we'd need a custom UI. 
        // Logic: if user clicked undo, they intend to undo.
        // If the user really wants a modal, I'll keep it but make it a React Modal later if they insist.
        // For now, replacing window.confirm with a simple immediate action or a toast-confirm if available.
        // Let's use a simple confirm but wrapped to be less 'system' looking if possible? 
        // No, I'll just remove the window.confirm as requested "no more local messages".
        const previousState = selectedMatch.history[selectedMatch.history.length - 1];

        // Optimistic UI Update
        setSelectedMatch(previousState);
        setScorecardData(previousState.innings);
        syncLocalPlayers(previousState);

        try {
            const { id, _id, lastUpdated, ...payload } = previousState;
            await axios.put(`${API_URL}/api/matches/${previousState._id || previousState.id}`, payload, config);
            toast.success("Undo successful!");
        } catch (err) {
            if (err.response?.status === 401) {
                localStorage.removeItem('token');
                navigate('/login');
                toast.error("Session expired");
            } else {
                toast.error("Undo failed on server");
            }
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
            setMatches(Array.isArray(res.data) ? res.data : []);
        } catch (err) {
            console.error(err);
            toast.error("Failed to load matches");
            setMatches([]);
        }
    };

    useEffect(() => {
        document.title = 'SMCC | Admin Dashboard';
        if (!activeToken) navigate('/login');
        fetchMatches();

        socket.on('matchUpdate', (updatedMatch) => {
            setMatches(prevMatches => {
                const matchesArr = Array.isArray(prevMatches) ? prevMatches : [];
                const index = matchesArr.findIndex(m => m._id === updatedMatch._id || m.id === updatedMatch.id);
                if (index !== -1) {
                    const newMatches = [...matchesArr];
                    newMatches[index] = updatedMatch;
                    return newMatches;
                }
                return [updatedMatch, ...matchesArr];
            });

            const currentSelected = matchRef.current;
            if (currentSelected && (currentSelected._id === updatedMatch._id || currentSelected.id === updatedMatch.id)) {
                syncLocalPlayers(updatedMatch);
                setSelectedMatch(updatedMatch);
                setScorecardData(updatedMatch.innings);
            }
        });

        socket.on('matchDeleted', (matchId) => {
            setMatches(prev => (Array.isArray(prev) ? prev : []).filter(m => m._id !== matchId && m.id !== matchId));
            const currentSelected = matchRef.current;
            if (currentSelected?._id === matchId || currentSelected?.id === matchId) setSelectedMatch(null);
        });

        return () => {
            socket.off('matchUpdate');
            socket.off('matchDeleted');
        };
    }, [navigate, activeToken]); // Removed selectedMatch to prevent listener re-registration loop

    const syncLocalPlayers = (match) => {
        if (match.currentBatsmen && match.currentBatsmen.length >= 1) {
            const s = match.currentBatsmen.find(b => b.onStrike)?.name || '';
            const ns = match.currentBatsmen.find(b => !b.onStrike)?.name || '';
            setStriker(s);
            setNonStriker(ns);
        } else {
            setStriker('');
            setNonStriker('');
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
        // Deep copy ONCE for both update and history
        let updatedMatch = JSON.parse(JSON.stringify(selectedMatch));

        // Define locals at the top level so they are accessible everywhere
        let localStriker = striker;
        let localNonStriker = nonStriker;
        let localBowler = bowler;

        // --- History Logging (Optimized to use ONE clone) ---
        if (['runs', 'extra', 'wicket', 'swap_strike'].includes(type) && type !== 'init') {
            if (!updatedMatch.history) updatedMatch.history = [];
            // Create snapshot from the ALREADY cloned updatedMatch (before modification)
            const { history, ...snapshot } = updatedMatch;
            updatedMatch.history.push(snapshot);
            if (updatedMatch.history.length > 20) updatedMatch.history.shift();
        }

        if (type === 'manual') {
            updatedMatch = value;
            // Sync locals from the new manual state to ensure UI dropdowns match
            localStriker = updatedMatch.currentBatsmen?.find(b => b.onStrike)?.name || '';
            localNonStriker = updatedMatch.currentBatsmen?.find(b => !b.onStrike)?.name || '';
            localBowler = updatedMatch.currentBowler || '';
        } else {
            // Safety: Ensure innings structure exists and has 2 teams
            if (!updatedMatch.innings || updatedMatch.innings.length < 2) {
                const template = [
                    { team: updatedMatch.teamA, runs: 0, wickets: 0, overs: 0, batting: [], bowling: [], extras: { total: 0, wides: 0, noBalls: 0, byes: 0, legByes: 0 } },
                    { team: updatedMatch.teamB, runs: 0, wickets: 0, overs: 0, batting: [], bowling: [], extras: { total: 0, wides: 0, noBalls: 0, byes: 0, legByes: 0 } }
                ];
                updatedMatch.innings = template;
                setScorecardData(template); // Fix local state too
            }

            let battingTeam = updatedMatch.score.battingTeam?.trim() || updatedMatch.teamA?.trim();
            if (type === 'init' && value.team) {
                battingTeam = value.team.trim();
                updatedMatch.score.battingTeam = battingTeam;
            }
            if (!updatedMatch.score.thisOver) updatedMatch.score.thisOver = [];

            let battingTeamIdx;
            if (updatedMatch.innings.length > 2) {
                // Super Over Pair logic
                const pairStart = updatedMatch.innings.length - 2;
                battingTeamIdx = updatedMatch.score.target ? pairStart + 1 : pairStart;
            } else {
                // Main Match: Index 0 is 1st innings, Index 1 is 2nd innings.
                // We are in the 2nd innings if and only if a target has been set.
                battingTeamIdx = updatedMatch.score.target ? 1 : 0;

                // Initialization safety: If we are at index 0 and it's not started, assign teams.
                if (battingTeamIdx === 0) {
                    const inn0 = updatedMatch.innings[0];
                    if (inn0 && (inn0.runs === 0 && inn0.wickets === 0 && (!inn0.batting || inn0.batting.length === 0))) {
                        inn0.team = battingTeam;
                        if (updatedMatch.innings[1]) {
                            updatedMatch.innings[1].team = (battingTeam === updatedMatch.teamA ? updatedMatch.teamB : updatedMatch.teamA);
                        }
                    }
                }
            }

            let bowlingTeamIdx;
            if (updatedMatch.innings.length > 2) {
                const pairStart = updatedMatch.innings.length - 2;
                bowlingTeamIdx = (battingTeamIdx === pairStart) ? pairStart + 1 : pairStart;
            } else {
                bowlingTeamIdx = battingTeamIdx === 0 ? 1 : 0;
            }

            // Ensure the target innings exist in the array
            if (updatedMatch.innings.length > 2) {
                const last = updatedMatch.innings[updatedMatch.innings.length - 1];
                if (last.runs === 0 && last.wickets === 0 && (!last.balls || last.balls === 0) && (!last.batting || last.batting.length === 0)) {
                    updatedMatch.innings.pop();
                }
            }

            // Ensure the target innings exist in the array
            while (updatedMatch.innings.length <= Math.max(battingTeamIdx, bowlingTeamIdx)) {
                let teamName;
                const idx = updatedMatch.innings.length;
                if (idx < 2) {
                    // This block handles initialization if template was missing
                    teamName = idx === 0 ? battingTeam : (battingTeam === updatedMatch.teamA ? updatedMatch.teamB : updatedMatch.teamA);
                } else {
                    // Super Over Logic: Keep original batting order from main match
                    // Innings 0 team bats first in SO? Or original team 1st?
                    // Usually in SO, the team that batted 2nd in main match bats 1st?
                    // User said: "who bat 1st we known right this flow 1st batted team 1st innings"
                    // And Super Over usually follows the original batting order in some contexts.
                    const team1 = updatedMatch.innings[0]?.team || updatedMatch.teamA;
                    const team2 = updatedMatch.innings[1]?.team || updatedMatch.teamB;
                    teamName = idx % 2 === 0 ? team1 : team2;
                }

                updatedMatch.innings.push({
                    team: teamName,
                    runs: 0, wickets: 0, overs: 0, batting: [], bowling: [],
                    extras: { total: 0, wides: 0, noBalls: 0, byes: 0, legByes: 0 }
                });
            }

            // Sync batting team pointer
            if (updatedMatch.innings[battingTeamIdx]) {
                const currentInn = updatedMatch.innings[battingTeamIdx];
                updatedMatch.score.battingTeam = currentInn.team;

                // If initializing on an existing empty innings, ensure it's clean and correct
                if (type === 'init' && currentInn.runs === 0 && currentInn.wickets === 0 && currentInn.balls === 0) {
                    currentInn.batting = [];
                    currentInn.bowling = [];

                    // Enforce correct team name if it was wrong (e.g. from previous buggy creation)
                    if (battingTeamIdx >= 2) {
                        const chaser = updatedMatch.innings[1]?.team || updatedMatch.teamB;
                        const defender = updatedMatch.innings[0]?.team || updatedMatch.teamA;
                        currentInn.team = battingTeamIdx % 2 === 0 ? chaser : defender;
                        updatedMatch.score.battingTeam = currentInn.team;
                    }
                }
            }

            let currentInnings = updatedMatch.innings[battingTeamIdx];
            let currentBowling = updatedMatch.innings[bowlingTeamIdx];

            if (type === 'init') {
                const { s, ns, b } = value;
                localStriker = s;
                localNonStriker = ns;
                localBowler = b;

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
                localStriker = striker || updatedMatch.currentBatsmen?.find(b => b.onStrike)?.name || '';
                localNonStriker = nonStriker || updatedMatch.currentBatsmen?.find(b => !b.onStrike)?.name || '';
                localBowler = bowler || updatedMatch.currentBowler || '';

                let sIdx = currentInnings.batting.findIndex(p => p.player === localStriker);

                // Auto-fix: If player exists in currentBatsmen but not in innings list
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
                    console.error("Missing State:", { localStriker, localBowler, sIdx, bIdx });
                    toast.error("Batsman or Bowler missing! Please check Match Info.");
                    return;
                }

                let ballCounts = true;

                if (type === 'runs') {
                    updatedMatch.score.thisOver.push(value);
                    currentInnings.batting[sIdx].runs += value;
                    currentInnings.batting[sIdx].balls += 1;
                    if (value === 4) currentInnings.batting[sIdx].fours += 1;
                    if (value === 6) currentInnings.batting[sIdx].sixes += 1;

                    // Team breakdown
                    if (value === 0) {
                        currentInnings.dots = (currentInnings.dots || 0) + 1;
                        currentBowling.bowling[bIdx].dots = (currentBowling.bowling[bIdx].dots || 0) + 1;
                    }
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
                    if (value === 'w') {
                        updatedMatch.score.thisOver.push('wd');
                        currentInnings.extras.wides += amount;
                        currentBowling.bowling[bIdx].runs += amount;
                        currentBowling.bowling[bIdx].wides = (currentBowling.bowling[bIdx].wides || 0) + amount;
                        ballCounts = false;
                    }
                    else if (value === 'nb') {
                        updatedMatch.score.thisOver.push('nb');
                        currentInnings.extras.noBalls += amount;
                        currentBowling.bowling[bIdx].runs += amount;
                        currentBowling.bowling[bIdx].noBalls = (currentBowling.bowling[bIdx].noBalls || 0) + amount;
                        ballCounts = false;
                    }
                    else if (value === 'b') {
                        updatedMatch.score.thisOver.push(0);
                        currentInnings.extras.byes = (currentInnings.extras.byes || 0) + amount;
                    }
                    else if (value === 'lb') {
                        updatedMatch.score.thisOver.push(0);
                        currentInnings.extras.legByes = (currentInnings.extras.legByes || 0) + amount;
                    }
                    currentInnings.extras.total += amount;
                } else if (type === 'run_out_striker' || type === 'run_out_nonstriker') {
                    const isStrikerOut = type === 'run_out_striker';
                    const outPlayer = isStrikerOut ? localStriker : localNonStriker;
                    const pIdx = currentInnings.batting.findIndex(p => p.player === outPlayer);

                    if (pIdx !== -1) {
                        currentInnings.wickets += 1;
                        currentInnings.batting[pIdx].status = 'run out';
                        currentInnings.batting[sIdx].balls += 1; // Ball still counts

                        setRunOutOutType(isStrikerOut ? 'striker' : 'non-striker');
                        setBatsmanModalType('wicket');
                        setShowBatsmanModal(true);
                        return;
                    }
                } else if (type === 'wicket') {
                    const wDetail = params.wicketDetails || { type: 'caught', whomOut: 'striker' };
                    const isStrikerOut = wDetail.type === 'run out' ? wDetail.whomOut === 'striker' : true;
                    setRunOutOutType(isStrikerOut ? 'striker' : 'non-striker');

                    // Simple logic: we just need to know whom is out to show the correct replacement modal
                    // The actual state update will happen in 'wicket_with_replacement'
                    setBatsmanModalType('wicket');
                    setShowBatsmanModal(true);
                    return;
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

                            const wDetail = params.wicketDetails || { type: 'bowled', ballType: 'normal' };
                            let outStatus = '';
                            if (wDetail.type === 'caught') outStatus = `c ${wDetail.fielder} b ${localBowler}`;
                            else if (wDetail.type === 'bowled') outStatus = `b ${localBowler}`;
                            else if (wDetail.type === 'lbw') outStatus = `lbw b ${localBowler}`;
                            else if (wDetail.type === 'stumped') outStatus = `st ${wDetail.fielder} b ${localBowler}`;
                            else if (wDetail.type === 'run out') outStatus = `run out (${wDetail.fielder})`;
                            else if (wDetail.type === 'hit wicket') outStatus = `hit wicket b ${localBowler}`;
                            else outStatus = 'out';

                            currentInnings.batting[outIdx].status = outStatus;

                            // History Log
                            updatedMatch.score.thisOver.push('W');
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

                            const isMankad = wDetail.type === 'run out' && wDetail.ballType === 'mankad';
                            const isExtraBall = wDetail.type === 'run out' && (wDetail.ballType === 'wide' || wDetail.ballType === 'no-ball');

                            if (wDetail.type === 'run out') {
                                const completedRuns = parseInt(wDetail.runs || 0);
                                currentInnings.runs += completedRuns;
                                currentBowling.bowling[bIdx].runs += completedRuns;
                                currentInnings.batting[sIdx].runs += completedRuns;

                                if (wDetail.ballType === 'wide') {
                                    currentInnings.runs += 1;
                                    currentInnings.extras.wides += 1;
                                    currentInnings.extras.total += 1;
                                    currentBowling.bowling[bIdx].runs += 1;
                                    ballCounts = false;
                                } else if (wDetail.ballType === 'no-ball') {
                                    currentInnings.runs += 1;
                                    currentInnings.extras.noBalls += 1;
                                    currentInnings.extras.total += 1;
                                    currentBowling.bowling[bIdx].runs += 1;
                                    ballCounts = false;
                                } else if (wDetail.ballType === 'mankad') {
                                    ballCounts = false;
                                }

                                if (!isMankad) {
                                    currentInnings.batting[sIdx].balls += 1;
                                }

                                // Team breakdown for run out runs
                                if (completedRuns === 1) currentInnings.ones = (currentInnings.ones || 0) + 1;
                                else if (completedRuns === 2) currentInnings.twos = (currentInnings.twos || 0) + 1;
                                else if (completedRuns === 3) currentInnings.threes = (currentInnings.threes || 0) + 1;
                                else if (completedRuns === 0) currentInnings.dots = (currentInnings.dots || 0) + 1;

                                if (wDetail.crossed) {
                                    const temp = localStriker; localStriker = localNonStriker; localNonStriker = temp;
                                }
                            } else {
                                // Regular wickets (caught, bowled, lbw, stumped, hit wicket)
                                // Stumped on a wide?
                                if (wDetail.type === 'stumped' && wDetail.ballType === 'wide') {
                                    currentInnings.runs += 1;
                                    currentInnings.extras.wides += 1;
                                    currentInnings.extras.total += 1;
                                    currentBowling.bowling[bIdx].runs += 1;
                                    ballCounts = false;
                                } else {
                                    currentInnings.batting[sIdx].balls += 1;
                                }
                            }

                            // If it's a valid ball that counts for the over, increment here 
                            // because wicket_with_replacement is excluded from the global block
                            if (ballCounts) {
                                let currentOvers = currentInnings.overs;
                                let overFull = Math.floor(currentOvers);
                                let ballCount = Math.round((currentOvers * 10) % 10) + 1;

                                let bOvers = currentBowling.bowling[bIdx].overs;
                                let bOverFull = Math.floor(bOvers);
                                let bBallCount = Math.round((bOvers * 10) % 10) + 1;

                                const formatLimit = updatedMatch.innings.length > 2 ? 1 : updatedMatch.totalOvers;
                                if (ballCount >= 6) {
                                    updatedMatch.score.thisOver = [];
                                    ballCount = 0; overFull += 1;
                                    bBallCount = 0; bOverFull += 1;
                                    const temp = localStriker; localStriker = localNonStriker; localNonStriker = temp;
                                    if (overFull < formatLimit) { setShowBowlerModal(true); }
                                } else {
                                    if (bBallCount >= 6) { bBallCount = 0; bOverFull += 1; }
                                }
                                currentInnings.overs = parseFloat(`${overFull}.${ballCount}`);
                                currentBowling.bowling[bIdx].overs = parseFloat(`${bOverFull}.${bBallCount}`);
                                ballCounts = false; // Prevent double increment in global block
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
                        toast.error("This bowler was already bowling! Select a different replacement.");
                        return;
                    }
                    if (updatedMatch.score.lastOverBowler === value) {
                        toast.error("A bowler cannot bowl two overs in a row! This player bowled the previous over.");
                        return;
                    }

                    const bowlerStats = currentBowling.bowling.find(p => p.player === value);
                    if (bowlerStats && Math.floor(bowlerStats.overs) >= 2) {
                        toast.error("A bowler cannot bowl more than 2 overs!");
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

                    const formatLimit = updatedMatch.innings.length > 2 ? 1 : updatedMatch.totalOvers;
                    if (ballCount >= 6) {
                        updatedMatch.score.lastOverBowler = localBowler; // Track for Law 17.8
                        updatedMatch.score.thisOver = [];
                        ballCount = 0; overFull += 1;
                        bBallCount = 0; bOverFull += 1;
                        const temp = localStriker; localStriker = localNonStriker; localNonStriker = temp;
                        if (overFull < formatLimit) { setShowBowlerModal(true); }
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

                // --- Check for Innings Completion ---
                const isAllOut = currentInnings.wickets >= 10 || (updatedMatch.innings.length > 2 && currentInnings.wickets >= 2); // SO usually 2 wickets
                const isOversCompleted = currentInnings.overs >= (updatedMatch.innings.length > 2 ? 1 : updatedMatch.totalOvers);
                const targetChased = updatedMatch.score.target && currentInnings.runs >= updatedMatch.score.target;

                if (isAllOut || isOversCompleted || targetChased) {
                    // Update the final score in the innings array before any reset
                    updatedMatch.innings[battingTeamIdx].runs = currentInnings.runs;
                    updatedMatch.innings[battingTeamIdx].wickets = currentInnings.wickets;
                    updatedMatch.innings[battingTeamIdx].overs = currentInnings.overs;

                    if (!updatedMatch.score.target) {
                        // 1st Innings just ended
                        updatedMatch.score.target = currentInnings.runs + 1;
                        const nextTeam = updatedMatch.score.battingTeam === updatedMatch.teamA ? updatedMatch.teamB : updatedMatch.teamA;

                        toast.success(`${currentInnings.team} innings over. Target: ${updatedMatch.score.target}`, { icon: '🏏', duration: 5000 });

                        // Check if we need to add a new innings for the 2nd part of Super Over
                        if (updatedMatch.innings.length % 2 !== 0) {
                            updatedMatch.innings.push({
                                team: nextTeam, runs: 0, wickets: 0, overs: 0,
                                batting: [], bowling: [],
                                extras: { total: 0, wides: 0, noBalls: 0, byes: 0, legByes: 0 }
                            });
                        }

                        // Reset score object for 2nd innings
                        updatedMatch.score.battingTeam = nextTeam;
                        updatedMatch.score.runs = 0;
                        updatedMatch.score.wickets = 0;
                        updatedMatch.score.overs = 0;
                        updatedMatch.score.thisOver = [];

                        // Clear transition states
                        localStriker = ''; localNonStriker = ''; localBowler = '';
                        setStriker(''); setNonStriker(''); setBowler('');
                        setModalData({ s: '', ns: '', b: '', nextB: '', nextS: '' });
                        updatedMatch.currentBatsmen = [];
                        updatedMatch.currentBowler = '';
                    } else {
                        // 2nd (or 4th, 6th...) Innings just ended
                        const isSuperOver = updatedMatch.innings.length > 2;
                        const firstInningsOfPair = updatedMatch.innings[updatedMatch.innings.length - 2];

                        if (currentInnings.runs === firstInningsOfPair.runs) {
                            // TIE
                            updatedMatch.status = 'live'; // Keep it live so admin can choose
                            updatedMatch.score.runs = currentInnings.runs;
                            updatedMatch.score.wickets = currentInnings.wickets;
                            updatedMatch.score.overs = currentInnings.overs;
                            setSuperOverBattingTeam(updatedMatch.innings[0].team);
                            setShowSuperOverModal(true);
                            toast.success("Scores are Level! Match Tied.", { icon: '🤝', duration: 5000 });
                        } else {
                            // Decided
                            updatedMatch.status = 'completed';
                            const mom = calculateMOM(updatedMatch);
                            if (mom) updatedMatch.manOfTheMatch = mom;
                            toast.success("Match Completed!", { icon: '🏆' });
                        }
                    }
                } else {
                    // Ongoing innings -> Keep score object in sync with current innings
                    updatedMatch.score.runs = currentInnings.runs;
                    updatedMatch.score.wickets = currentInnings.wickets;
                    updatedMatch.score.overs = currentInnings.overs;
                    updatedMatch.currentBowler = localBowler;
                    updatedMatch.currentBatsmen = [
                        { name: localStriker, onStrike: true, runs: currentInnings.batting.find(p => p.player === localStriker)?.runs || 0, balls: currentInnings.batting.find(p => p.player === localStriker)?.balls || 0 },
                        { name: localNonStriker, onStrike: false, runs: currentInnings.batting.find(p => p.player === localNonStriker)?.runs || 0, balls: currentInnings.batting.find(p => p.player === localNonStriker)?.balls || 0 }
                    ].filter(b => b.name && b.name.trim() !== '');
                }
            }
        }

        setStriker(localStriker); setNonStriker(localNonStriker); setBowler(localBowler);

        // --- Optimistic Update ---
        // This ensures that history is available IMMEDIATELY for modals (e.g. Undo in Bowler Modal)
        setSelectedMatch(updatedMatch);
        setScorecardData(updatedMatch.innings);

        try {
            const { id, _id, lastUpdated, ...payload } = updatedMatch;
            const res = await axios.put(`${API_URL}/api/matches/${selectedMatch._id || selectedMatch.id}`, payload, config);

            // Resilience: Prepare new state from server
            let newMatchState = res.data;

            // Ensure history is preserved if backend didn't return it correctly
            if ((!newMatchState.history || newMatchState.history.length === 0) && updatedMatch.history && updatedMatch.history.length > 0) {
                newMatchState.history = updatedMatch.history;
            }

            setSelectedMatch(newMatchState);
            setScorecardData(newMatchState.innings);
        } catch (err) {
            const errorMsg = err.response?.data?.msg || err.response?.data?.error || "Update sync failed";
            if (err.response?.status === 401) {
                localStorage.removeItem('token');
                navigate('/login');
                toast.error("Session expired. Please login again.");
            } else {
                toast.error(errorMsg);
            }
            // Revert on error
            fetchMatches();
        } finally {
            setIsUpdating(false);
        }
    };

    const calculateMOM = (match) => {
        if (!match.innings || match.innings.length < 2) return null;

        // Combine stats from ALL innings (main + super overs)
        let candidates = {};

        match.innings.forEach(inn => {
            inn.batting.forEach(p => {
                if (!candidates[p.player]) candidates[p.player] = { runs: 0, wickets: 0 };
                candidates[p.player].runs += p.runs;
            });
            inn.bowling.forEach(p => {
                if (!candidates[p.player]) candidates[p.player] = { runs: 0, wickets: 0 };
                candidates[p.player].wickets += p.wickets;
            });
        });

        let best = null;
        let max = -1;
        Object.keys(candidates).forEach(name => {
            const score = candidates[name].runs + (candidates[name].wickets * 25);
            if (score > max) {
                max = score;
                best = name;
            }
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
            if (parseInt(createForm.totalOvers) <= 0) {
                toast.error("Total overs must be greater than 0!");
                return;
            }
            if (parseInt(createForm.totalOvers) > 20) {
                toast.error("Total overs cannot exceed 20!");
                return;
            }
            if (!createForm.time) {
                toast.error("Please select a match time!");
                return;
            }
            if (!validateSquads()) return;
            await axios.post(`${API_URL}/api/matches`, {
                ...createForm,
                teamASquad: squadA,
                teamBSquad: squadB,
                date: new Date(`${createForm.date}T${createForm.time}`).toISOString(),
                title: createForm.title || `${createForm.teamA} vs ${createForm.teamB}`
            }, config);
            toast.success("Match created successfully!");
            fetchMatches();
            setIsCreating(false);
            setCreateForm({
                title: '', teamA: '', teamB: '', status: 'upcoming',
                date: new Date().toISOString().split('T')[0],
                time: '09:00', venue: '', totalOvers: 20
            });
            setSquadA(Array(11).fill(''));
            setSquadB(Array(11).fill(''));
        } catch (err) {
            const errorMsg = err.response?.data?.msg || err.response?.data?.error || "Failed to create match";
            toast.error(errorMsg);
        }
    };

    const handleDelete = async (e, id) => {
        e.stopPropagation();
        try {
            await axios.delete(`${API_URL}/api/matches/${id}`, config);
            toast.success('Match deleted permanently'); fetchMatches();
            if (selectedMatch?._id === id || selectedMatch?.id === id) setSelectedMatch(null);
        } catch (err) {
            const errorMsg = err.response?.data?.msg || "Delete operation failed";
            toast.error(errorMsg);
        }
    };

    const handleStartSuperOver = () => {
        if (!selectedMatch) return;
        let updatedMatch = JSON.parse(JSON.stringify(selectedMatch));

        let nextBattingTeam, nextBowlingTeam;
        nextBattingTeam = superOverBattingTeam || (updatedMatch.innings && updatedMatch.innings[0]?.team) || updatedMatch.teamA;
        nextBowlingTeam = (nextBattingTeam === updatedMatch.teamA ? updatedMatch.teamB : updatedMatch.teamA);

        // Push BOTH innings for the Super Over pair to keep stats unique
        // Batting Innings
        updatedMatch.innings.push({
            team: nextBattingTeam, runs: 0, wickets: 0, overs: 0,
            batting: [], bowling: [],
            extras: { total: 0, wides: 0, noBalls: 0, byes: 0, legByes: 0 }
        });
        // Bowling Innings (to store bowling stats of this team)
        updatedMatch.innings.push({
            team: nextBowlingTeam, runs: 0, wickets: 0, overs: 0,
            batting: [], bowling: [],
            extras: { total: 0, wides: 0, noBalls: 0, byes: 0, legByes: 0 }
        });

        // Reset live score state
        updatedMatch.score = {
            battingTeam: nextBattingTeam,
            runs: 0, wickets: 0, overs: 0,
            thisOver: [],
            target: null
        };

        updatedMatch.status = 'live';
        updatedMatch.currentBatsmen = [];
        updatedMatch.currentBowler = null;

        setStriker(''); setNonStriker(''); setBowler('');

        handleUpdate('manual', updatedMatch);
        setShowSuperOverModal(false);
        toast.success(`Super Over Started! ${nextBattingTeam} batting first.`, { icon: '🔥' });
    };

    const handleDeclareTie = () => {
        if (!selectedMatch) return;
        let updatedMatch = JSON.parse(JSON.stringify(selectedMatch));
        updatedMatch.status = 'completed';
        const mom = calculateMOM(updatedMatch);
        if (mom) updatedMatch.manOfTheMatch = mom;
        handleUpdate('manual', updatedMatch);
        setShowSuperOverModal(false);
        toast.success("Match ended as a Tie!", { icon: '🤝' });
    };

    const getOversInBalls = (overs) => {
        return (Math.floor(overs) * 6) + Math.round((overs * 10) % 10);
    };

    const crr = (() => {
        if (!selectedMatch?.score?.overs) return '0.00';
        const totalBalls = getOversInBalls(selectedMatch?.score?.overs || 0);
        if (totalBalls === 0) return '0.00';
        return (((selectedMatch?.score?.runs || 0) / totalBalls) * 6).toFixed(2);
    })();

    const calculateRRR = () => {
        if (!selectedMatch?.score?.target) return null;
        const runsNeeded = (selectedMatch?.score?.target || 0) - (selectedMatch?.score?.runs || 0);
        const totalBalls = (selectedMatch?.totalOvers || 0) * 6;
        const ballsBowled = getOversInBalls(selectedMatch?.score?.overs || 0);
        const ballsRemaining = totalBalls - ballsBowled;
        if (ballsRemaining <= 0) return runsNeeded <= 0 ? '0.00' : '∞';
        return ((runsNeeded / ballsRemaining) * 6).toFixed(2);
    };
    const rrr = calculateRRR();

    return (
        <>
            <Container fluid="lg" className="py-4">
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
                            const battingTeam = tossData.decision === 'bat' ? tossData.winner : (tossData.winner === selectedMatch?.teamA ? selectedMatch?.teamB : selectedMatch?.teamA);
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
                            <Form.Label className="fw-bold small text-uppercase text-muted">Batting Team</Form.Label>
                            <Form.Select size="lg" className="rounded-3 border-0 shadow-sm fw-bold" value={modalData.team} onChange={e => setModalData({ ...modalData, team: e.target.value })}>
                                <option value={selectedMatch?.teamA}>{selectedMatch?.teamA} (Team A)</option>
                                <option value={selectedMatch?.teamB}>{selectedMatch?.teamB} (Team B)</option>
                            </Form.Select>
                        </Form.Group>
                        <Form.Group className="mb-3">
                            <Form.Label className="fw-bold small text-uppercase text-muted">Striker</Form.Label>
                            <Form.Select size="lg" className="rounded-3 border-0 shadow-sm" value={modalData.s} onChange={e => setModalData({ ...modalData, s: e.target.value })}>
                                <option value="">Select Striker</option>
                                {(modalData.team === selectedMatch?.teamA ? squadA : squadB).map((p, i) => <option key={i} value={p}>{p}</option>)}
                            </Form.Select>
                        </Form.Group>
                        <Form.Group className="mb-3">
                            <Form.Label className="fw-bold small text-uppercase text-muted">Non-Striker</Form.Label>
                            <Form.Select size="lg" className="rounded-3 border-0 shadow-sm" value={modalData.ns} onChange={e => setModalData({ ...modalData, ns: e.target.value })}>
                                <option value="">Select Non-Striker</option>
                                {(modalData.team === selectedMatch?.teamA ? squadA : squadB).map((p, i) => <option key={i} value={p}>{p}</option>)}
                            </Form.Select>
                        </Form.Group>
                        <Form.Group className="mb-3">
                            <Form.Label className="fw-bold small text-uppercase text-muted">Bowler</Form.Label>
                            <Form.Select size="lg" className="rounded-3 border-0 shadow-sm" value={modalData.b} onChange={e => setModalData({ ...modalData, b: e.target.value })}>
                                <option value="">Select Bowler</option>
                                {(modalData.team === selectedMatch?.teamA ? squadB : squadA).map((p, i) => <option key={i} value={p}>{p}</option>)}
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
                    <Modal.Footer className="border-0 bg-light pb-4 px-4 d-flex gap-2">
                        <Button variant="outline-danger" size="lg" className="flex-grow-1 fw-bold rounded-pill" onClick={() => { setShowBowlerModal(false); undoLastBall(); }}>CANCEL & UNDO</Button>
                        <Button variant="primary" size="lg" className="flex-grow-2 fw-black rounded-pill shadow" onClick={() => { if (!modalData.nextB) return toast.error("Select a bowler"); handleUpdate('new_bowler', modalData.nextB); setShowBowlerModal(false); setModalData({ ...modalData, nextB: '' }); }}>START OVER</Button>
                    </Modal.Footer>
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
                                {getAvailableBatsmen('batting').map((p, i) => <option key={i} value={p}>{p}</option>)}
                            </Form.Select>
                        </Form.Group>
                    </Modal.Body>
                    <Modal.Footer className="border-0 bg-light pb-4 px-4 d-flex gap-2">
                        <Button variant="outline-danger" size="lg" className="flex-grow-1 fw-bold rounded-pill" onClick={() => { setShowBatsmanModal(false); undoLastBall(); }}>CANCEL & UNDO</Button>
                        <Button variant={batsmanModalType === 'wicket' ? 'danger' : 'info'} size="lg" className="flex-grow-2 fw-black rounded-pill shadow" onClick={() => {
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
                        {(wicketDetails.type === 'run out' || wicketDetails.type === 'stumped') && (
                            <Form.Group className="mb-3">
                                <Form.Label className="fw-bold small text-uppercase text-muted">Ball Category</Form.Label>
                                <Form.Select size="lg" className="rounded-3 border-0 shadow-sm" value={wicketDetails.ballType} onChange={e => setWicketDetails({ ...wicketDetails, ballType: e.target.value })}>
                                    <option value="normal">Normal Ball</option>
                                    <option value="wide">Wide Ball (+1 Extra)</option>
                                    {wicketDetails.type === 'run out' && <option value="no-ball">No Ball (+1 Extra)</option>}
                                    {wicketDetails.type === 'run out' && <option value="mankad">Mankad (Non-striker)</option>}
                                </Form.Select>
                                {wicketDetails.ballType === 'mankad' && <small className="text-danger d-block mt-1">⚠️ Mankad does not count as a ball in the over.</small>}
                            </Form.Group>
                        )}
                        {wicketDetails.type === 'run out' && (
                            <>
                                <Form.Group className="mb-3">
                                    <Form.Label className="fw-bold small text-uppercase text-muted">Who is Out?</Form.Label>
                                    <div className="d-flex gap-2">
                                        <Button
                                            variant={wicketDetails.whomOut === 'striker' ? 'danger' : 'outline-danger'}
                                            className="flex-grow-1 fw-bold"
                                            disabled={wicketDetails.ballType === 'mankad'}
                                            onClick={() => setWicketDetails({ ...wicketDetails, whomOut: 'striker' })}
                                        >
                                            STRIKER ({toCamelCase(striker)})
                                        </Button>
                                        <Button
                                            variant={wicketDetails.whomOut === 'non-striker' ? 'danger' : 'outline-danger'}
                                            className="flex-grow-1 fw-bold"
                                            onClick={() => setWicketDetails({ ...wicketDetails, whomOut: 'non-striker' })}
                                        >
                                            NON-STRIKER ({toCamelCase(nonStriker)})
                                        </Button>
                                    </div>
                                    {wicketDetails.ballType === 'mankad' && <small className="text-muted mt-1 d-block">Mankad only applies to the non-striker.</small>}
                                </Form.Group>
                                {wicketDetails.ballType !== 'mankad' && (
                                    <>
                                        <Form.Group className="mb-3 d-flex align-items-center justify-content-between">
                                            <Form.Label className="fw-bold small text-uppercase text-muted m-0">Batters Crossed?</Form.Label>
                                            <Form.Check type="switch" checked={!!wicketDetails.crossed} onChange={e => setWicketDetails({ ...wicketDetails, crossed: e.target.checked })} />
                                        </Form.Group>
                                        <Form.Group className="mb-3">
                                            <Form.Label className="fw-bold small text-uppercase text-muted">Runs Completed</Form.Label>
                                            <Form.Select size="lg" className="rounded-3 border-0 shadow-sm" value={wicketDetails.runs} onChange={e => setWicketDetails({ ...wicketDetails, runs: parseInt(e.target.value) })}>
                                                {[0, 1, 2, 3].map(r => <option key={r} value={r}>{r}</option>)}
                                            </Form.Select>
                                        </Form.Group>
                                    </>
                                )}
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

                <div className="d-flex flex-column flex-md-row justify-content-between align-items-md-center gap-3 mb-5">
                    <div className="d-flex gap-3 align-items-center">
                        <Button variant="outline-primary" className="rounded-pill px-3 shadow-sm" onClick={() => navigate('/')}>
                            <i className="bi bi-arrow-left"></i> Home
                        </Button>
                        <Button variant="outline-secondary" className="rounded-pill shadow-sm" onClick={() => { toast.success('Syncing matches...'); fetchMatches(); }}>
                            <i className="bi bi-arrow-clockwise"></i> Sync
                        </Button>
                        <h2 className="fw-black premium-gradient-text m-0">Admin Dashboard</h2>
                    </div>
                    <Button variant="primary" className="rounded-pill shadow-sm px-4 py-2 fw-bold" onClick={() => { setIsCreating(true); setSelectedMatch(null); }}>
                        <i className="bi bi-plus-lg me-2"></i>New Match
                    </Button>
                </div>

                <div style={{ maxWidth: '1600px', margin: '0 auto' }}>
                    <Row>
                        <Col lg={4} className="mb-4">
                            <Card className="shadow-sm border-0">
                                <Card.Header className="bg-white fw-bold d-flex justify-content-between"><span>Matches</span><Badge bg="secondary">{matches.length}</Badge></Card.Header>
                                <ListGroup variant="flush" className="overflow-auto" style={{ maxHeight: '75vh' }}>
                                    {matches.map(m => (
                                        <ListGroup.Item key={m._id || m.id} className="d-flex justify-content-between align-items-center py-3 border-start border-4 p-0 pointer-event" style={{ borderLeftColor: m.status === 'live' ? '#ff4b2b' : '#333' }}>
                                            <div className={`flex-grow-1 p-3 ${selectedMatch?._id === m._id || selectedMatch?.id === m.id ? 'bg-primary text-white' : ''}`} style={{ cursor: 'pointer' }} onClick={() => handleEdit(m)}>
                                                <div className="fw-bold fs-6">{m.teamA.toUpperCase()} vs {m.teamB.toUpperCase()}</div>
                                                <small className={selectedMatch?._id === m._id || selectedMatch?.id === m.id ? 'text-white-50' : 'text-muted'}>
                                                    {m.status.toUpperCase()} | {new Date(m.date).toLocaleDateString()} | {formatTime(m.date)}
                                                </small>
                                            </div>
                                            <div className="d-flex align-items-center">
                                                {(m.status === 'completed' || m.status === 'abandoned') && (
                                                    <Button variant="link" className="text-secondary px-2" title="Copy Match & Squads" onClick={(e) => {
                                                        e.stopPropagation();
                                                        setCreateForm({
                                                            title: m.title || '', teamA: m.teamA, teamB: m.teamB, status: 'upcoming',
                                                            date: new Date().toISOString().split('T')[0], time: m.date ? new Date(m.date).toTimeString().substring(0, 5) : '09:00', venue: m.venue || '', totalOvers: m.totalOvers || 20
                                                        });
                                                        setSquadA(m.teamASquad || Array(11).fill(''));
                                                        setSquadB(m.teamBSquad || Array(11).fill(''));
                                                        setIsCreating(true);
                                                        setSelectedMatch(null);
                                                        window.scrollTo({ top: 0, behavior: 'smooth' });
                                                    }}>
                                                        <i className="bi bi-files fs-5"></i>
                                                    </Button>
                                                )}
                                                {m.status !== 'completed' && m.status !== 'abandoned' && (
                                                    <Button variant="link" className="text-danger px-3 border-start ms-2" onClick={(e) => handleDelete(e, m._id || m.id)}>
                                                        <span className="fs-4">×</span>
                                                    </Button>
                                                )}
                                            </div>
                                        </ListGroup.Item>
                                    ))}
                                </ListGroup>
                            </Card>
                        </Col>

                        <Col lg={8}>
                            {isCreating ? (
                                <Card className="shadow-lg border-0">
                                    <Card.Body className="p-4">
                                        <h4 className="mb-4 fw-bold">New Match</h4>
                                        <Form onSubmit={handleCreateSubmit}>
                                            <Row className="g-3">
                                                <Col md={12}>
                                                    <Form.Group>
                                                        <Form.Label className="small fw-bold">Title</Form.Label>
                                                        <Form.Control
                                                            placeholder="e.g. Final, Quarter Final (Optional)"
                                                            value={createForm.title}
                                                            onChange={e => setCreateForm({ ...createForm, title: e.target.value })}
                                                        />
                                                    </Form.Group>
                                                </Col>
                                                <Col md={6}>
                                                    <Form.Group>
                                                        <Form.Label className="small fw-bold">Team A</Form.Label>
                                                        <Form.Control required placeholder="Team Name" value={createForm.teamA} onChange={e => setCreateForm({ ...createForm, teamA: e.target.value })} />
                                                    </Form.Group>
                                                </Col>
                                                <Col md={6}>
                                                    <Form.Group>
                                                        <Form.Label className="small fw-bold">Team B</Form.Label>
                                                        <Form.Control required placeholder="Team Name" value={createForm.teamB} onChange={e => setCreateForm({ ...createForm, teamB: e.target.value })} />
                                                    </Form.Group>
                                                </Col>
                                                <Col md={6}>
                                                    <Form.Group>
                                                        <Form.Label className="small fw-bold">Overs</Form.Label>
                                                        <Form.Control type="number" min="1" max="20" required value={createForm.totalOvers} onChange={e => setCreateForm({ ...createForm, totalOvers: e.target.value })} />
                                                    </Form.Group>
                                                </Col>
                                                <Col md={6}>
                                                    <Form.Group>
                                                        <Form.Label className="small fw-bold">Venue</Form.Label>
                                                        <Form.Control placeholder="Ground Name" value={createForm.venue} onChange={e => setCreateForm({ ...createForm, venue: e.target.value })} />
                                                    </Form.Group>
                                                </Col>
                                                <Col md={6}>
                                                    <Form.Group>
                                                        <Form.Label className="small fw-bold">Date</Form.Label>
                                                        <Form.Control type="date" value={createForm.date} onChange={e => setCreateForm({ ...createForm, date: e.target.value })} />
                                                    </Form.Group>
                                                </Col>
                                                <Col md={6}>
                                                    <Form.Group>
                                                        <Form.Label className="small fw-bold">Time (Local)</Form.Label>
                                                        <Form.Control type="time" value={createForm.time} onChange={e => setCreateForm({ ...createForm, time: e.target.value })} />
                                                    </Form.Group>
                                                </Col>
                                            </Row>
                                            <div className="mt-4 d-flex gap-2">
                                                <Button variant="outline-primary" onClick={() => setShowSquadModal(true)}>MANAGE SQUADS (11)</Button>
                                                <Button variant="primary" type="submit">Create</Button>
                                                <Button variant="outline-danger" onClick={() => setCreateForm({ title: '', teamA: '', teamB: '', status: 'upcoming', date: new Date().toISOString().split('T')[0], time: '09:00', venue: '', totalOvers: 20 })}>Clear</Button>
                                                <Button variant="light" onClick={() => setIsCreating(false)}>Cancel</Button>
                                            </div>
                                        </Form>
                                    </Card.Body>
                                </Card>
                            ) : selectedMatch ? (
                                <Card className="shadow-lg border-0 overflow-hidden">
                                    <Card.Header className="bg-dark text-white d-flex justify-content-between align-items-center py-3 px-4"><h5 className="m-0 fw-bold">{selectedMatch.teamA.toUpperCase()} vs {selectedMatch.teamB.toUpperCase()}</h5><Badge bg={selectedMatch.status === 'live' ? 'danger' : 'info'}>{selectedMatch.status.toUpperCase()}</Badge></Card.Header>
                                    <Card.Body className="p-4">
                                        <div className="text-center mb-4 bg-light rounded-4 p-4 border">
                                            {(() => {
                                                const lastInn = selectedMatch.innings && selectedMatch.innings.length > 0 ? selectedMatch.innings[selectedMatch.innings.length - 1] : null;
                                                // Ideally, use the LIVE score object, but if completed, fallback to the last innings data to ensure accuracy
                                                const dRuns = (selectedMatch.status === 'completed' && lastInn) ? lastInn.runs : selectedMatch.score.runs;
                                                const dWickets = (selectedMatch.status === 'completed' && lastInn) ? lastInn.wickets : selectedMatch.score.wickets;
                                                const dOvers = (selectedMatch.status === 'completed' && lastInn) ? lastInn.overs : selectedMatch.score.overs;

                                                // Determine limit for display
                                                const dLimit = selectedMatch.innings.length > 2 ? 1 : selectedMatch.totalOvers;

                                                return (
                                                    <>
                                                        <div className="display-3 fw-bold text-primary">{dRuns}/{dWickets}</div>
                                                        <div className="lead fw-bold">{dOvers} / {dLimit} {selectedMatch.innings.length > 2 ? 'Over (Super Over)' : 'Overs'}</div>
                                                    </>
                                                );
                                            })()}

                                            {/* Dynamic Previous Innings Display */}
                                            {selectedMatch.innings && selectedMatch.innings.length > 1 && (
                                                <div className="mt-2 d-flex flex-wrap justify-content-center gap-2">
                                                    {selectedMatch.innings.map((inn, i) => ({ ...inn, originalIdx: i }))
                                                        .filter(inn => {
                                                            const isCurrent = inn.team === selectedMatch.score?.battingTeam;
                                                            const hasStarted = inn.runs > 0 || inn.wickets > 0 || (inn.batting && inn.batting.length > 0);
                                                            return hasStarted && !isCurrent;
                                                        })
                                                        .sort((a, b) => a.originalIdx - b.originalIdx)
                                                        .map((inn) => {
                                                            const idx = inn.originalIdx;
                                                            if (idx >= 2 && inn.runs === 0 && inn.wickets === 0 && (!inn.batting || inn.batting.length === 0)) return null;
                                                            return (
                                                                <Badge key={idx} bg="secondary" className="opacity-75 shadow-sm text-uppercase x-small">
                                                                    {idx >= 2 ? `${inn.team} SO ${Math.floor(idx / 2)}:` : `${inn.team}:`} {inn.runs}/{inn.wickets} ({inn.overs})
                                                                </Badge>
                                                            );
                                                        })}
                                                </div>
                                            )}

                                            {/* Innings Break Announcement */}
                                            {selectedMatch.status === 'live' && selectedMatch.score.target && (!selectedMatch.currentBatsmen || selectedMatch.currentBatsmen.length === 0) && (
                                                <Alert variant="warning" className="fw-black py-2 mb-3 border-0 rounded-pill shadow-sm animate-bounce text-center">
                                                    ☕ {t('innings_break')}
                                                </Alert>
                                            )}

                                            {(() => {
                                                const winStr = calculateWinner(selectedMatch, true);
                                                const isFinished = selectedMatch.status === 'completed' || (
                                                    selectedMatch.score.target && (
                                                        selectedMatch.score.runs >= selectedMatch.score.target ||
                                                        (selectedMatch.score.overs >= (selectedMatch.innings.length > 2 ? 1 : selectedMatch.totalOvers) && selectedMatch.score.runs < selectedMatch.score.target - 1) ||
                                                        (selectedMatch.score.wickets >= (selectedMatch.innings.length > 2 ? 2 : 10) && selectedMatch.score.runs < selectedMatch.score.target - 1)
                                                    )
                                                );

                                                if (winStr && winStr !== 'Match Completed' && isFinished) {
                                                    return (
                                                        <div className="alert alert-success fw-black text-center py-2 mb-3 border-0 rounded-pill shadow-sm">
                                                            🏆 {winStr.toUpperCase()}
                                                        </div>
                                                    );
                                                }
                                                return null;
                                            })()}

                                            <div className="mt-3">
                                                <Badge bg="white" text="dark" className="border px-3 py-2 me-2">CRR: {crr}</Badge>
                                                {rrr && (selectedMatch.score.runs > 0 || selectedMatch.score.overs > 0) && <Badge bg="info" text="white" className="px-3 py-2 me-2">RRR: {rrr}</Badge>}
                                                {selectedMatch.score.target && <Badge bg="warning" text="dark" className="px-3 py-2 d-inline-flex align-items-center gap-2">
                                                    <i className="bi bi-flag-fill"></i>
                                                    TARGET: {selectedMatch.score.target}
                                                </Badge>}
                                            </div>
                                        </div>
                                        <div className="d-flex gap-2 mb-4 justify-content-center flex-wrap">
                                            <Button variant="outline-dark" size="lg" className="px-3 fw-bold" onClick={() => setShowSquadModal(true)}>👥 SQUADS</Button>
                                            {(!selectedMatch.toss?.winner && (selectedMatch.status === 'upcoming' || selectedMatch.status === 'live')) && <Button variant="warning" size="lg" className="px-5 fw-bold" onClick={() => {
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
                                            {/* INNINGS START BUTTONS */}
                                            {selectedMatch.status === 'upcoming' && (
                                                <Button variant="success" size="lg" className="px-5 fw-bold" onClick={() => {
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
                                                    // Pre-select team from toss if available
                                                    let team1st = selectedMatch.teamA;
                                                    if (selectedMatch.toss?.winner) {
                                                        const win = selectedMatch.toss.winner;
                                                        const dec = selectedMatch.toss.decision;
                                                        team1st = dec === 'bat' ? win : (win === selectedMatch.teamA ? selectedMatch.teamB : selectedMatch.teamA);
                                                    }
                                                    setModalData({ s: '', ns: '', b: '', nextB: '', nextS: '', team: team1st });
                                                    setShowStartModal(true);
                                                }}>
                                                    {(() => {
                                                        let team1st = selectedMatch.teamA;
                                                        if (selectedMatch.toss?.winner) {
                                                            const win = selectedMatch.toss.winner;
                                                            const dec = selectedMatch.toss.decision;
                                                            team1st = dec === 'bat' ? win : (win === selectedMatch.teamA ? selectedMatch.teamB : selectedMatch.teamA);
                                                        }
                                                        return `Start 1st Innings (${team1st})`;
                                                    })()}
                                                </Button>
                                            )}

                                            {/* Helper to check if current innings is done */}
                                            {(() => {
                                                // Determine active side strictly: Target score exists => chasing team (Index 1 or 3, etc)
                                                let currentInnIdx;
                                                if (selectedMatch.innings.length > 2) {
                                                    const pairStart = selectedMatch.innings.length - 2;
                                                    currentInnIdx = selectedMatch.score?.target ? pairStart + 1 : pairStart;
                                                } else {
                                                    currentInnIdx = selectedMatch.score?.target ? 1 : 0;
                                                }
                                                const currentInn = selectedMatch.innings[currentInnIdx];

                                                const limit = selectedMatch.innings.length > 2 ? 1 : selectedMatch.totalOvers;
                                                // Check strict completion: Overs reached, 10 wkts, or (Super Over & 2 wkts)
                                                const isComplete = currentInn && (
                                                    currentInn.overs >= limit ||
                                                    currentInn.wickets >= 10 ||
                                                    (selectedMatch.innings.length > 2 && currentInn.wickets >= 2)
                                                );

                                                return (
                                                    <>
                                                        {selectedMatch.status === 'live' && ((!selectedMatch.currentBatsmen || selectedMatch.currentBatsmen.length === 0) || isComplete) && (
                                                            (() => {
                                                                const targetIdx = isComplete ? selectedMatch.innings.length : currentInnIdx;

                                                                // Check for Super Over Tie to offer Draw
                                                                // If we are about to start Super Over 2 (Index 4) or higher...
                                                                let isTie = false;
                                                                if (targetIdx >= 4 && targetIdx % 2 === 0) {
                                                                    const prevInn2 = selectedMatch.innings[targetIdx - 1]; // SO 2nd Inn
                                                                    const prevInn1 = selectedMatch.innings[targetIdx - 2]; // SO 1st Inn
                                                                    if (prevInn1.runs === prevInn2.runs) isTie = true;
                                                                }

                                                                if (isTie) {
                                                                    return (
                                                                        <Button variant="warning" size="lg" className="px-5 fw-bold shadow-sm" onClick={() => {
                                                                            if (window.confirm("Super Over ended in a TIE. End match as DRAW?")) {
                                                                                handleUpdate('manual', { ...selectedMatch, status: 'completed' });
                                                                            }
                                                                        }}>
                                                                            End Match (Tie/Draw)
                                                                        </Button>
                                                                    );
                                                                }

                                                                return (
                                                                    <Button disabled={isUpdating} variant="success" size="lg" className="px-5 fw-bold shadow-sm" onClick={() => {
                                                                        const tIdx = targetIdx;
                                                                        let nextTeam;
                                                                        if (selectedMatch.innings[tIdx]?.team) {
                                                                            nextTeam = selectedMatch.innings[tIdx].team;
                                                                        } else if (tIdx === 1) {
                                                                            const team1 = selectedMatch.innings[0].team;
                                                                            nextTeam = (team1 === selectedMatch.teamA ? selectedMatch.teamB : selectedMatch.teamA);
                                                                        } else if (tIdx >= 2) {
                                                                            const team1 = selectedMatch.innings[0].team || selectedMatch.teamA;
                                                                            const team2 = (team1 === selectedMatch.teamA ? selectedMatch.teamB : selectedMatch.teamA);
                                                                            nextTeam = tIdx % 2 === 0 ? team1 : team2;
                                                                        }
                                                                        setModalData({ s: '', ns: '', b: '', nextB: '', nextS: '', team: nextTeam || selectedMatch.teamA });
                                                                        setShowStartModal(true);
                                                                    }}>
                                                                        {(() => {
                                                                            const tIdx = targetIdx;
                                                                            const team1 = selectedMatch.innings[0]?.team || selectedMatch.teamA;
                                                                            const team2 = (team1 === selectedMatch.teamA ? selectedMatch.teamB : selectedMatch.teamA);

                                                                            if (tIdx === 0) return `Start 1st Innings (${team1})`;
                                                                            if (tIdx === 1) return `Start 2nd Innings (${team2})`;

                                                                            const soBattingTeam = selectedMatch.innings[tIdx]?.team || (tIdx % 2 === 0 ? team1 : team2);
                                                                            return `Start Super Over - ${tIdx % 2 === 0 ? '1st' : '2nd'} Innings (${soBattingTeam})`;
                                                                        })()}
                                                                    </Button>
                                                                );
                                                            })()
                                                        )}

                                                        {/* SCORING BUTTONS - Only shown when players are on field AND innings NOT complete */}
                                                        {selectedMatch.status === 'live' && selectedMatch.currentBatsmen?.length > 0 && selectedMatch.currentBowler && !isComplete && (
                                                            <>
                                                                {[0, 1, 2, 3, 4, 6].map(r => (
                                                                    <Button key={r} disabled={isUpdating} variant="outline-primary" size="lg" className="px-3 fw-bold" onClick={() => {
                                                                        // ... (Keep existing robust check as backup)
                                                                        if (currentInn && currentInn.overs >= limit) {
                                                                            toast.error(`Over limit reached! Limit is ${limit} over(s).`);
                                                                            return;
                                                                        }
                                                                        handleUpdate('runs', r);
                                                                    }}>{r}</Button>
                                                                ))}
                                                                <Button variant="danger" size="lg" className="px-3 fw-bold" disabled={isUpdating} onClick={() => {
                                                                    if (currentInn && currentInn.overs >= limit) {
                                                                        toast.error(`Over limit reached! Limit is ${limit} over(s).`);
                                                                        return;
                                                                    }
                                                                    setWicketDetails({ type: 'caught', fielder: '', ballType: 'normal' }); setShowWicketModal(true);
                                                                }}>OUT</Button>
                                                                <Button variant="dark" size="lg" className="px-3 fw-bold ms-2" disabled={isUpdating || !selectedMatch.history || selectedMatch.history.length === 0} onClick={undoLastBall}>UNDO</Button>
                                                                <Button variant="outline-success" size="lg" className="px-3 fw-bold" onClick={() => setShowBowlerModal(true)}>⚾ CHANGE BOWLER</Button>
                                                                <Button variant="info" size="lg" className="px-3 fw-bold text-white" onClick={() => { setBatsmanModalType('retired'); setShowBatsmanModal(true); }}>RETIRE</Button>
                                                                <Button variant="warning" size="lg" className="px-2 fw-bold" disabled={isUpdating} onClick={() => {
                                                                    if (currentInn && currentInn.overs >= limit) {
                                                                        toast.error(`Over limit reached! Limit is ${limit} over(s).`);
                                                                        return;
                                                                    }
                                                                    handleUpdate('extra', 'w');
                                                                }}>WD</Button>
                                                                <Button variant="warning" size="lg" className="px-2 fw-bold" disabled={isUpdating} onClick={() => {
                                                                    if (currentInn && currentInn.overs >= limit) {
                                                                        toast.error(`Over limit reached! Limit is ${limit} over(s).`);
                                                                        return;
                                                                    }
                                                                    handleUpdate('extra', 'nb');
                                                                }}>NB</Button>
                                                            </>
                                                        )}
                                                    </>
                                                );
                                            })()}
                                            {selectedMatch.status === 'completed' && (
                                                <div className="text-center w-100 mb-3">
                                                    <Alert variant="success" className="py-3 shadow-sm border-0 rounded-4">
                                                        <h4 className="fw-black mb-1">{calculateWinner(selectedMatch)?.toUpperCase()}</h4>
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
                                                                    {(() => {
                                                                        const battingIdx = selectedMatch.innings.length > 2 ? selectedMatch.innings.length - 1 : (selectedMatch.score.battingTeam === selectedMatch.teamB ? 1 : 0);
                                                                        const bowlingIdx = battingIdx % 2 === 0 ? battingIdx + 1 : battingIdx - 1;
                                                                        const bStats = selectedMatch.innings[bowlingIdx]?.bowling.find(p => p.player === bowler);
                                                                        return bStats ? `${bStats.overs} ov | ${bStats.runs} r | ${bStats.wickets} w` : '0 ov';
                                                                    })()}
                                                                </div>
                                                            </div>
                                                            {selectedMatch.score.thisOver && selectedMatch.score.thisOver.length > 0 && (
                                                                <div className="mt-3">
                                                                    <div className="small fw-bold text-muted text-uppercase mb-2">This Over</div>
                                                                    <div className="d-flex gap-2">
                                                                        {selectedMatch.score.thisOver.map((ball, idx) => (
                                                                            <div key={idx} className={`rounded-circle d-flex align-items-center justify-content-center fw-bold small ${['W', 'OUT'].includes(ball) ? 'bg-danger text-white' : (['4', '6'].includes(ball.toString()) ? 'bg-success text-white' : 'bg-white border')}`} style={{ width: '25px', height: '25px' }}>
                                                                                {ball}
                                                                            </div>
                                                                        ))}
                                                                    </div>
                                                                </div>
                                                            )}
                                                        </Card.Body>
                                                    </Card>
                                                </Col>
                                            </Row>
                                        )}

                                        {/* Batting Summary Table */}
                                        {selectedMatch.status === 'live' && (
                                            <Card className="border-0 shadow-sm mt-0 mb-4 overflow-hidden">
                                                <Card.Header className="bg-primary text-white py-2 small fw-bold text-uppercase d-flex justify-content-between align-items-center">
                                                    <span><i className="bi bi-person-fill me-2"></i>Batting Summary: {selectedMatch.score.battingTeam}</span>
                                                    <Badge bg="white" text="primary" className="x-small">CRR: {crr}</Badge>
                                                </Card.Header>
                                                <Table hover responsive size="sm" className="mb-0">
                                                    <thead className="bg-light x-small text-uppercase">
                                                        <tr>
                                                            <th className="ps-3">Batter</th>
                                                            <th className="text-center">Status</th>
                                                            <th className="text-center">R</th>
                                                            <th className="text-center">B</th>
                                                            <th className="text-center">SR</th>
                                                        </tr>
                                                    </thead>
                                                    <tbody className="small">
                                                        {(() => {
                                                            const bTeam = selectedMatch.score.battingTeam?.trim();
                                                            const reversed = [...selectedMatch.innings].map((inn, i) => ({ ...inn, idx: i })).reverse();
                                                            const currentInnings = reversed.find(inn => inn.team?.trim().toLowerCase() === bTeam?.toLowerCase());

                                                            if (!currentInnings || !currentInnings.batting || currentInnings.batting.length === 0) {
                                                                return <tr><td colSpan={5} className="text-center py-2 text-muted">No batting data yet</td></tr>;
                                                            }
                                                            return currentInnings.batting.map((b, i) => (
                                                                <tr key={i} className={b.onStrike ? 'bg-primary bg-opacity-10' : ''}>
                                                                    <td className="ps-3 fw-bold">{toCamelCase(b.player)}{b.onStrike ? '*' : ''}</td>
                                                                    <td className="text-center small text-muted text-truncate" style={{ maxWidth: '100px' }}>{b.status}</td>
                                                                    <td className="text-center fw-bold">{b.runs}</td>
                                                                    <td className="text-center">{b.balls}</td>
                                                                    <td className="text-center text-muted">{b.strikeRate}</td>
                                                                </tr>
                                                            ));
                                                        })()}
                                                    </tbody>
                                                </Table>
                                            </Card>
                                        )}

                                        {/* Bowling Summary Table */}
                                        {selectedMatch.status === 'live' && (
                                            <Card className="border-0 shadow-sm mt-0 mb-4 overflow-hidden">
                                                <Card.Header className="bg-dark text-white py-2 small fw-bold text-uppercase">
                                                    <i className="bi bi-bullseye me-2"></i>Bowling Summary: {selectedMatch.innings[selectedMatch.score.battingTeam === selectedMatch.teamA ? (selectedMatch.innings.length > 2 ? 3 : 1) : (selectedMatch.innings.length > 2 ? 2 : 0)]?.team || 'N/A'}
                                                </Card.Header>
                                                <Table hover responsive size="sm" className="mb-0">
                                                    <thead className="bg-light x-small text-uppercase">
                                                        <tr>
                                                            <th className="ps-3">Bowler</th>
                                                            <th className="text-center">O</th>
                                                            <th className="text-center">M</th>
                                                            <th className="text-center">R</th>
                                                            <th className="text-center">W</th>
                                                            <th className="text-center">ECON</th>
                                                            <th className="text-center">0s</th>
                                                            <th className="text-center">WD</th>
                                                            <th className="text-center">NB</th>
                                                        </tr>
                                                    </thead>
                                                    <tbody className="small">
                                                        {(() => {
                                                            const bTeam = selectedMatch.score.battingTeam;
                                                            if (!bTeam) return <tr><td colSpan={9} className="text-center py-2 text-muted">Initialize innings first</td></tr>;

                                                            let battingIdx;
                                                            if (selectedMatch.innings.length > 2) {
                                                                battingIdx = selectedMatch.innings.length - 1;
                                                            } else {
                                                                battingIdx = (bTeam.trim().toLowerCase() === selectedMatch.teamB.trim().toLowerCase()) ? 1 : 0;
                                                            }

                                                            const bowlingIdx = battingIdx % 2 === 0 ? battingIdx + 1 : battingIdx - 1;
                                                            const bowlingInnings = selectedMatch.innings[bowlingIdx];
                                                            if (!bowlingInnings || !bowlingInnings.bowling || bowlingInnings.bowling.length === 0) {
                                                                return <tr><td colSpan={9} className="text-center py-2 text-muted">No bowling data yet</td></tr>;
                                                            }
                                                            return bowlingInnings.bowling.map((b, i) => (
                                                                <tr key={i}>
                                                                    <td className="ps-3 fw-bold">{toCamelCase(b.player)}</td>
                                                                    <td className="text-center">{b.overs}</td>
                                                                    <td className="text-center">{b.maidens || 0}</td>
                                                                    <td className="text-center">{b.runs}</td>
                                                                    <td className="text-center fw-bold text-danger">{b.wickets}</td>
                                                                    <td className="text-center text-muted">{b.economy}</td>
                                                                    <td className="text-center">{b.dots || 0}</td>
                                                                    <td className="text-center">{b.wides || 0}</td>
                                                                    <td className="text-center">{b.noBalls || 0}</td>
                                                                </tr>
                                                            ));
                                                        })()}
                                                    </tbody>
                                                </Table>
                                            </Card>
                                        )}

                                        {selectedMatch.toss?.winner && (
                                            <Alert variant="warning" className="text-center fw-bold">
                                                🪙 Toss won by {selectedMatch.toss.winner} and elected to {selectedMatch.toss.decision} first.
                                            </Alert>
                                        )}
                                        {selectedMatch.status === 'live' && (
                                            <div className="d-flex gap-3 mb-4 justify-content-center">
                                                <Button variant="outline-danger" className="fw-bold px-3" onClick={() => {
                                                    setRunOutOutType('striker');
                                                    setBatsmanModalType('retired');
                                                    setShowBatsmanModal(true);
                                                }}>🏥 RETIRE BATSMAN</Button>
                                                <Button variant="outline-info" className="fw-bold px-3" onClick={() => setShowBowlerModal(true)}>⚾ CHANGE BOWLER</Button>
                                                <Button variant="outline-primary" className="fw-bold px-3" onClick={fetchMatches}>🔄 MANUAL SYNC</Button>
                                            </div>
                                        )}

                                        <details className="mt-4">
                                            <summary className="btn btn-sm btn-link text-decoration-none fw-bold p-0 text-muted">🔧 Correction Panel (Manual Overrides)</summary>
                                            <Card className="mt-2 border-0 bg-light p-4 shadow-sm">
                                                <Row className="g-3">
                                                    <Col md={4}>
                                                        <Form.Label className="small fw-bold text-uppercase text-muted">Runs</Form.Label>
                                                        <Form.Control size="sm" type="number" min="0" value={selectedMatch.score.runs} onChange={e => handleUpdate('manual', { ...selectedMatch, score: { ...selectedMatch.score, runs: Math.max(0, parseInt(e.target.value) || 0) } })} />
                                                    </Col>
                                                    <Col md={4}>
                                                        <Form.Label className="small fw-bold text-uppercase text-muted">Wickets</Form.Label>
                                                        <Form.Control size="sm" type="number" min="0" max="10" value={selectedMatch.score.wickets} onChange={e => handleUpdate('manual', { ...selectedMatch, score: { ...selectedMatch.score, wickets: Math.min(10, Math.max(0, parseInt(e.target.value) || 0)) } })} />
                                                    </Col>
                                                    <Col md={4}>
                                                        <Form.Label className="small fw-bold text-uppercase text-muted">Overs</Form.Label>
                                                        <Form.Control size="sm" type="number" step="0.1" min="0" max={selectedMatch.totalOvers} value={selectedMatch.score.overs} onChange={e => handleUpdate('manual', { ...selectedMatch, score: { ...selectedMatch.score, overs: Math.min(selectedMatch.totalOvers, Math.max(0, parseFloat(e.target.value) || 0)) } })} />
                                                    </Col>
                                                    <Col md={4}>
                                                        <Form.Label className="small fw-bold text-uppercase text-muted">Title</Form.Label>
                                                        <Form.Control size="sm" value={selectedMatch.title} onChange={e => handleUpdate('manual', { ...selectedMatch, title: e.target.value })} placeholder="Match Title" />
                                                    </Col>
                                                    <Col md={4}>
                                                        <Form.Label className="small fw-bold text-uppercase text-muted">Venue</Form.Label>
                                                        <Form.Control size="sm" value={selectedMatch.venue} onChange={e => handleUpdate('manual', { ...selectedMatch, venue: e.target.value })} placeholder="Match Venue" />
                                                    </Col>
                                                    <Col md={4}>
                                                        <Form.Label className="small fw-bold text-uppercase text-muted">Total Format (Overs)</Form.Label>
                                                        <Form.Control size="sm" type="number" value={selectedMatch.totalOvers} onChange={e => handleUpdate('manual', { ...selectedMatch, totalOvers: parseInt(e.target.value) || 1 })} />
                                                    </Col>
                                                    <Col md={4}>
                                                        <Form.Label className="small fw-bold text-uppercase text-muted">Match Time</Form.Label>
                                                        <Form.Control size="sm" type="time" value={new Date(selectedMatch.date).toTimeString().slice(0, 5)} onChange={e => {
                                                            const newDate = new Date(selectedMatch.date);
                                                            const [h, m] = e.target.value.split(':');
                                                            newDate.setHours(h, m);
                                                            handleUpdate('manual', { ...selectedMatch, date: newDate.toISOString() });
                                                        }} />
                                                    </Col>

                                                    <Col md={4}>
                                                        <Form.Label className="small fw-bold text-uppercase text-muted">Striker</Form.Label>
                                                        <Form.Select size="sm" value={striker} onChange={e => { setStriker(e.target.value); handleUpdate('manual', { ...selectedMatch, currentBatsmen: selectedMatch.currentBatsmen.map((b, i) => i === 0 ? { ...b, name: e.target.value } : b) }); }}>
                                                            <option value="">Select</option>
                                                            {(selectedMatch.score.battingTeam === selectedMatch.teamA ? squadA : squadB).map(p => <option key={p} value={p}>{p}</option>)}
                                                        </Form.Select>
                                                    </Col>
                                                    <Col md={4}>
                                                        <Form.Label className="small fw-bold text-uppercase text-muted">Non-Striker</Form.Label>
                                                        <Form.Select size="sm" value={nonStriker} onChange={e => { setNonStriker(e.target.value); handleUpdate('manual', { ...selectedMatch, currentBatsmen: selectedMatch.currentBatsmen.map((b, i) => i === 1 ? { ...b, name: e.target.value } : b) }); }}>
                                                            <option value="">Select</option>
                                                            {(selectedMatch.score.battingTeam === selectedMatch.teamA ? squadA : squadB).map(p => <option key={p} value={p}>{p}</option>)}
                                                        </Form.Select>
                                                    </Col>
                                                    <Col md={4}>
                                                        <Form.Label className="small fw-bold text-uppercase text-muted">Bowler</Form.Label>
                                                        <Form.Select size="sm" value={bowler} onChange={e => { setBowler(e.target.value); handleUpdate('manual', { ...selectedMatch, currentBowler: e.target.value }); }}>
                                                            <option value="">Select</option>
                                                            {(selectedMatch.score.battingTeam === selectedMatch.teamA ? squadB : squadA).map(p => <option key={p} value={p}>{p}</option>)}
                                                        </Form.Select>
                                                    </Col>

                                                    <Col md={6}>
                                                        <Form.Label className="small fw-bold text-uppercase text-muted">Batting Team</Form.Label>
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
                                                    <Col md={6}>
                                                        <Form.Label className="small fw-bold text-uppercase text-muted">Status Override</Form.Label>
                                                        <Form.Select size="sm" value={selectedMatch.status} onChange={e => handleUpdate('manual', { ...selectedMatch, status: e.target.value })}>
                                                            <option value="upcoming">Upcoming</option>
                                                            <option value="live">Live</option>
                                                            <option value="completed">Completed</option>
                                                            <option value="cancelled">Cancelled</option>
                                                            <option value="abandoned">Abandoned</option>
                                                        </Form.Select>
                                                    </Col>
                                                </Row>
                                            </Card>
                                        </details>
                                    </Card.Body>
                                </Card>
                            ) : (<div className="text-center py-5 bg-white rounded-4 shadow-sm d-flex flex-column align-items-center border"><Spinner animation="grow" variant="primary" className="mb-4" /><h4>Ready to Score?</h4><p className="text-muted">Select a match to start updates.</p></div>)
                            }
                        </Col >
                    </Row >
                </div>
            </Container >

            {/* Super Over Modal */}
            <Modal show={showSuperOverModal} onHide={() => { }} centered backdrop="static">
                <Modal.Header className="bg-primary text-white">
                    <Modal.Title className="fw-black text-uppercase letter-spacing-2">Match Tied! Tie Break Needed</Modal.Title>
                </Modal.Header>
                <Modal.Body className="p-4 text-center">
                    <i className="bi bi-fire text-danger display-1 mb-3"></i>
                    <h4 className="fw-black mb-3 text-uppercase">It's a Super Over!</h4>
                    <p className="text-muted mb-4">
                        Both teams have scored equal runs. According to rules, a Super Over (one-over eliminator) should be played to determine the winner.
                    </p>
                    <div className="bg-light p-3 rounded-4 mb-4 text-start small">
                        <div className="mb-3">
                            <label className="fw-bold small text-uppercase text-muted mb-2">Who bats first in Super Over?</label>
                            <Form.Select
                                size="lg"
                                className="rounded-3 border-0 shadow-sm fw-bold"
                                value={superOverBattingTeam}
                                onChange={e => setSuperOverBattingTeam(e.target.value)}
                            >
                                <option value={selectedMatch?.teamA}>{selectedMatch?.teamA}</option>
                                <option value={selectedMatch?.teamB}>{selectedMatch?.teamB}</option>
                            </Form.Select>
                        </div>
                        <ul className="mb-0 text-muted">
                            <li><strong>Format:</strong> 1 over (6 balls) per side.</li>
                            <li><strong>Wickets:</strong> 2 wickets per team in SO.</li>
                            <li><strong>Repeated Ties:</strong> Subsequent SO will be played if needed.</li>
                        </ul>
                    </div>
                </Modal.Body>
                <Modal.Footer className="border-0 justify-content-center pb-4">
                    <Button variant="outline-secondary" className="px-4 fw-bold" onClick={handleDeclareTie}>
                        DECLARE DRAW / TIE
                    </Button>
                    <Button variant="primary" className="px-4 fw-black premium-btn shadow" onClick={handleStartSuperOver}>
                        START SUPER OVER
                    </Button>
                </Modal.Footer>
            </Modal>
        </>
    );
};

export default AdminDashboard;
