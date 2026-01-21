// Anti-Fraud Call Interface with Continuous Voice Monitoring

// Check authentication on page load
requireAuth();

// Speech Recognition setup
let recognition = null;
let isRecording = false;
let isCallActive = false;
let silenceTimer = null;
let audioContext = null;
let mediaStream = null;
let analyser = null;
let silenceThreshold = 30; // Adjust based on environment
let silenceDelay = 2000; // 2 seconds of silence before sending
let currentAudio = null;

// Initialize Speech Recognition
function initSpeechRecognition() {
    if ('webkitSpeechRecognition' in window || 'SpeechRecognition' in window) {
        const SpeechRecognition = window.SpeechRecognition || window.webkitSpeechRecognition;
        recognition = new SpeechRecognition();
        
        recognition.continuous = true; // Changed to continuous
        recognition.interimResults = true; // Changed to get interim results
        recognition.lang = 'en-US'; // English for anti-fraud
        
        recognition.onstart = function() {
            console.log('Speech recognition started');
        };
        
        recognition.onresult = function(event) {
            const last = event.results.length - 1;
            const transcript = event.results[last][0].transcript;
            
            if (event.results[last].isFinal) {
                console.log('Final transcript:', transcript);
                
                // Clear any existing silence timer
                if (silenceTimer) {
                    clearTimeout(silenceTimer);
                }
                
                // Set a timer to send after silence
                silenceTimer = setTimeout(() => {
                    if (isCallActive && transcript.trim()) {
                        sendMessage(transcript.trim());
                    }
                }, silenceDelay);
            } else {
                console.log('Interim transcript:', transcript);
            }
        };
        
        recognition.onerror = function(event) {
            console.error('Speech recognition error:', event.error);
            if (event.error === 'no-speech') {
                // Restart recognition if no speech detected
                if (isCallActive) {
                    setTimeout(() => {
                        if (isCallActive) {
                            recognition.start();
                        }
                    }, 100);
                }
            } else {
                updateStatus('Error: ' + event.error, 'warning');
            }
        };
        
        recognition.onend = function() {
            console.log('Speech recognition ended');
            // Automatically restart if call is still active
            if (isCallActive) {
                setTimeout(() => {
                    if (isCallActive) {
                        recognition.start();
                    }
                }, 100);
            }
        };
        
        return true;
    } else {
        console.warn('Speech Recognition not supported');
        alert('Speech Recognition is not supported in your browser. Please use Chrome or Edge.');
        return false;
    }
}

// Initialize audio monitoring for silence detection
async function initAudioMonitoring() {
    try {
        mediaStream = await navigator.mediaDevices.getUserMedia({ audio: true });
        audioContext = new (window.AudioContext || window.webkitAudioContext)();
        analyser = audioContext.createAnalyser();
        const microphone = audioContext.createMediaStreamSource(mediaStream);
        microphone.connect(analyser);
        analyser.fftSize = 512;
        
        console.log('Audio monitoring initialized');
        return true;
    } catch (error) {
        console.error('Error accessing microphone:', error);
        alert('Please allow microphone access to use this feature.');
        return false;
    }
}

// UI Elements
const startRecordBtn = document.getElementById('startRecordBtn');
const stopRecordBtn = document.getElementById('stopRecordBtn');
const sendTextBtn = document.getElementById('sendTextBtn');
const manualInput = document.getElementById('manualInput');
const transcriptBox = document.getElementById('transcriptBox');
const recipientPhone = document.getElementById('recipientPhone');
const statusBadge = document.getElementById('statusBadge');
const clearBtn = document.getElementById('clearBtn');

// Event Listeners
startRecordBtn.addEventListener('click', startCall);
stopRecordBtn.addEventListener('click', endCall);
sendTextBtn.addEventListener('click', sendManualText);
clearBtn.addEventListener('click', clearConversation);

// Allow Enter key to send manual text
manualInput.addEventListener('keypress', (e) => {
    if (e.key === 'Enter') {
        sendManualText();
    }
});

// Initialize
document.addEventListener('DOMContentLoaded', () => {
    initSpeechRecognition();
});

// Start call (continuous monitoring)
async function startCall() {
    if (!recipientPhone.value.trim()) {
        alert('Please enter a recipient phone number first!');
        recipientPhone.focus();
        return;
    }
    
    isCallActive = true;
    
    // Initialize audio monitoring and speech recognition
    const audioReady = await initAudioMonitoring();
    if (!audioReady) {
        isCallActive = false;
        return;
    }
    
    if (recognition) {
        recognition.start();
        updateCallUI(true);
        updateStatus('Call Active - Listening...', 'success');
        
        addMessageToTranscript('system', 'Call started. Speak naturally, the system will detect pauses and respond automatically.');
    } else {
        alert('Speech Recognition is not available. Please use manual input.');
        isCallActive = false;
    }
}

// End call
function endCall() {
    isCallActive = false;
    
    if (recognition) {
        recognition.stop();
    }
    
    if (silenceTimer) {
        clearTimeout(silenceTimer);
    }
    
    if (mediaStream) {
        mediaStream.getTracks().forEach(track => track.stop());
    }
    
    if (audioContext) {
        audioContext.close();
    }
    
    if (currentAudio) {
        currentAudio.pause();
        currentAudio = null;
    }
    
    updateCallUI(false);
    updateStatus('Call Ended', 'secondary');
    
    addMessageToTranscript('system', 'Call ended.');
}

// Start recording (legacy - for manual control)
function startRecording() {
    startCall();
}

// Stop recording (legacy - for manual control)
function stopRecording() {
    endCall();
}

// Send manual text
function sendManualText() {
    const text = manualInput.value.trim();
    
    if (!recipientPhone.value.trim()) {
        alert('Please enter a recipient phone number first!');
        recipientPhone.focus();
        return;
    }
    
    if (text) {
        sendMessage(text);
        manualInput.value = '';
    }
}

// Send message to API
async function sendMessage(text) {
    const phone = recipientPhone.value.trim();
    
    // Add user message to transcript
    addMessageToTranscript('user', text);
    
    // Update status
    updateStatus('Processing...', 'primary');
    
    try {
        const response = await authenticatedFetch('/api/fraud/', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'X-Installation-Id': 'web-interface'
            },
            body: JSON.stringify({
                phone_number: phone,
                prompt: text
            })
        });
        
        if (response.ok) {
            // Get response text from headers
            const responseText = response.headers.get('X-Response-Text');
            const messageId = response.headers.get('X-Message-Id');
            const conversationId = response.headers.get('X-Conversation-Id');
            
            // Get audio blob
            const audioBlob = await response.blob();
            
            // Add assistant message to transcript with audio
            addMessageToTranscript('assistant', responseText, audioBlob);
            
            // Auto-play audio if call is active
            if (isCallActive) {
                playAudio(audioBlob);
            }
            
            updateStatus('Call Active - Listening...', 'success');
            
            console.log('Message ID:', messageId);
            console.log('Conversation ID:', conversationId);
        } else {
            const errorData = await response.json();
            throw new Error(errorData.detail || 'Failed to send message');
        }
    } catch (error) {
        console.error('Error sending message:', error);
        addMessageToTranscript('system', 'Error: ' + error.message);
        
        if (isCallActive) {
            updateStatus('Call Active - Listening...', 'success');
        } else {
            updateStatus('Error', 'danger');
        }
    }
}

// Play audio response
function playAudio(audioBlob) {
    const audioUrl = URL.createObjectURL(audioBlob);
    currentAudio = new Audio(audioUrl);
    
    currentAudio.onended = function() {
        console.log('Audio playback ended');
        // Audio has finished, continue listening
        if (isCallActive) {
            updateStatus('Call Active - Listening...', 'success');
        }
    };
    
    currentAudio.onerror = function(error) {
        console.error('Audio playback error:', error);
    };
    
    currentAudio.play().catch(error => {
        console.error('Failed to play audio:', error);
    });
}

// Add message to transcript
function addMessageToTranscript(sender, text, audioBlob = null) {
    // Clear placeholder if this is the first message
    const placeholder = transcriptBox.querySelector('.text-muted.text-center');
    if (placeholder) {
        placeholder.remove();
    }
    
    const messageDiv = document.createElement('div');
    
    let icon, label, className;
    if (sender === 'user') {
        icon = '<i class="bi bi-person-fill text-primary"></i>';
        label = 'You';
        className = 'message user';
    } else if (sender === 'system') {
        icon = '<i class="bi bi-info-circle-fill text-info"></i>';
        label = 'System';
        className = 'message';
        messageDiv.style.backgroundColor = '#e7f3ff';
        messageDiv.style.marginLeft = '0';
        messageDiv.style.marginRight = '0';
    } else {
        icon = '<i class="bi bi-robot text-success"></i>';
        label = 'Sarah (AI)';
        className = 'message assistant';
    }
    
    messageDiv.className = className;
    
    let content = `
        <div class="d-flex align-items-start">
            <div class="me-2">${icon}</div>
            <div class="flex-grow-1">
                <strong>${label}:</strong>
                <p class="mb-0 mt-1">${escapeHtml(text)}</p>
    `;
    
    // Add audio player if available
    if (audioBlob) {
        const audioUrl = URL.createObjectURL(audioBlob);
        content += `
                <audio controls class="audio-player mt-2">
                    <source src="${audioUrl}" type="audio/mpeg">
                    Your browser does not support the audio element.
                </audio>
        `;
    }
    
    content += `
            </div>
        </div>
    `;
    
    messageDiv.innerHTML = content;
    transcriptBox.appendChild(messageDiv);
    
    // Auto-scroll to bottom
    transcriptBox.scrollTop = transcriptBox.scrollHeight;
}

// Clear conversation
function clearConversation() {
    if (confirm('Are you sure you want to clear the conversation?')) {
        transcriptBox.innerHTML = `
            <p class="text-muted text-center">
                <i class="bi bi-info-circle"></i> 
                Start speaking or typing to begin the conversation...
            </p>
        `;
    }
}

// Update recording UI
function updateRecordingUI(recording) {
    startRecordBtn.disabled = recording;
    stopRecordBtn.disabled = !recording;
    
    if (recording) {
        startRecordBtn.classList.add('recording');
    } else {
        startRecordBtn.classList.remove('recording');
    }
}

// Update call UI
function updateCallUI(active) {
    startRecordBtn.disabled = active;
    stopRecordBtn.disabled = !active;
    recipientPhone.disabled = active;
    
    if (active) {
        startRecordBtn.classList.add('recording');
        startRecordBtn.innerHTML = '<i class="bi bi-telephone-fill"></i> Call Active';
        stopRecordBtn.innerHTML = '<i class="bi bi-telephone-x-fill"></i> End Call';
    } else {
        startRecordBtn.classList.remove('recording');
        startRecordBtn.innerHTML = '<i class="bi bi-telephone-fill"></i> Start Call';
        stopRecordBtn.innerHTML = '<i class="bi bi-telephone-x-fill"></i> End Call';
    }
}

// Update status badge
function updateStatus(text, type) {
    statusBadge.textContent = text;
    statusBadge.className = `badge bg-${type}`;
}

// Escape HTML to prevent XSS
function escapeHtml(text) {
    const div = document.createElement('div');
    div.textContent = text;
    return div.innerHTML;
}
