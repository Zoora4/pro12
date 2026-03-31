import 'package:flutter/material.dart';
import 'upload_controller.dart';

class UploadScreen extends StatefulWidget {
  const UploadScreen({super.key});

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  bool _opened = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_opened) return;
    _opened = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        UploadController.pickFile(context);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}