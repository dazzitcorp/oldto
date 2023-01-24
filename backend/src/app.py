#!/usr/bin/env python
"""Run a server for the API.

The server defaults to loading data from a `images.geojson` file in
the current directory. To choose a different file, create a `config.py`
file with:

    GEOJSON_FILE_NAME=...

or use an environment variable (prefixed with "FLASK"):

    FLASK_GEOJSON_FILE_NAME=... app.py

Running this file directly starts a server in debug mode that listens
on port 8081. For more control, run the server through Flask instead,
e.g.:

    flask --debug run --extra-files images.geojson --port 8081

(The `--extra-files images.geojson` bit will cause the server
to reload if `images.geojson` changes.)

Supported endpoints:
- /api/locations.js?var=lat_lons (default: LOCATIONS)
- /api/locations.json
- /api/locations/43.651501,-79.359842.json
- /api/images/86514.json
"""

import hashlib
import json
import logging
import pathlib
import re
import shutil
from collections import Counter, defaultdict

import click
from flask import Flask, Response, abort, current_app, jsonify, request

# Change ETAG_VERSION when the data hasn't changed but the structure of a response has.
ETAG_VERSION = "2"
VAR_RE = re.compile(r"(?a:^\w+$)")


def _load_geojson_features(geojson_file_name):
    def _lat_lng_key(lat, lng):
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

    # Filter out the null geometries ahead of time.
    with open(geojson_file_name) as geojson_file:
        geojson_features = [
            f for f in json.load(geojson_file)["features"] if f["geometry"]
        ]
        for f in geojson_features:
            f["properties"]["id"] = f["id"]
            f["properties"]["location"] = _lat_lng_key(*f["geometry"]["coordinates"])
    return geojson_features


def _geojson_features_locations(geojson_features):
    locations = defaultdict(Counter)
    for f in geojson_features:
        location = f["properties"]["location"]
        year = f["properties"]["date"] or ""
        locations[location][year] += 1
    return locations


def _geojson_features_locations_json(geojson_features_locations):
    return json.dumps(geojson_features_locations, sort_keys=True)


def _geojson_features_locations_json_etag(geojson_features_locations_json):
    md5 = hashlib.md5(ETAG_VERSION.encode())
    md5.update(geojson_features_locations_json.encode())
    return md5.hexdigest()


def _geojson_features_by_location(geojson_features):
    locations = defaultdict(dict)
    for f in geojson_features:
        locations[f["properties"]["location"]][f["id"]] = f["properties"]
    return locations


def _geojson_features_by_image(geojson_features):
    images = {f["id"]: f["properties"] for f in geojson_features}
    return images


def _bake(dir):
    current_app.logger.info(f"Baking to {dir}...")

    root = pathlib.Path(dir)
    if root.exists():
        shutil.rmtree(root)
    root.mkdir(parents=True)
    with open(root / "locations.js", "w") as f:
        f.write(
            f"var LOCATIONS={current_app.config['GEOJSON_FEATURES_LOCATIONS_JSON']}"
        )
    with open(root / "locations.json", "w") as f:
        f.write(current_app.config["GEOJSON_FEATURES_LOCATIONS_JSON"])

    locations = root / "locations"
    locations.mkdir()
    for id, location in current_app.config["GEOJSON_FEATURES_BY_LOCATION"].items():
        with open(locations / f"{id}.json", "w") as f:
            json.dump(location, f, indent=True, sort_keys=True)

    images = root / "images"
    images.mkdir()
    for id, image in current_app.config["GEOJSON_FEATURES_BY_IMAGE"].items():
        with open(images / f"{id}.json", "w") as f:
            json.dump(image, f, indent=True, sort_keys=True)

    current_app.logger.info("Done.")


def create_app():
    app = Flask(__name__, instance_relative_config=True)

    app.logger.setLevel(logging.INFO)

    # First defaults...
    app.config.from_mapping(
        GEOJSON_FILE_NAME="images.geojson",
    )
    # Then file...
    app.config.from_pyfile("config.py", silent=True)
    # Then env... (e.g. FLASK_GEOJSON_FILE_NAME)
    app.config.from_prefixed_env(prefix="FLASK")

    # Since the locations JSON is *the thing* we do on *every* page load,
    # pre-compute it.

    app.logger.info(f"Loading features from {app.config['GEOJSON_FILE_NAME']}...")
    app.config["GEOJSON_FEATURES"] = _load_geojson_features(
        app.config["GEOJSON_FILE_NAME"]
    )
    app.config["GEOJSON_FEATURES_LOCATIONS"] = _geojson_features_locations(
        app.config["GEOJSON_FEATURES"]
    )
    app.config["GEOJSON_FEATURES_LOCATIONS_JSON"] = _geojson_features_locations_json(
        app.config["GEOJSON_FEATURES_LOCATIONS"]
    )
    app.config[
        "GEOJSON_FEATURES_LOCATIONS_JSON_ETAG"
    ] = _geojson_features_locations_json_etag(
        app.config["GEOJSON_FEATURES_LOCATIONS_JSON"]
    )
    app.config["GEOJSON_FEATURES_BY_LOCATION"] = _geojson_features_by_location(
        app.config["GEOJSON_FEATURES"]
    )
    app.config["GEOJSON_FEATURES_BY_IMAGE"] = _geojson_features_by_image(
        app.config["GEOJSON_FEATURES"]
    )

    app.logger.info(
        f"Loaded {len(app.config['GEOJSON_FEATURES']):,} features "
        f"from {app.config['GEOJSON_FILE_NAME']}."
    )
    app.logger.info(
        f"The features ETag is {app.config['GEOJSON_FEATURES_LOCATIONS_JSON_ETAG']}."
    )

    @app.route("/api/locations.js")
    def locations_js():
        var = request.args.get("var", "LOCATIONS")
        if not VAR_RE.match(var):
            abort(400)

        if request.if_none_match.contains(
            current_app.config["GEOJSON_FEATURES_LOCATIONS_JSON_ETAG"]
        ):
            return jsonify(message="OK"), 304

        response = Response(
            f"var {var}={current_app.config['GEOJSON_FEATURES_LOCATIONS_JSON']}",
            mimetype="text/javascript",
        )
        response.set_etag(current_app.config["GEOJSON_FEATURES_LOCATIONS_JSON_ETAG"])
        return response

    @app.route("/api/locations.json")
    def locations_json():
        if request.if_none_match.contains(
            current_app.config["GEOJSON_FEATURES_LOCATIONS_JSON_ETAG"]
        ):
            return jsonify(message="OK"), 304

        response = Response(
            current_app.config["GEOJSON_FEATURES_LOCATIONS_JSON"],
            mimetype="application/json",
        )
        response.set_etag(current_app.config["GEOJSON_FEATURES_LOCATIONS_JSON_ETAG"])
        return response

    @app.route("/api/locations/<location_id>.json")
    def locations_location(location_id):
        if request.if_none_match.contains(
            current_app.config["GEOJSON_FEATURES_LOCATIONS_JSON_ETAG"]
        ):
            return jsonify(message="OK"), 304

        location = app.config["GEOJSON_FEATURES_BY_LOCATION"].get(location_id)
        if not location:
            abort(404)

        response = Response(
            json.dumps(location, sort_keys=True),
            mimetype="application/json",
        )
        response.set_etag(current_app.config["GEOJSON_FEATURES_LOCATIONS_JSON_ETAG"])
        return response

    @app.route("/api/images/<image_id>.json")
    def images_image(image_id):
        if request.if_none_match.contains(
            current_app.config["GEOJSON_FEATURES_LOCATIONS_JSON_ETAG"]
        ):
            return jsonify(message="OK"), 304

        image = app.config["GEOJSON_FEATURES_BY_IMAGE"].get(image_id)
        if not image:
            abort(404)

        response = Response(
            json.dumps(image, sort_keys=True),
            mimetype="application/json",
        )
        response.set_etag(current_app.config["GEOJSON_FEATURES_LOCATIONS_JSON_ETAG"])
        return response

    @app.cli.command("bake")
    @click.option(
        "--dir", "-d", default="../dist/api", type=click.Path(file_okay=False)
    )
    def bake(dir):
        with app.app_context():
            _bake(dir)

    return app


if __name__ == "__main__":
    app = create_app()
    app.run(port=8081, debug=True)
