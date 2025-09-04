(
// Configurar el puerto OSC receptor (debe coincidir con send_port en Arduino)
OSCdef.new(
    key: \sensores,
    func: { |msg, time, addr, recvPort|
        // msg[0] es la dirección OSC "/sensores"
        // msg[1] es la cadena enviada desde Arduino
        ("Mensaje OSC recibido: " ++ msg[1]).postln;
    },
    path: "/sensores",
    recvPort: 57120
);
)