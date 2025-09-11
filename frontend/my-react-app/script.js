const form = document.getElementById('auth-form');
const toggleForm = document.getElementById('toggle-form');
const formTitle = document.getElementById('form-title');
let isLogin = true;



const apiUrl = 'https://bl1t01glhj.execute-api.us-east-1.amazonaws.com';

// Debug function to log issues
const debugLog = (message) => {
    console.log(`[DEBUG] ${message}`);
};
     
// Ensure toggleForm exists before adding event listener
if (toggleForm) {
    toggleForm.addEventListener('click', () => {
        debugLog(`Toggling form: isLogin was ${isLogin}`);
        isLogin = !isLogin;
        formTitle.textContent = isLogin ? 'Login' : 'Sign Up';
        toggleForm.textContent = isLogin ? "Don't have an account? Sign up" : 'Already have an account? Log in';
        debugLog(`Form toggled: isLogin now ${isLogin}`);
    });
} else {
    console.error('Toggle form element not found');
}

// Ensure form exists before adding event listener
if (form) {
    form.addEventListener('submit', async (e) => {
        e.preventDefault();

        const username = document.getElementById('username').value;
        const password = document.getElementById('password').value;
        const endpoint = isLogin ? '/login' : '/users';

        debugLog(`Submitting ${isLogin ? 'login' : 'signup'} for username: ${username}`);

        try {
            const response = await fetch(`${apiUrl}${endpoint}`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                    'Accept': 'application/json',
                },
                body: JSON.stringify({ name: username, password }),
                mode: 'cors', // Explicitly set CORS mode
                credentials: 'same-origin', // Adjust if needed based on auth requirements
            });

            let data;
            let clone
            try {
                clone = response.clone();
                data = await response.json();
            } catch (err) {
                const text = await clone.text();
                console.error("Failed to parse JSON:", text);
                return;
            }

            debugLog(`Response status: ${response.status}`);

            if (!response.ok) {
                if (response.status === 403) {
                    throw new Error('Access forbidden: Check CORS settings or server permissions');
                } else if (response.status === 401) {
                    throw new Error('Invalid username or password');
                } else if (response.status === 400) {
                    throw new Error(data.detail || 'Invalid input data');
                } else if (response.status === 500) {
                    throw new Error('Server error, please try again later');
                } else {
                    throw new Error(data.detail || 'Something went wrong');
                }
            }

            // Success messages
            if (isLogin) {
                alert(`Login successful! Welcome, ${username}!`);
            } else {
                alert('Signup successful! You can now log in with your credentials.');
            }
            form.reset();

            // If signup, switch to login form
            if (!isLogin) {
                isLogin = true;
                formTitle.textContent = 'Login';
                toggleForm.textContent = "Don't have an account? Sign up";
                debugLog('Switched to login form after signup');
            }

        } catch (error) {
            debugLog(`Error occurred: ${error.message}`);
            if (error.message.includes('Failed to fetch')) {
                alert('Network error: Unable to connect to the server. Check your internet connection or server CORS settings.');
            } else if (error.message.includes('forbidden')) {
                alert('Error: Access forbidden. Please check server CORS configuration or contact the administrator.');
            } else {
                alert(`Error: ${error.message}`);
            }
        }
    });
} else {
    console.error('Auth form element not found');
}