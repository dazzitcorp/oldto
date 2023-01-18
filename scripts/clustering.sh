#!/bin/sh
# change the viewport location in frontend/js/viewer.js
# change the variable location in this script accordingly
# make sure you are serving the files from frontend
set -o errexit
LOCATION="yonge-and-bay"
OUT_DIR="screenshots"

mkdir -p $OUT_DIR

for EPS in $(seq 0.0001 0.00001 0.0002);
do
  echo "run for epsilon: $EPS"
  python pipeline/src/cluster_geojson.py --output_file pipeline/dist/clustered.images.geojson --epsilon $EPS
  python pipeline/src/gtjson_to_site.py pipeline/dist/clustered.images.geojson frontend/
  cd frontend
  npm run build
  cd -
  OUTPUT_PATH="${OUT_DIR}/${LOCATION}-clustered-${EPS}.png"
  echo $OUTPUT_PATH
  node scripts/screenshot.js $OUTPUT_PATH
done
