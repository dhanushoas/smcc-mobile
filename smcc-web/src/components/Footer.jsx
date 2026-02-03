import React from 'react';
import { Container } from 'react-bootstrap';
import { useApp } from '../AppContext';

const Footer = () => {
    const { t } = useApp();

    return (
        <footer className="py-4 mt-auto border-top bg-light">
            <Container className="text-center">
                <p className="mb-1 fw-bold text-primary">SMCC LIVE</p>
                <p className="text-muted small mb-1">
                    &copy; {new Date().getFullYear()} S Mettur Cricket Council. All rights reserved.
                </p>
                <p className="text-muted fw-bold" style={{ fontSize: '0.9rem' }}>
                    Developed by Dhanush Thangaraj
                </p>
            </Container>
        </footer>
    );
};

export default Footer;
