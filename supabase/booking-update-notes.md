# Private booking updates

After the original private booking database setup, apply these SQL scripts in order:

1. `automatic-viewing-slots.sql`
2. `admin-viewing-bookings.sql`
3. `close-cancelled-extra-viewings.sql`
4. `litter-viewing-windows.sql`
5. `client-onboarding.sql`
6. `client-account-controls.sql`

Deploy `functions/client-api/index.ts` after the SQL, then publish the files in `docs`.
Do not reapply an earlier function definition after a later update.

Each active litter opens normal weekday slots from birth + 14 days through birth + 55 days inclusive (six calendar weeks). Overlapping windows share slots. Malta public holidays remain excluded. Slots default to closed, manual overrides take priority, and owners can reset an override to the litter schedule. Pending and confirmed appointments share a unique reservation constraint and transaction lock.

Clients must save first name, surname, puppy name and contact number before requesting bookings. Puppy names remain editable. Contact details are stored in a private schema and returned only to the client or authorized owners.

Owners can limit booking types, disable new requests, set an expiry date, suspend/resume access and archive/restore accounts. Existing bookings remain recorded. Expiry is inclusive of the selected date in Malta. Account controls cannot modify configured owner accounts.

Permanent login removal requires typing the client's email. The server archives access first, then calls Supabase Auth `deleteUser(id, true)`, which irreversibly removes login credentials while keeping the user reference for historical bookings. A removed login cannot be restored. No real login was removed during development; deletion endpoint checks used mocked Auth calls, and database checks ran inside rolled-back transactions.


## Recoverable deletion and remembered sign-in

Delete account now archives membership without deleting the Auth login. Restore account or generate a new Invite / replace invitation to restore archived access, keeping details and booking history. Account limits and expiry stay unchanged; suspended accounts must be resumed explicitly. Earlier permanently removed Auth logins cannot be restored by this flow.

Remember me is optional and unchecked by default. Checked sign-in persists the session in localStorage across browser restarts; unchecked sign-in uses sessionStorage. Refresh-token rotation updates the selected storage, and signing out or a revoked-access response clears both session stores. Passwords are never stored. Invitation setup uses a temporary session.

Verified with mocked endpoint and browser-storage tests, including owner protection, no Auth deletion, archived reinvitation, suspended-account rejection, persisted token rotation and logout clearing. No real client accounts were altered.


## Multiple dogs per client
Apply multiple-client-dogs.sql after client-account-controls.sql, then publish client.js and both private pages. Client details store a primary puppy name plus extra names in the private profile. Profiles support up to 20 distinct dog names; each boarding request selects 1–4 saved dogs. The database calculates dog_count from the submitted name array, keeps historical booking names, rejects unsaved or repeated names and overlapping active bookings for the same member/dog name, and retains the locked four-dog daily capacity check. Existing clients keep their original puppy name automatically. Older profile forms preserve extra names.

A rolled-back database test verifies two different dogs consume two spaces, capacity cannot exceed four, duplicate dog bookings fail, withdrawal releases space, and legacy edits preserve extra dogs. No real families or bookings are changed by the test.
