import 'dart:async';
import 'package:flutter_tts/flutter_tts.dart';
import '../../services/text_extractor_services.dart';

class AnalyzeController {
  final FlutterTts _tts = FlutterTts();

  String extractedText = '';
  List<String> paragraphs = [];
  List<List<TextRun>> richParagraphs = [];
  List<String> sentences = [];

  int currentSentenceIndex = 0;
  bool isPlaying = false;
  bool _disposed = false;

  // TTS settings
  double speed = 0.5;
  double pitch = 1.0;

  Function? _onUpdateUI;

  Future<void> loadFile(String path, {String? overrideText}) async {
    extractedText = '';
    paragraphs = [];
    richParagraphs = [];
    sentences = [];
    currentSentenceIndex = 0;
    isPlaying = false;
    await _tts.stop();

    if (overrideText != null && overrideText.isNotEmpty) {
      extractedText = overrideText;
      paragraphs = TextExtractorService.toParagraphs(extractedText);
      richParagraphs = paragraphs.map((p) => [TextRun(p)]).toList();
    } else {
      extractedText = await TextExtractorService.extractText(path);
      paragraphs = TextExtractorService.toParagraphs(extractedText);
      richParagraphs =
          await TextExtractorService.extractParagraphRuns(path);
      if (richParagraphs.isEmpty) {
        richParagraphs = paragraphs.map((p) => [TextRun(p)]).toList();
      }
    }

    sentences = paragraphs
        .expand((p) => TextExtractorService.toSentences(p))
        .toList();

    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(speed);
    await _tts.setPitch(pitch);

    _tts.setCompletionHandler(() {
      if (_disposed || !isPlaying) return;
      currentSentenceIndex++;
      if (currentSentenceIndex < sentences.length) {
        _tts.speak(sentences[currentSentenceIndex]);
        _onUpdateUI?.call();
      } else {
        isPlaying = false;
        currentSentenceIndex = 0;
        _onUpdateUI?.call();
      }
    });
  }

  Future<void> playPause(Function updateUI) async {
    if (_disposed) return;
    _onUpdateUI = updateUI;

    if (isPlaying) {
      await _tts.stop();
      isPlaying = false;
      updateUI();
      return;
    }

    if (sentences.isEmpty) return;
    isPlaying = true;
    updateUI();
    await _tts.speak(sentences[currentSentenceIndex]);
  }

  Future<void> stop(Function updateUI) async {
    if (_disposed) return;
    await _tts.stop();
    isPlaying = false;
    currentSentenceIndex = 0;
    updateUI();
  }

  // Tap a specific sentence to start reading from it
  Future<void> readFromSentence(int index, Function updateUI) async {
    if (_disposed) return;
    _onUpdateUI = updateUI;
    await _tts.stop();
    currentSentenceIndex = index;
    isPlaying = true;
    updateUI();
    await _tts.speak(sentences[index]);
  }

  Future<void> setSpeed(double value) async {
    speed = value;
    await _tts.setSpeechRate(value);
  }

  Future<void> setPitch(double value) async {
    pitch = value;
    await _tts.setPitch(value);
  }

  void dispose() {
    _disposed = true;
    isPlaying = false;
    _tts.stop();
  }
}