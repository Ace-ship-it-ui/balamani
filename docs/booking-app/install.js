'use strict';

const installButton = document.getElementById('install-app');
const installHelp = document.getElementById('install-help');
const standalone = window.matchMedia('(display-mode: standalone)').matches || navigator.standalone;
const appleMobile = /iPhone|iPad|iPod/i.test(navigator.userAgent)
  || (navigator.platform === 'MacIntel' && navigator.maxTouchPoints > 1);
let installPrompt;

if (!standalone) {
  installButton.hidden = false;
  window.addEventListener('beforeinstallprompt', event => {
    event.preventDefault();
    installPrompt = event;
  });
  installButton.addEventListener('click', async () => {
    if (installPrompt) {
      const prompt = installPrompt;
      installPrompt = null;
      await prompt.prompt();
      return;
    }
    installHelp.textContent = appleMobile
      ? 'Open this app in Safari, tap Share, then Add to Home Screen. If shown, turn on Open as Web App.'
      : 'Open your browser menu and choose Install app or Add to Home screen.';
    installHelp.hidden = !installHelp.hidden;
    installButton.setAttribute('aria-expanded', String(!installHelp.hidden));
  });
  window.addEventListener('appinstalled', () => {
    installButton.hidden = true;
    installHelp.hidden = true;
  });
}

if ('serviceWorker' in navigator) {
  navigator.serviceWorker.register('sw.js').catch(error => {
    console.warn('Booking app offline page could not be enabled.', error);
  });
}
