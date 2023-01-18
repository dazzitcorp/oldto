clustered_geojson := pipeline/dist/clustered.images.geojson
archives_geojson := pipeline/dist/toronto-archives/images.geojson
archives_images := pipeline/dist/toronto-archives/images.ndjson
archives_image_geocodes := pipeline/dist/toronto-archives/geocode_results.json
parent_mined_data := pipeline/dist/toronto-archives/parent_mined_data.json
series_geocodes := pipeline/dist/toronto-archives/parent.geocode_results.json
streets := pipeline/dist/streets.txt

tpl_images := pipeline/dist/tpl/toronto-library.ndjson
tpl_nonstar_images := pipeline/dist/tpl/non-star-images.ndjson
tpl_geocodes := pipeline/dist/tpl/library_geocodes.json
tpl_images_geojson := pipeline/dist/tpl/library-images.geojson
tpl_geojson := pipeline/dist/tpl/images.geojson

geojson := pipeline/dist/images.geojson

all: $(geojson).md5

$(clustered_geojson): pipeline/src/cluster_geojson.py.md5 $(geojson).md5
	python pipeline/src/cluster_geojson.py --input_file $(geojson) --output_file $@

# truth-metics does not exist as a file, this is a command
.PHONY: truth-metrics
truth-metrics: $(geojson).md5 pipeline/dist/truth.gtjson.md5
	python pipeline/src/calculate_metrics.py --truth_data pipeline/dist/truth.gtjson --computed_data $(geojson)

# diff-sample does not exist as a file, this is a command
.PHONY: diff-sample
diff-sample:
	pipeline/src/geocode.py --sample 0.05 --output /tmp/geocode_results.new.5pct.json
	pipeline/src/generate_geojson.py --sample 0.05 /tmp/geocode_results.new.5pct

# mining data from parents has outstanding issues. Use a stale version of the file until resolving AP-237
$(archives_geojson): pipeline/src/generate_geojson.py.md5 $(archives_image_geocodes).md5
	pipeline/src/generate_geojson.py \
	--input $(archives_images) \
	--parent_data $(parent_mined_data) \
	--geocode_results $(archives_image_geocodes) \
	--path_to_size pipeline/dist/toronto-archives/image-sizes.txt \
	--source toronto-archives \
	--output $@

$(parent_mined_data): pipeline/src/geocode.py.md5 pipeline/src/mine_parents_for_data.py pipeline/dist/series.ndjson.md5 $(archives_image_geocodes).md5
	pipeline/src/geocode.py --input pipeline/dist/series.ndjson --output $(series_geocodes) --strict true
	pipeline/src/mine_parents_for_data.py --seri`es_geocoded $(series_geocodes) --geocoded_results $(archives_image_geocodes) --output $@

$(archives_image_geocodes): pipeline/src/geocode.py.md5 pipeline/dist/toronto-pois.osm.csv.md5 $(streets).md5 $(archives_images).md5
	pipeline/src/geocode.py \
	--input $(archives_images) \
	--street_names $(streets) \
	--output $@

$(streets): pipeline/src/extract_noun_phrases.py.md5 $(archives_images).md5
	pipeline/src/extract_noun_phrases.py --noun_type streets > /tmp/streets+examples.txt
	cut -f2 /tmp/streets+examples.txt | sed 1d | sort > $@

$(tpl_nonstar_images): $(tpl_images).md5 pipeline/src/filter_star_images.py.md5
	pipeline/src/filter_star_images.py \
		$(tpl_images) \
		> $(tpl_nonstar_images)

$(tpl_geocodes): pipeline/src/geocode.py.md5 pipeline/dist/toronto-pois.osm.csv.md5 $(streets).md5 $(tpl_nonstar_images).md5
	python pipeline/src/geocode.py \
	--input $(tpl_nonstar_images) \
	--street_names $(streets) \
	--output $@

# mining data from parents has outstanding issues. Use a stale version of the file until resolving AP-237
$(tpl_geojson): pipeline/src/generate_geojson.py.md5 $(tpl_geocodes).md5
	pipeline/src/generate_geojson.py \
	--input $(tpl_nonstar_images) \
	--geocode_results $(tpl_geocodes) \
	--path_to_size pipeline/dist/tpl/image-sizes.txt \
	--source tpl \
	--drop_unlocated \
	--output $@

$(geojson): $(tpl_geojson).md5 $(archives_geojson).md5
	pipeline/src/merge_feature_collections.py \
	  $(archives_geojson) \
	  $(tpl_geojson) \
	  $@

# .md5 hash files keep track of the previous md5 hash of a file
# generate a new .md5 hash file if the md5 hash of a file does not match what is in an existing .md5 hash file
# by runnning make update, it makes sure that this step will run
%.md5: %
	@$(if $(filter-out $(shell cat $@ 2>/dev/null), $(shell md5sum $*)),md5sum $* > $@)

.PHONY: requirements
requirements: requirements.txt backend/requirements.txt pipeline/requirements.txt ;

requirements.txt: requirements.in
	.venv/bin/pip-compile --output-file "$@" --resolver=backtracking "$<"

backend/requirements.txt: backend/requirements.in
	.venv/bin/pip-compile --output-file "$@" --resolver=backtracking "$<"

pipeline/requirements.txt: pipeline/requirements.in
	.venv/bin/pip-compile --output-file "$@" --resolver=backtracking "$<"

.PHONY: deps
deps: requirements.txt
	.venv/bin/pip install -r requirements.txt

# by making sure that files are newer than input sources, we will make sure steps only run if the .md5 file changes, instead of using timestamps
# this is useful if you're using a new repo from version control, since it's impossible to trust those timestamps
.PHONY: update
update:
	find pipeline/src/ -maxdepth 1 ! -name '*.md5' | xargs touch
	find pipeline/dist/ ! -name '*.md5' ! -name 'toronto-pois.osm.csv' ! -name 'images.ndjson' ! -name 'series.ndjson' ! -name 'truth.gtjson'  | grep -v 'Old Toronto Responses' | xargs touch

clean:
	rm pipeline/dist/*.md5
	rm pipeline/dist/*/*.md5
	rm pipeline/src/*.md5
