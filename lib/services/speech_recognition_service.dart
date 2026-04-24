// lib/services/speech_recognition_service.dart

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:record/record.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;
import 'package:synchronized/synchronized.dart';
import '../utils/utils.dart';
import '../utils/speech_models.dart';
import 'voice_command_service.dart';

class SpeechRecognitionService {
  static final SpeechRecognitionService instance =
      SpeechRecognitionService._();
  SpeechRecognitionService._();

  final AudioRecorder _audioRecorder = AudioRecorder();
  sherpa.OnlineRecognizer? _recognizer;
  sherpa.OnlineStream? _stream;

  final _lock = Lock();

  static bool _nativeInitialized = false;

  bool _isProcessing = false;
  bool _isStopping = false;

  StreamSubscription<Uint8List>? _audioSub;

  final StreamController<String> _displayController =
      StreamController<String>.broadcast();
  final StreamController<String> _commandController =
      StreamController<String>.broadcast();
  final StreamController<bool> _stateController =
      StreamController<bool>.broadcast();

  Stream<String> get textStream    => _displayController.stream;
  Stream<String> get commandStream => _commandController.stream;
  Stream<bool>   get stateStream   => _stateController.stream;

  Future<void> initialize() async {
    if (_nativeInitialized && _recognizer != null && _stream != null) {
      debugPrint('SpeechRecognitionService: already initialized, skipping');
      return;
    }

    if (_recognizer != null) {
      _stream?.free();
      _recognizer?.free();
      _stream = null;
      _recognizer = null;
    }

    sherpa.initBindings();

    final modelConfig = await getOnlineModelConfig();
    final config = sherpa.OnlineRecognizerConfig(
      model: modelConfig,
      enableEndpoint: true,
      decodingMethod: 'greedy_search',
      rule1MinTrailingSilence: 2.4,
      rule2MinTrailingSilence: 1.4,
      rule3MinUtteranceLength: 300,
    );

    _recognizer = sherpa.OnlineRecognizer(config);
    _stream = _recognizer!.createStream();
    _nativeInitialized = true;

    debugPrint('SpeechRecognitionService: initialized');
  }

  Future<void> startRecording() async {
    if (_isStopping) {
      debugPrint('SpeechRecognitionService: still stopping, ignoring start');
      return;
    }
    if (!await _audioRecorder.hasPermission()) return;
    if (_isProcessing) return;
    if (_recognizer == null || _stream == null) return;

    // Reset stream before starting
    await _lock.synchronized(() {
      if (_recognizer != null && _stream != null) {
        _recognizer!.reset(_stream!);
      }
    });

    _isProcessing = true;
    _stateController.add(true);

    final audioStream = await _audioRecorder.startStream(const RecordConfig(
      encoder: AudioEncoder.pcm16bits,
      sampleRate: 16000,
      numChannels: 1,
    ));

    _audioSub = audioStream.listen((data) async {
      if (!_isProcessing) return;

      await _lock.synchronized(() {
        if (!_isProcessing || _recognizer == null || _stream == null) return;

        try {
          final samples = convertBytesToFloat32(Uint8List.fromList(data));
          _stream!.acceptWaveform(samples: samples, sampleRate: 16000);

          while (_recognizer!.isReady(_stream!)) {
            _recognizer!.decode(_stream!);
          }

          final result = _recognizer!.getResult(_stream!);
          final text = result.text.trim().toUpperCase();

          if (text.isNotEmpty) {
            _displayController.add(text);
          }

          // Emit command on endpoint, then reset
          if (_recognizer!.isEndpoint(_stream!)) {
            if (text.isNotEmpty) {
              debugPrint('Endpoint — emitting command: "$text"');
              _commandController.add(text);
            }
            _recognizer!.reset(_stream!);
          }
        } catch (e) {
          debugPrint('Audio processing error: $e');
        }
      });
    });
  }

  Future<void> stopRecording() async {
    if (_isStopping) return;
    _isStopping = true;

    // 1. Stop accepting new audio FIRST
    _isProcessing = false;

    // 2. Cancel the audio subscription before touching the recognizer
    await _audioSub?.cancel();
    _audioSub = null;

    // 3. Stop the microphone
    try {
      await _audioRecorder.stop();
    } catch (e) {
      debugPrint('stopRecording: audioRecorder.stop error: $e');
    }

    _stateController.add(false);

    // 4. SAFE reset under lock — NO decode() call here.
    //    decode() after mic stop is what triggers the mutex crash.
    await _lock.synchronized(() {
      if (_recognizer == null || _stream == null) return;
      try {
        // Just get whatever was already decoded, then reset
        final result = _recognizer!.getResult(_stream!);
        final text = result.text.trim().toUpperCase();
        if (text.isNotEmpty) {
          debugPrint('Stop — last partial: "$text"');
          _commandController.add(text);
        }
        _recognizer!.reset(_stream!);
      } catch (e) {
        debugPrint('Stop reset error (safe to ignore): $e');
      }
    });

    _isStopping = false;
    VoiceCommandService.instance.reset();
  }

  void dispose() {
    _isProcessing = false;
    _isStopping = false;
    _audioSub?.cancel();
    _audioRecorder.dispose();
    _stream?.free();
    _recognizer?.free();
    _stream = null;
    _recognizer = null;
    _nativeInitialized = false;
    _displayController.close();
    _commandController.close();
    _stateController.close();
  }
}