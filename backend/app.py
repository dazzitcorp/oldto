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
- /api/locations.js?var=lat_lons
- /api/locations/43.651501,-79.359842.json
- /api/images/86514.json
"""

import copy
import json
import logging
import re
from collections import Counter, defaultdict

from flask import Flask, Response, abort, current_app, jsonify, request

VAR_RE = re.compile(r"(?a:^\w+$)")


def _load_geojson_features(geojson_file_name):
    # Filter out the null geometries ahead of time.
    with open(geojson_file_name) as geojson_file:
        geojson_features = [
            f for f in json.load(geojson_file)["features"] if f["geometry"]
        ]
    return geojson_features


def _lat_lng_key(lat, lng):
    """Return a key that concatenates the lat and lng, rounded to 6 decimal places.
    Rounding is done differently in JavaScript and Python; 3.499999 rounds to 3.4
    in Python, but 3.5 in JavaScript. The workaround is to first round to 7 decimals,
    and then to 6.
    """

    def _round6(f):
        return round(round(f, 7), 6)

    lat = _round6(lat)
    lng = _round6(lng)

    return f"{lat:2.6f},{lng:2.6f}"


def _geojson_features_by_location(geojson_features):
    def f_to_l(f):
        props = copy.deepcopy(f["properties"])
        image = props.pop("image")
        image["image_url"] = image.pop("url")
        return dict(image, id=f["id"], **props)

    locations = defaultdict(dict)
    for f in geojson_features:
        lng, lat = f["geometry"]["coordinates"]
        locations[_lat_lng_key(lat, lng)][f["id"]] = f_to_l(f)
    return locations


def _geojson_features_by_image(geojson_features):
    return {f["id"]: f for f in geojson_features}


def _locations(geojson_features):
    counts = defaultdict(Counter)
    for f in geojson_features:
        lng, lat = f["geometry"]["coordinates"]
        year = f["properties"]["date"] or ""
        counts[_lat_lng_key(lat, lng)][year] += 1
    return counts


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

    app.config["GEOJSON_FEATURES"] = _load_geojson_features(
        app.config["GEOJSON_FILE_NAME"]
    )
    app.config["GEOJSON_FEATURES_BY_LOCATION"] = _geojson_features_by_location(
        app.config["GEOJSON_FEATURES"]
    )
    app.config["GEOJSON_FEATURES_BY_IMAGE"] = _geojson_features_by_image(
        app.config["GEOJSON_FEATURES"]
    )

    app.logger.info(
        f"Loaded {len(app.config['GEOJSON_FEATURES']):,} features from {app.config['GEOJSON_FILE_NAME']}."
    )

    def _geojson_features():
        return current_app.config.get("GEOJSON_FEATURES", [])

    @app.route("/api/locations.js")
    def locations_js():
        var = request.args.get("var", "locations")
        if not VAR_RE.match(var):
            abort(400)
        js = "var %s=%s" % (
            var,
            json.dumps(_locations(_geojson_features()), sort_keys=True),
        )
        return Response(js, mimetype="text/javascript")

    @app.route("/api/locations/<location_id>.json")
    def locations_location(location_id):
        location = app.config["GEOJSON_FEATURES_BY_LOCATION"].get(location_id)
        return jsonify(location) if location else abort(404)

    @app.route("/api/images/<image_id>.json")
    def images_image(image_id):
        image = app.config["GEOJSON_FEATURES_BY_IMAGE"].get(image_id)
        return jsonify(image) if image else abort(404)

    return app


if __name__ == "__main__":
    app = create_app()
    app.run(port=8081, debug=True)
