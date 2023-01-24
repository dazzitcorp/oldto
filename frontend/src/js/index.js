/* global mapReady */

import './app-history';
import './search';

import { fillPopularImagesPanel, initializeMap } from './viewer';
import { imagesReady, locationsReady } from './index-init';

$(function() {
  Promise.all([locationsReady, mapReady]).then(() => {
    initializeMap();
  });
  imagesReady.then(() => {
    fillPopularImagesPanel();
  });
});
