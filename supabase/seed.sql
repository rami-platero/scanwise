-- Sample data for demoing without having to scan through the app first.
-- Run this in Supabase: Dashboard -> SQL Editor -> New query -> Run.
-- Needs schema.sql to have been run already.
--
-- Safe to re-run: it deletes these specific seeded rows (by their fixed
-- ids below) before inserting them again, so it won't pile up duplicates.

delete from notifications where product_id in (
  'a0000000-0000-0000-0000-000000000001',
  'a0000000-0000-0000-0000-000000000002',
  'a0000000-0000-0000-0000-000000000003',
  'a0000000-0000-0000-0000-000000000004',
  'a0000000-0000-0000-0000-000000000005',
  'a0000000-0000-0000-0000-000000000006',
  'a0000000-0000-0000-0000-000000000007'
);

delete from products where id in (
  'a0000000-0000-0000-0000-000000000001',
  'a0000000-0000-0000-0000-000000000002',
  'a0000000-0000-0000-0000-000000000003',
  'a0000000-0000-0000-0000-000000000004',
  'a0000000-0000-0000-0000-000000000005',
  'a0000000-0000-0000-0000-000000000006',
  'a0000000-0000-0000-0000-000000000007'
);

-- Confirmed products (same samples as lib/src/provider/fake_catalog.dart).
insert into products
  (id, name, brand, category, model, confidence, price_min, price_max, scanned_at, icon, description, image_ref)
values
  (
    'a0000000-0000-0000-0000-000000000001',
    'Silent Hill 2', 'Konami', 'Videojuegos', 'SLUS-20228',
    0.95, 45, 90, now() - interval '2 hours', 'videogame',
    'Juego de PlayStation 2, edicion NTSC-U (SLUS-20228). Terror psicologico, uno de los mas buscados de la saga.',
    'asset:assets/covers/silent_hill_2.jpg'
  ),
  (
    'a0000000-0000-0000-0000-000000000002',
    'Silent Hill 3', 'Konami', 'Videojuegos', 'SLUS-20550',
    0.93, 60, 130, now() - interval '1 day', 'videogame',
    'Juego de PlayStation 2 (SLUS-20550), secuela directa de Silent Hill 2. Muy buscado por coleccionistas.',
    'asset:assets/covers/silent_hill_3.jpg'
  ),
  (
    'a0000000-0000-0000-0000-000000000003',
    'PlayStation 2 Fat', 'Sony', 'Consolas', 'SCPH-30000',
    0.92, 80, 160, now() - interval '2 days', 'videogame',
    'Consola PlayStation 2 modelo Fat (SCPH-30000), con lector de discos original.',
    null
  ),
  (
    'a0000000-0000-0000-0000-000000000004',
    'Nintendo GameCube', 'Nintendo', 'Consolas', 'DOL-001',
    0.90, 70, 150, now() - interval '3 days', 'videogame',
    'Consola Nintendo GameCube (DOL-001), incluye lector de mini-DVD.',
    null
  ),
  (
    'a0000000-0000-0000-0000-000000000005',
    'Xbox Original', 'Microsoft', 'Consolas', 'Model 1',
    0.89, 50, 110, now() - interval '5 days', 'videogame',
    'Consola Xbox original de Microsoft, primera generacion.',
    null
  ),
  -- Left unconfirmed on purpose, to show the "Sin confirmar" state in
  -- History (tapping it resumes the guidance flow).
  (
    'a0000000-0000-0000-0000-000000000006',
    'Consola de videojuegos', 'Sony', 'Consolas', '',
    0.70, 80, 160, now() - interval '6 days', 'videogame',
    'Version exacta no determinada todavia.',
    null
  ),
  (
    'a0000000-0000-0000-0000-000000000007',
    'Juego de PlayStation 2', 'Konami', 'Videojuegos', '',
    0.58, 45, 90, now() - interval '7 days', 'videogame',
    'Version exacta no determinada todavia.',
    null
  );

-- One "identification complete" notification per confirmed product.
-- Items 6 and 7 (unconfirmed) don't get one, same as the real app.
insert into notifications
  (id, product_id, title, body, icon, unread, created_at)
values
  (
    'b0000000-0000-0000-0000-000000000001',
    'a0000000-0000-0000-0000-000000000001',
    'Identificacion completada',
    'Silent Hill 2 fue identificado con 95% de certeza.',
    'videogame', true, now() - interval '2 hours'
  ),
  (
    'b0000000-0000-0000-0000-000000000002',
    'a0000000-0000-0000-0000-000000000002',
    'Identificacion completada',
    'Silent Hill 3 fue identificado con 93% de certeza.',
    'videogame', true, now() - interval '1 day'
  ),
  (
    'b0000000-0000-0000-0000-000000000003',
    'a0000000-0000-0000-0000-000000000003',
    'Identificacion completada',
    'PlayStation 2 Fat fue identificado con 92% de certeza.',
    'videogame', false, now() - interval '2 days'
  ),
  (
    'b0000000-0000-0000-0000-000000000004',
    'a0000000-0000-0000-0000-000000000004',
    'Identificacion completada',
    'Nintendo GameCube fue identificado con 90% de certeza.',
    'videogame', false, now() - interval '3 days'
  ),
  (
    'b0000000-0000-0000-0000-000000000005',
    'a0000000-0000-0000-0000-000000000005',
    'Identificacion completada',
    'Xbox Original fue identificado con 89% de certeza.',
    'videogame', false, now() - interval '5 days'
  );
