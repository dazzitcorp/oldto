#!/usr/bin/env python
"""Run a dev server for the OldTO API.

This is useful for iterating on geocoding since it will reload the GeoJSON file if it changes.

Supported endpoints:
- /api/oldtoronto/lat_lng_counts?var=lat_lons
- /api/oldtoronto/by_location?lat=43.651501&lng=-79.359842
- /api/layer/oldtoronto/86514
"""

import argparse
import copy
import json
import os
from collections import Counter, defaultdict

from flask import Flask, Response, abort, jsonify, request
from haversine import haversine

geojson_features = []  # file's features
geojson_file_mtime = 0  # file's last modified time
geojson_file_name = None  # file's name


def old_toronto_key(lat, lng):
    """Return a key for a record that matches the old toronto convention of the
    concatenation of the lat and lng rounded to 6 decimals.
    Rounding is done differently in JavaScript from Python - 3.499999 rounds to
    3.4 in Python, 3.5 in JavaScript, hence the workaround to first round to 7
    decimals and then to 6.
    """

    def round6(f):
        return round(round(f, 7), 6)

    lat = round6(lat)
    lng = round6(lng)

    return f"{lat:2.6f},{lng:2.6f}"


app = Flask(__name__)


def load_geojson_features():
    global geojson_file_name, geojson_file_mtime, geojson_features
    geojson_file_mtime = os.stat(geojson_file_name).st_mtime
    # Filter out the null geometries ahead of time.
    with open(geojson_file_name) as geojson_file:
        geojson_features = [
            f for f in json.load(geojson_file)["features"] if f["geometry"]
        ]
    print(f"Loaded {len(geojson_features)} features from {geojson_file_name}")


# Check for changes to the GeoJSON file before every request.
@app.before_request
def maybe_load_geojson_features():
    global geojson_file_mtime, geojson_file_name
    if os.stat(geojson_file_name).st_mtime > geojson_file_mtime:
        load_geojson_features()


def _lat_lng_counts():
    counts = defaultdict(Counter)
    for f in geojson_features:
        lng, lat = f["geometry"]["coordinates"]
        year = f["properties"]["date"] or ""
        counts[old_toronto_key(lat, lng)][year] += 1
    return counts


@app.route("/api/oldtoronto/lat_lng_counts")
def lat_lng_counts():
    var = request.args.get("var")
    js = "var %s=%s" % (var, json.dumps(_lat_lng_counts()))
    return Response(js, mimetype="text/javascript")


def _by_location(lat: float, lng: float):
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


@app.route("/api/oldtoronto/by_location")
def by_location():
    return jsonify(
        _by_location(float(request.args.get("lat")), float(request.args.get("lng")))
    )


def _by_photo_id(photo_id: str):
    for feature in geojson_features:
        if feature["id"] == photo_id:
            return feature
    return None


@app.route("/api/layer/oldtoronto/<photo_id>")
def by_photo_id(photo_id):
    photo = _by_photo_id(photo_id)
    return jsonify(photo) if photo else abort(404)


if __name__ == "__main__":
    parser = argparse.ArgumentParser("Run a simple API server for Old Toronto")
    parser.add_argument(
        "--port", type=int, help="Port on which to serve.", default=8081
    )
    parser.add_argument(
        "geojson",
        type=str,
        default="pipeline_data/images.geojson",
        help="Path to images.geojson",
    )
    args = parser.parse_args()

    geojson_file_name = args.geojson
    load_geojson_features()

    app.run(host="0.0.0.0", port=args.port, debug=True)
