/* global mapReady */

import './app-history';
import './search';

import { fillPopularImagesPanel, initializeMap } from './viewer';
import { locationsReady } from './index-init';

$(function() {
  fillPopularImagesPanel();
  Promise.all([locationsReady, mapReady]).then(() => {
    initializeMap();
  })
});
