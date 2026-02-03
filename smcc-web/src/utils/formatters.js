export const toCamelCase = (text) => {
    if (!text) return '';
    return text.toString().trim().split(' ').map(word => {
        if (!word) return '';
        if (word.length === 1) return word.toUpperCase();
        return word.charAt(0).toUpperCase() + word.slice(1).toLowerCase();
    }).join(' ');
};
