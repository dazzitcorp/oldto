#!/usr/bin/env python3
"""Calculate metrics between two GTJSON files.

This will print row-by-row metrics and overall summary statistics. These can be
copy/pasted into a spreadsheet for further analysis.

Taxonomy of errors:

Dates:
    - No date associated with a record but there should be one.
    - Date incorrectly associated with an undated record.
    - Date is imprecise (1984 vs. 1984-03-01)
    - Date is incorrect (1984 vs. 1985)
    - Date is overly precise (1985 vs. 1980/1989)

Geocodes
    - Missing a location
    - Have a location where there should be none
    - Location is far (>250m?) from true location. Bullseye = within 25m?
"""
import argparse
import csv
import json
import sys

from haversine import haversine


def diff_date(truth_date, computed_date):
    """Compare two dates. Returns (match?, reason for mismatch)."""
    if computed_date == truth_date:
        return (True, "")
    if computed_date is None:
        return (False, "Missing date")
    if truth_date is None:
        return (False, "Should be missing date")
    return (False, "complex")  # TODO(danvk): make errors more precise


def _coord_to_str(coord):
    # Returns (lat, lng) for easy pasting into Google Maps
    return "%.6f,%.6f" % (coord[1], coord[0]) if coord else "None"


def diff_geocode(truth_coord, computed_coord):
    """Compare two coordinates. Returns (match? reason for mismatch).

    Coords are (lng, lat). Either may be None.
    """
    if _coord_to_str(truth_coord) == _coord_to_str(computed_coord):
        return (True, "")
    if computed_coord is None:
        return (False, "Missing geocode")
    if truth_coord is None:
        return (False, "Should be missing geocode")
    distance_km = haversine(truth_coord, computed_coord)
    if distance_km > 0.25:
        return (False, "Too far: %.3f km" % distance_km)
    return (True, "")


def tally_stats(truth_features, computed_features):
    """Print row-by-row results and overall metrics."""
    id_to_truth_feature = {f["id"]: f for f in truth_features}

    num_datable = 0
    num_dated_correct = 0
    num_geocodable = 0
    num_geocoded_correct = 0
    num_geocoded = 0

    out = csv.writer(sys.stdout, delimiter="\t")
    out.writerow(
        [
            "id",
            "title",
            "computed date",
            "true date",
            "date match",
            "date reason",
            "computed location",
            "true location",
            "location match",
            "location reason",
            "location string",
            "notes",
        ]
    )
    for feature in computed_features:
        id_ = feature["id"]
        props = feature["properties"]
        truth_feature = id_to_truth_feature.get(id_)
        if not truth_feature:
            continue

        true_date = truth_feature["properties"]["date"]
        computed_date = props["date"]
        if true_date:
            num_datable += 1
        (date_match, date_reason) = diff_date(true_date, computed_date)

        true_coords = (
            truth_feature["geometry"] and truth_feature["geometry"]["coordinates"]
        )
        computed_coords = feature["geometry"] and feature["geometry"]["coordinates"]
        if true_coords:
            num_geocodable += 1
        if computed_coords:
            num_geocoded += 1
        (geocode_match, geocode_reason) = diff_geocode(true_coords, computed_coords)

        if date_match and true_date:
            num_dated_correct += 1
        if geocode_match and true_coords:
            num_geocoded_correct += 1

        if computed_coords:
            search_term = props["geocode"]["search_term"]
        else:
            search_term = ""
        out.writerow(
            [
                str(x)
                for x in (
                    id_,
                    props["title"],
                    computed_date,
                    true_date,
                    date_match,
                    date_reason,
                    _coord_to_str(computed_coords),
                    _coord_to_str(true_coords),
                    geocode_match,
                    geocode_reason,
                    search_term,
                    truth_feature["properties"]["geocoding_notes"],
                )
            ]
        )

    num_geocoded_incorrect = num_geocoded - num_geocoded_correct
    print(
        """
Results:
  Dates
    %3d / %3d = %.2f%% of datable images correctly dated.

  Geocodes
    %3d / %3d = %.2f%% of locatable images correctly located.
    %3d / %3d = %.2f%% incorrectly located.
"""
        % (
            num_dated_correct,
            num_datable,
            100.0 * num_dated_correct / num_datable,
            num_geocoded_correct,
            num_geocodable,
            100.0 * num_geocoded_correct / num_geocodable,
            num_geocoded_incorrect,
            num_geocoded,
            100.0 * num_geocoded_incorrect / num_geocoded,
        )
    )


if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        "Comparse geojson derived from geocoding against truth data"
    )
    parser.add_argument(
        "--truth_data",
        type=str,
        help=".gtjson files containing truth data",
        default="pipeline/dist/truth.gtjson",
    )
    parser.add_argument(
        "--computed_data",
        type=str,
        help="result of generate_geojson.py from geocoded images",
        default="pipeline/dist/images.geojson",
    )
    args = parser.parse_args()

    truth_features = json.load(open(args.truth_data))["features"]
    computed_features = json.load(open(args.computed_data))["features"]

    tally_stats(truth_features, computed_features)
