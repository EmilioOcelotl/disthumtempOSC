import cv2
import numpy as np
from pythonosc import udp_client

def main():
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

    # Convertir a escala de grises
    old_gray = cv2.cvtColor(old_frame, cv2.COLOR_BGR2GRAY)

    # Mejoras: aplicar CLAHE + blur
    clahe = cv2.createCLAHE(clipLimit=2.0, tileGridSize=(8, 8))
    old_gray = clahe.apply(old_gray)
    old_gray = cv2.GaussianBlur(old_gray, (5, 5), 0)

    # Región de interés (ROI) opcional
    use_roi = False  # cambia a True si quieres usarla
    if use_roi:
        x1, y1, x2, y2 = 100, 200, 1000, 600  # ajusta a tu zona
        old_gray = old_gray[y1:y2, x1:x2]

    p0 = cv2.goodFeaturesToTrack(old_gray, mask=None, **feature_params)

    frame_count = 0
    try:
        while True:
            ret, frame = cap.read()
            if not ret:
                break

            frame_gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
            frame_gray = clahe.apply(frame_gray)
            frame_gray = cv2.GaussianBlur(frame_gray, (5, 5), 0)

            if use_roi:
                frame_gray = frame_gray[y1:y2, x1:x2]

            # Re-inicializar p0 si es None o vacío
            if p0 is None or len(p0) == 0:
                p0 = cv2.goodFeaturesToTrack(old_gray, mask=None, **feature_params)

            if p0 is not None and len(p0) > 0:
                # Calcular Optical Flow
                p1, st, err = cv2.calcOpticalFlowPyrLK(old_gray, frame_gray, p0, None, **lk_params)

                if p1 is not None:
                    good_new = p1[st == 1]
                    good_old = p0[st == 1]

                    displacements = good_new - good_old
                    magnitudes = np.linalg.norm(displacements, axis=1)

                    # Usar mediana para mayor robustez
                    avg_magnitude = np.median(magnitudes) if len(magnitudes) > 0 else 0.0
                else:
                    avg_magnitude = 0.0
            else:
                avg_magnitude = 0.0

            frame_count += 1
            if frame_count % 5 == 0:
                print(f"Frame {frame_count}: magnitud mediana = {avg_magnitude:.4f}")

            # Enviar OSC cada frame
            client.send_message("/flow", float(avg_magnitude))

            # Preparar para siguiente frame
            old_gray = frame_gray.copy()
            p0 = cv2.goodFeaturesToTrack(old_gray, mask=None, **feature_params)

    except KeyboardInterrupt:
        print("Interrumpido por el usuario.")

    finally:
        cap.release()
        print("Cámara liberada. Programa terminado.")

if __name__ == "__main__":
    main()
