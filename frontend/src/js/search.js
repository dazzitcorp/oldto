/* global process */

/**
 * This module supports address search and the current location button.
 */

import { map, markerIcons, updateClearFilters } from './viewer';

export let locationMarker = null;

function setLocation(latLng, title) {
  map.panTo(latLng);
  map.setZoom(17);

  if (locationMarker) {
    locationMarker.setMap(null);
  }
  locationMarker = new google.maps.Marker({
    position: latLng,
    map,
    title,
    icon: markerIcons.searchPin
  });

  updateClearFilters();
}

export function hideLocationMarker() {
  if (locationMarker) {
    locationMarker.setMap(null);
    locationMarker = null;
  }
}

$(() => {
  $('#location-search').on('keypress', function(e) {
    if (e.which !== 13) return;

    document.activeElement.blur();  // hides keyboard for kiosk

    const address = $(this).val();
    $.getJSON('https://maps.googleapis.com/maps/api/geocode/json', {
      address,
      key: process.env.GOOGLE_MAPS_API_KEY_FOR_GEOCODING,
      // This is a bit tight to avoid a bug with how Google geocodes "140 Yonge".
      bounds: '43.598284,-79.448761|43.712376, -79.291565'
    }).done(response => {
      if (response && response.results && response.results.length > 0) {
        const latLng = response.results[0].geometry.location;
        setLocation(latLng, address);
        // TODO: analytics event - link - address-search
      }
    }).fail(e => {
      console.error(e);
      // TODO: analytics event - link - address-search-fail
    })
  });

  $('#current-location').on('click', () => {
    navigator.geolocation.getCurrentPosition(position => {
      const { latitude, longitude } = position.coords;
      setLocation({lat: latitude, lng: longitude}, 'Current Location');
      // TODO: analytics event - link - current-location
    }, e => {
      console.error(e);
      // TODO: analytics event - link - current-location-error
    });
  });
});
