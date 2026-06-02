-- ═══════════════════════════════════════════════════════════════════════════
-- Migration 024 — Intégrité référentielle : FK réellement manquantes
-- ───────────────────────────────────────────────────────────────────────────
-- CORRECTION DE L'AUDIT : contrairement à l'estimation initiale, le module Production
-- possède DÉJÀ ses FK (vérifié sur l'export du schéma, 02/06/2026) :
--   production_sessions (lot_id, equipement_id, shift_id, equipe_id),
--   production_arrets (session_id, arret_type_id), production_comptages (session_id),
--   session_cadences (session_id), suivi_fabrication (lot_id, atelier_id, processus_id),
--   suivi_conditionnement (lot_id, equipement_id), atelier_arrets (atelier_id, lot_id),
--   shift_planning (shift_id, equipe_id, equipement_id), planification_conditionnement,
--   objectifs_production, ateliers (processus_id), arret_sous_familles (famille_id),
--   arret_types (sous_famille_id), plan_rooms (atelier_id, equipement_id).
--
-- SEULE `arret_conditionnement` n'a AUCUNE FK. On ajoute les 2 sûres, en NOT VALID
-- (= ne bloque pas sur d'éventuels orphelins déjà présents ; valide seulement les
-- futurs inserts). Les liaisons par texte (product_flux/cadences/equipment_cadences)
-- restent SANS FK : c'est un choix de design (import GS en masse + flexibilité,
-- room_code null = flexible) — voir notes en fin de fichier.
-- ═══════════════════════════════════════════════════════════════════════════

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables
             WHERE table_schema='public' AND table_name='arret_conditionnement') THEN

    -- suivi_id (uuid) → suivi_conditionnement(id) (uuid)  ✔ types compatibles
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='arret_conditionnement_suivi_id_fkey') THEN
      ALTER TABLE public.arret_conditionnement
        ADD CONSTRAINT arret_conditionnement_suivi_id_fkey
        FOREIGN KEY (suivi_id) REFERENCES public.suivi_conditionnement(id) NOT VALID;
    END IF;

    -- lot_id (bigint) → lots(id) (bigint)  ✔ types compatibles
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='arret_conditionnement_lot_id_fkey') THEN
      ALTER TABLE public.arret_conditionnement
        ADD CONSTRAINT arret_conditionnement_lot_id_fkey
        FOREIGN KEY (lot_id) REFERENCES public.lots(id) NOT VALID;
    END IF;

  END IF;
END $$;

-- ── Vérification ──
SELECT conname, conrelid::regclass AS "table", confrelid::regclass AS "references"
FROM pg_constraint
WHERE conname LIKE 'arret_conditionnement%' AND contype = 'f'
ORDER BY conname;

-- ═══════════════════════════════════════════════════════════════════════════
-- NOTES — décisions documentées (PAS de FK ajoutée, volontairement) :
--
-- 1. arret_conditionnement.equipement_id est de type `uuid`, mais
--    equipements_conditionnement.id est `bigint` → FK IMPOSSIBLE sans changer le type.
--    Pour la rétablir : vérifier que la table est réellement utilisée, puis
--    `ALTER TABLE arret_conditionnement ALTER COLUMN equipement_id TYPE bigint USING ...`
--    (après conversion/contrôle des données). Opération risquée → à faire manuellement.
--
-- 2. product_flux (product_code, op_number, room_code), cadences (numero_salle,
--    code_article), equipment_cadences (room_code, product_code) : liaisons par TEXTE
--    SANS FK, VOLONTAIRES. Une FK product_code→products.code_article bloquerait l'import
--    GS de codes pas encore présents (contraire au design « import en masse »). Intégrité
--    gérée applicativement (parseGsCsv, opByRoom, getLotsMap).
--
-- 3. Redondances de schéma signalées par l'audit (à arbitrer plus tard, pas bloquant) :
--    • operations_master ⇄ plan_rooms : colonnes TRS dupliquées (op_number, trs_cible_pct,
--      to_shift_min, pause_min, vdlp/vdlc/chgt_format/reglage/micro_arrets/maint_min,
--      op_code, equipment_name). operations_master = source de vérité (règle N°17) ;
--      plan_rooms n'est qu'un miroir d'affichage du plan → ne JAMAIS écrire les réfs TRS
--      dans plan_rooms (lecture seule, sync depuis operations_master).
--    • equipment_cadences (room_code/product_code/cadence_theorique) ressemble à un ANCÊTRE
--      de cadences (numero_salle/code_article/cadence_objectif_b_min) → cadences fait foi.
--    • "Cadence objectif" stockée à 4 endroits : equipements_conditionnement.cadence_objectif_boite_min,
--      objectifs_production.cadence_objectif_boite_min, cadences.cadence_objectif_b_min,
--      session_cadences.cadence_bpm. La source live du TRS = `cadences` (par salle×article×taille),
--      figée à l'ouverture dans production_sessions.cadence_objectif_snapshot.
--    • 3 sous-systèmes de suivi parallèles : suivi_fabrication (fab), production_sessions (TRS
--      cond.), suivi_conditionnement (cond.) → ne pas les croiser ; production_sessions fait
--      foi pour le TRS/OEE.
-- ═══════════════════════════════════════════════════════════════════════════
