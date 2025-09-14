// Recibir Optical Flow de Python
OSCFunc({ |msg, time, addr, recvPort|
    ("Optical Flow recibido: " ++ msg).postln;
}, '/flow');

// Recibir datos de Arduino
OSCFunc({ |msg, time, addr, recvPort|
    ("Mensaje Arduino recibido: " ++ msg).postln;
}, '/sensores');