import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';

import 'package:pokemonapp/main.dart';
import 'package:pokemonapp/providers/pokemon_provider.dart';
import 'package:pokemonapp/services/pokemon_service.dart';

import 'test_data.dart';

Finder field(String label) => find.byWidgetPredicate(
      (widget) => widget is TextField && widget.decoration?.labelText == label,
    );

Future<void> reveal(WidgetTester tester, Finder finder) =>
    tester.scrollUntilVisible(
      finder.hitTestable(),
      180,
      scrollable: find.byWidgetPredicate(
        (widget) =>
            widget is Scrollable && widget.axisDirection == AxisDirection.down,
      ),
    );

Future<http.Response> defaultHandler(http.Request request) async {
  if (request.url.path == '/pokemons') {
    return jsonResponse([pokemonJson(id: 1, name: 'bulbasaur')]);
  }
  if (request.url.path == '/pokemons/aleatorio' ||
      request.url.path == '/pokemons/133') {
    return jsonResponse(pokemonJson(id: 133, name: 'eevee'));
  }
  return jsonResponse(pokemonJson());
}

Future<PokemonProvider> mountApp(
  WidgetTester tester, {
  Future<http.Response> Function(http.Request)? handler,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final provider = PokemonProvider(
    service: PokemonService(client: MockClient(handler ?? defaultHandler)),
  );
  addTearDown(provider.dispose);
  unawaited(provider.loadList());
  await tester.pumpWidget(
    ChangeNotifierProvider.value(value: provider, child: const PokemonApp()),
  );
  return provider;
}

void main() {
  testWidgets(
      'pesquisa pelo nome, abre detalhes e mostra os dois novos atributos',
      (tester) async {
    final paths = <String>[];
    await mountApp(tester, handler: (request) async {
      paths.add(request.url.path);
      return defaultHandler(request);
    });
    await tester.pumpAndSettle();
    await tester.enterText(field('Nome do Pokémon'), ' PIKACHU ');
    await tester.tap(find.text('Pesquisar'));
    await tester.pumpAndSettle();
    expect(paths, contains('/pokemons/nome/pikachu'));
    await reveal(tester, find.text('PIKACHU'));
    await tester.tap(find.text('PIKACHU'));
    await tester.pumpAndSettle();
    expect(find.text('Detalhes do Pokémon'), findsOneWidget);
    expect(paths, contains('/pokemons/25'));
    await reveal(tester, find.text('Velocidade'));
    expect(find.text('90'), findsOneWidget);
    await reveal(tester, find.text('Ataque especial'));
    expect(find.text('50'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Detalhes do Pokémon'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('nome vazio é validado sem requisição', (tester) async {
    final paths = <String>[];
    await mountApp(tester, handler: (request) async {
      paths.add(request.url.path);
      return defaultHandler(request);
    });
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pesquisar'));
    await tester.pumpAndSettle();
    expect(find.text('Informe o nome do Pokémon, como pikachu ou mr-mime.'),
        findsOneWidget);
    expect(paths, ['/pokemons']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('mostra erro 404 e permite tentar a pesquisa novamente',
      (tester) async {
    var searches = 0;
    await mountApp(tester, handler: (request) async {
      if (request.url.path.startsWith('/pokemons/nome/') && searches++ == 0) {
        return jsonResponse({'erro': 'Pokémon não encontrado.'}, status: 404);
      }
      return defaultHandler(request);
    });
    await tester.pumpAndSettle();
    await tester.enterText(field('Nome do Pokémon'), 'pikachu');
    await tester.tap(find.text('Pesquisar'));
    await tester.pumpAndSettle();
    await reveal(tester, find.text('Tentar pesquisa novamente'));
    expect(find.text('Pokémon não encontrado.'), findsOneWidget);
    await tester.tap(find.text('Tentar pesquisa novamente'));
    await tester.pumpAndSettle();
    await reveal(tester, find.text('PIKACHU'));
    expect(find.text('PIKACHU'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('falha da lista permite recuperar a listagem', (tester) async {
    var calls = 0;
    await mountApp(tester, handler: (request) async {
      if (request.url.path == '/pokemons' && calls++ == 0) {
        throw http.ClientException('offline');
      }
      return defaultHandler(request);
    });
    await tester.pumpAndSettle();
    await reveal(tester, find.text('Tentar carregar lista novamente'));
    await tester.tap(find.text('Tentar carregar lista novamente'));
    await tester.pumpAndSettle();
    await reveal(tester, find.text('BULBASAUR'));
    expect(find.text('BULBASAUR'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('melhoria própria busca Pokémon aleatório pelo Flask',
      (tester) async {
    final paths = <String>[];
    await mountApp(tester, handler: (request) async {
      paths.add(request.url.path);
      return defaultHandler(request);
    });
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pokémon aleatório'));
    await tester.pumpAndSettle();
    expect(paths, contains('/pokemons/aleatorio'));
    await reveal(tester, find.text('EEVEE'));
    await tester.tap(find.text('EEVEE'));
    await tester.pumpAndSettle();
    expect(paths, contains('/pokemons/133'));
    expect(find.text('Detalhes do Pokémon'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('layout permanece utilizável em tela estreita', (tester) async {
    await mountApp(tester);
    await tester.pumpAndSettle();
    tester.view.physicalSize = const Size(320, 568);
    await tester.pumpAndSettle();
    await reveal(tester, find.text('BULBASAUR'));
    expect(find.text('BULBASAUR'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
