import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'core/history/history_store.dart';
import 'screens/splash_screen.dart';

// ✅ DO NOT call sherpa.initBindings() here.
// It is called exactly once inside SpeechRecognitionService.initialize().
// Calling it multiple times corrupts the ONNX Runtime's internal thread pool
// mutex → pthread_mutex_lock on destroyed mutex → SIGABRT crash.

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await HistoryStore.init();

  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: SplashScreen(),
    );
  }
}