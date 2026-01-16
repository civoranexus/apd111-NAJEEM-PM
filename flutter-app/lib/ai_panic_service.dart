import 'package:speech_to_text/speech_to_text.dart';

class AIPanicService {
  final SpeechToText _speech = SpeechToText();
  bool _isListening = false;

  final List<String> panicKeywords = [
    "help",
    "save me",
    "danger",
    "emergency",
    "don't touch me",
    "leave me",
    "stop",
  ];
  Future<void> startListening({
    required Function onPanicDetected,
  }) async {
    final available = await _speech.initialize();

    if (!available) return;

    if (_isListening) return;

    _isListening = true;

    _speech.listen(
      listenMode: ListenMode.confirmation,
      onResult: (result) {
        final spokenText = result.recognizedWords.toLowerCase();

        for (final word in panicKeywords) {
          if (spokenText.contains(word)) {
            stopListening();
            onPanicDetected(); 
            break;
          }
        }
      },
    );
  }
  void stopListening() {
    if (_isListening) {
      _speech.stop();
      _isListening = false;
    }
  }
}
