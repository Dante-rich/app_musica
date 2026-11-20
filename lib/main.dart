import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:audio_service/audio_service.dart';
import 'package:just_audio_platform_interface/just_audio_platform_interface.dart'
    show JustAudioPlatform;

import 'componentes.dart';
import 'manejador_audio.dart';
import 'motor.dart';
import 'pantalla_ajustes.dart';
import 'pantalla_bienvenida.dart';
import 'pantalla_biblioteca.dart';
import 'pantalla_inicio.dart';
import 'pantalla_reproductor.dart';
import 'registro_errores.dart';
import 'utilidades.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  RegistroErrores.instalar();
  RegistroErrores.anotar('Inicio', 'La app arrancó desde cero (v$kVersionApp)');
  // Se guarda la plataforma de audio original para el segundo reproductor del crossfade.
  plataformaAudioOriginal = JustAudioPlatform.instance;
  // Opciones de la notificación elegidas en Ajustes (se leen al abrir la app).
  final prefs = await SharedPreferences.getInstance();
  final mantener = prefs.getBool('notif_mantener') ?? false;
  final fija = (prefs.getBool('notif_ongoing') ?? true) && !mantener;
  final colorGuardado = prefs.getInt('color_acento');
  final colorNotif = ((prefs.getBool('notif_usar_color') ?? false) && colorGuardado != null)
      ? Color(colorGuardado)
      : null;
  final motor = MotorMusica();
  motor.esperandoBienvenida.value = !(prefs.getBool('bienvenida_vista') ?? false);
  await AudioService.init(
    builder: () => ManejadorAudio(motor),
    config: AudioServiceConfig(
      androidNotificationChannelId: 'com.mimusica.audio',
      androidNotificationChannelName: 'Reproducción de música',
      androidNotificationOngoing: fija,
      androidStopForegroundOnPause: !mantener,
      notificationColor: colorNotif,
    ),
  );
  runApp(AppMusica(motor: motor));
}

ThemeData construirTema(Color acento, bool amoled, bool claro) {
  final fondo = claro
      ? const Color(0xFFEFEDF5)
      : (amoled ? Colors.black : const Color(0xFF101014));
  final panel = claro
      ? Colors.white
      : (amoled ? const Color(0xFF111114) : const Color(0xFF1B1B22));
  final sobreAcento =
      ThemeData.estimateBrightnessForColor(acento) == Brightness.dark ? Colors.white : Colors.black;
  final velo = claro ? Colors.black : Colors.white;

  return ThemeData(
    useMaterial3: true,
    brightness: claro ? Brightness.light : Brightness.dark,
    scaffoldBackgroundColor: fondo,
    colorScheme: claro
        ? ColorScheme.light(
            primary: acento,
            onPrimary: sobreAcento,
            secondary: acento,
            surface: panel,
            onSurface: const Color(0xFF1B1B22),
          )
        : ColorScheme.dark(
            primary: acento,
            onPrimary: sobreAcento,
            secondary: acento,
            surface: panel,
          ),
    appBarTheme: AppBarTheme(backgroundColor: fondo, surfaceTintColor: Colors.transparent),
    sliderTheme: SliderThemeData(
      activeTrackColor: acento,
      thumbColor: acento,
      inactiveTrackColor: velo.withValues(alpha: 0.12),
      overlayColor: acento.withValues(alpha: 0.15),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Color.alphaBlend(velo.withValues(alpha: 0.03), fondo),
      indicatorColor: acento.withValues(alpha: 0.22),
    ),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.fixed),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: panel,
      surfaceTintColor: Colors.transparent,
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: Color.alphaBlend(acento.withValues(alpha: 0.08), panel),
      surfaceTintColor: Colors.transparent,
    ),
  );
}

class AppMusica extends StatefulWidget {
  final MotorMusica motor;

  const AppMusica({super.key, required this.motor});

  @override
  State<AppMusica> createState() => _AppMusicaState();
}

class _AppMusicaState extends State<AppMusica> with WidgetsBindingObserver {
  MotorMusica get motor => widget.motor;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    motor.iniciar();
  }

  @override
  void didChangePlatformBrightness() {
    // En modo automático, sigue al teléfono cuando cambia de claro a oscuro.
    if (motor.modoTema.value == 0 && mounted) setState(() {});
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    motor.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: motor.tema,
      builder: (context, _) {
        final dinamico = motor.acentoDinamico.value;
        final acento = (motor.usarDinamico.value && dinamico != null)
            ? dinamico
            : motor.acentoBase.value;
        final modo = motor.modoTema.value;
        final claro = modo == 1 ||
            (modo == 0 &&
                WidgetsBinding.instance.platformDispatcher.platformBrightness ==
                    Brightness.light);
        modoClaroActivo = claro;
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: kNombreApp,
          themeAnimationDuration: const Duration(milliseconds: 500),
          theme: construirTema(acento, motor.amoled.value, claro),
          home: ValueListenableBuilder<bool>(
            valueListenable: motor.esperandoBienvenida,
            builder: (context, esperando, _) => esperando
                ? PantallaBienvenida(motor: motor)
                : PantallaPrincipal(motor: motor),
          ),
        );
      },
    );
  }
}

class PantallaPrincipal extends StatefulWidget {
  final MotorMusica motor;

  const PantallaPrincipal({super.key, required this.motor});

  @override
  State<PantallaPrincipal> createState() => _PantallaPrincipalState();
}

class _PantallaPrincipalState extends State<PantallaPrincipal> {
  final GlobalKey<EstadoBiblioteca> _claveBiblioteca = GlobalKey<EstadoBiblioteca>();
  StreamSubscription<String>? _subAvisos;
  int _indice = 0;

  @override
  void initState() {
    super.initState();
    // Los avisos del motor se muestran como mensajes en pantalla.
    _subAvisos = widget.motor.avisos.listen((texto) {
      if (!mounted) return;
      final m = ScaffoldMessenger.of(context);
      m.hideCurrentSnackBar();
      m.showSnackBar(SnackBar(content: Text(texto)));
    });
  }

  @override
  void dispose() {
    _subAvisos?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final motor = widget.motor;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        // "Atrás": primero cierra detalles/selección de la biblioteca,
        // luego vuelve a Inicio y por último sale de la app.
        if (_indice == 1 && _claveBiblioteca.currentState?.retroceder() == true) return;
        if (_indice != 0) {
          setState(() => _indice = 0);
          return;
        }
        SystemNavigator.pop();
      },
      child: Scaffold(
        body: Column(
          children: [
            Expanded(
              child: IndexedStack(
                index: _indice,
                children: [
                  PantallaInicio(
                    motor: motor,
                    alIrABiblioteca: () => setState(() => _indice = 1),
                  ),
                  PantallaBiblioteca(key: _claveBiblioteca, motor: motor),
                  PantallaAjustes(motor: motor),
                ],
              ),
            ),
            MiniReproductor(
              motor: motor,
              alAbrir: () => abrirReproductor(context, motor),
            ),
          ],
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _indice,
          onDestinationSelected: (i) => setState(() => _indice = i),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home_rounded),
              label: 'Inicio',
            ),
            NavigationDestination(
              icon: Icon(Icons.library_music_outlined),
              selectedIcon: Icon(Icons.library_music_rounded),
              label: 'Biblioteca',
            ),
            NavigationDestination(
              icon: Icon(Icons.tune_rounded),
              label: 'Ajustes',
            ),
          ],
        ),
      ),
    );
  }
}
