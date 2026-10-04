import 'package:flutter/material.dart';

class SesliOgrenApp extends StatelessWidget {
  const SesliOgrenApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sesli Öğren',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF65558F),
        ),
        useMaterial3: true,
      ),
      home: const FoundationScreen(),
    );
  }
}

class FoundationScreen extends StatelessWidget {
  const FoundationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Semantics(
                    label: 'Düğüm, Sesli Öğren rehberi',
                    image: true,
                    child: Image.asset(
                      'assets/companions/D_KNOT_128.webp',
                      width: 128,
                      height: 128,
                      filterQuality: FilterQuality.medium,
                    ),
                  ),
                  const SizedBox(height: 28),
                  Text(
                    'Sesli Öğren',
                    style: theme.textTheme.headlineMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Materyalinden anlayarak ilerleyen bir öğrenme yolculuğu.',
                    style: theme.textTheme.bodyLarge,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
