# ScanWise

ScanWise identifies a **physical video game or game console** from a photo,
asks for extra photos when it can't pin down the exact version, prices it
against real eBay listings, and prepares the data needed to resell it.

> University course project (Programación para Móviles).

**Scope:** physical games (PS1/PS2/PS3/PS4/PS5, Xbox, Nintendo, Sega, PSP,
Game Boy, ...), consoles, and console accessories. Anything else is
rejected on purpose — point it at a phone or a DVD and it tells you it's
out of scope rather than inventing an answer.

## How the app works (user's point of view)

1. **Create an account / log in.** Each user only sees their own scans.
2. **Tap "Abrir camara"** and photograph the game or console (or scan the
   barcode on the box first — it's used as an extra hint).
3. **Gemini identifies it**: title, platform, region, catalog code,
   edition, what's included, and how confident it is.
4. **If it can't finish, it asks for specific extra photos** — the back of
   the case to read the catalog code, the serial sticker under a console,
   a close-up of a cartridge label. These requests are generated per item,
   not from a fixed checklist. Take them and tap **"Reanalizar"**; all the
   photos go back together for another pass (up to 3 rounds).
   - Don't want to give one (e.g. not opening a sealed game to photograph
     the disc)? Tap **"Omitir"** on that request instead — the next pass
     is told you declined it and works around it rather than asking again.
   - If a photo you did take didn't resolve what was asked, the next
     round's request for it shows up as a **red card**, so it's clear it's
     a repeat rather than a random re-ask.
   - You can also stop early with "Guardar asi".
5. **The result screen** shows everything identified, plus a price range.
   Prices try eBay first, fall back to MercadoLibre, and fall back again
   to Gemini's own USD estimate if neither marketplace answers — always
   labeled so an AI guess is never shown as if it were a real listing.
   From there:
   - **Comparar precios** — real active listings for that exact item,
     tappable to open in the browser.
   - **Generar publicacion** — editable title/description/price to copy
     into wherever you're selling.
   - **"Listo, volver al inicio"** takes you straight back to Home.
6. **Everything is saved to your history**, swipe to delete. If something
   with the same title and platform is already there, you're asked to
   confirm before saving a possible duplicate.
7. **Notifications** log each completed identification.

## Current features

| Feature | How real is it |
|---|---|
| Accounts (register / login / logout) | **Real** — Supabase Auth, session persists across restarts |
| Per-user data isolation | **Real** — `user_id` + row level security |
| Photo capture | **Real** — `image_picker`, opens the device camera |
| Barcode scanning | **Real** — `mobile_scanner`, live detection; feeds the code to the model as a hint |
| Product recognition | **Real** — Gemini vision with a strict JSON schema |
| "Ask for more photos" loop | **Real** — the model decides what's missing, lets you skip a request, and flags a repeat in red |
| Out-of-scope rejection | **Real** — non-game photos are refused |
| Price comparison | **Real** — eBay Browse API -> MercadoLibre -> AI estimate, in that order, always labeled |
| Duplicate-save warning | **Real** — same title + platform already in your history asks for confirmation first |
| Saved history (CRUD) | **Real** — Supabase |
| Listing export | Real data, UI-only share/copy buttons |
| Price-change notifications | Not built — needs a scheduled server-side job |

## Setup

Three services need credentials. All of them are free to start, and all
the keys live in **gitignored** config files.

### 1. Supabase (database + accounts)

1. Create a project at [supabase.com](https://supabase.com).
2. **SQL Editor -> New query**, paste [`supabase/schema.sql`](supabase/schema.sql), Run.
   This creates the tables, adds the auth columns, and replaces the old
   open demo policies with per-user row level security.
3. **Authentication -> Providers -> Email**: make sure Email is enabled.
   For a demo, also turn **"Confirm email" OFF** — otherwise a new account
   can't log in until the inbox link is clicked. (The app handles both:
   with confirmation on, it tells you to go check your email.)
4. **Project Settings -> Data API**: copy the Project URL and the
   anon/publishable key.
5. Copy [`lib/src/config/supabase_config.example.dart`](lib/src/config/supabase_config.example.dart)
   to `supabase_config.dart` (same folder) and paste them in.

> Upgrading an existing project from before auth: `schema.sql` is written
> to be re-runnable, so just run the whole thing again. Rows created
> before auth have `user_id = null` and become invisible — there's a
> commented-out cleanup at the bottom of the file to delete them.

### 2. Gemini (recognition)

1. Get a free API key at [aistudio.google.com/apikey](https://aistudio.google.com/apikey).
2. Copy [`lib/src/config/api_config.example.dart`](lib/src/config/api_config.example.dart)
   to `api_config.dart` and paste the key in.

The default model is `gemini-3.5-flash-lite` (fast and cheap). If it
struggles to read small catalog codes, switch `geminiModel` to something
stronger like `gemini-4-hydrogen`.

### 3. Prices: eBay (primary) + MercadoLibre (fallback) + AI estimate (last resort)

Price lookups go through `PriceComparisonService`
([`lib/src/services/price_comparison_service.dart`](lib/src/services/price_comparison_service.dart)),
which tries eBay first and falls back to MercadoLibre on any failure —
not configured, request error, or **eBay's new-account review**. You only
need one of the two configured to get real prices; having both just makes
the app resilient to either one being down or still pending.

If **both** come back empty, the result screen falls back a third time to
Gemini's own rough USD estimate (from `estimated_price_min_usd` /
`estimated_price_max_usd` in its response), adjusted for the item's visible
condition. This is never a real listing — the UI always labels it
"Estimación de la IA" so it can't be confused with actual market data.

#### eBay

1. Create a developer account at [developer.ebay.com](https://developer.ebay.com/my/keys).
2. Take the **Production** keyset: App ID (Client ID) + Cert ID (Client
   Secret). Sandbox technically works but has almost no real inventory,
   so prices there are meaningless.
3. Paste both into `api_config.dart`.

`ebayMarketplaceId` controls which market you price against — `EBAY_US`
by default, which is where retro game pricing is most liquid.

**New accounts go into review.** eBay shows *"Thank you for registering
... Access to your new account is pending approval, which takes at least
one business day"* right after signup — production calls fail until that
clears. This isn't something to work around; just leave the eBay keys in
and let `PriceComparisonService` fall back to MercadoLibre until the
review finishes. No code change needed when it does — eBay calls will
just start succeeding again.

#### MercadoLibre (works today, no review wait)

1. Log in at [developer.mercadolibre.com.ar](https://developer.mercadolibre.com.ar)
   (or your country's equivalent — `.com.mx`, `.com.br`, `.cl`, ...) with
   your normal MercadoLibre account.
2. **Mis aplicaciones → Crear nueva aplicación.** This is normally
   approved instantly — it's gated on your *account's* existing identity
   verification (the one from buying/selling), not a separate developer
   review queue like eBay's.
3. Copy the **Client ID** and **Client Secret** into `api_config.dart`.
4. Set `mercadoLibreSiteId` to your country (`MLA` Argentina, `MLM`
   Mexico, `MLB` Brazil, `MCO` Colombia, `MLC` Chile, ...).

**Coverage trade-off to know about:** MercadoLibre restricted free-text
search across every listing a while back. What's used here instead is
their **Catalog Products** API — it matches your query against
MercadoLibre's canonical catalogued products and prices against the
current best ("buy box") offer. That means solid results for consoles and
mainstream/re-released games, and weaker results for obscure regional or
retro variants that were never catalogued as a single product. This is
exactly why keeping eBay as the primary source matters once its review
clears — eBay's listing search has no such catalog-matching limitation.

### Then

```bash
flutter pub get
flutter run
```

Optional: [`supabase/seed.sql`](supabase/seed.sql) fills your account with
sample scans so the history isn't empty. Register in the app first, then
put your email at the top of that file before running it.

### If the network is unavailable during a demo

Set `useMockRecognition = true` in `api_config.dart`. Recognition then
comes from the bundled sample catalog instead of Gemini, through the exact
same screens. Everything else (auth, saving, history) still needs
Supabase.

## How the "ask for more photos" loop works

This is the part that makes the identification interactive rather than
one-shot:

1. Gemini is asked for a strict JSON object (schema in
   [`gemini_service.dart`](lib/src/services/gemini_service.dart)). Besides
   the identification, it returns `confidence`,
   `identification_complete`, `missing_info[]`, and `requested_photos[]`.
2. `requested_photos` is the key field: the model writes its own concrete
   requests, tailored to what it's looking at — "contratapa de la caja,
   para leer el codigo de catalogo" for a boxed game, "etiqueta del
   numero de serie en la base" for a console.
3. If the result is conclusive (complete + confidence >= 0.80), the app
   skips straight to pricing and saving — no pointless extra steps.
4. Otherwise the guidance screen lists those requests. Each photo taken
   is appended to the session - or the user taps **"Omitir"** instead,
   which records it in `skippedRequests` rather than a photo path.
5. **"Reanalizar"** sends *all* photos (original + new) in a single
   multi-image request, along with a note about what the previous pass
   concluded, what it was missing, and which requests were explicitly
   skipped (so the model stops asking for those), so it refines rather
   than starts over.
6. If a request's `id` matches one from the previous round, the guidance
   screen knows the earlier photo for it didn't resolve the issue and
   shows that card in red instead of the normal styling.
7. Capped at 3 rounds. On the last one the prompt tells the model it must
   conclude. The user can bail out early with "Guardar asi".

## Security note on API keys

The Gemini and eBay keys are compiled into the app, so anyone with the APK
can extract them. That's an accepted trade-off for a university demo, not
something to ship. The production fix is to move both calls behind a
backend (a Supabase Edge Function would fit here) so the secrets stay
server-side. The Supabase anon key is different — it's *designed* to be
public, and is protected by row level security.

## What the eBay prices actually mean

The Browse API returns **active listings** — what sellers are currently
asking, not what items sold for. Completed-sale data comes from eBay's
Marketplace Insights API, which requires separate approval. The UI says
"publicaciones activas" for exactly that reason. The suggested price is
the **median** rather than the average, so one overpriced sealed copy
doesn't drag the whole estimate up.

## Tech stack

- [Flutter](https://flutter.dev/) (Material 3), Dart SDK `^3.13.3`.
- [`supabase_flutter`](https://pub.dev/packages/supabase_flutter) — auth + Postgres CRUD.
- [`http`](https://pub.dev/packages/http) — Gemini, eBay and MercadoLibre REST calls.
- [`image_picker`](https://pub.dev/packages/image_picker) — camera/gallery.
- [`mobile_scanner`](https://pub.dev/packages/mobile_scanner) — live barcode scanning.
- [`permission_handler`](https://pub.dev/packages/permission_handler) — proactive camera permission (pinned to `^11.3.1`; newer majors need Android SDK 37).
- [`path_provider`](https://pub.dev/packages/path_provider) — permanent local storage for captured photos.
- [`url_launcher`](https://pub.dev/packages/url_launcher) — opening eBay/MercadoLibre listings.

## Project structure

```
lib/
  main.dart                       # initializes Supabase, then runs the app
  src/
    app.dart                      # MaterialApp, theme, routes, RouteObserver
    routes/routes.dart            # name -> screen map (named routes)
    pages/
      auth_gate.dart              # root: login screen or Home, by session
      login_page.dart             # sign in
      register_page.dart          # sign up
      camera_page.dart            # real photo capture
      barcode_page.dart           # live barcode scanning
      identifying_page.dart       # Gemini pass -> reject / guide / price+save
      guidance_page.dart          # collects the model's requested photos
      result_page.dart            # identified item + actions
      price_page.dart             # live price comparison (eBay or MercadoLibre)
      ...
    services/
      auth_service.dart           # Supabase Auth wrapper
      gemini_service.dart         # recognition + the JSON schema/prompt
      price_comparison_service.dart # picks eBay, falls back to MercadoLibre
      ebay_service.dart           # OAuth token cache + Browse search
      mercadolibre_service.dart   # OAuth token cache + Catalog search
      product_service.dart        # products CRUD (user-scoped)
      notification_service.dart   # notifications CRUD (user-scoped)
    models/
      recognition_result.dart     # typed Gemini response + PhotoRequest
      scan_session.dart           # photos + round, drives the re-ask loop
      market_listing.dart         # listing + price report (min/median/max), provider-agnostic
      product.dart                # the saved item
    provider/
      fake_catalog.dart           # offline sample items
      mock_recognition.dart       # offline stand-in for Gemini
    widgets/
      missing_product_scaffold.dart # fallback UI for a screen opened without its route arguments
    config/
      api_config.example.dart     # committed template (Gemini + eBay)
      api_config.dart             # your keys (gitignored)
      supabase_config.example.dart
      supabase_config.dart        # your keys (gitignored)
assets/covers/                    # cover art used by the offline samples
supabase/
  schema.sql                      # tables, auth columns, RLS policies
  seed.sql                        # optional sample data for your account
```

Navigation uses Flutter's built-in named routes
(`Navigator.pushNamed(context, 'route_name')`), the same pattern used in the
course's practico-1 project — no external routing package.

### A note on the bundled cover images

`assets/covers/*.jpg` are Konami's official key art, used only by the
offline sample catalog so a no-network demo still looks like something.
They're **not original work** — don't reuse this repo's `assets/` folder
anywhere public or commercial without sorting out rights first.

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

- [ ] Move the Gemini and eBay calls behind a server (Supabase Edge
      Function) so the API keys stop shipping inside the APK.
- [ ] Upload captured photos to Supabase Storage, so a scan's picture
      follows the account instead of living on one device.
- [ ] Use eBay's GTIN search so a scanned barcode can identify an item on
      its own, without needing a photo too.
- [ ] Completed-sale prices (needs eBay Marketplace Insights approval) —
      more useful for pricing than active listings.
- [ ] Native share sheet for exported listings (`share_plus`).
- [ ] Scheduled price-check job, so price-change notifications can be real.
