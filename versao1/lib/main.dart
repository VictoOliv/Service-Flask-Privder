import 'package:device_preview/device_preview.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'pages/tela_pokemon.dart';
import 'providers/pokemon_provider.dart';

void main() {
  DevicePreview.enable(enabled: const bool.fromEnvironment('DEVICE_PREVIEW'));
  runApp(
    ChangeNotifierProvider(
      create: (_) => PokemonProvider()..loadList(),
      child: const PokemonApp(),
    ),
  );
}

class PokemonApp extends StatelessWidget {
  const PokemonApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Pokédex Clássica',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFFB52538),
            brightness: Brightness.light,
          ),
          scaffoldBackgroundColor: const Color(0xFFFFF8F6),
          inputDecorationTheme: const InputDecorationTheme(
            border: OutlineInputBorder(),
            filled: true,
          ),
          cardTheme: const CardThemeData(clipBehavior: Clip.antiAlias),
        ),
        home: const PokemonPage(),
      );
}
