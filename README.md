# ScanWise

ScanWise identifies a second-hand product from a photo, helps confirm the
exact model when the first photo isn't enough, compares it against similar
listings, and prepares the data needed to publish it for sale.

> University course project (Programación para Móviles).

## How the app works (user's point of view)

1. **Open the app and tap "Abrir camara".** Point it at the product and take
   a photo (or scan its barcode if you still have the original box).
2. **Wait a few seconds while it identifies the product.** If the app is
   confident enough, it goes straight to the result.
3. **If it's not sure yet, it asks for more photos** — the logo, the back
   panel, the serial number — one by one, until it can confirm the exact
   model. Once you've taken them, tap "Confirmar modelo".
4. **The result screen shows what was identified**: brand, category, exact
   model, confidence, and a suggested price range. From here you can:
   - **Comparar precios** — see similar listings from other platforms that
     justify that price range.
   - **Generar publicacion** — get a ready-made title, description and
     price you can edit and copy to sell it elsewhere.
   - **Documentar el estado** — take a "before/after" pair of photos to show
     wear and tear before selling.
5. **Everything you scan is saved automatically** to your history. Open
   "Historial" from the home screen to see every product you've identified,
   resume one that's still missing its exact model, or swipe to delete it.
6. **Notifications** let you know when an identification finished — tap one
   to mark it as read.

## Current features

| Feature from the spec | Screen(s) | How real is it today |
|---|---|---|
| Initial photo recognition | Camera | **Real camera** (`image_picker`) takes an actual photo; the *recognition* of what's in it is a random pick from 5 sample products, not real AI |
| Interactive identification guidance | Guidance | Real flow, fixed sample prompts (not AI-generated) |
| Market price comparison | Price | UI only — sample listings, matched to whichever sample product was picked |
| Listing data export | Listing | Real data, built from the saved product (not AI-generated) |
| Barcode scanning | Barcode | **Real scanner** (`mobile_scanner`) reads actual barcodes live; what it's *matched* to afterward is the same random sample pick |
| Identified items history | History | **Real** — reads/deletes rows in Supabase |
| Condition comparison mode | Condition | UI only — no real camera yet |
| Notifications | Notifications | **Real** — reads/updates rows in Supabase, created automatically when a product is saved |

> The camera and the barcode scanner are both real now: they use the
> phone's actual camera (with the permission requested as soon as the
> screen opens, not on the shutter tap) and actually detect barcodes.
> What's still mocked is the *recognition* step — no AI/vision model
> looks at the photo yet. Instead, each scan randomly lands on one of 5
> sample products (`lib/src/provider/fake_catalog.dart`): Silent Hill 2,
> Silent Hill 3, a PS2 Fat, a GameCube, and an original Xbox — each with
> its own price range and similar listings, so repeat demos look varied
> even though nothing is actually being recognized.
>
> Two of the five (the Silent Hill games) show real official cover art
> (`assets/covers/`, sourced from a local RAWG dataset — see the note
> below on image rights). The other three (the consoles — no equivalent
> art available) show **your own captured photo** instead once a match
> is picked, labeled with that item's sample data. Either way, how many
> extra guidance photos get asked for also varies per item (0 to 2) —
> a clear cover shot needs no follow-up, a console needs its back panel
> and serial to pin down the exact revision.

## The real part: Supabase CRUD

Two tables back the features above:

- **`products`** — every identified product. A row is **created** the
  moment identification finishes (either right away, or once the model is
  confirmed through the guidance flow). History **reads** this table, the
  Listing screen's "Guardar cambios" **updates** it, and swiping an item in
  History **deletes** it.
- **`notifications`** — one row per "identification complete" event,
  created automatically alongside the product. The Notifications screen
  **reads** them and **updates** their read state.

No other table is needed right now: guidance prompts are fixed UI text, the
"similar listings" for price comparison would need real marketplace data to
be worth storing, and condition-comparison photos aren't real yet (no camera
plugin) — so there's nothing genuine to persist for those two until those
pieces exist.

**The product's picture now survives too.** A real captured photo gets
copied from image_picker's temp location into the app's own permanent
folder before saving, and either that path or the curated cover's asset
path gets stored in `products.image_ref`. That's why it used to vanish
once the product showed up again in History — the picture was never
written anywhere — and why it doesn't now. This is still local-only
storage on the one device, not a shared Supabase Storage bucket, so a
photo won't follow the product to a different phone.

### Setting up your own Supabase project

1. Create a free project at [supabase.com](https://supabase.com).
2. Open **SQL Editor** in the dashboard, paste the contents of
   [`supabase/schema.sql`](supabase/schema.sql) and run it. This creates the
   `products` and `notifications` tables with demo-friendly open policies
   (see the comments in that file — not meant for production).
3. Go to **Project Settings -> Data API** and copy the **Project URL** and
   the **anon public / publishable key**.
4. Copy [`lib/src/config/supabase_config.example.dart`](lib/src/config/supabase_config.example.dart)
   as `lib/src/config/supabase_config.dart` (same folder) and paste your two
   values in. This file is gitignored — everyone running the project sets
   their own.
5. `flutter pub get` and `flutter run`.

**Already ran this before and your table exists?** `schema.sql` now also
adds an `image_ref` column (used to persist the product's picture — see
below). Re-run the file, or just this one line, in the SQL Editor:

```sql
alter table products add column if not exists image_ref text;
```

## Tech stack

- [Flutter](https://flutter.dev/) (Material 3), Dart SDK `^3.13.3`.
- [`supabase_flutter`](https://pub.dev/packages/supabase_flutter) for the
  CRUD backend (Postgres under the hood).
- [`image_picker`](https://pub.dev/packages/image_picker) for the real
  camera photo (and gallery picking).
- [`mobile_scanner`](https://pub.dev/packages/mobile_scanner) for the real,
  live barcode/QR scanning.
- [`permission_handler`](https://pub.dev/packages/permission_handler) to ask
  for the camera permission proactively (pinned to `^11.3.1` — newer majors
  need Android SDK 37, which this machine's toolchain doesn't resolve yet).

### A note on the Silent Hill cover images

`assets/covers/silent_hill_2.jpg` and `assets/covers/silent_hill_3.jpg` are
official key art for those games (sourced via a local RAWG dataset). They
are **not original work** — they're Konami's copyrighted artwork, used
here only to make a one-day, non-commercial university demo look
realistic on the student's own device. Don't reuse this repo's `assets/`
folder in anything public, redistributed, or commercial without sorting
out rights first.

## Project structure

```
lib/
  main.dart                      # initializes Supabase, then runs the app
  src/
    app.dart                     # MaterialApp, theme, routes
    routes/routes.dart           # name -> screen map (named routes)
    pages/                       # one file per screen
    services/                    # Supabase CRUD (product_service, notification_service)
    provider/                    # sample/mock data for the parts without a real backend yet
    models/                      # plain Dart data classes
    utils/                       # formatting/icon helpers
    config/
      supabase_config.example.dart  # committed template
      supabase_config.dart          # your own credentials (gitignored)
assets/
  covers/                        # real cover art for the 2 Silent Hill samples
supabase/
  schema.sql                     # run this in the Supabase SQL editor
```

`provider/fake_catalog.dart` holds the 5 sample products (price, listings,
cover image if any, how many guidance steps it needs); `provider/product_provider.dart`
is the thin wrapper the pages actually call.

Navigation uses Flutter's built-in named routes
(`Navigator.pushNamed(context, 'route_name')`), the same pattern used in the
course's practico-1 project — no external routing package.

## Getting started

```bash
flutter pub get
flutter run
```

To check the code without running the app:

```bash
flutter analyze
```

## Roadmap

- [ ] Actual product recognition (replaces the mock provider behind the
      same interface, so the UI doesn't need to change) — the camera and
      barcode scanner already capture real input, this is the missing
      "look at it and tell me what it is" step.
- [ ] Upload the captured photo to Supabase Storage so it persists with
      the product (right now `photoPath` is a local file path only, lost
      once the app restarts).
- [ ] Native share sheet for exported listings (`share_plus`).
- [ ] Real "similar listings" data and a scheduled job to detect price
      changes (needed before price-change notifications can be real).
- [ ] Real camera for the condition-comparison photos.
