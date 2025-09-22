s.waitForBoot {
    "Servidor iniciado".postln;

    // -----------------------------
    // Flow Noise
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

        Out.ar(out, sig!2); // salida original
    }).add;

    // -----------------------------
    // FreeVerb para Flow Noise
    // -----------------------------
    SynthDef(\flowReverb, { |in=0, out=0, mix=0.5, room=0.7, damp=0.5|
        var sig = In.ar(in, 2);
        var rev = FreeVerb.ar(sig, mix: mix, room: room, damp: damp);
        Out.ar(out, rev);
    }).add;

    // -----------------------------
    // Pulsos con FreeVerb
    // -----------------------------
    SynthDef(\sensorPulseRev, { |freq=100, amp=0.3, dur=0.25, out=0|
        var env, sig, rev;

        env = EnvGen.kr(Env.perc(0.01, dur, 1, -4));
        sig = SinOsc.ar(freq) * env * amp;

        rev = FreeVerb.ar(sig, mix:0.5, room:0.8, damp:0.5);

        Out.ar(out, rev!2);
    }).add;

    // -----------------------------
    // Instancia flujo
    // -----------------------------
    s.sync;
    ~flowSynth = Synth(\flowNoise);

    // Envía flowNoise al reverb
    ~flowRev = Synth(\flowReverb, [\in, 0, \mix, 0.3, \room, 0.7, \damp, 0.5]);

    // -----------------------------
    // Listeners OSC
    // -----------------------------
    OSCFunc({ |msg, time, addr, recvPort|
        var flow, cutoff, bassFreq;
        if(msg.notEmpty) {
            flow = msg[1].asFloat;

            cutoff = flow.linlin(0, 50, 50, 4000).clip(50, 4000);
            ~flowSynth.set(\cutoff, cutoff);

            bassFreq = flow.linlin(0, 50, 40, 200).clip(40, 200);
            ~flowSynth.set(\bassFreq, bassFreq);

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
        var hum, freq;
        if(msg.notEmpty) {
            hum = msg[0].asFloat;
            freq = hum.linlin(0, 100, 60, 120);
            Synth(\sensorPulseRev, [\freq, freq, \amp, 0.2, \dur, 0.2]);
        };
    }, '/humedad');

    OSCFunc({ |msg, time, addr, recvPort|
        var temp, freq;
        if(msg.notEmpty) {
            temp = msg[0].asFloat;
            freq = temp.linlin(0, 40, 120, 200);
            Synth(\sensorPulseRev, [\freq, freq, \amp, 0.2, \dur, 0.2]);
        };
    }, '/temperatura');

    "Listeners OSC iniciados".postln;

    // -----------------------------
    // Escenas temporales
    // -----------------------------
    (
    Routine({
        loop {
            ~flowSynth.set(\amp, 0.5, \cutoff, 800);
            300.wait;

            ~flowSynth.set(\amp, 0.5, \cutoff, 2000);
            300.wait;

            ~flowSynth.set(\amp, 0.6, \cutoff, 400);
            300.wait;
        }
    }).play;
    )
};
