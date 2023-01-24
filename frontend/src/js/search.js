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
        setLocation(latLng, address);
      } else {
        // TODO: analytics event - link - address-search-fail
        console.error(status);
      }
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
