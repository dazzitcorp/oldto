#
# Command Variables
#

CAT = cat
CUT = cut
FIND = find
GREP = grep
MD5SUM = md5sum
NPM = npm
PYTHON = python3
RM = rm
RSYNC = rsync
RSYNC_ARGS_W_DELETE = $(RSYNC_ARGS) --delete --delete-after
RSYNC_ARGS = -avz --checksum --exclude='.DS_Store' --exclude='.well-known/' --human-readable --rsh=ssh --stats
RSYNC_DEST = $${SSH_USER}@$${SSH_HOST}:$${SSH_DIR}
SED = sed
SORT = sort
VENV_BLACK = .venv/bin/black
VENV_FLAKE8 = .venv/bin/flake8
VENV_FLASK = .venv/bin/flask
VENV_ISORT = .venv/bin/isort
VENV_PIP = .venv/bin/pip
VENV_PIP_COMPILE = .venv/bin/pip-compile
VENV_PIP_SYNC = .venv/bin/pip-sync
VENV_PYTHON = .venv/bin/python3
XARGS = xargs

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
	$(PYTHON) -m venv .venv
	$(VENV_PIP) install -r requirements.txt

.PHONY: lint
lint: backend-lint frontend-lint pipeline-lint ;

.PHONY: reformat
reformat: backend-reformat pipeline-reformat ;

requirements.txt: backend/requirements.txt pipeline/requirements.txt
	$(VENV_PIP_COMPILE) --output-file "$@" --resolver=backtracking "$<"
	$(VENV_PIP_SYNC) "$@"

.PHONY: rsync
# Go "bottom-up" so that "children" are on the server before "parents."
rsync:
	$(MAKE) backend-rsync
	$(MAKE) frontend-rsync

.PHONY: rsync-with-delete
# Go "bottom-up" so that "children" are on the server before "parents."
rsync-with-delete:
	$(MAKE) backend-rsync-with-delete
	$(MAKE) frontend-rsync-with-delete

#
# Backend Targets
#

.PHONY: backend-clean
backend-clean:
	$(RM) -rf backend/dist/*

.PHONY: backend-dist
backend-dist: backend-clean pipeline-dist
	BACKEND_IMAGES_GEOJSON_FILENAME=pipeline/dist/images.geojson BACKEND_IMAGES_JSON_FILENAME=pipeline/dist/images.json $(VENV_FLASK) --app backend/src/app --debug bake --dir backend/dist

.PHONY: backend-init
backend-init: ;

.PHONY: backend-lint
backend-lint:
	$(VENV_FLAKE8) backend/src

.PHONY: backend-reformat
backend-reformat:
	$(VENV_BLACK) backend/src
	$(VENV_ISORT) --profile black backend/src

backend/requirements.txt: backend/requirements.in
	$(VENV_PIP_COMPILE) --output-file "$@" --resolver=backtracking "$<"

.PHONY: backend-rsync
# Go "bottom-up" so that "children" are on the server before "parents."
backend-rsync:
	$(shell $(GREP) -v "^#" .env | $(XARGS)) && $(RSYNC) $(RSYNC_ARGS) --include="/api/" --include="/api/images/" --include="/api/images/*" --exclude="*" backend/dist/api $(RSYNC_DEST)
	$(shell $(GREP) -v "^#" .env | $(XARGS)) && $(RSYNC) $(RSYNC_ARGS) --include="/api/" --include="/api/locations/" --include="/api/locations/*" --exclude="*" backend/dist/api $(RSYNC_DEST)
	$(shell $(GREP) -v "^#" .env | $(XARGS)) && $(RSYNC) $(RSYNC_ARGS) --include="/api/" --exclude="/api/images/" --exclude="/api/locations/" backend/dist/api $(RSYNC_DEST)

.PHONY: backend-rsync-with-delete
# Go "bottom-up" so that "children" are on the server before "parents."
backend-rsync-with-delete:
	$(shell $(GREP) -v "^#" .env | $(XARGS)) && $(RSYNC) $(RSYNC_ARGS_W_DELETE) --include="/api/" --include="/api/images/" --include="/api/images/*" --exclude="*" backend/dist/api $(RSYNC_DEST)
	$(shell $(GREP) -v "^#" .env | $(XARGS)) && $(RSYNC) $(RSYNC_ARGS_W_DELETE) --include="/api/" --include="/api/locations/" --include="/api/locations/*" --exclude="*" backend/dist/api $(RSYNC_DEST)
	$(shell $(GREP) -v "^#" .env | $(XARGS)) && $(RSYNC) $(RSYNC_ARGS_W_DELETE) --include="/api/" --exclude="/api/images/" --exclude="/api/locations/" backend/dist/api $(RSYNC_DEST)

.PHONY: backend-serve
backend-serve:
	BACKEND_IMAGES_GEOJSON_FILENAME=pipeline/dist/images.geojson BACKEND_IMAGES_JSON_FILENAME=pipeline/dist/images.json $(VENV_FLASK) --app backend/src/app --debug run --port 8081

#
# Frontend Targets
#

.PHONY: frontend-clean
frontend-clean:
	$(RM) -rf frontend/dist/*

.PHONY: frontend-dist
frontend-dist: frontend-clean
	cd frontend && $(NPM) run build

.PHONY: frontend-init
frontend-init:
	cd frontend && $(NPM) install

.PHONY: frontend-lint
frontend-lint:
	cd frontend && $(NPM) run lint

.PHONY: frontend-rsync
frontend-rsync:
	$(shell $(GREP) -v "^#" .env | $(XARGS)) && $(RSYNC) $(RSYNC_ARGS) --exclude="/api/" frontend/dist/ $(RSYNC_DEST)

.PHONY: frontend-rsync-with-delete
frontend-rsync-with-delete:
	$(shell $(GREP) -v "^#" .env | $(XARGS)) && $(RSYNC) $(RSYNC_ARGS_W_DELETE) --exclude="/api/" frontend/dist/ $(RSYNC_DEST)

.PHONY: frontend-serve
frontend-serve:
	cd frontend && $(NPM) run start

#
# Pipeline Targets
#

.PHONY: pipeline-clean
pipeline-clean:
	$(RM) pipeline/dist/*.md5
	$(RM) pipeline/dist/toronto-archives/*.md5
	$(RM) pipeline/dist/tpl/*.md5
	$(RM) pipeline/src/*.md5

.PHONY: pipeline-dist
pipeline-dist: $(geojson).md5 ;

.PHONY: pipeline-init
# By making sure that files are newer than input sources, we will make sure
# steps only run if the .md5 file changes, instead of using timestamps. This
# is useful if you're using a new repo from version control, since it's
# impossible to trust those timestamps.
pipeline-init: pipeline-clean
	$(FIND) pipeline/dist/ ! -name '*.md5' ! -name 'toronto-pois.osm.csv' ! -name 'images.ndjson' ! -name 'series.ndjson' ! -name 'truth.gtjson'  | $(GREP) -v 'Old Toronto Responses' | $(XARGS) touch
	$(FIND) pipeline/src/ -maxdepth 1 ! -name '*.md5' | $(XARGS) touch

.PHONY: pipeline-lint
pipeline-lint:
	$(VENV_FLAKE8) pipeline/src

.PHONY: pipeline-reformat
pipeline-reformat:
	$(VENV_BLACK) pipeline/src
	$(VENV_ISORT) --profile black pipeline/src

pipeline/requirements.txt: pipeline/requirements.in
	$(VENV_PIP_COMPILE) --output-file "$@" --resolver=backtracking "$<"

#
# More Pipeline Targets
#

# .md5 hash files keep track of the previous md5 hash of a file. Generate a new
# .md5 hash file if the md5 hash of a file does not match what is in an
# existing .md5 hash file. "make pipeline-init" makes sure that this step will run.
%.md5: %
	@$(if $(filter-out $(shell $(CAT) $@ 2>/dev/null), $(shell $(MD5SUM) $*)),md5sum $* > $@)

#
# Pipeline Targets - pipeline/dist/
#

$(clustered_geojson): pipeline/src/cluster_geojson.py.md5 $(geojson).md5
	$(VENV_PYTHON) pipeline/src/cluster_geojson.py --input_file $(geojson) --output_file $@

$(geojson): $(tpl_geojson).md5 $(archives_geojson).md5
	$(VENV_PYTHON) pipeline/src/merge_feature_collections.py \
	  $(archives_geojson) \
	  $(tpl_geojson) \
	  $@

$(streets): pipeline/src/extract_noun_phrases.py.md5 $(archives_images).md5
	$(VENV_PYTHON) pipeline/src/extract_noun_phrases.py --noun_type streets > /tmp/streets+examples.txt
	$(CUT) -f2 /tmp/streets+examples.txt | $(SED) 1d | $(SORT) > $@

#
# Pipeline Targets - pipeline/dist/toronto-archives/
#

# Mining data from parents has outstanding issues. Use a stale version of the
# file until resolving AP-237
$(archives_geojson): pipeline/src/generate_geojson.py.md5 $(archives_image_geocodes).md5
	$(VENV_PYTHON) pipeline/src/generate_geojson.py \
	--input $(archives_images) \
	--parent_data $(archives_parent_mined_data) \
	--geocode_results $(archives_image_geocodes) \
	--path_to_size pipeline/dist/toronto-archives/image-sizes.txt \
	--source toronto-archives \
	--output $@

$(archives_image_geocodes): pipeline/src/geocode.py.md5 pipeline/dist/toronto-pois.osm.csv.md5 $(streets).md5 $(archives_images).md5
	$(VENV_PYTHON) pipeline/src/geocode.py \
	--input $(archives_images) \
	--street_names $(streets) \
	--output $@

$(archives_parent_mined_data): pipeline/src/geocode.py.md5 pipeline/src/mine_parents_for_data.py pipeline/dist/series.ndjson.md5 $(archives_image_geocodes).md5
	$(VENV_PYTHON) pipeline/src/geocode.py --input pipeline/dist/series.ndjson --output $(archives_series_geocodes) --strict true
	$(VENV_PYTHON) pipeline/src/mine_parents_for_data.py --seri`es_geocoded $(archives_series_geocodes) --geocoded_results $(archives_image_geocodes) --output $@

#
# Pipeline Targets - pipeline/dist/tpl/
#

$(tpl_geocodes): pipeline/src/geocode.py.md5 pipeline/dist/toronto-pois.osm.csv.md5 $(streets).md5 $(tpl_nonstar_images).md5
	$(VENV_PYTHON) pipeline/src/geocode.py \
	--input $(tpl_nonstar_images) \
	--street_names $(streets) \
	--output $@

# Mining data from parents has outstanding issues. Use a stale version of the
# file until resolving AP-237
$(tpl_geojson): pipeline/src/generate_geojson.py.md5 $(tpl_geocodes).md5
	$(VENV_PYTHON) pipeline/src/generate_geojson.py \
	--input $(tpl_nonstar_images) \
	--geocode_results $(tpl_geocodes) \
	--path_to_size pipeline/dist/tpl/image-sizes.txt \
	--source tpl \
	--drop_unlocated \
	--output $@

$(tpl_nonstar_images): $(tpl_images).md5 pipeline/src/filter_star_images.py.md5
	$(VENV_PYTHON) pipeline/src/filter_star_images.py \
		$(tpl_images) \
		> $(tpl_nonstar_images)

#
# Pipeline Targets - Other
#

.PHONY: pipeline-generate-diff-sample
pipeline-generate-diff-sample:
	$(VENV_PYTHON) pipeline/src/geocode.py --sample 0.05 --output /tmp/geocode_results.new.5pct.json
	$(VENV_PYTHON) pipeline/src/generate_geojson.py --sample 0.05 /tmp/geocode_results.new.5pct

.PHONY: pipeline-calculate-truth-metrics
pipeline-calculate-truth-metrics: $(geojson).md5 pipeline/dist/truth.gtjson.md5
	$(VENV_PYTHON) pipeline/src/calculate_metrics.py --truth_data pipeline/dist/truth.gtjson --computed_data $(geojson)
