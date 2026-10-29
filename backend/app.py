"""API Flask da Pokédex. Toda consulta externa fica em pokemon_api.py."""

from flask import Flask, Response, jsonify
from flask_cors import CORS

from pokemon_api import (
    PokemonAPIError,
    get_image,
    get_pokemon,
    list_pokemons,
    normalize_name,
    random_pokemon,
)

app = Flask(__name__)
CORS(app)


@app.errorhandler(PokemonAPIError)
def handle_api_error(error: PokemonAPIError):
    return jsonify({"erro": str(error)}), error.status


@app.errorhandler(404)
def handle_not_found(_error):
    return jsonify({"erro": "Rota ou Pokémon não encontrado."}), 404


@app.get("/")
def api_index():
    return jsonify({
        "aplicacao": "Pokédex",
        "rotas": [
            "/pokemons",
            "/pokemons/<id>",
            "/pokemons/nome/<nome>",
            "/pokemons/aleatorio",
            "/pokemons/<id>/imagem",
        ],
    })


@app.get("/pokemons")
def pokemon_list():
    return jsonify(list_pokemons())


@app.get("/pokemons/nome/<name>")
def pokemon_by_name(name: str):
    return jsonify(get_pokemon(normalize_name(name)))


@app.get("/pokemons/aleatorio")
def pokemon_random():
    return jsonify(random_pokemon())


@app.get("/pokemons/<int:pokemon_id>")
def pokemon_detail(pokemon_id: int):
    if pokemon_id < 1:
        raise PokemonAPIError("O ID deve ser um número inteiro positivo.", 400)
    return jsonify(get_pokemon(str(pokemon_id)))


@app.get("/pokemons/<int:pokemon_id>/imagem")
def pokemon_image(pokemon_id: int):
    if pokemon_id < 1:
        raise PokemonAPIError("O ID deve ser um número inteiro positivo.", 400)
    response = Response(get_image(pokemon_id), mimetype="image/png")
    response.headers["Cache-Control"] = "public, max-age=86400"
    return response


if __name__ == "__main__":
    app.run(host="127.0.0.1", port=5002, debug=False)

