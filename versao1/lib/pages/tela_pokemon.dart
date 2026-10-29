import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/pokemon.dart';
import '../providers/pokemon_provider.dart';
import '../widgets/pokemon_picture.dart';
import 'tela_detalhes_pokemon.dart';

class PokemonPage extends StatefulWidget {
  const PokemonPage({super.key});

  @override
  State<PokemonPage> createState() => _PokemonPageState();
}

class _PokemonPageState extends State<PokemonPage> {
  final _nameController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _search() {
    FocusScope.of(context).unfocus();
    context.read<PokemonProvider>().searchByName(_nameController.text);
  }

  void _open(Pokemon pokemon) => Navigator.push<void>(
        context,
        MaterialPageRoute(
            builder: (_) => PokemonDetailsPage(pokemonId: pokemon.id)),
      );

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Pokédex Clássica'),
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        ),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 850),
              child: Consumer<PokemonProvider>(
                builder: (context, provider, child) => RefreshIndicator(
                  onRefresh: provider.loadList,
                  child: CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      SliverPadding(
                        padding: const EdgeInsets.all(20),
                        sliver: SliverToBoxAdapter(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                'Encontre seu Pokémon',
                                style:
                                    Theme.of(context).textTheme.headlineSmall,
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                  'Pesquise pelo nome ou descubra um Pokémon aleatório.'),
                              const SizedBox(height: 20),
                              TextField(
                                controller: _nameController,
                                enabled: !provider.searchLoading,
                                textInputAction: TextInputAction.search,
                                autocorrect: false,
                                onSubmitted: (_) => _search(),
                                decoration: const InputDecoration(
                                  labelText: 'Nome do Pokémon',
                                  hintText: 'Ex.: pikachu',
                                  prefixIcon: Icon(Icons.search),
                                ),
                              ),
                              const SizedBox(height: 12),
                              FilledButton(
                                onPressed:
                                    provider.searchLoading ? null : _search,
                                child: const Text('Pesquisar'),
                              ),
                              OutlinedButton.icon(
                                onPressed: provider.searchLoading
                                    ? null
                                    : provider.searchRandom,
                                icon: const Icon(Icons.shuffle),
                                label: const Text('Pokémon aleatório'),
                              ),
                              if (provider.searchLoading) ...[
                                const SizedBox(height: 16),
                                const LinearProgressIndicator(),
                                const SizedBox(height: 8),
                                const Text('Pesquisando Pokémon...'),
                              ],
                              if (provider.searchError != null) ...[
                                const SizedBox(height: 16),
                                Text(provider.searchError!,
                                    style: TextStyle(
                                      color:
                                          Theme.of(context).colorScheme.error,
                                    )),
                                if (provider.canRetrySearch)
                                  TextButton(
                                    onPressed: provider.retrySearch,
                                    child:
                                        const Text('Tentar pesquisa novamente'),
                                  ),
                              ],
                              if (provider.searchResult
                                  case final pokemon?) ...[
                                const SizedBox(height: 20),
                                Text(
                                  'Resultado da pesquisa',
                                  style:
                                      Theme.of(context).textTheme.titleMedium,
                                ),
                                _PokemonTile(
                                    pokemon: pokemon,
                                    onTap: () => _open(pokemon)),
                                TextButton(
                                  onPressed: () {
                                    _nameController.clear();
                                    provider.clearSearch();
                                  },
                                  child: const Text('Limpar pesquisa'),
                                ),
                              ],
                              const Divider(height: 32),
                              Row(children: [
                                Expanded(
                                    child: Text(
                                  'Pokémon da aula · ${provider.pokemons.length}',
                                  style:
                                      Theme.of(context).textTheme.titleMedium,
                                )),
                                IconButton(
                                  tooltip: 'Atualizar lista',
                                  onPressed: provider.listLoading
                                      ? null
                                      : provider.loadList,
                                  icon: const Icon(Icons.refresh),
                                ),
                              ]),
                              if (provider.listLoading) ...[
                                const SizedBox(height: 16),
                                const Center(
                                    child: CircularProgressIndicator()),
                                const SizedBox(height: 8),
                                const Text('Carregando lista...',
                                    textAlign: TextAlign.center),
                              ],
                              if (provider.listError != null) ...[
                                Text(provider.listError!,
                                    textAlign: TextAlign.center),
                                TextButton(
                                  onPressed: provider.loadList,
                                  child: const Text(
                                      'Tentar carregar lista novamente'),
                                ),
                              ],
                              if (!provider.listLoading &&
                                  provider.listError == null &&
                                  provider.pokemons.isEmpty)
                                const Text('Nenhum Pokémon na lista.'),
                            ],
                          ),
                        ),
                      ),
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                        sliver: SliverList.builder(
                          itemCount: provider.pokemons.length,
                          itemBuilder: (context, index) {
                            final pokemon = provider.pokemons[index];
                            return _PokemonTile(
                                pokemon: pokemon, onTap: () => _open(pokemon));
                          },
                        ),
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

class _PokemonTile extends StatelessWidget {
  const _PokemonTile({required this.pokemon, required this.onTap});
  final Pokemon pokemon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
        child: ListTile(
          contentPadding: const EdgeInsets.all(12),
          leading: PokemonPicture(pokemon: pokemon, size: 56),
          title: Text(pokemon.displayName,
              style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text('${pokemon.number} · ${pokemon.types.join(' / ')}'),
          trailing: const Icon(Icons.chevron_right),
          onTap: onTap,
        ),
      );
}
