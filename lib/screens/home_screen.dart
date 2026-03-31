  import 'package:flutter/material.dart';
  import '../features/camera/camera_screen.dart';
  import '../features/upload/upload_screen.dart';

  class HomeScreen extends StatelessWidget {
    const HomeScreen({super.key});

    @override
    Widget build(BuildContext context) {
      return Scaffold(
        backgroundColor: const Color.fromARGB(255, 153, 181, 187),

        appBar: AppBar(
          backgroundColor: const Color.fromARGB(255, 153, 181, 187),
          elevation: 0,
          centerTitle: false,

          title: Row(
            children: [
              Image.asset(
                "assets/12.png",
                height: 70,
              ),
              const SizedBox(width: 10),
              const Text(
                "Readify",
                style: TextStyle(
                  color: Color(0xFF38616A),
                  fontWeight: FontWeight.bold,
                  fontSize: 30,
                ),
              ),
            ],
          ),
        ),

        body: Padding(
          padding: const EdgeInsets.only(top: 200),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [

                // CAMERA BUTTON
                SizedBox(
                  width: 320,
                  height: 150,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const CameraScreen(),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF38616A),
                      elevation: 15,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.camera_alt, size: 50),
                        SizedBox(width: 15),
                        Text(
                          "Camera",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 30),

                // DOCUMENT BUTTON
                SizedBox(
                  width: 320,
                  height: 150,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const UploadScreen(),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF38616A),
                      elevation: 15,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.upload_file, size: 50),
                        SizedBox(width: 15),
                        Text(
                          "Document",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              ],
            ),
          ),
        ),
      );
    }
  }