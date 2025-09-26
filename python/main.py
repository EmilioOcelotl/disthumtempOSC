import time
import cv2
import numpy as np
import board
import adafruit_dht
from pythonosc import udp_client
import random

def main():
    # ---- Configuración cámara ----
    cap = cv2.VideoCapture(0)
    if not cap.isOpened():
        print("Error: No se pudo abrir la cámara")
        return

    # Cliente OSC
    client = udp_client.SimpleUDPClient("127.0.0.1", 57120)

    # Parámetros optical flow
    feature_params = dict(maxCorners=50, qualityLevel=0.2, minDistance=10, blockSize=7)
    lk_params = dict(winSize=(21, 21), maxLevel=2,
                     criteria=(cv2.TERM_CRITERIA_EPS | cv2.TERM_CRITERIA_COUNT, 10, 0.03))

    # Primer frame
    ret, old_frame = cap.read()
    if not ret:
        print("Error: No se pudo leer el primer frame")
        return

    old_gray = cv2.cvtColor(old_frame, cv2.COLOR_BGR2GRAY)
    old_gray = cv2.GaussianBlur(old_gray, (7, 7), 0)

    p0 = cv2.goodFeaturesToTrack(old_gray, mask=None, **feature_params)
    frame_count = 0

    # ---- Configuración DHT ----
    dht_device = adafruit_dht.DHT11(board.D4)
    
    # Estados del sistema
    MODO_NORMAL = 0
    MODO_ZOOM = 1
    MODO_SILENCIO = 2
    
    modo_actual = MODO_NORMAL
    ultimo_cambio_modo = time.time()
    proximo_zoom = time.time() + random.uniform(50, 80)  # Primer zoom entre 50-80 segundos
    proximo_silencio = time.time() + random.uniform(180, 300)  # Primer silencio entre 3-5 min

    # Historial simple para detección de cambios
    flow_history = []
    max_history = 5

    print("=== SISTEMA MINIMALISTA INICIADO ===")
    print("Modo: NORMAL")
    print("Esperando primer zoom en {} segundos".format(int(proximo_zoom - time.time())))

    try:
        while True:
            current_time = time.time()
            
            # --- Gestión de modos ---
            if modo_actual == MODO_NORMAL:
                if current_time >= proximo_zoom:
                    modo_actual = MODO_ZOOM
                    ultimo_cambio_modo = current_time
                    duracion_zoom = random.uniform(6, 12)  # Zoom de 6-12 segundos
                    proximo_zoom = current_time + random.uniform(70, 120)  # Siguiente zoom
                    print("=== MODO ZOOM ACTIVADO ({}s) ===".format(int(duracion_zoom)))
                    client.send_message("/modo", 1)  # 1 = zoom
                    
            elif modo_actual == MODO_ZOOM:
                if current_time - ultimo_cambio_modo >= duracion_zoom:
                    modo_actual = MODO_NORMAL
                    ultimo_cambio_modo = current_time
                    print("=== VOLVIENDO A MODO NORMAL ===")
                    client.send_message("/modo", 0)  # 0 = normal
                    
            if current_time >= proximo_silencio and modo_actual != MODO_ZOOM:
                modo_actual = MODO_SILENCIO
                ultimo_cambio_modo = current_time
                duracion_silencio = random.uniform(20, 40)  # Silencio de 20-40 segundos
                proximo_silencio = current_time + random.uniform(240, 360)  # Siguiente silencio
                print("=== MODO SILENCIO ACTIVADO ({}s) ===".format(int(duracion_silencio)))
                client.send_message("/modo", 2)  # 2 = silencio
                
            elif modo_actual == MODO_SILENCIO:
                if current_time - ultimo_cambio_modo >= duracion_silencio:
                    modo_actual = MODO_NORMAL
                    ultimo_cambio_modo = current_time
                    print("=== FIN SILENCIO -> MODO NORMAL ===")
                    client.send_message("/modo", 0)

            # --- Cámara ---
            ret, frame = cap.read()
            if not ret:
                break

            frame_gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
            frame_gray = cv2.GaussianBlur(frame_gray, (7, 7), 0)

            if p0 is None or len(p0) == 0:
                p0 = cv2.goodFeaturesToTrack(old_gray, mask=None, **feature_params)

            # --- Cálculo de flujo óptico CRUDO ---
            raw_flow = 0.0
            if p0 is not None and len(p0) > 0:
                p1, st, err = cv2.calcOpticalFlowPyrLK(old_gray, frame_gray, p0, None, **lk_params)
                if p1 is not None and st is not None:
                    good_new = p1[st == 1]
                    good_old = p0[st == 1]
                    if len(good_new) > 0 and len(good_old) > 0:
                        displacements = good_new - good_old
                        magnitudes = np.linalg.norm(displacements, axis=1)
                        raw_flow = np.mean(magnitudes)  # Usar mean en lugar de median para más variación
                    else:
                        raw_flow = 0.0
                else:
                    raw_flow = 0.0
            else:
                raw_flow = 0.0

            # --- Envío OSC según modo ---
            if modo_actual != MODO_SILENCIO:
                # Flow base (siempre enviar, pero SC decidirá si sonificar)
                flow_processed = raw_flow * 100  # Escalar para mejor rango
                
                if modo_actual == MODO_ZOOM:
                    # En zoom, enviar datos más frecuentes y detallados
                    client.send_message("/flow", float(flow_processed))
                    # Enviar también datos "en crudo" para glitches
                    client.send_message("/flow_raw", float(raw_flow * 1000))
                else:
                    # Modo normal
                    client.send_message("/flow", float(flow_processed))

            # --- Sensor DHT (solo en modos activos) ---
            if modo_actual != MODO_SILENCIO and frame_count % 30 == 0:  # Cada ~1 segundo
                try:
                    temp = dht_device.temperature
                    hum = dht_device.humidity
                    if temp is not None and hum is not None:
                        # Enviar datos directos, sin suavizado
                        client.send_message("/temperatura", float(temp))
                        client.send_message("/humedad", float(hum))
                        
                        if frame_count % 150 == 0:  # Log cada 5 segundos
                            print("T:{}°C H:{}%".format(temp, hum))
                except RuntimeError:
                    pass  # Ignorar errores, son material glitch

            # --- Preparar siguiente frame ---
            old_gray = frame_gray.copy()
            # En modo zoom, recalcar features más frecuentemente
            if modo_actual == MODO_ZOOM or frame_count % 10 == 0:
                p0 = cv2.goodFeaturesToTrack(old_gray, mask=None, **feature_params)
            
            frame_count += 1

            # --- Debug mínimo ---
            if frame_count % 100 == 0 and modo_actual != MODO_SILENCIO:
                print("F{} M{} F:{:.3f}".format(
                    frame_count, 
                    ["NORM", "ZOOM", "SIL"][modo_actual],
                    raw_flow
                ))

            # Pausa mínima
            time.sleep(0.03)

    except KeyboardInterrupt:
        print("\n=== INTERRUMPIDO POR USUARIO ===")
    except Exception as e:
        print("\n=== ERROR: {} ===".format(e))
    finally:
        cap.release()
        print("=== CÁMARA LIBERADA ===")

if __name__ == "__main__":
    main()
