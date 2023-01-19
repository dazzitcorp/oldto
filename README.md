# OldTO

OldTO is a site that showcases historic photographs of Toronto by placing them 
on a map.

You can read more about it on the [Sidewalk Labs Blog][blog].

Here's a screen recording of what OldTO looked like (YouTube):

[![Screen recording of OldTO](https://img.youtube.com/vi/krW-wl7gACA/0.jpg)][youtube]

While the OldTO is no longer hosted by Sidewalk Labs, the source code was 
available in a repo. This revival is based on that code.

## How it works

OldTO begins with data from the [Toronto Archives][1], which you can find
in [`pipeline/dist/images.ndjson`](/pipeline/dist/images.ndjson).

To place the images on a map ("geocode" them), we use a [list of Toronto
street names](/pipeline/dist/streets.txt) and a collection of regular expressions
which look for addresses and cross-streets. We send these through the
[Google Maps Geocoding API][API] to get latitudes and longitudes for the
images. We also incorporate a [set of points of interest](/pipeline/dist/toronto-pois.osm.csv)
for popular locations like City Hall and the CN Tower.

## How to use it

There are three basic parts to this:

* the pipeline that generates data;
* the backend that serves data; and
* the frontend that presents data.

When you first get going, create a `.env` file (or, even better, separate
`.env.development` and `.env.production` files) in the `frontend` directory 
with the following keys and values:

    GOOGLE_MAPS_API_KEY=...
    MAPBOX_API_KEY=...

and a `settings.py` file in the `pipeline` directory with the following keys 
and values:

    GOOGLE_MAPS_API_KEY="..."

(Note that you might want to use different keys for frontend development/
frontend production/pipeline in order to better control their restrictions.)

Then perform some first-time initialization:

    make init

To run locally for development, use (in two different terminal windows):

    make backend-serve
    make frontend-serve

and visit http://localhost:8080/.

To create a distribution for production, use:

    make dist

Making a distribution gives you a set of files in:

* `backend/dist/`; and
* `frontend/dist/`

which, when combined into a single directory, can be served statically.

## Generating new geocodes

First, add your [Google Maps API key][api key] to the file `pipeline/src/settings.py`.

Next, you'll first want to download cached geocodes from [here][cached-geocodes].
Unzip this file into `cache/maps.googleapis.com`. This will make the geocoding
pipeline run faster and more consistently than geocoding from scratch.

With this in place, you can update `images.geojson` by running:

    make pipeline-dist

(Note that you'll need to have `md5sum` installed.)

### Analyzing results and changes

Before sending out a PR with geocoding changes, you'll want to run a diff to evaluate the change.

For a quick check, you can operate on a 5% sample and diff that against `master`:

    pipeline/src/geocode.py --sample 0.05 --output /tmp/geocode_results.new.5pct.json
    pipeline/src/diff_geocodes.py --sample 0.05 /tmp/geocode_results.new.5pct.json

To calculate metrics using truth data (must have jq installed):

    grep -E  "$(jq '.features[] | .id' pipeline/dist/truth.gtjson | sed s/\"//g | paste -s -d '|' )" pipeline/dist/images.ndjson > pipeline/dist/test.images.ndjson
    pipeline/src/geocode.py --input pipeline/dist/test.images.ndjson
    pipeline/src/generate_geojson.py --geocode_results pipeline/dist/test.images.ndjson --output pipeline/dist/test.images.geojson
    pipeline/src/calculate_metrics.py --truth_data pipeline/dist/truth.gtjson --computed_data pipeline/dist/test.images.geojson

To debug a specific image ID, run something like:

    pipeline/src/geocode.py --ids 520805 --output /tmp/geocode.json && \
    cat pipeline/src/geocode.py.log | grep -v regex

If you want to understand the differences between two `images.geojson` files, you can
use the `diff_geojson.py` script. This file will create a series of `.geojson` files
showing differences between an A and B GeoJSON. This is useful for using with the
data collected to the corrections google forms. Use those along with the
`check_changes_using_*` scripts.

Once you're ready to send the PR, run a diff on the full geocodes.

### Update street names

To update the list of street names, run:

    pipeline/src/extract_noun_phrases.py streets 1 > /tmp/streets+examples.txt && \
    cut -f2 /tmp/streets+examples.txt | sed 1d | sort > pipeline/dist/streets.txt

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
