# Pokédex Clássica

**Atividade 6 — somente a versão 1.**

Busca de Pokémon pelo nome, detalhes com velocidade e ataque especial e botão Pokémon aleatório, sempre via Flask.

## Estrutura

- `versao1/`: projeto Flutter completo da versão publicada.
- `backend/`: API Python necessária ao aplicativo.

## Terminal 1 — backend Python

```powershell
cd backend
python -m venv .venv
.\.venv\Scripts\python.exe -m pip install -r requirements.txt
.\.venv\Scripts\python.exe app.py
```

Confira http://127.0.0.1:5002/pokemons/nome/pikachu e deixe o backend rodando.
Em outro terminal, execute o Flutter conforme abaixo.

Rotas: `/pokemons`, `/pokemons/<id>`, `/pokemons/nome/<nome>`, `/pokemons/aleatorio` e `/pokemons/<id>/imagem`. Dados e imagens passam pelo Flask.

## Executar o Flutter

Instale o Flutter compatível com `versao1/pubspec.yaml` e execute:

```powershell
cd versao1
flutter pub get
flutter run -d chrome
```

## Verificação básica

```powershell
flutter analyze
flutter build web
```

O projeto foi conferido em Flutter Web em 28/10/2026, com análise e abertura básica.
Esta checagem não é uma bateria completa de testes. Builds nativos não foram validados.

Os testes automatizados existentes podem ser executados com `flutter test` e, no backend, `.venv/Scripts/python.exe -m unittest discover -s tests -v`.
