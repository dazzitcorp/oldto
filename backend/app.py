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
- /api/oldtoronto/lat_lng_counts?var=lat_lons
- /api/oldtoronto/by_location?lat=43.651501&lng=-79.359842
- /api/layer/oldtoronto/86514
"""

import copy
import json
from collections import Counter, defaultdict

from flask import Flask, Response, abort, current_app, jsonify, request
from haversine import haversine


def _load_geojson_features(geojson_file_name):
    # Filter out the null geometries ahead of time.
    with open(geojson_file_name) as geojson_file:
        geojson_features = [
            f for f in json.load(geojson_file)["features"] if f["geometry"]
        ]
        print(f"Loaded {len(geojson_features)} features from {geojson_file_name}.")
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


def _lat_lng_counts(geojson_features):
    counts = defaultdict(Counter)
    for f in geojson_features:
        lng, lat = f["geometry"]["coordinates"]
        year = f["properties"]["date"] or ""
        counts[_lat_lng_key(lat, lng)][year] += 1
    return counts


def _by_location(geojson_features, lat: float, lng: float):
    def poi_to_rec(poi):
        props = copy.deepcopy(poi["properties"])
        image = props.pop("image")
        image["image_url"] = image.pop("url")
        return dict(image, id=poi["id"], **props)

    pt = (lat, lng)
    results = {
        f["id"]: poi_to_rec(f)
        for f in geojson_features
        if haversine(pt, f["geometry"]["coordinates"][::-1]) < 0.005
    }
    return results


def _by_photo_id(geojson_features, photo_id: str):
    for f in geojson_features:
        if f["id"] == photo_id:
            return f
    return None


def create_app():
    app = Flask(__name__, instance_relative_config=True)

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

    def _geojson_features():
        return current_app.config.get("GEOJSON_FEATURES", [])

    @app.route("/api/oldtoronto/lat_lng_counts")
    def lat_lng_counts():
        var = request.args.get("var")
        js = "var %s=%s" % (
            var,
            json.dumps(_lat_lng_counts(_geojson_features())),
        )
        return Response(js, mimetype="text/javascript")

    @app.route("/api/oldtoronto/by_location")
    def by_location():
        return jsonify(
            _by_location(
                _geojson_features(),
                float(request.args.get("lat")),
                float(request.args.get("lng")),
            )
        )

    @app.route("/api/layer/oldtoronto/<photo_id>")
    def by_photo_id(photo_id):
        photo = _by_photo_id(_geojson_features(), photo_id)
        return jsonify(photo) if photo else abort(404)

    return app


if __name__ == "__main__":
    app = create_app()
    app.run(port=8081, debug=True)
