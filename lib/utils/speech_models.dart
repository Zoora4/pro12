import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;
import 'utils.dart';

Future<sherpa.OnlineModelConfig> getOnlineModelConfig() async {
  const modelDir = 'assets/models/stt';
  return sherpa.OnlineModelConfig(
    transducer: sherpa.OnlineTransducerModelConfig(
      encoder: await copyAssetFile('$modelDir/encoder.onnx'),
      decoder: await copyAssetFile('$modelDir/decoder.onnx'),
      joiner: await copyAssetFile('$modelDir/joiner.onnx'),
    ),
    tokens: await copyAssetFile('$modelDir/tokens.txt'),
    modelType: 'zipformer',
    // ✅ Must be 1 — the TTS isolate uses numThreads:4 for its own ONNX work.
    // Both share the same ONNX Runtime native library on the main isolate.
    // Using >1 here creates competing C++ thread pools → mutex destruction.
    numThreads: 1,
  );
}