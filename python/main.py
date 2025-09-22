import time
import cv2
import numpy as np
import board
import adafruit_dht
from pythonosc import udp_client

def main():
    # ---- Configuración cámara ----
    cap = cv2.VideoCapture(0)
    if not cap.isOpened():
        print("Error: No se pudo abrir la cámara")
        return

    # Cliente OSC
    client = udp_client.SimpleUDPClient("127.0.0.1", 57120)

    # Parámetros para detectar esquinas
    feature_params = dict(maxCorners=100, qualityLevel=0.3, minDistance=7, blockSize=7)

    # Parámetros de Lucas-Kanade
    lk_params = dict(winSize=(15, 15), maxLevel=2,
                     criteria=(cv2.TERM_CRITERIA_EPS | cv2.TERM_CRITERIA_COUNT, 10, 0.03))

    # Primer frame
    ret, old_frame = cap.read()
    if not ret:
        print("Error: No se pudo leer el primer frame")
        return

    old_gray = cv2.cvtColor(old_frame, cv2.COLOR_BGR2GRAY)
    clahe = cv2.createCLAHE(clipLimit=2.0, tileGridSize=(8, 8))
    old_gray = clahe.apply(old_gray)
    old_gray = cv2.GaussianBlur(old_gray, (5, 5), 0)

    use_roi = False
    if use_roi:
        x1, y1, x2, y2 = 100, 200, 1000, 600
        old_gray = old_gray[y1:y2, x1:x2]

    p0 = cv2.goodFeaturesToTrack(old_gray, mask=None, **feature_params)
    frame_count = 0

    # ---- Configuración DHT ----
    dht_device = adafruit_dht.DHT11(board.D4)  # GPIO4
    ultima_lectura_dht = 0
    intervalo_dht = 10  # segundos para capa contemplativa

    try:
        while True:
            # --- Cámara ---
            ret, frame = cap.read()
            if not ret:
                break

            frame_gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
            frame_gray = clahe.apply(frame_gray)
            frame_gray = cv2.GaussianBlur(frame_gray, (5, 5), 0)

            if use_roi:
                frame_gray = frame_gray[y1:y2, x1:x2]

            if p0 is None or len(p0) == 0:
                p0 = cv2.goodFeaturesToTrack(old_gray, mask=None, **feature_params)

            # --- Cálculo de flujo óptico ---
            if p0 is not None and len(p0) > 0:
                p1, st, err = cv2.calcOpticalFlowPyrLK(old_gray, frame_gray, p0, None, **lk_params)
                if p1 is not None:
                    good_new = p1[st == 1]
                    good_old = p0[st == 1]
                    displacements = good_new - good_old
                    magnitudes = np.linalg.norm(displacements, axis=1)
                    avg_magnitude = np.median(magnitudes) if len(magnitudes) > 0 else 0.0
                else:
                    avg_magnitude = 0.0
            else:
                avg_magnitude = 0.0

            frame_count += 1
            if frame_count % 5 == 0:
                print(f"Frame {frame_count}: magnitud mediana = {avg_magnitude:.4f}")

            # --- Enviar magnitud de flujo óptico ---
            client.send_message("/flow", float(avg_magnitude))

            # --- Lectura DHT cada intervalo_dht segundos ---
            tiempo_actual = time.time()
            if tiempo_actual - ultima_lectura_dht >= intervalo_dht:
                ultima_lectura_dht = tiempo_actual
                temperatura_valida = None
                humedad_valida = None

                # Reintentos hasta 3
                for intento in range(3):
                    try:
                        temp = dht_device.temperature
                        hum = dht_device.humidity
                        if temp is not None and hum is not None:
                            temperatura_valida = float(temp)
                            humedad_valida = float(hum)
                            break  # lectura válida, salir del loop
                    except RuntimeError as e:
                        print(f"Error lectura DHT (intento {intento+1}): {e}")
                        time.sleep(0.5)

                # Enviar solo si ambos valores son válidos
                if temperatura_valida is not None and humedad_valida is not None:
                    print(f"Temp={temperatura_valida}C  Humedad={humedad_valida}%")
                    client.send_message("/temperatura", temperatura_valida)
                    client.send_message("/humedad", humedad_valida)
                else:
                    print("No se obtuvo lectura válida de DHT después de 3 intentos.")

            # Preparar siguiente frame
            old_gray = frame_gray.copy()
            p0 = cv2.goodFeaturesToTrack(old_gray, mask=None, **feature_params)

    except KeyboardInterrupt:
        print("Interrumpido por el usuario.")
    finally:
        cap.release()
        print("Cámara liberada. Programa terminado.")

if __name__ == "__main__":
    main()
