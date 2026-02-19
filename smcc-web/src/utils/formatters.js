export const toCamelCase = (text) => {
    if (!text) return '';
    return text.toString().trim().split(' ').map(word => {
        if (!word) return '';
        if (word.length === 1) return word.toUpperCase();
        return word.charAt(0).toUpperCase() + word.slice(1).toLowerCase();
    }).join(' ');
};
export const formatTime = (dateInput) => {
    if (!dateInput) return '';
    const date = new Date(dateInput);
    if (isNaN(date.getTime())) return '';

    // Get formatted time like "1:00 PM"
    const timeStr = date.toLocaleTimeString('en-US', {
        hour: 'numeric',
        minute: '2-digit',
        hour12: true
    });

    // Convert to "1.00 pm"
    return timeStr.replace(':', '.').toLowerCase();
};
