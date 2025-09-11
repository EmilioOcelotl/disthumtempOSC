# main.py
import cv2
import time

def main():
    # Inicializar cámara
    cap = cv2.VideoCapture(0)  # 0 = cámara predeterminada
    if not cap.isOpened():
        print("Error: No se pudo abrir la cámara")
        return

    print("Cámara inicializada correctamente. Comenzando captura...")

    try:
        frame_count = 0
        while True:
            ret, frame = cap.read()
            if not ret:
                print("Error: No se pudo leer un frame")
                break

            frame_count += 1
            # Solo mostrar un mensaje en consola, no ventana
            print(f"Frame {frame_count} leído correctamente.")

            # Espera pequeña para no saturar la consola
            time.sleep(0.1)

    except KeyboardInterrupt:
        print("Captura interrumpida por el usuario.")

    finally:
        cap.release()
        print("Cámara liberada. Programa terminado.")

if __name__ == "__main__":
    main()
