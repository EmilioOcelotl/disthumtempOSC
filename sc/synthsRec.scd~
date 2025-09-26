(
s.waitForBoot {
    "Servidor iniciado".postln;

    // -----------------------------
    // Flow Noise y demás SynthDefs
    // -----------------------------
    SynthDef(\flowNoise, { |amp=0.5, cutoff=500, bassFreq=80, out=0|
        var sig, cutoffLag, bass;
        cutoffLag = Lag.kr(cutoff, 1);
        sig = PinkNoise.ar(0.3);
        sig = LPF.ar(sig, cutoffLag);
        bass = SinOsc.ar(Lag.kr(bassFreq, 0.3), 0, 0.2)
             + SinOsc.ar(Lag.kr(bassFreq*0.5, 0.5), 0, 0.1);
        bass = bass * (0.8 + LFNoise1.kr(0.5).range(0.7, 1.0));
        sig = (sig * 0.8) + (bass * 0.8);
        Out.ar(out, sig!2);
    }).add;

    SynthDef(\flowReverb, { |in=0, out=0, mix=0.5, room=0.7, damp=0.5|
        var sig = In.ar(in, 2);
        var rev = FreeVerb.ar(sig, mix: mix, room: room, damp: damp);
        Out.ar(out, rev);
    }).add;

    SynthDef(\sensorPulseRev, { |freq=100, amp=0.3, dur=0.25, out=0|
        var env, sig, rev;
        env = EnvGen.kr(Env.perc(0.01, dur, 1, -4));
        sig = SinOsc.ar(freq) * env * amp;
        rev = FreeVerb.ar(sig, mix:0.5, room:0.8, damp:0.5);
        Out.ar(out, rev!2);
    }).add;

    SynthDef(\beepPulseSynth, { |freq=2500, amp=0.2, dur=0.12, wave=0, out=0|
        var sig;
        sig = Select.ar(wave, [
            Saw.ar(freq, amp),
            Pulse.ar(freq, 0.5, amp)
        ]);
        sig = sig * EnvGen.kr(Env.perc(0.001, dur, 1, 0), doneAction: 2);
        Out.ar(out, sig!2);
    }).add;

    s.sync;
    ~flowSynth = Synth(\flowNoise);
    ~flowRev = Synth(\flowReverb, [\in, 0, \mix, 0.3, \room, 0.7, \damp, 0.5]);

    // -----------------------------
    // Grabar todo el audio del servidor
    // -----------------------------
    // Creamos la ruta correctamente
    var recFile = "/home/gatxs/recordings/recording_" ++ Date.getDate.format("%d%m%y_%H%M%S") ++ ".wav";
    "Grabando en: %".format(recFile).postln;

    s.record(recFile, recLevel: 1, maxTime: 60);

    // -----------------------------
    // Listeners OSC
    // -----------------------------
    OSCFunc({ |msg, time, addr, recvPort|
        var flow, cutoff, bassFreq;
        if(msg.notEmpty) {
            flow = msg[1].asFloat;
            cutoff = flow.linlin(0, 50, 50, 4000).clip(50, 4000);
            bassFreq = flow.linlin(0, 50, 40, 200).clip(40, 200);
            ~flowSynth.set(\cutoff, cutoff, \bassFreq, bassFreq);

            if(flow > 30) {
                Synth(\sensorPulseRev, [
                    \freq, flow.linlin(30, 50, 400, 2000),
                    \amp, 0.3,
                    \dur, 0.1
                ]);
            };
        };
    }, '/flow');

    OSCFunc({ |msg, time, addr, recvPort|
        var hum, freq, amp, dur;
        if(msg.notEmpty) {
            hum = msg[0].asFloat;
            freq = hum.linlin(0, 100, 2500, 3500);
            amp  = hum.linlin(0, 100, 0.15, 0.25);
            dur  = 0.10 + (hum/100*0.08);
            Synth(\beepPulseSynth, [\freq, freq, \amp, amp, \dur, dur, \wave, 1]);
        };
    }, '/humedad');

    OSCFunc({ |msg, time, addr, recvPort|
        var temp, freq, amp, dur;
        if(msg.notEmpty) {
            temp = msg[0].asFloat;
            freq = temp.linlin(0, 40, 2600, 3800);
            amp  = temp.linlin(0, 40, 0.15, 0.25);
            dur  = 0.10 + (temp/40*0.08);
            Synth(\beepPulseSynth, [\freq, freq, \amp, amp, \dur, dur, \wave, 0]);
        };
    }, '/temperatura');

    "Listeners OSC y grabación iniciados".postln;
};
)
