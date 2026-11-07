import 'package:flutter/material.dart';

void main() {
  runApp(const PartnershippingApp());
}

class PartnershippingApp extends StatelessWidget {
  const PartnershippingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Мы вдвоём',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFF2A88F), // тёплая пастель
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFFFF8F3),
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _taps = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Card(
              elevation: 0,
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('💞', style: TextStyle(fontSize: 64)),
                    const SizedBox(height: 16),
                    Text(
                      'Мы вдвоём',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Приложение установлено и работает!',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(220, 56),
                      ),
                      onPressed: () => setState(() => _taps++),
                      child: Text('Проверка: нажато $_taps'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
