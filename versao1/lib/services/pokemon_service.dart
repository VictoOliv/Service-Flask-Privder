import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/pokemon.dart';

class PokemonServiceException implements Exception {
  const PokemonServiceException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class PokemonService {
  PokemonService({
    http.Client? client,
    String? baseUrl,
    this.timeout = const Duration(seconds: 60),
  })  : _client = client ?? http.Client(),
        baseUrl = baseUrl ?? _defaultBaseUrl;

  static String get _defaultBaseUrl {
    const configured = String.fromEnvironment('API_BASE_URL');
    if (configured.isNotEmpty) return configured;
    return !kIsWeb && defaultTargetPlatform == TargetPlatform.android
        ? 'http://10.0.2.2:5002'
        : 'http://127.0.0.1:5002';
  }

  final http.Client _client;
  final String baseUrl;
  final Duration timeout;

  Future<http.Response> _get(String path) async {
    try {
      final response = await _client
          .get(Uri.parse(baseUrl).replace(path: path))
          .timeout(timeout);
      if (response.statusCode != 200) {
        var message = 'O backend retornou o erro HTTP ${response.statusCode}.';
        try {
          final body = jsonDecode(utf8.decode(response.bodyBytes));
          if (body is Map<String, dynamic> && body['erro'] is String) {
            message = body['erro'] as String;
          }
        } on FormatException {
          // Uma falha do servidor pode retornar HTML em vez de JSON.
        }
        throw PokemonServiceException(message, statusCode: response.statusCode);
      }
      return response;
    } on TimeoutException {
      throw const PokemonServiceException(
          'A consulta demorou demais. Tente novamente.');
    } on http.ClientException {
      throw const PokemonServiceException(
        'Não foi possível conectar ao Flask. Verifique se o backend está rodando na porta 5002.',
      );
    }
  }

  Future<List<Pokemon>> fetchList() async {
    final response = await _get('/pokemons');
    try {
      final body = jsonDecode(utf8.decode(response.bodyBytes));
      if (body is! List) throw const FormatException('Lista esperada.');
      return List.unmodifiable(body.map((item) {
        if (item is! Map<String, dynamic>) {
          throw const FormatException('Pokémon inválido.');
        }
        return Pokemon.fromJson(item);
      }));
    } on FormatException {
      throw const PokemonServiceException(
          'O backend retornou uma lista inválida.');
    }
  }

  Future<Pokemon> _fetchPokemon(String path) async {
    final response = await _get(path);
    try {
      final body = jsonDecode(utf8.decode(response.bodyBytes));
      if (body is! Map<String, dynamic>) {
        throw const FormatException('Objeto esperado.');
      }
      return Pokemon.fromJson(body);
    } on FormatException {
      throw const PokemonServiceException(
          'O backend retornou dados inválidos do Pokémon.');
    }
  }

  Future<Pokemon> fetchByName(String name) => _fetchPokemon(
        Uri(pathSegments: ['pokemons', 'nome', name.trim().toLowerCase()]).path,
      );

  Future<Pokemon> fetchById(int id) => _fetchPokemon('/pokemons/$id');

  Future<Pokemon> fetchRandom() => _fetchPokemon('/pokemons/aleatorio');

  Future<Uint8List> fetchImage(Pokemon pokemon) async {
    final path = '/pokemons/${pokemon.id}/imagem';
    if (pokemon.imagePath != path) {
      throw const PokemonServiceException('Endereço de imagem inválido.');
    }
    return (await _get(path)).bodyBytes;
  }

  void dispose() => _client.close();
}
