package com.example.app_musica

import android.media.audiofx.Visualizer
import android.os.Handler
import android.os.Looper
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import kotlin.math.hypot
import kotlin.math.log10
import kotlin.math.max
import kotlin.math.min
import kotlin.math.pow

/**
 * Actividad principal. Igual que AudioServiceActivity (para los controles de la
 * notificación) pero además analiza el audio que suena y manda el espectro a Flutter.
 */
class MainActivity : AudioServiceActivity() {
    private var visualizer: Visualizer? = null
    private var sink: EventChannel.EventSink? = null
    private val principal = Handler(Looper.getMainLooper())
    private val bandas = 32

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val mensajero = flutterEngine.dartExecutor.binaryMessenger

        EventChannel(mensajero, "mi_musica/espectro_datos").setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    sink = events
                }

                override fun onCancel(arguments: Any?) {
                    sink = null
                }
            }
        )

        MethodChannel(mensajero, "mi_musica/espectro").setMethodCallHandler { call, result ->
            when (call.method) {
                "iniciar" -> result.success(iniciar(call.argument<Int>("sesion") ?: 0))
                "detener" -> {
                    detener()
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun iniciar(sesion: Int): Boolean {
        detener()
        return try {
            val v = Visualizer(sesion)
            v.enabled = false
            val rango = Visualizer.getCaptureSizeRange()
            v.captureSize = rango[1]
            v.setDataCaptureListener(
                object : Visualizer.OnDataCaptureListener {
                    override fun onWaveFormDataCapture(
                        vis: Visualizer?, waveform: ByteArray?, samplingRate: Int
                    ) {
                    }

                    override fun onFftDataCapture(
                        vis: Visualizer?, fft: ByteArray?, samplingRate: Int
                    ) {
                        if (fft == null) return
                        val datos = procesar(fft)
                        principal.post { sink?.success(datos) }
                    }
                },
                Visualizer.getMaxCaptureRate() / 2,
                false,
                true
            )
            v.enabled = true
            visualizer = v
            true
        } catch (e: Exception) {
            false
        }
    }

    /** Agrupa el FFT en [bandas] barras con escala logarítmica (graves a la izquierda). */
    private fun procesar(fft: ByteArray): DoubleArray {
        val n = fft.size / 2 // número de "bins" complejos
        val salida = DoubleArray(bandas)
        val primero = 1
        val ultimo = (n * 0.75).toInt().coerceAtLeast(primero + bandas)
        var inicio = primero
        for (i in 0 until bandas) {
            val fin = max(
                inicio + 1,
                (primero * (ultimo.toDouble() / primero).pow((i + 1).toDouble() / bandas)).toInt()
            )
            var maximo = 0.0
            for (k in inicio until min(fin, n)) {
                val re = fft[2 * k].toDouble()
                val im = fft[2 * k + 1].toDouble()
                maximo = max(maximo, hypot(re, im))
            }
            // A decibelios aproximados y con un poco de realce en agudos.
            val db = 20 * log10(maximo + 1.0)
            val tilt = 1.0 + 0.7 * i / bandas
            salida[i] = ((db / 45.0) * tilt).coerceIn(0.0, 1.0)
            inicio = fin
        }
        return salida
    }

    private fun detener() {
        try {
            visualizer?.enabled = false
            visualizer?.release()
        } catch (e: Exception) {
        }
        visualizer = null
    }

    override fun onDestroy() {
        detener()
        super.onDestroy()
    }
}
