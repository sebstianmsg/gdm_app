import 'package:speech_to_text/speech_to_text.dart';

/// Estado del reconocimiento de voz expuesto por [VoiceInputService] (spec 27).
enum VoiceInputStatus {
  /// Todavía no se llamó a [VoiceInputService.initialize].
  notInitialized,

  /// El motor de voz del SO no está disponible en este dispositivo.
  unavailable,

  /// Inicializado y listo para escuchar.
  ready,

  /// Escuchando activamente el dictado.
  listening,

  /// El usuario negó el permiso de micrófono.
  permissionDenied,
}

/// Envoltura del paquete `speech_to_text` (motor de voz nativo del SO, gratis)
/// para el alta de gasto por voz. Expone `initialize`/`listen`/`stop` y un
/// estado simple; el parseo del texto lo hace `parseVoiceExpense` (spec 27).
class VoiceInputService {
  VoiceInputService({SpeechToText? speech}) : _speech = speech ?? SpeechToText();

  final SpeechToText _speech;

  VoiceInputStatus _status = VoiceInputStatus.notInitialized;
  VoiceInputStatus get status => _status;

  bool get isListening => _speech.isListening;

  /// Inicializa el motor de voz y pide el permiso de micrófono. Devuelve `true`
  /// si quedó disponible. Si el permiso se niega o el motor no existe, deja el
  /// [status] correspondiente y devuelve `false`. Nunca lanza.
  Future<bool> initialize() async {
    try {
      final available = await _speech.initialize(
        onError: (error) {
          // El SO reporta el permiso denegado como error de permiso.
          if (error.errorMsg.toLowerCase().contains('permission')) {
            _status = VoiceInputStatus.permissionDenied;
          }
        },
        onStatus: (status) {
          if (!_speech.isListening && _status == VoiceInputStatus.listening) {
            _status = VoiceInputStatus.ready;
          }
        },
      );
      if (_status == VoiceInputStatus.permissionDenied) return false;
      _status =
          available ? VoiceInputStatus.ready : VoiceInputStatus.unavailable;
      return available;
    } catch (_) {
      _status = VoiceInputStatus.unavailable;
      return false;
    }
  }

  /// Comienza a escuchar. [onResult] se invoca con el texto reconocido (parcial
  /// o final) y un flag `isFinal`. Usa el locale del dispositivo (default del
  /// paquete). No hace nada si no está inicializado o el permiso fue negado.
  Future<void> listen({
    required void Function(String transcript, bool isFinal) onResult,
  }) async {
    if (_status == VoiceInputStatus.notInitialized ||
        _status == VoiceInputStatus.unavailable ||
        _status == VoiceInputStatus.permissionDenied) {
      return;
    }
    _status = VoiceInputStatus.listening;
    await _speech.listen(
      onResult: (result) =>
          onResult(result.recognizedWords, result.finalResult),
    );
  }

  /// Detiene la escucha activa (dispara un resultado final). Nunca lanza.
  Future<void> stop() async {
    try {
      await _speech.stop();
    } catch (_) {
      // Ignorado: detener sin sesión activa no es un error para el caller.
    }
    if (_status == VoiceInputStatus.listening) {
      _status = VoiceInputStatus.ready;
    }
  }
}
