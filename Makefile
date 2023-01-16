clustered_geojson := data/clustered.images.geojson
archives_geojson := data/toronto-archives/images.geojson
archives_images := data/toronto-archives/images.ndjson
archives_image_geocodes := data/toronto-archives/geocode_results.json
parent_mined_data := data/toronto-archives/parent_mined_data.json
series_geocodes := data/toronto-archives/parent.geocode_results.json
streets := data/streets.txt

tpl_images := data/tpl/toronto-library.ndjson
tpl_nonstar_images := data/tpl/non-star-images.ndjson
tpl_geocodes := data/tpl/library_geocodes.json
tpl_images_geojson := data/tpl/library-images.geojson
tpl_geojson := data/tpl/images.geojson

geojson := data/images.geojson

all: $(geojson).md5

$(clustered_geojson): pipeline/cluster_geojson.py.md5 $(geojson).md5
	python pipeline/cluster_geojson.py --input_file $(geojson) --output_file $@

# truth-metics does not exist as a file, this is a command
.PHONY: truth-metrics
truth-metrics: $(geojson).md5 data/truth.gtjson.md5
	python pipeline/calculate_metrics.py --truth_data data/truth.gtjson --computed_data $(geojson)

# diff-sample does not exist as a file, this is a command
.PHONY: diff-sample
diff-sample:
	pipeline/geocode.py --sample 0.05 --output /tmp/geocode_results.new.5pct.json
	pipeline/generate_geojson.py --sample 0.05 /tmp/geocode_results.new.5pct

# mining data from parents has outstanding issues. Use a stale version of the file until resolving AP-237
$(archives_geojson): pipeline/generate_geojson.py.md5 $(archives_image_geocodes).md5
	pipeline/generate_geojson.py \
	--input $(archives_images) \
	--parent_data $(parent_mined_data) \
	--geocode_results $(archives_image_geocodes) \
	--path_to_size data/toronto-archives/image-sizes.txt \
	--source toronto-archives \
	--output $@

$(parent_mined_data): pipeline/geocode.py.md5 pipeline/mine_parents_for_data.py data/series.ndjson.md5 $(archives_image_geocodes).md5
	pipeline/geocode.py --input data/series.ndjson --output $(series_geocodes) --strict true
	pipeline/mine_parents_for_data.py --seri`es_geocoded $(series_geocodes) --geocoded_results $(archives_image_geocodes) --output $@

$(archives_image_geocodes): pipeline/geocode.py.md5 data/toronto-pois.osm.csv.md5 $(streets).md5 $(archives_images).md5
	pipeline/geocode.py \
	--input $(archives_images) \
	--street_names $(streets) \
	--output $@

$(streets): pipeline/extract_noun_phrases.py.md5 $(archives_images).md5
	pipeline/extract_noun_phrases.py --noun_type streets > /tmp/streets+examples.txt
	cut -f2 /tmp/streets+examples.txt | sed 1d | sort > $@

$(tpl_nonstar_images): $(tpl_images).md5 pipeline/filter_star_images.py.md5
	pipeline/filter_star_images.py \
		$(tpl_images) \
		> $(tpl_nonstar_images)

$(tpl_geocodes): pipeline/geocode.py.md5 data/toronto-pois.osm.csv.md5 $(streets).md5 $(tpl_nonstar_images).md5
	python pipeline/geocode.py \
	--input $(tpl_nonstar_images) \
	--street_names $(streets) \
	--output $@

# mining data from parents has outstanding issues. Use a stale version of the file until resolving AP-237
$(tpl_geojson): pipeline/generate_geojson.py.md5 $(tpl_geocodes).md5
	pipeline/generate_geojson.py \
	--input $(tpl_nonstar_images) \
	--geocode_results $(tpl_geocodes) \
	--path_to_size data/tpl/image-sizes.txt \
	--source tpl \
	--drop_unlocated \
	--output $@

$(geojson): $(tpl_geojson).md5 $(archives_geojson).md5
	pipeline/merge_feature_collections.py \
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
	find pipeline/ -maxdepth 1 ! -name '*.md5' | xargs touch
	find data/ ! -name '*.md5' ! -name 'toronto-pois.osm.csv' ! -name 'images.ndjson' ! -name 'series.ndjson' ! -name 'truth.gtjson'  | grep -v 'Old Toronto Responses' | xargs touch

clean:
	rm data/*.md5
	rm data/*/*.md5
	rm pipeline/*.md5
