// Anti-Fraud Call Interface with Continuous Voice Monitoring

requireAuth();
let socket = null;
let socketConnected = false;

// Speech Recognition
let recognition = null;
let isRecognitionRunning = false;
let shouldRestartRecognition = true;
let isCallActive = false;
let silenceTimer = null;

// Audio (initialized after Socket.IO)
let audioContext = null;
let mediaStream = null;
let analyser = null;
let silenceThreshold = 30;
let silenceDelay = 1500;
let currentAudio = null;

// PCM streaming
let audioProcessor = null;
let playbackContext = null;

// Call timer
let callStartTime = null;
let callTimerInterval = null;
let totalCallDuration = 0;
let call_api_counter = 0;
let pauseRecognitionDuringPlayback = true;

// --- Initialize Speech Recognition ---
// --- Initialize Speech Recognition ---
function initSpeechRecognition() {
    if ('webkitSpeechRecognition' in window || 'SpeechRecognition' in window) {
        const SpeechRecognition = window.SpeechRecognition || window.webkitSpeechRecognition;
        recognition = new SpeechRecognition();

        recognition.continuous = true;
        recognition.interimResults = true;
        recognition.lang = 'en-US';

        recognition.onstart = function () {
            isRecognitionRunning = true;
            console.log('Speech recognition started');
        };

        recognition.onresult = function (event) {
            const last = event.results.length - 1;
            const transcript = event.results[last][0].transcript;

            if (event.results[last].isFinal) {
                console.log('Final transcript:', transcript); // <-- Final transcript
                if (silenceTimer) clearTimeout(silenceTimer);

                silenceTimer = setTimeout(() => {
                    if (isCallActive && transcript.trim()) {
                        sendMessage(transcript.trim());
                    }
                }, silenceDelay);
            } else {
                console.log('Interim transcript:', transcript); // <-- Interim transcript
            }
        };

        recognition.onerror = function (event) {
            console.error('Speech recognition error:', event.error);

            if (event.error === 'no-speech') {
                updateStatus('Listening...', 'success');
            } else if (event.error === 'network' || event.error === 'audio-capture') {
                updateStatus('Error: ' + event.error + '. Please check microphone/network.', 'danger');
                endCall();
            } else {
                updateStatus('Error: ' + event.error, 'warning');
            }
        };

        recognition.onend = function () {
            isRecognitionRunning = false;
            console.log('Speech recognition ended');

            // Restart recognition only if call active and Socket.IO not yet connected
            if (isCallActive && shouldRestartRecognition && !socketConnected) {
                setTimeout(() => {
                    if (isCallActive && !isRecognitionRunning && shouldRestartRecognition) {
                        try { recognition.start(); }
                        catch (e) { console.warn("Recognition restart skipped"); }
                    }
                }, 300);
            }
        };

        return true;
    } else {
        console.warn('Speech Recognition not supported');
        alert('Speech Recognition is not supported in your browser. Please use Chrome or Edge.');
        return false;
    }
}


// --- UI Elements ---
const startRecordBtn = document.getElementById('startRecordBtn');
const stopRecordBtn = document.getElementById('stopRecordBtn');
const sendTextBtn = document.getElementById('sendTextBtn');
const manualInput = document.getElementById('manualInput');
const transcriptBox = document.getElementById('transcriptBox');
const recipientPhone = document.getElementById('recipientPhone');
const statusBadge = document.getElementById('statusBadge');
const clearBtn = document.getElementById('clearBtn');

// --- Event Listeners ---
startRecordBtn.addEventListener('click', startCall);
stopRecordBtn.addEventListener('click', endCall);
sendTextBtn.addEventListener('click', sendManualText);
clearBtn.addEventListener('click', clearConversation);
manualInput.addEventListener('keypress', (e) => { if (e.key === 'Enter') sendManualText(); });
document.addEventListener('DOMContentLoaded', () => { initSpeechRecognition(); });

// --- Start Call ---
async function startCall() {
    if (isCallActive || isRecognitionRunning) return;
    if (!recipientPhone.value.trim()) { alert('Enter recipient phone number'); recipientPhone.focus(); return; }

    isCallActive = true;
    shouldRestartRecognition = true;
    call_api_counter = 0;

    if (recognition) {
        try {
            recognition.start();
            updateCallUI(true);
            updateStatus('Call Active - Listening...', 'success');
            startCallTimer();
            addMessageToTranscript('system', 'Call started. Speak naturally...');
        } catch (e) { console.error("Recognition start failed:", e); }
    }
}

// --- End Call ---
// --- End call ---
function endCall() {
    isCallActive = false;

    // Stop recognition
    if (recognition) recognition.stop();
    if (silenceTimer) clearTimeout(silenceTimer);

    // Stop audio processor / media
    if (audioProcessor) { audioProcessor.disconnect(); audioProcessor = null; }
    if (mediaStream) mediaStream.getTracks().forEach(track => track.stop());
    if (audioContext) audioContext.close();
    if (currentAudio) { currentAudio.pause(); currentAudio = null; }

    // Disconnect Socket.IO if active
    if (socket && socketConnected) {
        socket.disconnect();
        socketConnected = false;
        socket = null;
        console.log('Socket.IO disconnected');
    }

    stopCallTimer();
    updateCallUI(false);
    updateStatus('Call Ended', 'secondary');

    const duration = formatDuration(totalCallDuration);
    addMessageToTranscript('system', `Call ended. Total duration: ${duration}`);
}

// --- Send message to API ---
async function sendMessage(text) {
    const phone = recipientPhone.value.trim();
    addMessageToTranscript('user', text);
    updateStatus('Processing...', 'primary');

    try {
        const bodyPayload = { phone_number: phone, prompt: text };
        if (call_api_counter === 0) bodyPayload.initiate_conversation = true;

        const response = await authenticatedFetch('/api/fraud/', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json', 'X-Installation-Id': 'web-interface' },
            body: JSON.stringify(bodyPayload)
        });

        call_api_counter += 1;
        const contentType = response.headers.get('content-type') || '';
        if (contentType.includes('application/json')) {
            const data = await response.json();
            handleJsonResponse(data);
        } else { await handleAudioResponse(response); }
    } catch (err) {
        console.error(err);
        addMessageToTranscript('system', 'Error: ' + err.message);
        updateStatus(isCallActive ? 'Call Active - Listening...' : 'Error', isCallActive ? 'success' : 'danger');
    }
}

// --- Handle JSON Response ---
function handleJsonResponse(data) {
    if (data.status === 'error' && data.error_type === 'tts_generation_error') {
        console.error('TTS generation failed:', data.error_message || '');
        addMessageToTranscript('assistant', data.message || '');
    }
    else if (data.status === 'initiate_socketio') {
        shouldRestartRecognition = false;
        isRecognitionRunning = false;
        recognition.stop();

        addMessageToTranscript('system', `Direct calling authorized: ${data.reason || ''}`);
        const call_token = data.call_token;
        console.log('Call token:', call_token);

        socket = io({ transports: ['websocket'], auth: { access_token: getAccessToken(), call_token } });

        socket.on('connect', async () => {
            console.log('Socket.IO connected');
            socketConnected = true;

            // Start real-time PCM streaming
            try {
                mediaStream = await navigator.mediaDevices.getUserMedia({ audio: true });
                audioContext = new (window.AudioContext || window.webkitAudioContext)();

                // Load AudioWorklet processor
                await audioContext.audioWorklet.addModule('/web/static/js/mic-processor.js');

                const micSource = audioContext.createMediaStreamSource(mediaStream);

                // Create AudioWorkletNode
                const micProcessor = new AudioWorkletNode(audioContext, 'mic-processor');

                // Listen to messages from the AudioWorklet
                micProcessor.port.onmessage = (event) => {
                    if (!isCallActive || !socketConnected) return;

                    const float32Array = event.data;
                    const pcm16 = float32ToInt16(float32Array);
                    const metadata = { timestamp: Date.now() };
                    socket.emit('audio_chunk', metadata, pcm16.buffer);
                };

                // Connect the graph
                micSource.connect(micProcessor);
                micProcessor.connect(audioContext.destination);

                console.log('Real-time PCM streaming started using AudioWorklet');

                initPlayback(); // for incoming audio

            } catch (err) {
                console.error('Failed to start PCM streaming:', err);
                alert('Please allow microphone access.');
            }
        });

        socket.on('disconnect', () => { socketConnected = false; });
        socket.on('audio_chunk', (metadata, chunkBuffer) => {
            const int16 = new Int16Array(chunkBuffer);
            const float32 = int16ToFloat32(int16);
            playChunk(float32);
        });
    }
}

// --- Float32 <-> Int16 conversion ---
function float32ToInt16(float32Array) {
    const int16 = new Int16Array(float32Array.length);
    for (let i = 0; i < float32Array.length; i++) int16[i] = Math.max(-1, Math.min(1, float32Array[i])) * 0x7FFF;
    return int16;
}
function int16ToFloat32(int16Array) {
    const float32 = new Float32Array(int16Array.length);
    for (let i = 0; i < int16Array.length; i++) float32[i] = int16Array[i] / 0x8000;
    return float32;
}

// --- Playback incoming audio ---
function initPlayback() { playbackContext = new (window.AudioContext || window.webkitAudioContext)(); }
function playChunk(float32Array) {
    if (!playbackContext) initPlayback();
    const buffer = playbackContext.createBuffer(1, float32Array.length, playbackContext.sampleRate);
    buffer.getChannelData(0).set(float32Array);
    const source = playbackContext.createBufferSource();
    source.buffer = buffer;
    source.connect(playbackContext.destination);
    source.start();
}

// --- Handle audio response ---
async function handleAudioResponse(response) {
    const encodedText = response.headers.get('X-Response-Text');
    const responseText = decodeURIComponent(encodedText || '');
    const audioBlob = await response.blob();
    addMessageToTranscript('assistant', responseText, audioBlob);
    if (isCallActive) playAudio(audioBlob);
}

// --- Play audio ---
function playAudio(audioBlob) {
    const audioUrl = URL.createObjectURL(audioBlob);
    currentAudio = new Audio(audioUrl);

    // Pause recognition if the flag is true
    if (pauseRecognitionDuringPlayback && recognition && isRecognitionRunning) {
        recognition.stop();
        shouldRestartRecognition = false;
        console.log('Speech recognition paused during audio playback');
    }

    currentAudio.onended = () => {
        console.log('Audio playback ended');

        // Resume recognition if the flag is true and call is active
        if (pauseRecognitionDuringPlayback && recognition && isCallActive && !isRecognitionRunning) {
            try {
                recognition.start();
                shouldRestartRecognition = true;
                console.log('Speech recognition resumed after audio playback');
            } catch (e) {
                console.warn('Failed to resume recognition:', e);
            }
        }

        if (isCallActive) updateStatus('Call Active - Listening...', 'success');
    };

    currentAudio.onerror = (e) => console.error('Audio playback error:', e);

    currentAudio.play().catch(e => console.error('Failed to play audio:', e));
}


// --- Transcript / UI Helpers ---
function addMessageToTranscript(sender, text, audioBlob = null) {
    const placeholder = transcriptBox.querySelector('.text-muted.text-center');
    if (placeholder) placeholder.remove();
    const div = document.createElement('div');
    let icon, label, className;
    if (sender === 'user') { icon = '<i class="bi bi-person-fill text-primary"></i>'; label = 'You'; className = 'message user'; }
    else if (sender === 'system') { icon = '<i class="bi bi-info-circle-fill text-info"></i>'; label = 'System'; className = 'message'; div.style.backgroundColor = '#e7f3ff'; div.style.marginLeft = '0'; div.style.marginRight = '0'; }
    else { icon = '<i class="bi bi-robot text-success"></i>'; label = 'Sarah (AI)'; className = 'message assistant'; }
    div.className = className;
    let content = `<div class="d-flex align-items-start"><div class="me-2">${icon}</div><div class="flex-grow-1"><strong>${label}:</strong><p class="mb-0 mt-1">${escapeHtml(text)}</p>`;
    if (audioBlob) { const url = URL.createObjectURL(audioBlob); content += `<audio controls class="audio-player mt-2"><source src="${url}" type="audio/mpeg">Your browser does not support audio.</audio>`; }
    content += '</div></div>';
    div.innerHTML = content;
    transcriptBox.appendChild(div);
    transcriptBox.scrollTop = transcriptBox.scrollHeight;
}

// --- UI / Timer Helpers ---
function clearConversation() { if (confirm('Clear conversation?')) transcriptBox.innerHTML = '<p class="text-muted text-center"><i class="bi bi-info-circle"></i> Start speaking or typing...</p>'; }
function updateCallUI(active) { startRecordBtn.disabled = active; stopRecordBtn.disabled = !active; recipientPhone.disabled = active; const timerContainer = document.getElementById('callTimerContainer'); if (active) { startRecordBtn.classList.add('recording'); startRecordBtn.innerHTML = '<i class="bi bi-telephone-fill"></i> Call Active'; stopRecordBtn.innerHTML = '<i class="bi bi-telephone-x-fill"></i> End Call'; if (timerContainer) timerContainer.classList.add('call-active'); } else { startRecordBtn.classList.remove('recording'); startRecordBtn.innerHTML = '<i class="bi bi-telephone-fill"></i> Start Call'; stopRecordBtn.innerHTML = '<i class="bi bi-telephone-x-fill"></i> End Call'; if (timerContainer) timerContainer.classList.remove('call-active'); } }
function updateStatus(text, type) { statusBadge.textContent = text; statusBadge.className = `badge bg-${type}`; }
function escapeHtml(text) { const div = document.createElement('div'); div.textContent = text; return div.innerHTML; }

function startCallTimer() { callStartTime = Date.now(); totalCallDuration = 0; const timerContainer = document.getElementById('callTimerContainer'); if (timerContainer) timerContainer.style.display = 'block'; callTimerInterval = setInterval(() => { const elapsed = Date.now() - callStartTime; totalCallDuration = Math.floor(elapsed / 1000); updateCallTimerDisplay(totalCallDuration); }, 100); }
function stopCallTimer() { if (callTimerInterval) { clearInterval(callTimerInterval); callTimerInterval = null; } setTimeout(() => { const timerContainer = document.getElementById('callTimerContainer'); if (timerContainer) timerContainer.style.display = 'none'; }, 3000); }
function updateCallTimerDisplay(seconds) { const hours = Math.floor(seconds / 3600), minutes = Math.floor((seconds % 3600) / 60), secs = seconds % 60; const formatted = [hours.toString().padStart(2, '0'), minutes.toString().padStart(2, '0'), secs.toString().padStart(2, '0')].join(':'); const timerElement = document.getElementById('callTimer'); if (timerElement) timerElement.textContent = formatted; }
function formatDuration(seconds) { const hours = Math.floor(seconds / 3600), minutes = Math.floor((seconds % 3600) / 60), secs = seconds % 60; if (hours > 0) return `${hours}h ${minutes}m ${secs}s`; else if (minutes > 0) return `${minutes}m ${secs}s`; else return `${secs}s`; }
function getCurrentCallDuration() { return totalCallDuration; }
function startRecording() { startCall(); }
function stopRecording() { endCall(); }
function sendManualText() { const text = manualInput.value.trim(); if (!recipientPhone.value.trim()) { alert('Enter recipient phone'); recipientPhone.focus(); return; } if (text) { sendMessage(text); manualInput.value = ''; } }
