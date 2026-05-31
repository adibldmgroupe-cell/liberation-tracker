-- ═══════════════════════════════════════════════════════════
-- MIGRATION 019 — RLS notifications : policies INSERT + UPDATE
-- Bug : la table notifications a RLS activé SANS policy INSERT ni UPDATE.
-- Conséquence (règle N°13) :
--   • createNotification() échouait silencieusement → aucune notification
--     créée lors des actions documentaires (vérif AQ, transmission DT, AR…) ;
--   • markAsRead() / markAllAsRead() (UPDATE is_read) étaient bloqués.
-- (SELECT fonctionne déjà ; DELETE a été ajouté par la migration 018.)
-- À exécuter UNE FOIS dans Supabase SQL Editor (un seul bloc).
-- ═══════════════════════════════════════════════════════════

-- INSERT : création de notifications (createNotification)
DROP POLICY IF EXISTS "insert_auth" ON notifications;
CREATE POLICY "insert_auth" ON notifications
  FOR INSERT TO authenticated WITH CHECK (true);

-- UPDATE : marquer comme lu (markAsRead / markAllAsRead)
DROP POLICY IF EXISTS "update_auth" ON notifications;
CREATE POLICY "update_auth" ON notifications
  FOR UPDATE TO authenticated USING (true) WITH CHECK (true);

-- Vérification rapide (optionnel) :
-- SELECT policyname, cmd FROM pg_policies WHERE tablename = 'notifications';
-- Doit lister : SELECT, INSERT (insert_auth), UPDATE (update_auth), DELETE (delete_auth).
