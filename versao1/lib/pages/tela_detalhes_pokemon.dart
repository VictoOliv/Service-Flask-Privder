import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/pokemon.dart';
import '../providers/pokemon_provider.dart';
import '../widgets/pokemon_picture.dart';

class PokemonDetailsPage extends StatefulWidget {
  const PokemonDetailsPage({super.key, required this.pokemonId});
  final int pokemonId;

  @override
  State<PokemonDetailsPage> createState() => _PokemonDetailsPageState();
}

class _PokemonDetailsPageState extends State<PokemonDetailsPage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (mounted) {
        context.read<PokemonProvider>().loadDetails(widget.pokemonId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PokemonProvider>();
    final pokemon = provider.selectedPokemon;
    return Scaffold(
      appBar: AppBar(title: const Text('Detalhes do Pokémon')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: provider.detailsLoading
                ? const Center(child: CircularProgressIndicator())
                : provider.detailsError != null
                    ? ListView(padding: const EdgeInsets.all(24), children: [
                        const Icon(Icons.cloud_off, size: 48),
                        const SizedBox(height: 16),
                        Text(provider.detailsError!,
                            textAlign: TextAlign.center),
                        TextButton(
                          onPressed: () =>
                              provider.loadDetails(widget.pokemonId),
                          child: const Text('Tentar detalhes novamente'),
                        ),
                      ])
                    : pokemon == null || pokemon.id != widget.pokemonId
                        ? const Center(child: CircularProgressIndicator())
                        : _PokemonContent(pokemon: pokemon),
          ),
        ),
      ),
    );
  }
}

class _PokemonContent extends StatelessWidget {
  const _PokemonContent({required this.pokemon});
  final Pokemon pokemon;

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Card(
            color: Theme.of(context).colorScheme.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(children: [
                Text(pokemon.number,
                    style: Theme.of(context).textTheme.titleMedium),
                PokemonPicture(pokemon: pokemon, size: 160),
                Text(
                  pokemon.displayName,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 16),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final type in pokemon.types)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(type.toUpperCase()),
                    ),
                ]),
              ]),
            ),
          ),
          _Section(
              title: 'Dados básicos',
              child: Wrap(
                spacing: 32,
                runSpacing: 20,
                children: [
                  _Info(label: 'Altura', value: pokemon.heightLabel),
                  _Info(label: 'Peso', value: pokemon.weightLabel),
                  _Info(
                      label: 'Experiência',
                      value: pokemon.experience?.toString() ?? 'Não informada'),
                ],
              )),
          _Section(
              title: 'Atributos',
              child: Column(children: [
                _StatBar(label: 'HP', value: pokemon.hp),
                _StatBar(label: 'Ataque', value: pokemon.attack),
                _StatBar(label: 'Defesa', value: pokemon.defense),
              ])),
          _Section(
              title: 'Novos atributos',
              child: Column(children: [
                _StatBar(label: 'Velocidade', value: pokemon.speed),
                _StatBar(
                    label: 'Ataque especial', value: pokemon.specialAttack),
              ])),
          _Section(
              title: 'Habilidades',
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final ability in pokemon.abilities)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.secondaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(ability.replaceAll('-', ' ')),
                    ),
                  if (pokemon.abilities.isEmpty)
                    const Text('Nenhuma habilidade informada.'),
                ],
              )),
          const Padding(
            padding: EdgeInsets.all(12),
            child: Text(
              'Dados e imagens da PokéAPI, recebidos pelo backend Flask.',
              textAlign: TextAlign.center,
            ),
          ),
        ],
      );
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Card(
        margin: const EdgeInsets.only(top: 16),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            child,
          ]),
        ),
      );
}

class _Info extends StatelessWidget {
  const _Info({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label),
          const SizedBox(height: 6),
          Text(value, style: Theme.of(context).textTheme.titleLarge),
        ],
      );
}

class _StatBar extends StatelessWidget {
  const _StatBar({required this.label, required this.value});
  final String label;
  final int value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(children: [
          Row(children: [Expanded(child: Text(label)), Text('$value')]),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: (value / 255).clamp(0, 1),
            minHeight: 8,
            semanticsLabel: label,
            semanticsValue: '$value',
          ),
        ]),
      );
}
