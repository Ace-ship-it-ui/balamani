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
