import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import 'motor.dart';
import 'utilidades.dart';

class PantallaEcualizador extends StatefulWidget {
  final MotorMusica motor;

  const PantallaEcualizador({super.key, required this.motor});

  @override
  State<PantallaEcualizador> createState() => _PantallaEcualizadorState();
}

class _PantallaEcualizadorState extends State<PantallaEcualizador> {
  // Cada valor va de -1 (bajar al máximo) a 1 (subir al máximo).
  // Se adapta solo al número de bandas que tenga tu teléfono.
  static const Map<String, List<double>> presets = {
    'Plano': [0.0, 0.0, 0.0, 0.0, 0.0],
    'Graves': [0.8, 0.5, 0.0, 0.0, 0.0],
    'Agudos': [0.0, 0.0, 0.0, 0.5, 0.8],
    'Vocal': [-0.3, 0.0, 0.6, 0.4, -0.2],
    'Rock': [0.6, 0.3, -0.2, 0.4, 0.6],
    'Pop': [-0.2, 0.3, 0.6, 0.3, -0.2],
  };

  MotorMusica get motor => widget.motor;

  Future<void> _aplicarPreset(AndroidEqualizerParameters p, List<double> valores) async {
    final n = p.bands.length;
    for (var i = 0; i < n; i++) {
      final pos = n == 1 ? 0 : (i / (n - 1) * (valores.length - 1)).round();
      final v = valores[pos];
      final ganancia = v >= 0 ? v * p.maxDecibels : -v * p.minDecibels;
      await p.bands[i].setGain(ganancia);
    }
    await motor.guardarEcualizador(p);
  }

  String _frecuencia(double hz) {
    if (hz >= 1000) {
      final k = hz / 1000;
      return '${k.toStringAsFixed(k == k.roundToDouble() ? 0 : 1)} kHz';
    }
    return '${hz.round()} Hz';
  }

  @override
  Widget build(BuildContext context) {
    final hayAudio = motor.reproductor.audioSource != null;

    return Scaffold(
      appBar: AppBar(title: const Text('Ecualizador')),
      body: !hayAudio
          ? Center(
              child: Padding(
                padding: EdgeInsets.all(28),
                child: Text(
                  'Reproduce una canción primero para poder ajustar el ecualizador.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: tSuave),
                ),
              ),
            )
          : FutureBuilder<AndroidEqualizerParameters>(
              future: motor.ecualizador.parameters,
              builder: (context, snapshot) {
                final params = snapshot.data;
                if (params == null) {
                  return Center(child: CircularProgressIndicator(color: context.acento));
                }
                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    StreamBuilder<bool>(
                      stream: motor.ecualizador.enabledStream,
                      initialData: motor.ecualizador.enabled,
                      builder: (context, snap) {
                        return SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Activar ecualizador',
                              style: TextStyle(fontWeight: FontWeight.w600)),
                          value: snap.data ?? false,
                          activeThumbColor: context.acento,
                          onChanged: (v) async {
                            await motor.ecualizador.setEnabled(v);
                            await motor.guardarEcualizadorActivo(v);
                          },
                        );
                      },
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: presets.entries.map((e) {
                        return ActionChip(
                          label: Text(e.key),
                          onPressed: () => _aplicarPreset(params, e.value),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 12),
                    ListenableBuilder(
                      listenable: motor,
                      builder: (context, _) => Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Refuerzo de graves: ${(motor.gravesRef * 100).round()}%',
                              style: const TextStyle(fontWeight: FontWeight.w600)),
                          Slider(
                            value: motor.gravesRef,
                            onChanged: (v) => motor.ajustarGraves(params, v),
                            onChangeEnd: (v) => motor.ajustarGraves(params, v, guardar: true),
                          ),
                          Text('Potenciador de volumen: +${motor.potenciadorDb.toStringAsFixed(0)} dB',
                              style: const TextStyle(fontWeight: FontWeight.w600)),
                          Slider(
                            max: 12,
                            divisions: 12,
                            value: motor.potenciadorDb,
                            onChanged: (v) => motor.ajustarPotenciador(v),
                            onChangeEnd: (v) => motor.ajustarPotenciador(v, guardar: true),
                          ),
                          Text(
                            'El potenciador sube el volumen de canciones muy bajitas. '
                            'Si notas distorsión, bájalo.',
                            style: TextStyle(color: tSuave, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    StreamBuilder<bool>(
                      stream: motor.ecualizador.enabledStream,
                      initialData: motor.ecualizador.enabled,
                      builder: (context, snap) {
                        final activo = snap.data ?? false;
                        return Opacity(
                          opacity: activo ? 1 : 0.45,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: params.bands.map((banda) {
                              return Expanded(
                                child: StreamBuilder<double>(
                                  stream: banda.gainStream,
                                  initialData: banda.gain,
                                  builder: (context, snapGanancia) {
                                    final g = (snapGanancia.data ?? 0.0)
                                        .clamp(params.minDecibels, params.maxDecibels)
                                        .toDouble();
                                    return Column(
                                      children: [
                                        Text(
                                          '${g.toStringAsFixed(1)} dB',
                                          style: TextStyle(
                                              fontSize: 11, color: tSuave),
                                        ),
                                        SizedBox(
                                          height: 240,
                                          child: RotatedBox(
                                            quarterTurns: 3,
                                            child: Slider(
                                              min: params.minDecibels,
                                              max: params.maxDecibels,
                                              value: g,
                                              onChanged: (v) => banda.setGain(v),
                                              onChangeEnd: (_) => motor.guardarEcualizador(params),
                                            ),
                                          ),
                                        ),
                                        Text(
                                          _frecuencia(banda.centerFrequency),
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                      ],
                                    );
                                  },
                                ),
                              );
                            }).toList(),
                          ),
                        );
                      },
                    ),
                  ],
                );
              },
            ),
    );
  }
}
