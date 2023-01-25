#!/usr/bin/env python
"""Run a server for the API.

The server defaults to loading data from `images.geojson` and `images.json`
files in the current directory. To choose different files, create a `config.py`
file with:

    IMAGES_GEOJSON_FILENAME=...
    IMAGES_JSON_FILENAME=...

or use environment variables (prefixed with "BACKEND"):

    BACKEND_IMAGES_GEOJSON_FILENAME=... BACKEND_IMAGES_JSON_FILE_NAME=... app.py

(`images.json`, by the way, is a JSON list of "featured features."
The IDs in the list are image IDs.)

Running this file directly starts a server in debug mode that listens
on port 8081. For more control, run the server through Flask instead,
e.g.:

    flask --debug run --extra-files images.geojson:images.json --port 8081

(The `--extra-files images.geojson:images.json` bit will cause the server
to reload if either file changes.)

Supported endpoints:

- /api/locations_ex.json
- /api/locations/43.651501,-79.359842.json

- /api/images_ex.json
- /api/images/86514.json

(The `_ex` suffixes are because those files aren't just lists, they're...
bespoke.)
"""

import hashlib
import json
import logging
import pathlib
import shutil
import sys
from collections import Counter, defaultdict

import click
from flask import Flask, Response, abort, current_app, jsonify, request, url_for

# Change ETAG_VERSION when the content of the response hasn't changed
# but the structure has -- e.g., a new field was added.
ETAG_VERSION = "2"


def _check_can_load(filename):
    if not pathlib.Path(filename).is_file():
        print(f"file not found: {filename}", file=sys.stderr)
        exit(1)


def _load_images_geojson(images_geojson_filename):
    def _lat_lng_key(lng, lat):
        """Return a key that concatenates the lat and lng, rounded to 6 decimal
        places. Rounding is done differently in JavaScript and Python; 3.499999
        rounds to 3.4 in Python, but 3.5 in JavaScript. The workaround is to
        first round to 7 decimals, and then to 6.
        """

        def _round6(f):
            return round(round(f, 7), 6)

        lat = _round6(lat)
        lng = _round6(lng)

        return f"{lat:2.6f},{lng:2.6f}"

    _check_can_load(images_geojson_filename)
    with open(images_geojson_filename) as geojson_file:
        # Filter out null geometries ahead of time.
        images_geojson = [
            f for f in json.load(geojson_file)["features"] if f["geometry"]
        ]
        # Add the location and image id to the image's properties.
        for f in images_geojson:
            f["properties"]["id"] = f["id"]
            f["properties"]["location"] = _lat_lng_key(*f["geometry"]["coordinates"])
    return images_geojson


def _load_images_json(images_json_filename):
    _check_can_load(images_json_filename)
    with open(images_json_filename) as json_file:
        images_json = json.load(json_file)
    return images_json


def _locations(images_geojson):
    """{
        "<location>": {
            "": <count>,
            "<year>": <count>
        }, ...
    }"""
    locations = defaultdict(Counter)
    for f in images_geojson:
        location = f["properties"]["location"]
        year = f["properties"]["date"] or ""
        locations[location][year] += 1
    return locations


def _locations_json(locations):
    return json.dumps(locations, sort_keys=True)


def _images(images_json, by_image):
    """[
        {
            <image properties>
        }, ...
    ]"""
    featured = sorted(
        [by_image[featured] for featured in images_json if featured in by_image],
        key=lambda f: (f["date"] or "", f["title"], f["id"]),
    )
    return featured


def _images_json(images):
    return json.dumps(images, sort_keys=True)


def _etag(locations_json, images_json):
    md5 = hashlib.md5(ETAG_VERSION.encode())
    md5.update(locations_json.encode())
    md5.update(images_json.encode())
    return md5.hexdigest()


def _by_location(images_geojson):
    """{
        "<location>": {
            "<image>": {
                <image properties>
            }, ...
        }, ...
    }"""
    locations = defaultdict(dict)
    for f in images_geojson:
        locations[f["properties"]["location"]][f["id"]] = f["properties"]
    return locations


def _by_image(images_geojson):
    """{
        "<image>": {
            <image properties>
        }, ...
    }"""
    images = {f["id"]: f["properties"] for f in images_geojson}
    return images


def create_app():
    app = Flask(__name__, instance_relative_config=True)

    app.logger.setLevel(logging.INFO)

    # First defaults...
    app.config.from_mapping(
        IMAGES_GEOJSON_FILENAME="images.geojson",
        IMAGES_JSON_FILENAME="images.json",
    )
    # Then file...
    app.config.from_pyfile("config.py", silent=True)
    # Then env...
    app.config.from_prefixed_env(prefix="BACKEND")

    # Load...
    app.logger.info(f"Loading {app.config['IMAGES_GEOJSON_FILENAME']}...")
    images_geojson = _load_images_geojson(app.config["IMAGES_GEOJSON_FILENAME"])

    app.logger.info(f"Loading {app.config['IMAGES_JSON_FILENAME']}...")
    images_json = _load_images_json(app.config["IMAGES_JSON_FILENAME"])

    app.logger.info("Working...")

    # Derive: location id -> image id -> image
    app.config["BY_LOCATION"] = _by_location(images_geojson)

    # Derive: image id -> image
    app.config["BY_IMAGE"] = _by_image(images_geojson)

    # Since the locations and images JSON are produced on *every* page load,
    # pre-compute them.

    # Derive: location ids -> year ids -> counts
    app.config["LOCATIONS"] = _locations(images_geojson)
    app.config["LOCATIONS_JSON"] = _locations_json(app.config["LOCATIONS"])

    # Derive: [image, ...]
    app.config["IMAGES"] = _images(images_json, app.config["BY_IMAGE"])
    app.config["IMAGES_JSON"] = _images_json(app.config["IMAGES"])

    # Derive: ETag
    app.config["ETAG"] = _etag(app.config["LOCATIONS_JSON"], app.config["IMAGES_JSON"])

    app.logger.info(f"Loaded {len(app.config['LOCATIONS']):,} features.")
    app.logger.info(f"Loaded {len(app.config['IMAGES']):,} featured features.")
    app.logger.info(f"Current ETag is {app.config['ETAG']}.")

    @app.route("/api/locations_ex.json")
    def locations_json():
        if request.if_none_match.contains(current_app.config["ETAG"]):
            return jsonify(message="OK"), 304

        response = Response(
            current_app.config["LOCATIONS_JSON"],
            mimetype="application/json",
        )
        response.set_etag(current_app.config["ETAG"])
        return response

    @app.route("/api/locations/<location_id>.json")
    def locations_location(location_id):
        if request.if_none_match.contains(current_app.config["ETAG"]):
            return jsonify(message="OK"), 304

        location = app.config["BY_LOCATION"].get(location_id)
        if not location:
            abort(404)

        response = Response(
            json.dumps(location, sort_keys=True),
            mimetype="application/json",
        )
        response.set_etag(current_app.config["ETAG"])
        return response

    @app.route("/api/images_ex.json")
    def images_json():
        if request.if_none_match.contains(current_app.config["ETAG"]):
            return jsonify(message="OK"), 304

        response = Response(
            current_app.config["IMAGES_JSON"],
            mimetype="application/json",
        )
        response.set_etag(current_app.config["ETAG"])
        return response

    @app.route("/api/images/<image_id>.json")
    def images_image(image_id):
        if request.if_none_match.contains(current_app.config["ETAG"]):
            return jsonify(message="OK"), 304

        image = app.config["BY_IMAGE"].get(image_id)
        if not image:
            abort(404)

        response = Response(
            json.dumps(image, sort_keys=True),
            mimetype="application/json",
        )
        response.set_etag(current_app.config["ETAG"])
        return response

    @app.cli.command("bake")
    @click.option("--dir", "-d", default="../dist", type=click.Path(file_okay=False))
    def bake(dir):
        app.config["SERVER_NAME"] = "localhost"
        with app.app_context():
            current_app.logger.info(f"Baking to {dir}...")

            root = pathlib.Path(dir)
            root.mkdir(exist_ok=True, parents=True)

            api = root / "api"
            if api.exists():
                current_app.logger.info("Removing...")
                shutil.rmtree(api)
            api.mkdir()

            locations = root / "api" / "locations"
            locations.mkdir()

            images = root / "api" / "images"
            images.mkdir()

            current_app.logger.info("Writing...")

            with open(root / url_for("locations_json", _external=False)[1:], "w") as f:
                f.write(current_app.config["LOCATIONS_JSON"])

            for id, location in current_app.config["BY_LOCATION"].items():
                with open(
                    root
                    / url_for("locations_location", location_id=id, _external=False)[
                        1:
                    ],
                    "w",
                ) as f:
                    json.dump(location, f, indent=True, sort_keys=True)

            with open(root / url_for("images_json", _external=False)[1:], "w") as f:
                f.write(current_app.config["IMAGES_JSON"])

            for id, image in current_app.config["BY_IMAGE"].items():
                with open(
                    root / url_for("images_image", image_id=id, _external=False)[1:],
                    "w",
                ) as f:
                    json.dump(image, f, indent=True, sort_keys=True)

            current_app.logger.info("Done.")

    return app


if __name__ == "__main__":
    app = create_app()
    app.run(port=8081, debug=True)
