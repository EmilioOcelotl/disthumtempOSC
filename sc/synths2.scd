s.waitForBoot {
    "=== SISTEMA ZOOM/SILENCIO CON CRACKS SELECTIVOS ===".postln;

    // -----------------------------
    // SYNTHDEFS
    // -----------------------------
    SynthDef(\vibracionBase, { |freq=60, amp=0.1, gate=1, out=0|
        var sig, env;
        env = EnvGen.kr(Env.asr(1.0, 1, 2.0), gate, doneAction: 2); // Fade más largo
        sig = SinOsc.ar(freq) * amp;
        sig = sig + (SinOsc.ar(freq * 2) * 0.1);
        sig = sig * env;
        Out.ar(out, sig!2);
    }).add;

    SynthDef(\bleepDigital, { |freq=3000, amp=0.3, dur=0.05, pan=0, out=0|
        var sig, env, click;
        env = EnvGen.kr(Env.perc(0.001, dur), doneAction: 2);
        sig = Pulse.ar(freq, 0.5) * env * amp;
        click = WhiteNoise.ar(EnvGen.kr(Env.perc(0.0001, 0.002))) * 0.3;
        sig = (sig * 0.8) + (click * 0.2);
        sig = Pan2.ar(sig, pan);
        Out.ar(out, sig);
    }).add;

    // CRACKS/GLITCHES - Solo para modo ZOOM
    SynthDef(\crackZoom, { |freq=100, amp=0.3, dur=0.08, density=8, out=0|
        var trig, sig, env;
        trig = Dust.ar(density);
        env = EnvGen.kr(Env.perc(0.001, dur), trig);
        sig = LPF.ar(WhiteNoise.ar(1), freq) * env * amp;
        sig = HPF.ar(sig, 300);
        Out.ar(out, sig!2);
    }).add;

    SynthDef(\subVibracion, { |freq=30, amp=0.15, gate=1, out=0|
        var sig, env;
        env = EnvGen.kr(Env.asr(1.5, 1, 3.0), gate, doneAction: 2); // Fade más largo
        sig = SinOsc.ar(freq) * amp;
        sig = sig * env;
        Out.ar(out, sig!2);
    }).add;

    // BEEP DE NOTIFICACIÓN
    SynthDef(\notificacionVida, { |freq=1000, amp=0.05, dur=0.12, pan=0, out=0|
        var env, sig;
        env = EnvGen.kr(Env.perc(0.005, dur, curve: -2), doneAction: 2);
        sig = SinOsc.ar(freq) * 0.7;
        sig = sig + (Pulse.ar(freq * 1.01, 0.3) * 0.3);
        sig = sig * env * amp;
        sig = Pan2.ar(sig, pan);
        Out.ar(out, sig);
    }).add;

    // SYNTH PARA FADEOUT SUAVE
    SynthDef(\fadeOut, { |out=0, dur=3.0|
        var env = EnvGen.kr(Env([1, 1, 0], [dur-0.1, 0.1], \sin), doneAction: 2);
        Out.ar(out, Silent.ar(2) * env);
    }).add;

    s.sync;

    // -----------------------------
    // VARIABLES GLOBALES
    // -----------------------------
    ~modoActual = 0;
    ~ultimoFlow = 0;
    ~ultimaTemp = 20;
    ~ultimaHum = 50;
    ~fadeOutSynth = nil;

    // Instancias persistentes
    ~vibracionBase = Synth(\vibracionBase, [\freq, 60, \amp, 0.08]);
    ~subVibracion = Synth(\subVibracion, [\freq, 35, \amp, 0.05]);

    "Synths de vibración iniciados".postln;

    // -----------------------------
    // FUNCIÓN DE MODO CON CROSSFADE Y CRACKS SELECTIVOS
    // -----------------------------
    ~cambiarModo = { |nuevoModo|
        var modos = ["NORMAL", "ZOOM", "SILENCIO"];
        var modoAnterior = ~modoActual;
        ~modoActual = nuevoModo;

        ("=== MODO CAMBIADO: " ++ modos[modoAnterior] ++ " → " ++ modos[nuevoModo] ++ " ===").postln;

        switch(nuevoModo,
            0, { // NORMAL - Solo vibración suave, SIN cracks
                // Fade in suave si veníamos de silencio
                if(modoAnterior == 2, {
                    ~vibracionBase.free; // liberar instancia previa por si quedó
                    ~subVibracion.free;
                    ~vibracionBase = Synth(\vibracionBase, [\freq, 60, \amp, 0, \gate, 1]);
                    ~subVibracion = Synth(\subVibracion, [\freq, 35, \amp, 0, \gate, 1]);
                    // Fade in progresivo
                    ~vibracionBase.set(\amp, 0.08, \freq, 60);
                    ~subVibracion.set(\amp, 0.05, \freq, 35);
                }, {
                    // Transición normal desde zoom u otro estado
                    if(~vibracionBase.isPlaying.not, {
                        ~vibracionBase = Synth(\vibracionBase, [\freq, 60, \amp, 0.08]);
                    });
                    if(~subVibracion.isPlaying.not, {
                        ~subVibracion = Synth(\subVibracion, [\freq, 35, \amp, 0.05]);
                    });
                    // asegurar amplitud de referencia
                    ~vibracionBase.set(\amp, 0.08);
                    ~subVibracion.set(\amp, 0.05);
                });
            },

            1, { // ZOOM - Vibración intensa + CRACKS
                if(~vibracionBase.isPlaying, {
                    ~vibracionBase.set(\amp, 0.12);
                }, {
                    ~vibracionBase = Synth(\vibracionBase, [\freq, 60, \amp, 0.12]);
                });
                if(~subVibracion.isPlaying, {
                    ~subVibracion.set(\amp, 0.08);
                }, {
                    ~subVibracion = Synth(\subVibracion, [\freq, 35, \amp, 0.08]);
                });

                "🎛️  CRACKS ACTIVADOS (solo en ZOOM)".postln;
            },

            2, { // SILENCIO ABSOLUTO - Con crossfade
                // Fade out suave de 3 segundos
                if(~fadeOutSynth.notNil, { ~fadeOutSynth.free });
                ~fadeOutSynth = Synth(\fadeOut, [\dur, 3.0]);

                // Apagar synths después del fade
                SystemClock.sched(3.0, {
                    if(~vibracionBase.isPlaying, { ~vibracionBase.set(\gate, 0) });
                    if(~subVibracion.isPlaying, { ~subVibracion.set(\gate, 0) });
                    "🔇 SILENCIO ABSOLUTO ACTIVADO".postln;
                });
            }
        ); // end switch
    };

    // -----------------------------
    // LISTENERS OSC - CRACKS SOLO EN ZOOM
    // -----------------------------

    // Modo del sistema
    OSCFunc({ |msg|
        var modo = msg[1].asInteger;
        if (modo != ~modoActual) {
            ~cambiarModo.(modo);
        };
    }, '/modo');

    // Flow principal - CRACKS SOLO EN ZOOM
    OSCFunc({ |msg|
        var flow = msg[1].asFloat;
        ~ultimoFlow = flow;

        if (~modoActual != 2) { // No en silencio
            var freqBase = flow.linlin(0, 30, 40, 120).clip(40, 120);
            var freqSub = flow.linlin(0, 30, 25, 60).clip(25, 60);
            var ampBase = flow.linlin(0, 30, 0.05, 0.15).clip(0.05, 0.15);

            if(~vibracionBase.isPlaying, {
                ~vibracionBase.set(\freq, freqBase, \amp, ampBase)
            });
            if(~subVibracion.isPlaying, {
                ~subVibracion.set(\freq, freqSub)
            });

            // 🎯 CRACKS SOLO EN MODO ZOOM
            if ((~modoActual == 1) && (flow > 5)) {
                Synth(\crackZoom, [
                    \freq, flow.linlin(5, 30, 500, 2500),
                    \amp, flow.linlin(5, 30, 0.1, 0.4),
                    \density, flow.linlin(5, 30, 3, 15),
                    \dur, 0.08
                ]);
            };
        };
    }, '/flow');

    // Flow raw - CRACKS EXTRAS SOLO EN ZOOM
    OSCFunc({ |msg|
        if (~modoActual == 1) { // 🎯 SOLO EN ZOOM
            var flowRaw = msg[1].asFloat;
            if ((flowRaw > 3) && (0.6.coin)) {
                Synth(\crackZoom, [
                    \freq, exprand(300, 3500),
                    \amp, flowRaw.linlin(0, 50, 0.08, 0.5),
                    \density, rrand(2, 20),
                    \dur, rrand(0.02, 0.15)
                ]);
            };
        };
    }, '/flow_raw');

    // Temperatura - Notificaciones en NORMAL y ZOOM
    OSCFunc({ |msg|
        var temp = msg[1].asFloat;
        ~ultimaTemp = temp;

        if (~modoActual != 2) { // No en silencio
            var probBleep = temp.linlin(15, 35, 0.1, 0.8);

            // Bleeps en NORMAL y ZOOM
            if (probBleep.coin) {
                Synth(\bleepDigital, [
                    \freq, temp.linlin(15, 35, 2500, 4000),
                    \amp, temp.linlin(15, 35, 0.1, 0.3),
                    \dur, 0.03,
                    \pan, 1.0.rand2
                ]);
            };

            // Notificación de vida (más suave)
            Synth(\notificacionVida, [
                \freq, temp.linlin(15, 35, 800, 1200),
                \amp, 0.04,
                \dur, 0.1,
                \pan, 0
            ]);
        };
    }, '/temperatura');

    // Humedad - Notificaciones en NORMAL y ZOOM
    OSCFunc({ |msg|
        var hum = msg[1].asFloat;
        ~ultimaHum = hum;

        if (~modoActual != 2) {
            if (0.3.coin) {
                Synth(\bleepDigital, [
                    \freq, hum.linlin(30, 80, 2000, 3500),
                    \amp, hum.linlin(30, 80, 0.15, 0.25),
                    \dur, hum.linlin(30, 80, 0.02, 0.08),
                    \pan, 1.0.rand2
                ]);
            };

            Synth(\notificacionVida, [
                \freq, hum.linlin(30, 80, 900, 1100),
                \amp, 0.03,
                \dur, 0.08,
                \pan, 0.2.rand2
            ]);
        };
    }, '/humedad');

    // -----------------------------
    // FUNCIONES DE UTILIDAD
    // -----------------------------
    ~estadoActual = {
        var modos = ["NORMAL", "ZOOM", "SILENCIO"];
        "=== ESTADO ACTUAL ===".postln;
        "Modo: %".format(modos[~modoActual]).postln;
        "Flow: %".format(~ultimoFlow.round(0.01)).postln;
        "Temp: %°C".format(~ultimaTemp).postln;
        ("Hum: " ++ ~ultimaHum.asString ++ "%").postln;
        "Cracks: %".format(if(~modoActual == 1, "ACTIVOS", "INACTIVOS")).postln;
    };

    "=== SISTEMA ZOOM/SILENCIO INICIADO ===".postln;
    "• NORMAL: Vibración + Bleeps".postln;
    "• ZOOM: Vibración intensa + CRACKS".postln;
    "• SILENCIO: Absoluto con crossfade".postln;
    "• Transiciones suaves de 3 segundos".postln;
};
