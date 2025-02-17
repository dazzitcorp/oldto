#!/bin/sh

set -o errexit

cat pipeline/dist/feedback_corrections.tsv | grep "Submit correction" | awk -F'\t' '{ print $3","$4","$5}' > /tmp/corrections.csv
grep -E "$(cat /tmp/corrections.csv | awk -F, '{ print $1 }' | paste -s -d '|')" /tmp/images.ndjson > /tmp/corrections.ndjson
python pipeline/src/geocode.py --input /tmp/corrections.ndjson --output /tmp/corrections.geocode_results.json
python pipeline/src/corrections_metrics.py
cat /tmp/incorrect.csv
