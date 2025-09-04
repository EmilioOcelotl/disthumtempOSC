s.boot;

(
// -----------------------------------------------------
// 1. CONFIGURACIÓN OSC
// -----------------------------------------------------

~recvPort = 57120;

OSCdef.new(
    key: \gotas,
    path: "/sensores",
    recvPort: ~recvPort,
    func: { |msg, time, addr, recvPort|
        var raw = msg[1].asString;
        var valores = raw.split($|); // separar por "|"

        var distancia = valores[0].asFloat;    
        var humedad   = valores[1].asFloat;    
        var temp      = valores[2].asFloat;    
        var trigger   = valores[3].asInteger;

        ("Distancia: " ++ distancia 
        ++ " Humedad: " ++ humedad 
        ++ " Temp: " ++ temp 
        ++ " Trigger: " ++ trigger).postln;

        if(trigger == 1) {
            // map distancia a frecuencia (50-200 mm -> 300-1200 Hz)
            var freq = distancia.linlin(50, 200, 300, 1200);
            
            // amplitud y decay modulados por temperatura y humedad
            var amp = temp.linlin(15, 30, 0.1, 0.3);
            var decay = humedad.linlin(30, 70, 0.05, 0.3);
            
            Synth(\gota_simple, [\freq, freq, \amp, amp, \decay, decay]);
        }
    }
);

// -----------------------------------------------------
// 2. DEFINICIÓN DEL SYNTH SIMPLE
// -----------------------------------------------------
SynthDef(\gota_simple, { |freq=440, amp=0.1, decay=0.1|
    var env = EnvGen.kr(Env.perc(0.001, decay), doneAction: 2); // ataque rapidísimo
    var sig = SinOsc.ar(freq) * env * amp;
    Out.ar(0, sig!2); // estéreo
}).add;
)
