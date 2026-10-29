class Pokemon {
  const Pokemon({
    required this.id,
    required this.name,
    required this.types,
    required this.height,
    required this.weight,
    required this.experience,
    required this.abilities,
    required this.hp,
    required this.attack,
    required this.defense,
    required this.speed,
    required this.specialAttack,
    this.imagePath,
  });

  final int id;
  final String name;
  final String? imagePath;
  final List<String> types;
  final int height;
  final int weight;
  final int? experience;
  final List<String> abilities;
  final int hp;
  final int attack;
  final int defense;
  final int speed;
  final int specialAttack;

  String get displayName => name.toUpperCase();
  String get number => '#${id.toString().padLeft(3, '0')}';
  String get heightLabel => '${(height / 10).toStringAsFixed(1)} m';
  String get weightLabel => '${(weight / 10).toStringAsFixed(1)} kg';

  factory Pokemon.fromJson(Map<String, dynamic> json) {
    final image = json['imagem'];
    if (image != null && image is! String) {
      throw const FormatException('Imagem inválida.');
    }
    final experience = json['experiencia'];
    if (experience != null && experience is! int) {
      throw const FormatException('Experiência inválida.');
    }
    return Pokemon(
      id: _readInt(json, 'id'),
      name: _readText(json, 'nome'),
      imagePath: image as String?,
      types: _readList(json, 'tipos'),
      height: _readInt(json, 'altura'),
      weight: _readInt(json, 'peso'),
      experience: experience as int?,
      abilities: _readList(json, 'habilidades'),
      hp: _readInt(json, 'hp'),
      attack: _readInt(json, 'ataque'),
      defense: _readInt(json, 'defesa'),
      speed: _readInt(json, 'velocidade'),
      specialAttack: _readInt(json, 'ataque_especial'),
    );
  }
}

int _readInt(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! int || value < 0 || (key == 'id' && value == 0)) {
    throw FormatException('Campo numérico inválido: $key.');
  }
  return value;
}

String _readText(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('Campo de texto inválido: $key.');
  }
  return value;
}

List<String> _readList(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! List || value.any((item) => item is! String || item.isEmpty)) {
    throw FormatException('Lista inválida: $key.');
  }
  return List<String>.unmodifiable(value.cast<String>());
}
