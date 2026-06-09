-- 038 : étendre l'enum `service_type` avec les 11 services ajoutés à la table `services`
--
-- Contexte : ces services ont été ajoutés à la table `services` (donc visibles comme colonnes
-- dans l'écran Permissions), MAIS la colonne `permissions.service` (et `profiles.service`) est
-- de type enum `service_type`, qui n'a PAS été étendu → impossible de leur affecter des
-- permissions OU des utilisateurs (erreur 22P02 "invalid input value for enum service_type").
--
-- ⚠️ RÈGLE N°12 : exécuter cette migration SEULE (un ALTER TYPE ADD VALUE ne peut pas être
-- utilisé — INSERT/UPDATE — dans la même transaction que son ajout). Ne rien mettre d'autre ici.
-- Les grants de permissions à ces services se feront APRÈS (2e exécution / via l'écran Permissions).

ALTER TYPE service_type ADD VALUE IF NOT EXISTS 'aq_systeme';
ALTER TYPE service_type ADD VALUE IF NOT EXISTS 'aq_validation';
ALTER TYPE service_type ADD VALUE IF NOT EXISTS 'aq_process';
ALTER TYPE service_type ADD VALUE IF NOT EXISTS 'controle_gestion';
ALTER TYPE service_type ADD VALUE IF NOT EXISTS 'administration_finance';
ALTER TYPE service_type ADD VALUE IF NOT EXISTS 'business_developpement';
ALTER TYPE service_type ADD VALUE IF NOT EXISTS 'commercial';
ALTER TYPE service_type ADD VALUE IF NOT EXISTS 'promotion_medicale_marketing';
ALTER TYPE service_type ADD VALUE IF NOT EXISTS 'achat';
ALTER TYPE service_type ADD VALUE IF NOT EXISTS 'direction_generale';
ALTER TYPE service_type ADD VALUE IF NOT EXISTS 'direction_site';

-- Vérification (lecture seule) :
-- SELECT enumlabel FROM pg_enum WHERE enumtypid = 'service_type'::regtype ORDER BY enumsortorder;
