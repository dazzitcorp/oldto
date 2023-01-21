/* global mapReady */

import {fillPopularImagesPanel, initializeMap} from './viewer';
import './app-history';
import './search';

$(function() {
  fillPopularImagesPanel();
  mapReady.then(() => {
    initializeMap();
  })
});
