import copy
import unittest
from unittest.mock import patch

import requests

from app import app
from pokemon_api import catalog_names, fetch_json, get_image, list_pokemons

PNG = b"\x89PNG\r\n\x1a\n" + b"test-image"


def raw_pokemon(pokemon_id=25, name="pikachu"):
    return {
        "id": pokemon_id,
        "name": name,
        "height": 4,
        "weight": 60,
        "base_experience": 112,
        "sprites": {"front_default": f"https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/{pokemon_id}.png"},
        "types": [{"slot": 1, "type": {"name": "electric"}}],
        "abilities": [{"ability": {"name": "static"}}, {"ability": {"name": "lightning-rod"}}],
        # Ordem propositalmente diferente: a aplicação deve usar o nome do atributo.
        "stats": [
            {"stat": {"name": name}, "base_stat": value}
            for name, value in (
                ("speed", 90), ("special-defense", 50), ("hp", 35),
                ("special-attack", 50), ("defense", 40), ("attack", 55),
            )
        ],
    }


def response(status=200, data=None, content=None):
    from unittest.mock import Mock
    result = Mock()
    result.status_code = status
    result.json.return_value = data
    result.content = content
    if status >= 400:
        result.raise_for_status.side_effect = requests.HTTPError(str(status))
    return result


class PokemonApiTests(unittest.TestCase):
    def setUp(self):
        for function in (fetch_json, list_pokemons, catalog_names, get_image):
            function.cache_clear()
        self.client = app.test_client()

    def test_name_normalization_and_new_fields(self):
        with patch("pokemon_api.requests.get", return_value=response(data=raw_pokemon())) as fetch:
            result = self.client.get("/pokemons/nome/%20PIKACHU%20")
            self.assertEqual(result.status_code, 200)
            data = result.json
            self.assertEqual(data["id"], 25)
            self.assertEqual(data["nome"], "pikachu")
            self.assertEqual(data["tipo"], "electric")
            self.assertEqual(data["altura"], 4)
            self.assertEqual(data["peso"], 60)
            self.assertEqual(data["velocidade"], 90)
            self.assertEqual(data["ataque_especial"], 50)
            self.assertEqual(data["hp"], 35)
            self.assertEqual(data["ataque"], 55)
            self.assertEqual(data["defesa"], 40)
            self.assertEqual(data["imagem"], "/pokemons/25/imagem")
            self.assertEqual(data["habilidades"], ["static", "lightning-rod"])
            self.assertTrue(fetch.call_args.args[0].endswith("/pokemon/pikachu"))
            self.assertIn("timeout", fetch.call_args.kwargs)

    def test_original_id_endpoint_is_preserved(self):
        with patch("pokemon_api.requests.get", return_value=response(data=raw_pokemon())):
            result = self.client.get("/pokemons/25")
            self.assertEqual(result.status_code, 200)
            self.assertEqual(result.json["velocidade"], 90)
            self.assertEqual(result.json["ataque_especial"], 50)

    def test_invalid_name_and_zero_id_do_not_access_upstream(self):
        with patch("pokemon_api.requests.get") as fetch:
            for path in ("/pokemons/nome/pikachu!", "/pokemons/0"):
                with self.subTest(path=path):
                    self.assertEqual(self.client.get(path).status_code, 400)
            fetch.assert_not_called()

    def test_not_found(self):
        with patch("pokemon_api.requests.get", return_value=response(status=404)):
            result = self.client.get("/pokemons/nome/inexistente")
            self.assertEqual(result.status_code, 404)
            self.assertIn("não encontrado", result.json["erro"])

    def test_upstream_failure_is_not_reported_as_not_found(self):
        with patch("pokemon_api.requests.get", return_value=response(status=503)):
            result = self.client.get("/pokemons/25")
            self.assertEqual(result.status_code, 502)
            self.assertIn("PokéAPI", result.json["erro"])

    def test_timeouts_and_connection_errors(self):
        for error, expected in ((requests.Timeout(), 504), (requests.ConnectionError(), 502)):
            with self.subTest(error=type(error).__name__):
                with patch("pokemon_api.requests.get", side_effect=error):
                    result = self.client.get("/pokemons/25")
                    self.assertEqual(result.status_code, expected)
                    self.assertIn("erro", result.json)

    def test_invalid_json_and_missing_stats(self):
        invalid_json = response()
        invalid_json.json.side_effect = ValueError("bad json")
        bad_pokemon = copy.deepcopy(raw_pokemon())
        bad_pokemon["stats"] = []
        for upstream in (invalid_json, response(data=[]), response(data=bad_pokemon)):
            fetch_json.cache_clear()
            with patch("pokemon_api.requests.get", return_value=upstream):
                self.assertEqual(self.client.get("/pokemons/25").status_code, 502)

    def test_resource_cache_avoids_repeated_calls(self):
        with patch("pokemon_api.requests.get", return_value=response(data=raw_pokemon())) as fetch:
            self.assertEqual(self.client.get("/pokemons/nome/pikachu").status_code, 200)
            self.assertEqual(self.client.get("/pokemons/nome/pikachu").status_code, 200)
            self.assertEqual(fetch.call_count, 1)

    def test_original_list_and_cors(self):
        def upstream(url, **_kwargs):
            if "?limit=30" in url:
                return response(data={"results": [{"name": "pikachu"}, {"name": "eevee"}]})
            return response(data=raw_pokemon(133, "eevee") if url.endswith("eevee") else raw_pokemon())
        with patch("pokemon_api.requests.get", side_effect=upstream):
            result = self.client.get("/pokemons", headers={"Origin": "http://localhost:8201"})
            self.assertEqual(result.status_code, 200)
            self.assertEqual([item["id"] for item in result.json], [25, 133])
            self.assertEqual(result.headers["Access-Control-Allow-Origin"], "http://localhost:8201")

    def test_random_uses_existing_names_instead_of_assuming_contiguous_ids(self):
        def upstream(url, **_kwargs):
            if "?limit=100000" in url:
                return response(data={"results": [{"name": "pikachu"}, {"name": "deoxys-attack"}]})
            self.assertTrue(url.endswith("/pokemon/deoxys-attack"))
            return response(data=raw_pokemon(10001, "deoxys-attack"))
        with patch("pokemon_api.random.choice", side_effect=lambda names: names[-1]):
            with patch("pokemon_api.requests.get", side_effect=upstream):
                result = self.client.get("/pokemons/aleatorio")
                self.assertEqual(result.status_code, 200)
                self.assertEqual(result.json["id"], 10001)

    def test_image_proxy_and_cache(self):
        with patch("pokemon_api.fetch_json", return_value=raw_pokemon()):
            with patch("pokemon_api.requests.get", return_value=response(content=PNG)) as fetch:
                result = self.client.get("/pokemons/25/imagem")
                self.assertEqual(result.status_code, 200)
                self.assertEqual(result.content_type, "image/png")
                self.assertEqual(result.data, PNG)
                self.assertIn("max-age", result.headers["Cache-Control"])
                self.assertEqual(self.client.get("/pokemons/25/imagem").status_code, 200)
                self.assertEqual(fetch.call_count, 1)
                self.assertFalse(fetch.call_args.kwargs["allow_redirects"])

    def test_untrusted_image_origin_is_blocked(self):
        data = raw_pokemon()
        data["sprites"]["front_default"] = "http://127.0.0.1/private"
        with patch("pokemon_api.fetch_json", return_value=data):
            with patch("pokemon_api.requests.get") as fetch:
                self.assertEqual(self.client.get("/pokemons/25/imagem").status_code, 502)
                fetch.assert_not_called()

    def test_missing_image_is_not_a_pokemon_failure(self):
        data = raw_pokemon()
        data["sprites"]["front_default"] = None
        with patch("pokemon_api.fetch_json", return_value=data):
            self.assertIsNone(self.client.get("/pokemons/25").json["imagem"])
            self.assertEqual(self.client.get("/pokemons/25/imagem").status_code, 404)


if __name__ == "__main__":
    unittest.main()

