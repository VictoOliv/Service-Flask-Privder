import 'dart:convert';

import 'package:http/http.dart' as http;

Map<String, Object?> pokemonJson({
  int id = 25,
  String name = 'pikachu',
  bool image = false,
}) =>
    {
      'id': id,
      'nome': name,
      'imagem': image ? '/pokemons/$id/imagem' : null,
      'tipo': 'electric',
      'tipos': ['electric'],
      'altura': 4,
      'peso': 60,
      'experiencia': 112,
      'habilidades': ['static', 'lightning-rod'],
      'hp': 35,
      'ataque': 55,
      'defesa': 40,
      'velocidade': 90,
      'ataque_especial': 50,
    };

http.Response jsonResponse(Object data, {int status = 200}) => http.Response(
      jsonEncode(data),
      status,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
