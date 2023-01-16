# OldTO

OldTO was a site that showcased historic photographs of Toronto by placing them on a map.

You can read more about it on the [Sidewalk Labs Blog][blog].

Here's a screen recording of what OldTO looked like (YouTube):

[![Screen recording of OldTO](https://img.youtube.com/vi/krW-wl7gACA/0.jpg)][youtube]

While the OldTO is no longer hosted by Sidewalk Labs, the source code is all available in this
repo and it is possible to run it yourself. The instructions below describe how to do this.

## How it works

OldTO begins with data from the [Toronto Archives][1], which you can find
in [`pipeline_data/images.ndjson`](/pipeline_data/images.ndjson).

To place the images on a map ("geocode" them), we use a [list of Toronto
street names](/pipeline_data/streets.txt) and a collection of regular expressions
which look for addresses and cross-streets. We send these through the
[Google Maps Geocoding API][API] to get latitudes and longitudes for the
images. We also incorporate a [set of points of interest](/pipeline_data/toronto-pois.osm.csv)
for popular locations like the CN Tower or City Hall.

## Development setup

Setup dependencies (on a Mac):

    brew install coreutils csvkit

OldTO requires Python 3. Once you have this set up, you can install the
Python dependencies in a virtual environment via:

    python3 -m venv .venv
    source .venv/bin/activate
    pip install -r requirements.txt

## Running the site

### Backend

The data for the OldTO site is served by a Python API server.
Start by running this:

    source .venv/bin/activate
    backend/app.py pipeline_data/images.geojson

If you've generated geocodes in a different location, change `pipeline_data/images.geojson` to that.

### Frontend

The OldTO site lives in the `frontend` directory:

    cd frontend

To install the required packages, use:

    npm install

Then create a `.env` file (or, even better, separate `.env.development` and `.env.production` files) in the `frontend` directory with the following keys and values:

    FACEBOOK_APP_ID=...
    GOOGLE_ANALYTICS_TRACKING_ID=...
    GOOGLE_MAPS_API_KEY=...
    MAPBOX_API_KEY=...

Now you can build the site:

    npm run build

or run it locally:

    npm run start

If you run it locally, visit http://localhost:8080/ to browse it.

(To run the frontend locally you have to run the backend locally too!)

## Generating new geocodes

First, add your [Google Maps API key][api key] to the file `pipeline/settings.py`.

Next, you'll first want to download cached geocodes from [here][cached-geocodes].
Unzip this file into `cache/maps.googleapis.com`. This will make the geocoding
pipeline run faster and more consistently than geocoding from scratch.

With this in place, you can update `images.geojson` by running:

    make

Note, to run the makefile on an OSX machine you will probably want to install md5sum, which can be done by running:

    brew update && brew install md5sha1sum

### Analyzing results and changes

Before sending out a PR with geocoding changes, you'll want to run a diff to evaluate the change.

For a quick check, you can operate on a 5% sample and diff that against `master`:

    pipeline/geocode.py --sample 0.05 --output /tmp/geocode_results.new.5pct.json
    pipeline/diff_geocodes.py --sample 0.05 /tmp/geocode_results.new.5pct.json

To calculate metrics using truth data (must have jq installed):

    grep -E  "$(jq '.features[] | .id' pipeline_data/truth.gtjson | sed s/\"//g | paste -s -d '|' )" pipeline_data/images.ndjson > pipeline_data/test.images.ndjson
    pipeline/geocode.py --input pipeline_data/test.images.ndjson
    pipeline/generate_geojson.py --geocode_results pipeline_data/test.images.ndjson --output pipeline_data/test.images.geojson
    pipeline/calculate_metrics.py --truth_data pipeline_data/truth.gtjson --computed_data pipeline_data/test.images.geojson

To debug a specific image ID, run something like:

    pipeline/geocode.py --ids 520805 --output /tmp/geocode.json && \
    cat pipeline/geocode.py.log | grep -v regex

If you want to understand the differences between two `images.geojson` files, you can
use the `diff_geojson.py` script. This file will create a series of `.geojson` files
showing differences between an A and B GeoJSON. This is useful for using with the
data collected to the corrections google forms. Use those along with the
`check_changes_using_*` scripts.

Once you're ready to send the PR, run a diff on the full geocodes.

### Update street names

To update the list of street names, run:

    pipeline/extract_noun_phrases.py streets 1 > /tmp/streets+examples.txt && \
    cut -f2 /tmp/streets+examples.txt | sed 1d | sort > pipeline_data/streets.txt

[1]: https://www.toronto.ca/city-government/accountability-operations-customer-service/access-city-information-or-records/city-of-toronto-archives/
[m]: https://gencat.eloquent-systems.com/city-of-toronto-archives-m-public.html
[API]: https://developers.google.com/maps/documentation/geocoding/intro
[api key]: https://developers.google.com/maps/documentation/javascript/get-api-key
[image]: https://gencat.eloquent-systems.com/city-of-toronto-archives-m-permalink.html?key=571480
[file]: https://gencat.eloquent-systems.com/city-of-toronto-archives-m-permalink.html?key=348714
[GeoJSON]: http://geojson.org
[cached-geocodes]: https://drive.google.com/open?id=1F0J3RHUA1bVRJTJGlRKDuE_IVpb1BwQH
[about]: https://oldtoronto.sidewalklabs.com/about.html
[blog]: https://medium.com/sidewalk-talk/explore-toronto-through-historical-photos-one-block-at-a-time-2fbcd38b511a
[youtube]: https://www.youtube.com/watch?v=krW-wl7gACA
