const express = require('express');
const router = express.Router();
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const User = require('../models/User');
const passport = require('passport');

// @route   POST api/auth/login
// @desc    Authenticate user & get token
// @access  Public
router.post('/login', async (req, res) => {
    const { username, password } = req.body;

    try {
        console.log(`Login attempt for username: ${username}`);
        let user = await User.findOne({ where: { username } });

        if (!user) {
            console.log('Login failed: User not found');
            return res.status(400).json({ msg: 'Invalid Credentials' });
        }

        if (!user.password) {
            console.log('Login failed: User has no password (likely OAuth user)');
            return res.status(400).json({ msg: 'This account uses Google Login. Please use "Continue with Google".' });
        }

        const isMatch = await bcrypt.compare(password, user.password);
        if (!isMatch) {
            console.log('Login failed: Incorrect password');
            return res.status(400).json({ msg: 'Invalid Credentials' });
        }

        // Single Admin Session Check
        if (user.role === 'admin' && user.isLoggedIn) {
            console.log('Login failed: Admin already logged in elsewhere');
            return res.status(403).json({
                msg: 'Another admin is currently active. Only one admin session is allowed at a time.',
                type: 'ALREADY_LOGGED_IN'
            });
        }

        // Mark as logged in
        user.isLoggedIn = true;
        await user.save();

        const jwtSecret = process.env.JWT_SECRET || 'smccsecrettoken123_fallback';
        if (!process.env.JWT_SECRET) {
            console.warn('WARNING: JWT_SECRET is not defined in environment variables. Using fallback secret.');
        }

        const payload = {
            user: {
                id: user.id,
                role: user.role
            }
        };

        jwt.sign(
            payload,
            jwtSecret,
            { expiresIn: '100h' },
            (err, token) => {
                if (err) {
                    console.error('JWT Signing Error:', err);
                    return res.status(500).json({ msg: 'Token generation failed' });
                }
                res.json({
                    token,
                    user: {
                        id: user.id,
                        role: user.role
                    }
                });
            }
        );
    } catch (err) {
        console.error('DATABASE or SERVER ERROR during login:', err);
        res.status(500).send('Server error: ' + err.message);
    }
});

// Google Auth Initiate
router.get('/google', passport.authenticate('google', { scope: ['profile', 'email'] }));

// Google Auth Callback
router.get('/google/callback', passport.authenticate('google', { failureRedirect: '/login' }), (req, res) => {
    const jwtSecret = process.env.JWT_SECRET || 'smccsecrettoken123_fallback';
    if (!process.env.JWT_SECRET) {
        console.warn('WARNING: JWT_SECRET (Google) is not defined. Using fallback.');
    }

    const payload = {
        user: {
            id: req.user.id,
            role: req.user.role
        }
    };

    jwt.sign(
        payload,
        jwtSecret,
        { expiresIn: '100h' },
        (err, token) => {
            if (err) {
                console.error('JWT Signing Error (Google):', err);
                return res.status(500).send('Token generation failed');
            }
            // Redirect to frontend with token
            const frontendUrl = process.env.FRONTEND_URL || 'http://localhost:5173';
            res.redirect(`${frontendUrl}/google-auth?token=${token}`);
        }
    );
});

// @route   POST api/auth/logout
// @desc    Logout user & clear session
// @access  Private (but we can make it public for simplicity if token is passed)
router.post('/logout', async (req, res) => {
    try {
        const { userId } = req.body;
        if (!userId) return res.status(400).json({ msg: 'User ID required' });

        const user = await User.findByPk(userId);
        if (user) {
            user.isLoggedIn = false;
            await user.save();
            return res.json({ msg: 'Logged out successfully' });
        }
        res.status(404).json({ msg: 'User not found' });
    } catch (err) {
        res.status(500).send('Server error');
    }
});

// @route   POST api/auth/reset-session
// @desc    Force reset an active session (for emergency lockouts)
// @access  Public (protected by password)
router.post('/reset-session', async (req, res) => {
    const { username, password } = req.body;
    try {
        const user = await User.findOne({ where: { username } });
        if (!user) return res.status(400).json({ msg: 'Invalid Credentials' });

        const isMatch = await bcrypt.compare(password, user.password);
        if (!isMatch) return res.status(400).json({ msg: 'Invalid Credentials' });

        user.isLoggedIn = false;
        await user.save();
        res.json({ msg: 'Session reset successfully. You can now login.' });
    } catch (err) {
        res.status(500).send('Server error');
    }
});

module.exports = router;
