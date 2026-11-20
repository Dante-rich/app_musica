# app_musica

# 🎵 SoundThread

Reproductor de música **local** para Android, hecho con Flutter. Lee las canciones que ya tienes en tu teléfono: sin cuentas, sin anuncios y sin conexión a internet.

> Desarrollado por **Lemus. C** · Guadalajara, México · Versión 1.0.1

## ✨ Características

**Reproducción**
- Crossfade real entre canciones (dos reproductores que se mezclan), compatible con aleatorio y repetir.
- Ecualizador, refuerzo de graves y potenciador de volumen.
- Velocidad y tono ajustables.
- Letras sincronizadas desde archivos `.lrc`.
- Doble toque sobre la carátula para saltar 10 s.
- Temporizador de sueño y cola editable (se puede guardar como lista).

**Visual**
- Visualizador de espectro en tiempo real sobre la carátula.
- Tema claro, oscuro o automático, y modo AMOLED.
- Color de acento libre (selector de color), o tomado de la carátula.
- Pantalla de arranque e icono propios.

**Biblioteca**
- Búsqueda global que ignora acentos y mayúsculas (canciones, artistas, álbumes, carpetas).
- Editor de etiquetas y carátulas dentro de la app (no modifica tus archivos).
- Filtros: carpetas bloqueadas, ocultar ruido (notas de voz, tonos) y modo manual.
- Listas inteligentes: nunca escuchadas, nuevas, top 50, olvidadas, favoritas, largas y cortas.
- Estadísticas con el **tiempo real** escuchado.
- Arranque instantáneo gracias a una copia local de la biblioteca.

**Notificación y pantalla de bloqueo**
- Controles con anterior, play/pausa, siguiente, **aleatorio** y **me gusta**.
- Opciones para mantener la notificación al pausar y usar el color de la carátula.

## 🔒 Privacidad

- La app **no pide acceso a internet** ni recopila datos.
- Todo (favoritos, conteos, ajustes, etiquetas) se guarda solo en tu teléfono.
- Permisos que usa:
  - **Audio / almacenamiento:** para encontrar tus canciones.
  - **Notificaciones:** para los controles en la barra y la pantalla de bloqueo.
  - **Micrófono:** únicamente para animar el visualizador de espectro. No graba ni guarda audio.

## 🛠️ Tecnologías

- [Flutter](https://flutter.dev) (Material 3) y Dart
- [`just_audio`](https://pub.dev/packages/just_audio) y [`audio_service`](https://pub.dev/packages/audio_service)
- [`on_audio_query`](https://pub.dev/packages/on_audio_query)
- [`permission_handler`](https://pub.dev/packages/permission_handler)
- [`shared_preferences`](https://pub.dev/packages/shared_preferences), [`path_provider`](https://pub.dev/packages/path_provider)
- [`image_picker`](https://pub.dev/packages/image_picker), [`share_plus`](https://pub.dev/packages/share_plus)
- Código nativo en Kotlin para el visualizador (Android `Visualizer`)

## 🚀 Cómo ejecutarla

Necesitas [Flutter](https://docs.flutter.dev/get-started/install) instalado y un teléfono Android (o emulador) con música.

```bash
git clone https://github.com/TU_USUARIO/TU_REPOSITORIO.git
cd TU_REPOSITORIO
flutter pub get
flutter run
```

## 📦 Generar el APK

```bash
flutter build apk --release
```

El archivo queda en `build/app/outputs/flutter-apk/app-release.apk`.

> Para publicar, firma el APK con tu propia llave. **Nunca subas tu archivo `.jks` ni `key.properties` a GitHub** (agrégalos a `.gitignore`).

## 🗂️ Estructura principal

```
lib/
├── main.dart                 # Arranque, tema y navegación
├── motor.dart                # Lógica: reproducción, biblioteca, crossfade
├── manejador_audio.dart      # Notificación y controles del sistema
├── pantalla_*.dart           # Pantallas (inicio, biblioteca, reproductor, ajustes…)
├── componentes.dart          # Widgets reutilizables
└── utilidades.dart           # Colores, búsqueda y utilidades
android/                      # Configuración nativa (manifiesto, visualizador, íconos)
```

## 🗺️ Ideas a futuro

- Widget para la pantalla de inicio
- Historial de reproducción
- Páginas de artista y álbum
- Reanudar automáticamente al conectar auriculares o Bluetooth

## 📄 Licencia

Elige una licencia antes de publicar (por ejemplo MIT) y reemplaza este texto. Si no pones ninguna, el código queda con todos los derechos reservados.

---

Hecho con cariño por **Lemus. C** 🎧
