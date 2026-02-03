import React, { createContext, useState, useContext, useEffect } from 'react';
import { translations } from './utils/translations';

const AppContext = createContext();

export const AppProvider = ({ children }) => {
    const [language, setLanguage] = useState(localStorage.getItem('lang') || 'en');
    const [theme, setTheme] = useState(localStorage.getItem('theme') || 'light');

    useEffect(() => {
        document.documentElement.setAttribute('data-theme', theme);
        localStorage.setItem('theme', theme);
    }, [theme]);

    useEffect(() => {
        localStorage.setItem('lang', language);
    }, [language]);

    const t = (key) => translations[language][key] || key;

    const toggleTheme = () => setTheme(prev => prev === 'light' ? 'dark' : 'light');
    const toggleLanguage = (lang) => setLanguage(lang);

    return (
        <AppContext.Provider value={{ language, theme, t, toggleTheme, toggleLanguage }}>
            {children}
        </AppContext.Provider>
    );
};

export const useApp = () => useContext(AppContext);
export { translations };
