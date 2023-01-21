#
# Command Variables
#

RSYNC = rsync
RSYNC_ARGS_W_DELETE = -avz --delete -e ssh --exclude='.DS_Store' --exclude='.well-known/' --progress
RSYNC_ARGS_WO_DELETE = -avz -e ssh --exclude='.DS_Store' --exclude='.well-known/' --progress
RSYNC_DEST = $${SSH_USER}@$${SSH_HOST}:$${SSH_DIR}

#
# Pipeline Variables - pipeline/dist/
#

clustered_geojson := pipeline/dist/clustered.images.geojson
geojson := pipeline/dist/images.geojson
streets := pipeline/dist/streets.txt

#
# Pipeline Variables - pipeline/dist/toronto-archives/
#

archives_geojson := pipeline/dist/toronto-archives/images.geojson
archives_image_geocodes := pipeline/dist/toronto-archives/geocode_results.json
archives_images := pipeline/dist/toronto-archives/images.ndjson
archives_parent_mined_data := pipeline/dist/toronto-archives/parent_mined_data.json
archives_series_geocodes := pipeline/dist/toronto-archives/parent.geocode_results.json

#
# Pipeline Variables - pipeline/dist/tpl/
#

tpl_geocodes := pipeline/dist/tpl/library_geocodes.json
tpl_geojson := pipeline/dist/tpl/images.geojson
tpl_images := pipeline/dist/tpl/toronto-library.ndjson
tpl_images_geojson := pipeline/dist/tpl/library-images.geojson
tpl_nonstar_images := pipeline/dist/tpl/non-star-images.ndjson

#
# Top Level Targets
#

all: ;

.PHONY: clean
clean: backend-clean frontend-clean pipeline-clean ;

.PHONY: dist
dist: backend-dist frontend-dist;

.PHONY: init
# This doesn't depend on `requirements.txt` because this is for first-time
# initialization; at that point, it has to exist and it has to be
# up-to-date.
init: backend-init frontend-init pipeline-init
	python3 -m venv .venv
	.venv/bin/pip install -r requirements.txt

requirements.txt: backend/requirements.txt pipeline/requirements.txt
	.venv/bin/pip-compile --output-file "$@" --resolver=backtracking "$<"
	.venv/bin/pip-sync "$@"

.PHONY: sync
# Go "bottom-up" so that "children" are on the server before "parents."
sync:
	$(MAKE) backend-sync
	$(MAKE) frontend-sync

.PHONY: sync-full
# Go "bottom-up" so that "children" are on the server before "parents."
sync-full:
	$(MAKE) backend-sync-full
	$(MAKE) frontend-sync-full

#
# Backend Targets
#

.PHONY: backend-clean
backend-clean:
	rm -rf backend/dist/*

.PHONY: backend-dist
backend-dist: backend-clean pipeline-dist
	cd backend/src && ../../.venv/bin/flask --debug bake

.PHONY: backend-init
backend-init: ;

.PHONY: backend-serve
backend-serve:
	cd backend/src && ../../.venv/bin/flask --debug run --port 8081

backend/requirements.txt: backend/requirements.in
	.venv/bin/pip-compile --output-file "$@" --resolver=backtracking "$<"

.PHONY: backend-sync
# Go "bottom-up" so that "children" are on the server before "parents."
backend-sync:
	$(shell grep -v "^#" .env | xargs) && $(RSYNC) $(RSYNC_ARGS_WO_DELETE) --include="/api/images/" --exclude="*" backend/dist/api/images/ $(RSYNC_DEST)
	$(shell grep -v "^#" .env | xargs) && $(RSYNC) $(RSYNC_ARGS_WO_DELETE) --include="/api/locations/" --exclude="*" backend/dist/api/locations/ $(RSYNC_DEST)
	$(shell grep -v "^#" .env | xargs) && $(RSYNC) $(RSYNC_ARGS_WO_DELETE) --include="/api/" --exclude="*" --exclude="/api/images/" --exclude="/api/locations/" backend/dist/api/ $(RSYNC_DEST)

.PHONY: backend-sync-full
# Go "bottom-up" so that "children" are on the server before "parents."
backend-sync-full:
	$(shell grep -v "^#" .env | xargs) && $(RSYNC) $(RSYNC_ARGS_W_DELETE) --include="/api/images/" --exclude="*" backend/dist/api/images/ $(RSYNC_DEST)
	$(shell grep -v "^#" .env | xargs) && $(RSYNC) $(RSYNC_ARGS_W_DELETE) --include="/api/locations/" --exclude="*" backend/dist/api/locations/ $(RSYNC_DEST)
	$(shell grep -v "^#" .env | xargs) && $(RSYNC) $(RSYNC_ARGS_W_DELETE) --include="/api/" --exclude="*" --exclude="/api/images/" --exclude="/api/locations/" backend/dist/api/ $(RSYNC_DEST)

#
# Frontend Targets
#

.PHONY: frontend-clean
frontend-clean:
	rm -rf frontend/dist/*

.PHONY: frontend-dist
frontend-dist: frontend-clean
	cd frontend && npm run build

.PHONY: frontend-init
frontend-init:
	cd frontend && npm install

.PHONY: frontend-serve
frontend-serve:
	cd frontend && npm run start

.PHONY: frontend-sync
frontend-sync:
	$(shell grep -v "^#" .env | xargs) && $(RSYNC) $(RSYNC_ARGS_WO_DELETE) --exclude="/api/" frontend/dist/ $(RSYNC_DEST)

.PHONY: frontend-sync-full
frontend-sync-full:
	$(shell grep -v "^#" .env | xargs) && $(RSYNC) $(RSYNC_ARGS_W_DELETE) --exclude="/api/" frontend/dist/ $(RSYNC_DEST)

#
# Pipeline Targets
#

.PHONY: pipeline-clean
pipeline-clean:
	rm pipeline/dist/*.md5
	rm pipeline/dist/toronto-archives/*.md5
	rm pipeline/dist/tpl/*.md5
	rm pipeline/src/*.md5

.PHONY: pipeline-dist
pipeline-dist: $(geojson).md5 ;

.PHONY: pipeline-init
# By making sure that files are newer than input sources, we will make sure 
# steps only run if the .md5 file changes, instead of using timestamps. This
# is useful if you're using a new repo from version control, since it's
# impossible to trust those timestamps.
pipeline-init: pipeline-clean
	find pipeline/dist/ ! -name '*.md5' ! -name 'toronto-pois.osm.csv' ! -name 'images.ndjson' ! -name 'series.ndjson' ! -name 'truth.gtjson'  | grep -v 'Old Toronto Responses' | xargs touch
	find pipeline/src/ -maxdepth 1 ! -name '*.md5' | xargs touch

pipeline/requirements.txt: pipeline/requirements.in
	.venv/bin/pip-compile --output-file "$@" --resolver=backtracking "$<"

#
# More Pipeline Targets
#

# .md5 hash files keep track of the previous md5 hash of a file. Generate a new
# .md5 hash file if the md5 hash of a file does not match what is in an
# existing .md5 hash file. "make pipeline-init" makes sure that this step will run.
%.md5: %
	@$(if $(filter-out $(shell cat $@ 2>/dev/null), $(shell md5sum $*)),md5sum $* > $@)

#
# Pipeline Targets - pipeline/dist/
#

$(clustered_geojson): pipeline/src/cluster_geojson.py.md5 $(geojson).md5
	.venv/bin/python3 pipeline/src/cluster_geojson.py --input_file $(geojson) --output_file $@

$(geojson): $(tpl_geojson).md5 $(archives_geojson).md5
	.venv/bin/python3 pipeline/src/merge_feature_collections.py \
	  $(archives_geojson) \
	  $(tpl_geojson) \
	  $@

$(streets): pipeline/src/extract_noun_phrases.py.md5 $(archives_images).md5
	.venv/bin/python3 pipeline/src/extract_noun_phrases.py --noun_type streets > /tmp/streets+examples.txt
	cut -f2 /tmp/streets+examples.txt | sed 1d | sort > $@

#
# Pipeline Targets - pipeline/dist/toronto-archives/
#

# Mining data from parents has outstanding issues. Use a stale version of the
# file until resolving AP-237
$(archives_geojson): pipeline/src/generate_geojson.py.md5 $(archives_image_geocodes).md5
	.venv/bin/python3 pipeline/src/generate_geojson.py \
	--input $(archives_images) \
	--parent_data $(archives_parent_mined_data) \
	--geocode_results $(archives_image_geocodes) \
	--path_to_size pipeline/dist/toronto-archives/image-sizes.txt \
	--source toronto-archives \
	--output $@

$(archives_image_geocodes): pipeline/src/geocode.py.md5 pipeline/dist/toronto-pois.osm.csv.md5 $(streets).md5 $(archives_images).md5
	.venv/bin/python3 pipeline/src/geocode.py \
	--input $(archives_images) \
	--street_names $(streets) \
	--output $@

$(archives_parent_mined_data): pipeline/src/geocode.py.md5 pipeline/src/mine_parents_for_data.py pipeline/dist/series.ndjson.md5 $(archives_image_geocodes).md5
	.venv/bin/python3 pipeline/src/geocode.py --input pipeline/dist/series.ndjson --output $(archives_series_geocodes) --strict true
	.venv/bin/python3 pipeline/src/mine_parents_for_data.py --seri`es_geocoded $(archives_series_geocodes) --geocoded_results $(archives_image_geocodes) --output $@

#
# Pipeline Targets - pipeline/dist/tpl/
#

$(tpl_geocodes): pipeline/src/geocode.py.md5 pipeline/dist/toronto-pois.osm.csv.md5 $(streets).md5 $(tpl_nonstar_images).md5
	.venv/bin/python3 pipeline/src/geocode.py \
	--input $(tpl_nonstar_images) \
	--street_names $(streets) \
	--output $@

# Mining data from parents has outstanding issues. Use a stale version of the 
# file until resolving AP-237
$(tpl_geojson): pipeline/src/generate_geojson.py.md5 $(tpl_geocodes).md5
	.venv/bin/python3 pipeline/src/generate_geojson.py \
	--input $(tpl_nonstar_images) \
	--geocode_results $(tpl_geocodes) \
	--path_to_size pipeline/dist/tpl/image-sizes.txt \
	--source tpl \
	--drop_unlocated \
	--output $@

$(tpl_nonstar_images): $(tpl_images).md5 pipeline/src/filter_star_images.py.md5
	.venv/bin/python3 pipeline/src/filter_star_images.py \
		$(tpl_images) \
		> $(tpl_nonstar_images)

#
# Pipeline Targets - Other
#

.PHONY: pipeline-generate-diff-sample
pipeline-generate-diff-sample:
	.venv/bin/python3 pipeline/src/geocode.py --sample 0.05 --output /tmp/geocode_results.new.5pct.json
	.venv/bin/python3 pipeline/src/generate_geojson.py --sample 0.05 /tmp/geocode_results.new.5pct

.PHONY: pipeline-calculate-truth-metrics
pipeline-calculate-truth-metrics: $(geojson).md5 pipeline/dist/truth.gtjson.md5
	.venv/bin/python3 pipeline/src/calculate_metrics.py --truth_data pipeline/dist/truth.gtjson --computed_data $(geojson)
