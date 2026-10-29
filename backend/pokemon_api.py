"""Acesso à PokéAPI, normalização do contrato e cache local em memória."""

from concurrent.futures import ThreadPoolExecutor
from functools import lru_cache
import random
import re
from typing import Any
from urllib.parse import urlparse

import requests

API_ROOT = "https://pokeapi.co/api/v2/"
HTTP_TIMEOUT = (3.05, 8)
NAME_PATTERN = re.compile(r"^[a-z0-9]+(?:-[a-z0-9]+)*$")


class PokemonAPIError(Exception):
    def __init__(self, message: str, status: int = 502):
        super().__init__(message)
        self.status = status


@lru_cache(maxsize=512)
def fetch_json(resource: str) -> dict[str, Any]:
    try:
        response = requests.get(API_ROOT + resource, timeout=HTTP_TIMEOUT)
        if response.status_code == 404:
            raise PokemonAPIError("Pokémon não encontrado.", 404)
        response.raise_for_status()
    except requests.Timeout as error:
        raise PokemonAPIError("A PokéAPI demorou para responder. Tente novamente.", 504) from error
    except requests.RequestException as error:
        raise PokemonAPIError("Não foi possível consultar a PokéAPI. Tente novamente.", 502) from error

    try:
        data = response.json()
        if not isinstance(data, dict):
            raise ValueError("Objeto JSON esperado.")
        return data
    except ValueError as error:
        raise PokemonAPIError("A PokéAPI retornou dados inválidos.") from error


def normalize_name(name: str) -> str:
    name = name.strip().lower()
    if not name or len(name) > 80 or not NAME_PATTERN.fullmatch(name):
        raise PokemonAPIError("Informe um nome válido, como pikachu ou mr-mime.", 400)
    return name


def serialize_pokemon(data: dict[str, Any]) -> dict[str, Any]:
    try:
        stats = {item["stat"]["name"]: item["base_stat"] for item in data["stats"]}
        types = [item["type"]["name"] for item in sorted(data["types"], key=lambda item: item["slot"])]
        pokemon_id = data["id"]
        return {
            "id": pokemon_id,
            "nome": data["name"],
            # O Flutter recebe somente uma rota local, nunca o endereço externo do sprite.
            "imagem": f"/pokemons/{pokemon_id}/imagem" if data["sprites"]["front_default"] else None,
            "tipo": types[0],
            "tipos": types,
            "altura": data["height"],
            "peso": data["weight"],
            "experiencia": data["base_experience"],
            "habilidades": [item["ability"]["name"] for item in data["abilities"]],
            "hp": stats["hp"],
            "ataque": stats["attack"],
            "defesa": stats["defense"],
            "velocidade": stats["speed"],
            "ataque_especial": stats["special-attack"],
        }
    except (KeyError, TypeError, IndexError) as error:
        raise PokemonAPIError("A PokéAPI retornou um Pokémon em formato inválido.") from error


def get_pokemon(selector: str) -> dict[str, Any]:
    return serialize_pokemon(fetch_json("pokemon/" + selector))


@lru_cache(maxsize=1)
def list_pokemons() -> list[dict[str, Any]]:
    try:
        names = [normalize_name(item["name"]) for item in fetch_json("pokemon?limit=30")["results"]]
    except (KeyError, TypeError) as error:
        raise PokemonAPIError("A PokéAPI retornou uma lista inválida.") from error
    # Preserva os 30 Pokémon da aula, limitando a seis consultas simultâneas.
    with ThreadPoolExecutor(max_workers=6) as executor:
        return list(executor.map(get_pokemon, names))


@lru_cache(maxsize=1)
def catalog_names() -> tuple[str, ...]:
    try:
        names = tuple(normalize_name(item["name"]) for item in fetch_json("pokemon?limit=100000")["results"])
        if not names:
            raise ValueError("Catálogo vazio.")
        return names
    except (KeyError, TypeError, ValueError) as error:
        raise PokemonAPIError("A PokéAPI retornou um catálogo inválido.") from error


def random_pokemon() -> dict[str, Any]:
    # Seleciona um recurso existente; IDs de formas alternativas não são contíguos.
    return get_pokemon(random.choice(catalog_names()))


@lru_cache(maxsize=128)
def get_image(pokemon_id: int) -> bytes:
    data = fetch_json(f"pokemon/{pokemon_id}")
    try:
        url = data["sprites"]["front_default"]
    except (KeyError, TypeError) as error:
        raise PokemonAPIError("Imagem indisponível.", 404) from error
    if not url:
        raise PokemonAPIError("Este Pokémon não possui imagem.", 404)
    parsed = urlparse(url)
    if parsed.scheme != "https" or parsed.netloc != "raw.githubusercontent.com" or not parsed.path.startswith("/PokeAPI/sprites/"):
        raise PokemonAPIError("A origem da imagem não é permitida.")

    try:
        response = requests.get(url, timeout=HTTP_TIMEOUT, allow_redirects=False)
        if response.status_code != 200:
            raise PokemonAPIError("Não foi possível carregar a imagem.", 502)
        content = response.content
        if len(content) > 2_000_000 or not content.startswith(b"\x89PNG\r\n\x1a\n"):
            raise PokemonAPIError("A imagem recebida é inválida.")
        return content
    except requests.Timeout as error:
        raise PokemonAPIError("A imagem demorou para responder.", 504) from error
    except requests.RequestException as error:
        raise PokemonAPIError("Não foi possível carregar a imagem.", 502) from error

