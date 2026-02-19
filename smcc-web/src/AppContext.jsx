import React, { createContext, useState, useContext, useEffect } from 'react';
import { translations } from './utils/translations';

const AppContext = createContext();

export const AppProvider = ({ children }) => {
    const [language, setLanguage] = useState(localStorage.getItem('lang') || 'en');
    useEffect(() => {
        localStorage.setItem('lang', language);
    }, [language]);

    const t = (key) => translations[language][key] || key;
    const toggleLanguage = (lang) => setLanguage(lang);

    return (
        <AppContext.Provider value={{ language, t, toggleLanguage }}>
            {children}
        </AppContext.Provider>
    );
};

export const useApp = () => useContext(AppContext);
export { translations };
