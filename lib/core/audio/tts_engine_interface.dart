/// Contrato para motores locais de síntese de voz TTS nativos (Android/iOS).
abstract class TtsEngineInterface {
  /// Fala o texto em idioma português brasileiro.
  Future<bool> speak(String text);

  /// Interrompe fala atual.
  Future<void> stop();

  /// Libera recursos da engine de áudio/voz.
  void dispose();
}
