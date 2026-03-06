class MicProcessor extends AudioWorkletProcessor {
    process(inputs) {
        const input = inputs[0][0]; // first channel
        if (input) {
            this.port.postMessage(input);
        }
        return true; // keep processor alive
    }
}

registerProcessor('mic-processor', MicProcessor);
