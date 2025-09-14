// Abrir puerto OSC 57120 y escuchar mensajes en /flow
(
OSCFunc({ |msg, time, addr, recvPort|
    ("Optical Flow recibido: " ++ msg).postln;
}, '/flow');
)