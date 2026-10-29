import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:pokemonapp/models/pokemon.dart';
import 'package:pokemonapp/providers/pokemon_provider.dart';
import 'package:pokemonapp/services/pokemon_service.dart';

import 'test_data.dart';

void main() {
  test('modelo recebe os novos atributos e converte as unidades da PokéAPI',
      () {
    final pokemon = Pokemon.fromJson(pokemonJson());
    expect(pokemon.speed, 90);
    expect(pokemon.specialAttack, 50);
    expect(pokemon.heightLabel, '0.4 m');
    expect(pokemon.weightLabel, '6.0 kg');
    expect(pokemon.abilities, ['static', 'lightning-rod']);
  });

  test('nome, ID e aleatório usam somente as rotas Flask', () async {
    final paths = <String>[];
    final service = PokemonService(
      baseUrl: 'http://localhost:5002',
      client: MockClient((request) async {
        expect(request.url.host, 'localhost');
        paths.add(request.url.path);
        return jsonResponse(pokemonJson());
      }),
    );
    addTearDown(service.dispose);
    await service.fetchByName(' PIKACHU ');
    await service.fetchById(25);
    await service.fetchRandom();
    expect(paths,
        ['/pokemons/nome/pikachu', '/pokemons/25', '/pokemons/aleatorio']);
  });

  test('lista original continua disponível', () async {
    final service = PokemonService(client: MockClient((request) async {
      expect(request.url.path, '/pokemons');
      return jsonResponse([pokemonJson()]);
    }));
    addTearDown(service.dispose);
    expect((await service.fetchList()).single.name, 'pikachu');
  });

  test('imagem também é recebida pelo Flask', () async {
    final service = PokemonService(client: MockClient((request) async {
      expect(request.url.host, '10.0.2.2');
      expect(request.url.path, '/pokemons/25/imagem');
      return http.Response.bytes([137, 80, 78, 71], 200);
    }));
    addTearDown(service.dispose);
    final image =
        await service.fetchImage(Pokemon.fromJson(pokemonJson(image: true)));
    expect(image, [137, 80, 78, 71]);
  });

  test('imagem com endereço externo é rejeitada antes da rede', () async {
    var calls = 0;
    final service = PokemonService(client: MockClient((_) async {
      calls++;
      return http.Response('', 200);
    }));
    addTearDown(service.dispose);
    final data = pokemonJson()..['imagem'] = 'https://pokeapi.co/image.png';
    await expectLater(service.fetchImage(Pokemon.fromJson(data)),
        throwsA(isA<PokemonServiceException>()));
    expect(calls, 0);
  });

  test('erro 404 preserva a mensagem do Flask', () async {
    final service = PokemonService(
        client: MockClient((_) async =>
            jsonResponse({'erro': 'Pokémon não encontrado.'}, status: 404)));
    addTearDown(service.dispose);
    await expectLater(
        service.fetchByName('inexistente'),
        throwsA(isA<PokemonServiceException>()
            .having((error) => error.statusCode, 'status', 404)
            .having((error) => error.message, 'mensagem',
                'Pokémon não encontrado.')));
  });

  test('HTTP com corpo HTML informa o status', () async {
    final service = PokemonService(
        client:
            MockClient((_) async => http.Response('<html>erro</html>', 500)));
    addTearDown(service.dispose);
    await expectLater(
        service.fetchById(25),
        throwsA(isA<PokemonServiceException>()
            .having((error) => error.message, 'mensagem', contains('500'))));
  });

  for (final data in <Object>[
    [],
    {'id': 25},
    {...pokemonJson(), 'velocidade': 'rápido'},
    {...pokemonJson(), 'ataque_especial': null},
  ]) {
    test('rejeita detalhes inválidos: $data', () async {
      final service =
          PokemonService(client: MockClient((_) async => jsonResponse(data)));
      addTearDown(service.dispose);
      await expectLater(
          service.fetchById(25), throwsA(isA<PokemonServiceException>()));
    });
  }

  test('rejeita lista inválida', () async {
    final service = PokemonService(
        client: MockClient((_) async => jsonResponse({'erro': 'inválido'})));
    addTearDown(service.dispose);
    await expectLater(
        service.fetchList(), throwsA(isA<PokemonServiceException>()));
  });

  test('trata desconexão', () async {
    final service = PokemonService(client: MockClient((_) async {
      throw http.ClientException('offline');
    }));
    addTearDown(service.dispose);
    await expectLater(
        service.fetchById(25),
        throwsA(isA<PokemonServiceException>()
            .having((error) => error.message, 'mensagem', contains('Flask'))));
  });

  test('trata timeout', () async {
    final service = PokemonService(
      timeout: const Duration(milliseconds: 1),
      client: MockClient((_) => Completer<http.Response>().future),
    );
    addTearDown(service.dispose);
    await expectLater(
        service.fetchById(25),
        throwsA(isA<PokemonServiceException>().having(
            (error) => error.message, 'mensagem', contains('demorou'))));
  });

  test('provider normaliza o nome e controla carregamento', () async {
    final response = Completer<http.Response>();
    final provider =
        PokemonProvider(service: PokemonService(client: MockClient((request) {
      expect(request.url.path, '/pokemons/nome/pikachu');
      return response.future;
    })));
    addTearDown(provider.dispose);
    var changes = 0;
    provider.addListener(() => changes++);
    final pending = provider.searchByName(' PIKACHU ');
    expect(provider.searchLoading, isTrue);
    response.complete(jsonResponse(pokemonJson()));
    await pending;
    expect(provider.searchLoading, isFalse);
    expect(provider.searchResult!.id, 25);
    expect(changes, 2);
  });

  test('provider valida nome e ID sem acessar a rede', () async {
    var calls = 0;
    final provider =
        PokemonProvider(service: PokemonService(client: MockClient((_) async {
      calls++;
      return jsonResponse(pokemonJson());
    })));
    addTearDown(provider.dispose);
    await provider.searchByName('');
    expect(provider.searchError, contains('nome'));
    for (final id in ['0', '-1', '2.5', 'abc', '']) {
      await provider.searchById(id);
      expect(provider.searchError, contains('ID'));
    }
    expect(calls, 0);
  });

  test('falha de pesquisa pode ser repetida sem perder a lista', () async {
    var searches = 0;
    final provider = PokemonProvider(
        service: PokemonService(client: MockClient((request) async {
      if (request.url.path == '/pokemons') {
        return jsonResponse([pokemonJson(id: 1, name: 'bulbasaur')]);
      }
      if (searches++ == 0) {
        return jsonResponse({'erro': 'Pokémon não encontrado.'}, status: 404);
      }
      return jsonResponse(pokemonJson());
    })));
    addTearDown(provider.dispose);
    await provider.loadList();
    await provider.searchByName('pikachu');
    expect(provider.searchError, isNotNull);
    expect(provider.pokemons.single.id, 1);
    await provider.retrySearch();
    expect(provider.searchError, isNull);
    expect(provider.searchResult!.id, 25);
    expect(provider.pokemons.single.id, 1);
  });

  test('estados de lista, pesquisa e detalhes são independentes', () async {
    final list = Completer<http.Response>();
    final provider = PokemonProvider(
        service: PokemonService(client: MockClient((request) async {
      if (request.url.path == '/pokemons') return list.future;
      return jsonResponse(pokemonJson());
    })));
    addTearDown(provider.dispose);
    final pending = provider.loadList();
    await provider.searchByName('pikachu');
    await provider.loadDetails(25);
    expect(provider.listLoading, isTrue);
    expect(provider.searchLoading, isFalse);
    expect(provider.detailsLoading, isFalse);
    expect(provider.selectedPokemon!.specialAttack, 50);
    list.complete(jsonResponse([]));
    await pending;
  });

  test('respostas antigas não substituem a pesquisa mais recente', () async {
    final first = Completer<http.Response>();
    final second = Completer<http.Response>();
    final provider = PokemonProvider(
        service: PokemonService(
            client: MockClient((request) => request.url.path.endsWith('pikachu')
                ? first.future
                : second.future)));
    addTearDown(provider.dispose);
    final oldSearch = provider.searchByName('pikachu');
    final newSearch = provider.searchByName('eevee');
    second.complete(jsonResponse(pokemonJson(id: 133, name: 'eevee')));
    await newSearch;
    first.complete(jsonResponse(pokemonJson()));
    await oldSearch;
    expect(provider.searchResult!.id, 133);
  });

  test('limpar a pesquisa descarta uma resposta pendente', () async {
    final response = Completer<http.Response>();
    final provider = PokemonProvider(
        service: PokemonService(client: MockClient((_) => response.future)));
    addTearDown(provider.dispose);
    final pending = provider.searchRandom();
    provider.clearSearch();
    response.complete(jsonResponse(pokemonJson()));
    await pending;
    expect(provider.searchResult, isNull);
    expect(provider.searchLoading, isFalse);
  });

  test('erro de imagem é isolado e permite nova tentativa', () async {
    var calls = 0;
    final provider =
        PokemonProvider(service: PokemonService(client: MockClient((_) async {
      if (calls++ == 0) {
        return jsonResponse({'erro': 'Imagem indisponível'}, status: 502);
      }
      return http.Response.bytes([137, 80, 78, 71], 200);
    })));
    addTearDown(provider.dispose);
    final pokemon = Pokemon.fromJson(pokemonJson(image: true));
    await provider.loadImage(pokemon);
    expect(provider.imageFailed(25), isTrue);
    expect(provider.searchError, isNull);
    await provider.loadImage(pokemon, retry: true);
    expect(provider.imageFor(25), [137, 80, 78, 71]);
    await provider.loadImage(pokemon);
    expect(calls, 2);
  });

  test('dispose durante uma requisição não notifica listeners', () async {
    final response = Completer<http.Response>();
    final provider = PokemonProvider(
        service: PokemonService(client: MockClient((_) => response.future)));
    final pending = provider.searchByName('pikachu');
    provider.dispose();
    response.complete(jsonResponse(pokemonJson()));
    await pending;
  });
}
