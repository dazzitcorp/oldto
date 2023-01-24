/* global mapboxgl */
/* global process */

import 'mapbox-gl-compare';

const BASE_STYLE = 'mapbox://styles/rvilim/cjg87z8j1068k2sp653i9xpbm?fresh=true';

// TODO(danvk): show minor roads depending on zoom level, building names.
const LABEL_LAYERS = [
  'road_major',
  'road_major_label',
  'poi_label',
  'bridge_major',
  'bridge_minor'
]
const YEARS = [1947, 1983, 1985, 1987, 1989, 1991, 1992, 2018];

mapboxgl.accessToken = process.env.MAPBOX_API_KEY;

var map = new mapboxgl.Map({
  container: 'map',
  style: BASE_STYLE,
  center: [-79.3738487, 43.6486135],
  zoom: 13
});
map.addControl(new mapboxgl.NavigationControl({showCompass: false}), 'bottom-right');
map.addControl(new mapboxgl.GeolocateControl({
  positionOptions: {
    enableHighAccuracy: true
  }
}), 'bottom-right');

var map2 = new mapboxgl.Map({
  container: 'map2',
  style: BASE_STYLE,
  center: [-79.3738487, 43.6486135],
  zoom: 13
})

new mapboxgl.Compare(map, map2, {
  // mousemove: true // Optional. Set to true to enable swiping during cursor movement.
});

let marker;

map.on('load', () => {
  window.map = map;

  map.setLayoutProperty('Satellite', 'visibility', 'none');
  for (const year of YEARS) {
    map.setPaintProperty('' + year, 'raster-fade-duration', 0);
    map2.setPaintProperty('' + year, 'raster-fade-duration', 0);
  }

  showYear('1947', map);
  showYear('2018', map2);
});

function showYear(year, map) {
  const newLayer = '' + year;

  $('#year').text(year);
  const currentLayer = newLayer
  map.setLayoutProperty(currentLayer, 'visibility', 'visible');
  map.moveLayer(currentLayer, 'landuse_overlay_national_park');  // move to, below labels
  for (const year of YEARS) {
    const layer = '' + year;
    if (layer !== currentLayer) {
      map.setLayoutProperty(layer, 'visibility', 'none');
    }
  }
}

let labelsVisible = false;
function setLabelVisibility() {
  const visibility = labelsVisible ? 'visible' : 'none';
  for (const label of LABEL_LAYERS) {
    map.setLayoutProperty(label, 'visibility', visibility);
    map2.setLayoutProperty(label, 'visibility', visibility);
  }
}

$('#year-select').on('change', function() {
  const year = $(this).val();
  showYear(year, map);
});

$('#show-labels').on('change', function() {
  labelsVisible = $(this).is(':checked');
  setLabelVisibility();
});

$('#location-search').on('keypress', function(e) {
  if (e.which !== 13) return;

  document.activeElement.blur();  // hides keyboard for kiosk

  const address = $(this).val();
  // This is a bit tight to avoid a bug with how Google geocodes "140 Yonge".
  const bounds = {
    south: 43.598284,
    west: -79.448761,
    north: 43.712376,
    east: -79.291565
  };

  new google.maps.Geocoder().geocode({
    address: address,
  bounds: bounds
  }, (results, status) => {
    if (status === 'OK') {
      // TODO: analytics event - link - address-search
      const latLng = results[0].geometry.location;

      if (marker) {
        marker.setMap(null);
      }
      marker = new mapboxgl.Marker()
        .setLngLat([latLng.lng(), latLng.lat()])
        .addTo(map);

      map.setCenter([latLng.lng(), latLng.lat()]);
      map.setZoom(15);
    } else {
      // TODO: analytics event - link - address-search-fail
      console.error(status);
    }
  })

});
