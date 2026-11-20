import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';

import 'motor.dart';

/// Controla la notificación y la pantalla de bloqueo.
/// Botones: anterior, reproducir/pausar, siguiente, aleatorio y me gusta.
/// (No hay botón de "detener").
class ManejadorAudio extends BaseAudioHandler with SeekHandler {
  final MotorMusica motor;

  ManejadorAudio(this.motor) {
    _enlazar();
  }

  AudioPlayer get _p => motor.reproductor;

  void _enlazar() {
    _p.playbackEventStream.listen((_) => _transmitir(), onError: (Object _) {});
    _p.playingStream.listen((_) => _transmitir());
    _p.shuffleModeEnabledStream.listen((_) => _transmitir());
    motor.favoritosVN.addListener(_transmitir);

    _p.sequenceStateStream.listen((estado) {
      final tag = estado?.currentSource?.tag;
      if (tag is MediaItem) mediaItem.add(tag);
      final secuencia = estado?.sequence ?? const <IndexedAudioSource>[];
      queue.add(<MediaItem>[
        for (final s in secuencia)
          if (s.tag is MediaItem) s.tag as MediaItem,
      ]);
      _transmitir();
    });

    _p.durationStream.listen((d) {
      final item = mediaItem.value;
      if (item != null && d != null && item.duration != d) {
        mediaItem.add(item.copyWith(duration: d));
      }
    });
  }

  void _transmitir() {
    final suena = _p.playing;
    final id = int.tryParse(mediaItem.value?.id ?? '');
    final favorita = id != null && motor.favoritos.contains(id);
    final azar = _p.shuffleModeEnabled;

    playbackState.add(PlaybackState(
      controls: [
        MediaControl.skipToPrevious,
        if (suena) MediaControl.pause else MediaControl.play,
        MediaControl.skipToNext,
        MediaControl.custom(
          androidIcon: azar ? 'drawable/ic_azar_on' : 'drawable/ic_azar_off',
          label: 'Aleatorio',
          name: 'azar',
        ),
        MediaControl.custom(
          androidIcon: favorita ? 'drawable/ic_megusta_on' : 'drawable/ic_megusta_off',
          label: 'Me gusta',
          name: 'megusta',
        ),
      ],
      systemActions: const {
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
      },
      androidCompactActionIndices: const [0, 1, 2],
      processingState: const {
        ProcessingState.idle: AudioProcessingState.idle,
        ProcessingState.loading: AudioProcessingState.loading,
        ProcessingState.buffering: AudioProcessingState.buffering,
        ProcessingState.ready: AudioProcessingState.ready,
        ProcessingState.completed: AudioProcessingState.completed,
      }[_p.processingState]!,
      playing: suena,
      updatePosition: _p.position,
      bufferedPosition: _p.bufferedPosition,
      speed: _p.speed,
      queueIndex: _p.currentIndex,
    ));
  }

  @override
  Future<void> play() => _p.play();

  @override
  Future<void> pause() => _p.pause();

  @override
  Future<void> seek(Duration position) => _p.seek(position);

  @override
  Future<void> skipToNext() => motor.siguiente();

  @override
  Future<void> skipToPrevious() => motor.anterior();

  @override
  Future<void> skipToQueueItem(int index) => _p.seek(Duration.zero, index: index);

  @override
  Future<void> stop() async {
    await _p.stop();
    await super.stop();
  }

  @override
  Future<dynamic> customAction(String name, [Map<String, dynamic>? extras]) async {
    if (name == 'azar') {
      await motor.alternarAleatorio();
    } else if (name == 'megusta') {
      final id = int.tryParse(mediaItem.value?.id ?? '');
      if (id != null) motor.alternarFavorito(id);
    }
    return super.customAction(name, extras);
  }
}
