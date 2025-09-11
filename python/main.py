import cv2
import numpy as np

def main():
    cap = cv2.VideoCapture(0)
    if not cap.isOpened():
        print("Error: No se pudo abrir la cámara")
        return

    feature_params = dict(maxCorners=100, qualityLevel=0.3, minDistance=7, blockSize=7)
    lk_params = dict(winSize=(15, 15), maxLevel=2,
                     criteria=(cv2.TERM_CRITERIA_EPS | cv2.TERM_CRITERIA_COUNT, 10, 0.03))

    ret, old_frame = cap.read()
    if not ret:
        print("Error: No se pudo leer el primer frame")
        return

    old_gray = cv2.cvtColor(old_frame, cv2.COLOR_BGR2GRAY)
    p0 = cv2.goodFeaturesToTrack(old_gray, mask=None, **feature_params)

    # Define tu umbral de movimiento
    movement_threshold = 2.0  # ajusta según la sensibilidad deseada

    try:
        while True:
            ret, frame = cap.read()
            if not ret:
                break

            frame_gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
            p1, st, err = cv2.calcOpticalFlowPyrLK(old_gray, frame_gray, p0, None, **lk_params)

            if p1 is not None:
                good_new = p1[st == 1]
                good_old = p0[st == 1]

                displacements = good_new - good_old
                magnitudes = np.linalg.norm(displacements, axis=1)

                avg_magnitude = np.mean(magnitudes) if len(magnitudes) > 0 else 0.0

                # Umbral: evento de movimiento
                if avg_magnitude > movement_threshold:
                    print(1)
                else:
                    print(0)

            old_gray = frame_gray.copy()
            p0 = cv2.goodFeaturesToTrack(old_gray, mask=None, **feature_params)

    except KeyboardInterrupt:
        print("Interrumpido por el usuario.")

    finally:
        cap.release()
        print("Cámara liberada. Programa terminado.")

if __name__ == "__main__":
    main()
