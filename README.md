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

## Client area

`docs/client.html` is the real invite-only client login. Supabase project `pqkzhfcqpkcqttixoysr` stores accounts and bookings. Public registration is disabled. `supabase/migrations/001_client_area.sql` defines protected application tables and service-only procedures; `supabase/functions/client-api/index.ts` validates every user session and membership before reading data or accepting changes. Clients can only see their own bookings. Owners are configured in a private database table, never through user-editable metadata.

Owners generate single-use invitation/recovery links and send them privately themselves. No email provider is required for this flow. The calendar polls shared state every 10 seconds and rechecks blocked dates inside the booking transaction. Capacity is four dogs per day, counting pending and confirmed requests on both arrival and departure dates. Each booking contains 1–4 dog names. Declining or cancelling releases slots. There is no maximum stay length; arrival must be within two years. The calendar shares aggregate occupancy without other clients’ identities. Apply migrations 001 through 004 in order. An owner can block new requests without cancelling existing stays.

The Edge Function performs live `auth.getUser` validation; legacy-only gateway JWT verification is off to support modern signing keys. Initial owner links can be generated with the dashboard's server credential and the `bootstrap` action, restricted to the private owner allowlist. Never expose this credential in the website or repository. Owner activation is a separate controlled step.

The prototype under `previews/` remains a local demonstration only. No customer records, passwords, generated invitation links or service secrets belong in this public repository. The browser publishable key is intentionally public; database privileges and server checks enforce access.

Deploy function changes through Supabase and website changes through GitHub Pages. Database migrations must be applied before publishing dependent frontend changes. Update the fixed site URL and CORS origin in the function if the site moves to a custom domain.

## Invitation validity

Apply `20261010170449_durable_invitations.sql` before deploying the updated client-api function. All newly generated invitations (including owner bootstrap links) remain valid until used once or replaced. Only SHA-256 hashes of random 256-bit tickets are stored in a private table. Redemption atomically consumes the ticket and creates a fresh short-lived Supabase Auth credential. Password-recovery links retain their normal expiry. Existing legacy invitation links must be replaced; their old Auth expiry cannot be removed.

Generating a replacement invitation revokes any unused durable invitation for that account. If activation fails after acceptance, generate a replacement. Never publish generated private links.

## Reviews

The live-review worker is not configured. The script leaves the static reviews unchanged until a real worker URL is supplied. The displayed excerpt count is manually maintained; currently the label says 20 while the page contains 18 excerpt cards.

## Puppy viewings

Apply migration 005 for a separate appointment system. Owners create non-overlapping start/end times in Europe/Malta, one family per appointment. Pending requests hold the slot until approved, declined or withdrawn. Confirmed viewings can be cancelled by owners. Viewing slots never affect kennel capacity or blocked dates. Clients see shared slot availability and only their own requests; owners see all requests. Closing an appointment prevents new requests and does not cancel existing appointments.
