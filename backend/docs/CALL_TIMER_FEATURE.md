# Call Timer Feature Documentation

## Overview
The call timer feature provides real-time tracking of call duration in the AIO-Kebbi anti-fraud call interface.

## Features

### Visual Display
- **Location**: Below the call control buttons
- **Format**: HH:MM:SS (e.g., 00:03:45)
- **Style**: Large, monospace font with blue theme
- **Animation**: Subtle pulse effect during active calls

### Functionality
- ✅ Starts automatically when call begins
- ✅ Updates in real-time (every 100ms)
- ✅ Stops when call ends
- ✅ Shows total duration in end message
- ✅ Hidden when not in a call

## Usage

### Starting Timer
The timer starts automatically when you click "Start Call":
```javascript
// Timer starts at 00:00:00
startCall() → startCallTimer()
```

### During Call
- Timer updates continuously
- Format: `HH:MM:SS`
- Examples:
  - `00:00:15` - 15 seconds
  - `00:02:30` - 2 minutes 30 seconds
  - `01:15:45` - 1 hour 15 minutes 45 seconds

### Ending Call
When call ends, the system:
1. Stops the timer
2. Displays total duration in transcript
3. Hides timer after 3 seconds

## API for Future Development

### Get Current Duration
```javascript
// Returns duration in seconds
const duration = getCurrentCallDuration();
console.log(duration); // e.g., 125 (for 2m 5s)
```

### Format Duration
```javascript
// Convert seconds to readable format
const formatted = formatDuration(125);
console.log(formatted); // "2m 5s"

const formatted2 = formatDuration(3665);
console.log(formatted2); // "1h 1m 5s"
```

## Future Integration Ideas

### 1. Call Analytics
```javascript
// Track call metrics
const callData = {
    phone_number: recipientPhone.value,
    duration: getCurrentCallDuration(),
    messages_sent: messageCount,
    timestamp: callStartTime
};

// Send to analytics API
fetch('/api/analytics/call', {
    method: 'POST',
    body: JSON.stringify(callData)
});
```

### 2. Call Limits
```javascript
// Warn if call exceeds certain duration
callTimerInterval = setInterval(() => {
    const elapsed = Date.now() - callStartTime;
    totalCallDuration = Math.floor(elapsed / 1000);
    updateCallTimerDisplay(totalCallDuration);
    
    // Alert after 5 minutes
    if (totalCallDuration === 300) {
        showAlert('Call has been active for 5 minutes', 'info');
    }
    
    // Auto-end after 30 minutes
    if (totalCallDuration >= 1800) {
        endCall();
        showAlert('Call ended: Maximum duration reached', 'warning');
    }
}, 100);
```

### 3. Call History
```javascript
// Save call to history when ended
function endCall() {
    // ... existing code ...
    
    const callRecord = {
        phone: recipientPhone.value,
        duration: totalCallDuration,
        start_time: callStartTime,
        end_time: Date.now(),
        messages: conversationHistory
    };
    
    // Save to local storage or backend
    saveCallHistory(callRecord);
}
```

### 4. Billing Integration
```javascript
// Calculate cost based on duration
function calculateCallCost(durationSeconds) {
    const ratePerMinute = 0.10; // $0.10 per minute
    const minutes = Math.ceil(durationSeconds / 60);
    return (minutes * ratePerMinute).toFixed(2);
}

// Display cost when call ends
const cost = calculateCallCost(totalCallDuration);
addMessageToTranscript('system', `Call cost: $${cost}`);
```

### 5. Real-time Statistics Dashboard
```javascript
// Send periodic updates to dashboard
setInterval(() => {
    if (isCallActive) {
        updateDashboard({
            active_calls: 1,
            current_duration: getCurrentCallDuration(),
            phone_number: recipientPhone.value
        });
    }
}, 5000); // Every 5 seconds
```

## Technical Details

### Variables
```javascript
let callStartTime = null;      // Timestamp when call started
let callTimerInterval = null;   // Interval ID for timer updates
let totalCallDuration = 0;      // Duration in seconds
```

### Timer Resolution
- **Update Frequency**: 100ms (10 times per second)
- **Display Precision**: 1 second
- **Why 100ms**: Smooth display updates without performance impact

### Performance
- Minimal CPU usage
- Updates only DOM element text
- No memory leaks (interval cleared on end)

## CSS Customization

### Change Timer Color
```css
#callTimer {
    color: #your-color-here;
}
```

### Adjust Animation Speed
```css
.call-active #callTimer {
    animation: pulse-timer 1s infinite; /* Change 2s to 1s */
}
```

### Hide Timer Completely
```css
#callTimerContainer {
    display: none !important;
}
```

## Testing

### Manual Test
1. Start a call
2. Timer should appear and start from 00:00:00
3. Wait and verify it counts up correctly
4. End call
5. Check transcript shows correct duration
6. Timer should disappear after 3 seconds

### Console Test
```javascript
// In browser console during call:
getCurrentCallDuration(); // Check current duration
formatDuration(getCurrentCallDuration()); // Check formatting
```

## Troubleshooting

### Timer Not Showing
- Check if `callTimerContainer` element exists in HTML
- Verify `startCallTimer()` is called in `startCall()`
- Check CSS display property

### Timer Not Updating
- Verify `callTimerInterval` is set
- Check browser console for errors
- Ensure `isCallActive` is true

### Incorrect Duration
- Check `callStartTime` is set correctly
- Verify `Date.now()` is working
- Console log `totalCallDuration` value

## Browser Compatibility
- ✅ Chrome/Edge: Full support
- ✅ Firefox: Full support
- ✅ Safari: Full support
- ✅ Mobile browsers: Full support

## Dependencies
- No external libraries required
- Uses native JavaScript Date API
- DOM manipulation only

---

**Ready for integration with backend analytics, billing, and monitoring systems!** 📊
