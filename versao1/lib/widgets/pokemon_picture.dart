import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/pokemon.dart';
import '../providers/pokemon_provider.dart';

class PokemonPicture extends StatefulWidget {
  const PokemonPicture({super.key, required this.pokemon, this.size = 80});
  final Pokemon pokemon;
  final double size;

  @override
  State<PokemonPicture> createState() => _PokemonPictureState();
}

class _PokemonPictureState extends State<PokemonPicture> {
  @override
  void initState() {
    super.initState();
    _scheduleLoad();
  }

  @override
  void didUpdateWidget(covariant PokemonPicture oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pokemon.id != widget.pokemon.id ||
        oldWidget.pokemon.imagePath != widget.pokemon.imagePath) {
      _scheduleLoad();
    }
  }

  void _scheduleLoad() {
    Future.microtask(() {
      if (mounted) context.read<PokemonProvider>().loadImage(widget.pokemon);
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PokemonProvider>();
    final image = provider.imageFor(widget.pokemon.id);
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: image != null
          ? Image.memory(
              image,
              fit: BoxFit.contain,
              semanticLabel: 'Imagem de ${widget.pokemon.name}',
              filterQuality: FilterQuality.none,
              errorBuilder: (_, error, stackTrace) =>
                  const Icon(Icons.broken_image_outlined),
            )
          : provider.imageFailed(widget.pokemon.id)
              ? IconButton(
                  tooltip: 'Recarregar imagem',
                  onPressed: () =>
                      provider.loadImage(widget.pokemon, retry: true),
                  icon: const Icon(Icons.broken_image_outlined),
                )
              : Icon(
                  Icons.catching_pokemon,
                  size: widget.size * .55,
                  color: Theme.of(context).colorScheme.primary,
                  semanticLabel:
                      'Imagem de ${widget.pokemon.name} indisponível ou carregando',
                ),
    );
  }
}
