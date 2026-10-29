import 'package:flutter/foundation.dart';

import '../models/pokemon.dart';
import '../services/pokemon_service.dart';

class PokemonProvider extends ChangeNotifier {
  PokemonProvider({PokemonService? service})
      : _service = service ?? PokemonService();

  final PokemonService _service;
  List<Pokemon> _pokemons = const [];
  Pokemon? _searchResult;
  Pokemon? _selectedPokemon;
  bool _listLoading = false;
  bool _searchLoading = false;
  bool _detailsLoading = false;
  String? _listError;
  String? _searchError;
  String? _detailsError;
  int _listRequest = 0;
  int _searchRequest = 0;
  int _detailsRequest = 0;
  bool _disposed = false;
  Future<Pokemon> Function()? _lastSearch;
  final Map<int, Uint8List> _images = {};
  final Set<int> _loadingImages = {};
  final Set<int> _failedImages = {};

  List<Pokemon> get pokemons => _pokemons;
  Pokemon? get searchResult => _searchResult;
  Pokemon? get selectedPokemon => _selectedPokemon;
  bool get listLoading => _listLoading;
  bool get searchLoading => _searchLoading;
  bool get detailsLoading => _detailsLoading;
  String? get listError => _listError;
  String? get searchError => _searchError;
  bool get canRetrySearch => _lastSearch != null;
  String? get detailsError => _detailsError;
  Uint8List? imageFor(int id) => _images[id];
  bool imageFailed(int id) => _failedImages.contains(id);

  Future<void> loadList() async {
    if (_disposed) return;
    final request = ++_listRequest;
    _listLoading = true;
    _listError = null;
    notifyListeners();
    try {
      final result = await _service.fetchList();
      if (!_disposed && request == _listRequest) _pokemons = result;
    } on PokemonServiceException catch (error) {
      if (!_disposed && request == _listRequest) _listError = error.message;
    } finally {
      if (!_disposed && request == _listRequest) {
        _listLoading = false;
        notifyListeners();
      }
    }
  }

  Future<void> searchByName(String name) async {
    name = name.trim().toLowerCase();
    if (!RegExp(r'^[a-z0-9]+(?:-[a-z0-9]+)*$').hasMatch(name) ||
        name.length > 80) {
      _rejectSearch('Informe o nome do Pokémon, como pikachu ou mr-mime.');
      return;
    }
    final normalized = name;
    await _search(() => _service.fetchByName(normalized));
  }

  Future<void> searchById(String text) async {
    final id = int.tryParse(text.trim());
    if (id == null || id < 1 || id > 2147483647) {
      _rejectSearch('Informe um ID inteiro positivo, como 25.');
      return;
    }
    await _search(() => _service.fetchById(id));
  }

  Future<void> searchRandom() => _search(_service.fetchRandom);

  Future<void> retrySearch() async {
    final search = _lastSearch;
    if (search != null) await _search(search);
  }

  void _rejectSearch(String message) {
    if (_disposed) return;
    _searchRequest++;
    _searchResult = null;
    _searchError = message;
    _searchLoading = false;
    _lastSearch = null;
    notifyListeners();
  }

  Future<void> _search(Future<Pokemon> Function() fetch) async {
    if (_disposed) return;
    final request = ++_searchRequest;
    _lastSearch = fetch;
    _searchLoading = true;
    _searchError = null;
    _searchResult = null;
    notifyListeners();
    try {
      final result = await fetch();
      if (!_disposed && request == _searchRequest) _searchResult = result;
    } on PokemonServiceException catch (error) {
      if (!_disposed && request == _searchRequest) _searchError = error.message;
    } finally {
      if (!_disposed && request == _searchRequest) {
        _searchLoading = false;
        notifyListeners();
      }
    }
  }

  void clearSearch() {
    if (_disposed) return;
    _searchRequest++;
    _searchResult = null;
    _searchError = null;
    _searchLoading = false;
    _lastSearch = null;
    notifyListeners();
  }

  Future<void> loadDetails(int id) async {
    if (_disposed) return;
    final request = ++_detailsRequest;
    _selectedPokemon = null;
    _detailsLoading = true;
    _detailsError = null;
    notifyListeners();
    try {
      final result = await _service.fetchById(id);
      if (!_disposed && request == _detailsRequest) _selectedPokemon = result;
    } on PokemonServiceException catch (error) {
      if (!_disposed && request == _detailsRequest) {
        _detailsError = error.message;
      }
    } finally {
      if (!_disposed && request == _detailsRequest) {
        _detailsLoading = false;
        notifyListeners();
      }
    }
  }

  Future<void> loadImage(Pokemon pokemon, {bool retry = false}) async {
    final id = pokemon.id;
    if (_disposed ||
        pokemon.imagePath == null ||
        _images.containsKey(id) ||
        _loadingImages.contains(id) ||
        (!retry && _failedImages.contains(id))) {
      return;
    }
    _failedImages.remove(id);
    _loadingImages.add(id);
    notifyListeners();
    try {
      final bytes = await _service.fetchImage(pokemon);
      if (!_disposed) _images[id] = bytes;
    } on PokemonServiceException {
      if (!_disposed) _failedImages.add(id);
    } finally {
      _loadingImages.remove(id);
      if (!_disposed) notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _service.dispose();
    super.dispose();
  }
}
