-- Sample data for demoing without having to scan anything first.
-- Run this in Supabase: Dashboard -> SQL Editor -> New query -> Run.
-- Needs schema.sql to have been run already.
--
-- IMPORTANT: rows now belong to a user. Register the account inside the
-- app first, then put that email below - the seed attaches everything to
-- it. Without this the rows exist but no one can see them (RLS).
--
-- Safe to re-run: it clears its own seeded rows before inserting them.

do $$
declare
  target_user uuid;
begin
  -- >>> CHANGE THIS to the email you registered with in the app <<<
  select id into target_user from auth.users where email = 'tu-email@ejemplo.com';

  if target_user is null then
    raise exception
      'No existe un usuario con ese email. Registrate en la app primero y '
      'despues corregi el email en este script.';
  end if;

  delete from notifications
    where user_id = target_user and title = 'Identificacion completada';
  delete from products
    where user_id = target_user and ebay_query like 'SEED:%';

  insert into products
    (user_id, name, brand, category, model, confidence, price_min, price_max,
     scanned_at, icon, description, item_type, platform, region, edition,
     completeness, ebay_query)
  values
    (target_user, 'Silent Hill 2', 'Konami', 'Juegos', 'SLUS-20228',
     0.95, 45, 90, now() - interval '2 hours', 'videogame',
     'Juego de PlayStation 2, edicion NTSC-U. Terror psicologico, uno de los '
     'mas buscados de la saga.',
     'game', 'PlayStation 2', 'NTSC-U', '', 'complete_in_box',
     'SEED: Silent Hill 2 PlayStation 2 SLUS-20228'),

    (target_user, 'Silent Hill 3', 'Konami', 'Juegos', 'SLUS-20550',
     0.93, 60, 130, now() - interval '1 day', 'videogame',
     'Juego de PlayStation 2, secuela directa de Silent Hill 2. Muy buscado '
     'por coleccionistas.',
     'game', 'PlayStation 2', 'NTSC-U', '', 'box_and_game_no_manual',
     'SEED: Silent Hill 3 PlayStation 2 SLUS-20550'),

    (target_user, 'PlayStation 2 Fat', 'Sony', 'Consolas', 'SCPH-39001',
     0.92, 80, 160, now() - interval '2 days', 'videogame',
     'Consola PlayStation 2 modelo Fat, con lector de discos original.',
     'console', 'PlayStation 2', 'NTSC-U', '', 'console_with_accessories',
     'SEED: PlayStation 2 console SCPH-39001'),

    (target_user, 'Nintendo GameCube', 'Nintendo', 'Consolas', 'DOL-001',
     0.90, 70, 150, now() - interval '3 days', 'videogame',
     'Consola Nintendo GameCube, incluye lector de mini-DVD.',
     'console', 'GameCube', 'NTSC-U', '', 'console_only',
     'SEED: Nintendo GameCube console DOL-001'),

    (target_user, 'The Legend of Zelda: Ocarina of Time', 'Nintendo',
     'Juegos', 'NUS-CZLE-USA',
     0.88, 35, 120, now() - interval '5 days', 'videogame',
     'Cartucho de Nintendo 64. Etiqueta en buen estado, sin caja.',
     'game', 'Nintendo 64', 'NTSC-U', '', 'game_only',
     'SEED: Zelda Ocarina of Time Nintendo 64'),

    -- Low confidence on purpose: shows the "Sin confirmar" badge.
    (target_user, 'Juego de PlayStation 1', 'Sony', 'Juegos', '',
     0.52, 0, 0, now() - interval '7 days', 'videogame',
     'No se pudo determinar el titulo exacto con las fotos disponibles.',
     'game', 'PlayStation', '', '', 'unknown',
     'SEED: PlayStation 1 game');

  insert into notifications (user_id, product_id, title, body, icon, unread)
  select
    target_user,
    p.id,
    'Identificacion completada',
    p.name || ' fue identificado con ' ||
      round(p.confidence * 100) || '% de certeza.',
    'videogame',
    p.scanned_at > now() - interval '1 day'
  from products p
  where p.user_id = target_user and p.ebay_query like 'SEED:%';
end $$;
