  import 'package:flutter/material.dart';
  import 'home_screen.dart';
  import 'history_screen.dart';

  class MainNavScreen extends StatefulWidget {
    const MainNavScreen({super.key});

    @override
    State<MainNavScreen> createState() => _MainNavScreenState();
  }

  class _MainNavScreenState extends State<MainNavScreen> {
    int index = 0;

    final pages = const [
      HomeScreen(),
      HistoryScreen(),
    ];

    @override
    Widget build(BuildContext context) {
      return Scaffold(
        body: pages[index],

        bottomNavigationBar: BottomNavigationBar(
          currentIndex: index,
          onTap: (i) {
            setState(() => index = i);
          },
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home),
              label: "Home",
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.history),
              label: "History",
            ),
          ],
        ),
      );
    }
  }