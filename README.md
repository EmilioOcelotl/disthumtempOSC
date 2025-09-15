# opthumtempOSC

Lectura de sensores con Arduino y envío a SuperCollider vía OSC. 

## Arduino

En la carpeta arduino: cambiar arduino_secrets_example.h

## Python

Para crear el entorno en la carpeta python:

```
python3 -m venv nombreDelEntorno
```
Activar

```
source nombreDelEntorno/bin/activate
```
Instalar

```
pip install -r requirements.txt
```

## SuperCollider

Para ejecutar sclang sin pantalla: 

```
QT_QPA_PLATFORM=offscreen sclang optical.scd
```
