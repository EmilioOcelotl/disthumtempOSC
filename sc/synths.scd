s.waitForBoot {
    "Servidor iniciado".postln;

    // SynthDefs
    SynthDef(\flowNoise, { |cutoff=200, amp=0.8|
        var sig;
        sig = WhiteNoise.ar(0.5) * Crackle.ar(0.3);
        sig = LPF.ar(sig, cutoff);
        sig = sig * amp;
        Out.ar(0, sig!2);
    }).add;

    SynthDef(\sensorPulse, { |freq=100, amp=0.6, dur=0.2|
        var env = EnvGen.kr(Env.perc(0.01, dur, 1, -4), doneAction:2);
        var sig = SinOsc.ar(freq) * env * amp;
        Out.ar(0, sig!2);
    }).add;

    // ---------------------------------
    // Crear synth de flow solo después de que el server haya recibido el SynthDef
    s.sync; // espera que todos los SynthDefs estén cargados
    ~flowSynth = Synth(\flowNoise);

    // OSCFunc listeners
    OSCFunc({ |msg, time, addr, recvPort|
        if(msg.notEmpty) {
            var flow = msg[0].asFloat;
            var cutoff = flow.linlin(0, 5, 200, 2000).clip(20, 2000);
            ~flowSynth.set(\cutoff, cutoff);
        };
    }, '/flow');

    OSCFunc({ |msg, time, addr, recvPort|
        if(msg.notEmpty) {
            var hum = msg[0].asFloat;
            var freq = hum.linlin(0, 100, 60, 120);
            Synth(\sensorPulse, [\freq, freq]);
        };
    }, '/humedad');

    OSCFunc({ |msg, time, addr, recvPort|
        if(msg.notEmpty) {
            var temp = msg[0].asFloat;
            var freq = temp.linlin(0, 40, 120, 200);
            Synth(\sensorPulse, [\freq, freq]);
        };
    }, '/temperatura');

    "Listeners OSC iniciados".postln;
};
