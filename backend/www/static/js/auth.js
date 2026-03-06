// Authentication utilities for AIO-Kebbi

// Check if user is logged in
function isLoggedIn() {
    return localStorage.getItem('accessToken') !== null;
}

// Get access token
function getAccessToken() {
    return localStorage.getItem('accessToken');
}

// Logout function
function logout() {
    localStorage.removeItem('accessToken');
    window.location.href = '/login';
}

// Update navbar based on login status
function updateNavbar() {
    const loggedIn = isLoggedIn();
    const callNavItem = document.getElementById('callNavItem');
    const logoutNavItem = document.getElementById('logoutNavItem');
    
    if (callNavItem && logoutNavItem) {
        if (loggedIn) {
            callNavItem.style.display = 'block';
            logoutNavItem.style.display = 'block';
        } else {
            callNavItem.style.display = 'none';
            logoutNavItem.style.display = 'none';
        }
    }
}

// Protect pages that require authentication
function requireAuth() {
    if (!isLoggedIn()) {
        window.location.href = '/login';
    }
}

// Initialize on page load
document.addEventListener('DOMContentLoaded', () => {
    updateNavbar();
});

// API request helper with authentication
async function authenticatedFetch(url, options = {}) {
    const token = getAccessToken();
    
    if (!token) {
        throw new Error('No access token found');
    }
    
    const headers = {
        ...options.headers,
        'Authorization': `Bearer ${token}`
    };
    
    const response = await fetch(url, {
        ...options,
        headers
    });
    
    // If unauthorized, redirect to login
    if (response.status === 401) {
        logout();
        throw new Error('Unauthorized - please login again');
    }
    
    return response;
}
