    const form = document.getElementById('auth-form');
    const toggleForm = document.getElementById('toggle-form');
    const formTitle = document.getElementById('form-title');
    const submitBtn = document.getElementById('submit-btn');
    let isLogin = true;

    const apiUrl = 'https://zago9bm7n8.execute-api.us-east-1.amazonaws.com';

    // Enhanced alert system
    function showCustomAlert(type, title, message, duration = 5000) {
      // Remove any existing alerts
      const existingAlert = document.querySelector('.custom-alert');
      if (existingAlert) {
        existingAlert.remove();
      }

      const alert = document.createElement('div');
      alert.className = `custom-alert ${type}`;
      
      const icons = {
        success: '✓',
        error: '✕',
        info: 'ⓘ'
      };

      alert.innerHTML = `
        <div class="alert-icon">${icons[type] || 'ⓘ'}</div>
        <div class="alert-content">
          <div class="alert-title">${title}</div>
          <div class="alert-message">${message}</div>
        </div>
        <button class="alert-close">×</button>
      `;

      document.body.appendChild(alert);

      // Show the alert
      setTimeout(() => alert.classList.add('show'), 10);

      // Close button functionality
      const closeBtn = alert.querySelector('.alert-close');
      closeBtn.addEventListener('click', () => hideAlert(alert));

      // Auto-hide after duration
      const timeoutId = setTimeout(() => hideAlert(alert), duration);

      // Clear timeout if manually closed
      closeBtn.addEventListener('click', () => clearTimeout(timeoutId));

      return alert;
    }

    function hideAlert(alert) {
      alert.classList.add('fade-out');
      setTimeout(() => {
        if (alert.parentNode) {
          alert.remove();
        }
      }, 400);
    }

    // Debug function
    const debugLog = (message) => {
      console.log(`[DEBUG] ${message}`);
    };

    // Toggle form functionality
    if (toggleForm) {
      toggleForm.addEventListener('click', () => {
        debugLog(`Toggling form: isLogin was ${isLogin}`);
        isLogin = !isLogin;
        formTitle.textContent = isLogin ? 'Login' : 'Sign Up';
        toggleForm.textContent = isLogin ? "Don't have an account? Sign up" : 'Already have an account? Log in';
        submitBtn.textContent = isLogin ? 'Login' : 'Sign Up';
        debugLog(`Form toggled: isLogin now ${isLogin}`);
      });
    } else {
      console.error('Toggle form element not found');
    }

    // Form submission
    if (form) {
      form.addEventListener('submit', async (e) => {
        e.preventDefault();

        const username = document.getElementById('username').value;
        const password = document.getElementById('password').value;
        const endpoint = isLogin ? '/login' : '/users';

        debugLog(`Submitting ${isLogin ? 'login' : 'signup'} for username: ${username}`);

        // Add loading state
        submitBtn.classList.add('loading');
        submitBtn.textContent = '';

        try {
          const response = await fetch(`${apiUrl}${endpoint}`, {
            method: 'POST',
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: JSON.stringify({ name: username, password }),
            mode: 'cors',
            credentials: 'same-origin',
          });

          let data;
          let clone;
          try {
            clone = response.clone();
            data = await response.json();
          // eslint-disable-next-line no-unused-vars
          } catch (err) {
            const text = await clone.text();
            console.error("Failed to parse JSON:", text);
            throw new Error('Server returned invalid response');
          }

          debugLog(`Response status: ${response.status}`);

          if (!response.ok) {
            let errorTitle = 'Request Failed';
            let errorMessage = 'Something went wrong';

            if (response.status === 403) {
              errorTitle = 'Access Forbidden';
              errorMessage = 'You don\'t have permission to access this resource. Please check with the administrator.';
            } else if (response.status === 401) {
              errorTitle = 'Authentication Failed';
              errorMessage = 'Invalid username or password. Please check your credentials and try again.';
            } else if (response.status === 400) {
              errorTitle = 'Invalid Input';
              errorMessage = data.detail || 'Please check your input data and try again.';
            } else if (response.status === 500) {
              errorTitle = 'Server Error';
              errorMessage = 'Our servers are experiencing issues. Please try again in a few moments.';
            } else {
              errorMessage = data.detail || 'An unexpected error occurred. Please try again.';
            }

            throw new Error(`${errorTitle}|${errorMessage}`);
          }

          // Success handling
          if (isLogin) {
            showCustomAlert(
              'success',
              'Welcome Back!',
              `Successfully logged in as ${username}. Ready to get started?`,
              6000
            );
          } else {
            showCustomAlert(
              'success',
              'Account Created!',
              `Welcome ${username}! Your account has been created successfully. You can now log in with your credentials.`,
              7000
            );
          }

          form.reset();

          // If signup, switch to login form after a delay
          if (!isLogin) {
            setTimeout(() => {
              isLogin = true;
              formTitle.textContent = 'Login';
              toggleForm.textContent = "Don't have an account? Sign up";
              submitBtn.textContent = 'Login';
              debugLog('Switched to login form after signup');
            }, 2000);
          }

        } catch (error) {
          debugLog(`Error occurred: ${error.message}`);
          
          let errorTitle = 'Connection Error';
          let errorMessage = error.message;

          // Parse custom error format
          if (error.message.includes('|')) {
            const parts = error.message.split('|');
            errorTitle = parts[0];
            errorMessage = parts[1];
          } else if (error.message.includes('Failed to fetch')) {
            errorTitle = 'Network Error';
            errorMessage = 'Unable to connect to the server. Please check your internet connection and try again.';
          } else if (error.message.includes('forbidden')) {
            errorTitle = 'Access Forbidden';
            errorMessage = 'Server configuration issue. Please contact the administrator for assistance.';
          }

          showCustomAlert('error', errorTitle, errorMessage, 8000);
        } finally {
          // Remove loading state
          submitBtn.classList.remove('loading');
          submitBtn.textContent = isLogin ? 'Login' : 'Sign Up';
        }
      });
    } else {
      console.error('Auth form element not found');
    }