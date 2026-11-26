'use strict';

const link = document.getElementById('booking-app');
const target = new URL(link.href);
target.search = location.search;
target.hash = location.hash;
link.href = target.href;
location.replace(target.href);
