/* global mapReady */

import './app-history';
import './search';

import {fillPopularImagesPanel, initializeMap} from './viewer';

$(function() {
  fillPopularImagesPanel();
  mapReady.then(() => {
    initializeMap();
  })
});
