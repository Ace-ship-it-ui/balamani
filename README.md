# Balamani Shih Tzu

## Repository layout

- `docs/`: public website and GitHub Pages publishing folder.
- `docs/assets/css/`: website styles.
- `docs/assets/js/`: optional live-review integration.
- `docs/assets/images/`: images used by the website.
- `previews/client-area.html`: interactive client-area prototype. Open locally to try it; it is not a secure login or a working email system.
- Root image files: retained for compatibility with existing image URLs.

## Publishing

In repository Settings > Pages, select **Deploy from a branch**, then **main** and **/docs**, and save. Updates to `docs/` will then publish through GitHub Pages.

## Editing

Edit the HTML files in `docs/` and keep asset paths relative so the site works under the repository URL. The original laptop backups and unused image variants are not included.

## Client area status

The preview uses temporary in-tab data only. Real invitations, authentication, owner-only administration and cross-device calendar updates still require an online backend and email configuration. No customer records, passwords or service secrets belong in this public repository.

## Reviews

The live-review worker is not configured. The script leaves the static reviews unchanged until a real worker URL is supplied. The displayed excerpt count is manually maintained; currently the label says 20 while the page contains 18 excerpt cards.
