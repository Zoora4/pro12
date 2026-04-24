import 'package:flutter/foundation.dart';

class VoiceCommandService {
  static final VoiceCommandService instance = VoiceCommandService._();
  VoiceCommandService._();

  final Map<String, VoidCallback> _commands = {};
  String _lastTriggered = '';

  void registerCommand(String command, VoidCallback action) {
    _commands[command.toUpperCase()] = action;
  }

  void unregisterCommand(String command) {
    _commands.remove(command.toUpperCase());
  }

  void unregisterAll() {
    _commands.clear();
    _lastTriggered = '';
  }

  void reset() => _lastTriggered = '';

  void processText(String text) {
    final input = text.toUpperCase().trim();
    if (input.isEmpty) return;
    if (input == _lastTriggered) return;

    for (var entry in _commands.entries) {
      if (_matches(input, entry.key)) {
        _lastTriggered = input;
        debugPrint('VoiceCommand triggered: "${entry.key}" from "$input"');
        entry.value();
        break;
      }
    }
  }

  bool _matches(String input, String command) {
    if (input.contains(command)) return true;

    final inputWords = input.split(RegExp(r'\s+'));
    final commandWords = command.split(RegExp(r'\s+'));

    for (final cmdWord in commandWords) {
      if (cmdWord.length < 3) continue;
      for (final inputWord in inputWords) {
        if (inputWord.length < 3) continue;
        if (_similarity(inputWord, cmdWord) >= 0.75) return true;
      }
    }

    return false;
  }

  double _similarity(String a, String b) {
    if (a == b) return 1.0;
    if (a.length < 2 || b.length < 2) return 0.0;

    final aBigrams = <String>{};
    for (int i = 0; i < a.length - 1; i++) {
      aBigrams.add(a.substring(i, i + 2));
    }

    int intersectionSize = 0;
    for (int i = 0; i < b.length - 1; i++) {
      final bigram = b.substring(i, i + 2);
      if (aBigrams.contains(bigram)) intersectionSize++;
    }

    return (2.0 * intersectionSize) / (a.length + b.length - 2);
  }
}