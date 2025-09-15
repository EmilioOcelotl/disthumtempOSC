(
// Boot del servidor
s = Server.default;
s.options.device = "hw:3,0"; // tu USB Audio CODEC
s.boot;

// Esperar a que el servidor arranque completamente
s.waitForBoot {
    "Servidor iniciado. Reproduciendo tono de prueba 440Hz en USB Audio CODEC.".postln;

    // Crear SynthDef y enviar al servidor
    SynthDef(\testTone, { |freq=440, amp=0.5|
        Out.ar(0, SinOsc.ar(freq, 0, amp)!2);
    }).add;

    // Esperar a que el SynthDef esté en el servidor antes de instanciarlo
    s.sync;

    // Crear el synth
    ~testSynth = Synth(\testTone);
};
)
