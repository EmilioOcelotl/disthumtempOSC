s.waitForBoot {
    "Servidor iniciado".postln;

    // SynthDefs
    SynthDef(\flowNoise, { |cutoff=200, amp=0.8, lagTime=1, bassFreq=80|
        var sig, cutoffLag, bass;

        // suaviza cutoff
        cutoffLag = Lag.kr(cutoff, lagTime);

        // ruido filtrado
        sig = WhiteNoise.ar(0.5) * Crackle.ar(0.3);
        sig = LPF.ar(sig, cutoffLag);

        // seno grave
        bass = SinOsc.ar(Lag.kr(bassFreq, 0.3), 0, 0.3);

        // mezcla
        sig = (sig * amp) + bass;

        Out.ar(0, sig!2);
    }).add;

    SynthDef(\sensorPulse, { |freq=100, amp=0.6, dur=0.2|
        var env = EnvGen.kr(Env.perc(0.01, dur, 1, -4), doneAction:2);
        var sig = SinOsc.ar(freq) * env * amp;
        Out.ar(0, sig!2);
    }).add;

    // ---------------------------------
    // Crear synth de flow solo después de que el server haya recibido el SynthDef
    s.sync;
    ~flowSynth = Synth(\flowNoise);

    // OSCFunc listeners
    OSCFunc({ |msg, time, addr, recvPort|
        var flow, cutoff, bassFreq;
        if(msg.notEmpty) {
            flow = msg[1].asFloat;

            // cutoff para el filtro
            cutoff = flow.linlin(0, 50, 20, 2000).clip(20, 2000);
            ~flowSynth.set(\cutoff, cutoff);

            // mapear flow también a frecuencias graves
            bassFreq = flow.linlin(0, 50, 40, 200).clip(40, 200);
            ~flowSynth.set(\bassFreq, bassFreq);
        };
    }, '/flow');

    OSCFunc({ |msg, time, addr, recvPort|
        var hum, freq;
        if(msg.notEmpty) {
            hum = msg[0].asFloat;
            freq = hum.linlin(0, 100, 60, 120);
            Synth(\sensorPulse, [\freq, freq]);
        };
    }, '/humedad');

    OSCFunc({ |msg, time, addr, recvPort|
        var temp, freq;
        if(msg.notEmpty) {
            temp = msg[0].asFloat;
            freq = temp.linlin(0, 40, 120, 200);
            Synth(\sensorPulse, [\freq, freq]);
        };
    }, '/temperatura');

    "Listeners OSC iniciados".postln;
};
