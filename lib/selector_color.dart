import 'package:flutter/material.dart';

import 'utilidades.dart';

/// Hoja para elegir CUALQUIER color: barras de tono, intensidad y brillo,
/// o escribiendo el código hexadecimal (por ejemplo FF8800).
Future<Color?> pedirColor(BuildContext context, Color inicial) {
  return showModalBottomSheet<Color>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => _HojaColor(inicial: inicial),
  );
}

class _HojaColor extends StatefulWidget {
  final Color inicial;
  const _HojaColor({required this.inicial});

  @override
  State<_HojaColor> createState() => _EstadoHojaColor();
}

class _EstadoHojaColor extends State<_HojaColor> {
  // Brillo mínimo para que el color siempre se vea sobre el fondo oscuro.
  static const double _brilloMin = 0.30;

  late HSVColor _hsv;
  late final TextEditingController _hex;

  @override
  void initState() {
    super.initState();
    final h = HSVColor.fromColor(widget.inicial);
    _hsv = h.withValue(h.value < _brilloMin ? _brilloMin : h.value);
    _hex = TextEditingController(text: _aHex(_hsv.toColor()));
  }

  @override
  void dispose() {
    _hex.dispose();
    super.dispose();
  }

  String _aHex(Color c) =>
      (c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase();

  void _cambiar(HSVColor nuevo) {
    setState(() {
      _hsv = nuevo;
      _hex.text = _aHex(nuevo.toColor());
    });
  }

  void _desdeHex(String texto) {
    final t = texto.replaceAll('#', '').trim();
    if (t.length != 6) return;
    final v = int.tryParse(t, radix: 16);
    if (v == null) return;
    final h = HSVColor.fromColor(Color(0xFF000000 | v));
    setState(() => _hsv = h.withValue(h.value < _brilloMin ? _brilloMin : h.value));
  }

  Widget _barra({
    required String titulo,
    required List<Color> colores,
    required double valor,
    required double minimo,
    required double maximo,
    required ValueChanged<double> alCambiar,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titulo, style: TextStyle(color: tSuave, fontSize: 12)),
          const SizedBox(height: 6),
          SizedBox(
            height: 28,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  height: 14,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    gradient: LinearGradient(colors: colores),
                  ),
                ),
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 14,
                    activeTrackColor: Colors.transparent,
                    inactiveTrackColor: Colors.transparent,
                    thumbColor: Colors.white,
                    overlayColor: tBorde,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 12),
                  ),
                  child: Slider(
                    min: minimo,
                    max: maximo,
                    value: valor.clamp(minimo, maximo).toDouble(),
                    onChanged: alCambiar,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final color = _hsv.toColor();
    final tono = [
      for (var h = 0; h <= 360; h += 60) HSVColor.fromAHSV(1, h.toDouble() % 360, 1, 1).toColor(),
    ];
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 0, 24, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Elige tu color',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 14),
            Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(color: tBorde, width: 2),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    controller: _hex,
                    onChanged: _desdeHex,
                    maxLength: 7,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                      prefixText: '#',
                      labelText: 'Código hexadecimal',
                      counterText: '',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
              ],
            ),
            _barra(
              titulo: 'Tono',
              colores: tono,
              valor: _hsv.hue,
              minimo: 0,
              maximo: 359.9,
              alCambiar: (v) => _cambiar(_hsv.withHue(v)),
            ),
            _barra(
              titulo: 'Intensidad',
              colores: [
                HSVColor.fromAHSV(1, _hsv.hue, 0, _hsv.value).toColor(),
                HSVColor.fromAHSV(1, _hsv.hue, 1, _hsv.value).toColor(),
              ],
              valor: _hsv.saturation,
              minimo: 0,
              maximo: 1,
              alCambiar: (v) => _cambiar(_hsv.withSaturation(v)),
            ),
            _barra(
              titulo: 'Brillo',
              colores: [
                HSVColor.fromAHSV(1, _hsv.hue, _hsv.saturation, _brilloMin).toColor(),
                HSVColor.fromAHSV(1, _hsv.hue, _hsv.saturation, 1).toColor(),
              ],
              valor: _hsv.value,
              minimo: _brilloMin,
              maximo: 1,
              alCambiar: (v) => _cambiar(_hsv.withValue(v)),
            ),
            const SizedBox(height: 22),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancelar'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: context.acento),
                    onPressed: () => Navigator.pop(context, color),
                    child: const Text('Usar este color'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
