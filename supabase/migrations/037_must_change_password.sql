-- 037 : changement de mot de passe OBLIGATOIRE à la première connexion
--
-- Ajoute un marqueur sur profiles. DEFAULT true → TOUS les comptes EXISTANTS
-- (admins inclus, par choix de l'utilisateur) ET tous les comptes FUTURS sont
-- automatiquement marqués « doit changer son mot de passe ».
-- Le marqueur repasse à false dès que l'utilisateur a défini son nouveau mot de passe.
--
-- La policy "write_auth" existante (profiles FOR UPDATE USING id = auth.uid(),
-- migration 001) permet déjà à chaque utilisateur de baisser SON propre marqueur.
--
-- NB : tant que cette migration n'est pas exécutée, le garde-fou applicatif lit la
-- colonne via select('*') → valeur undefined → comportement inchangé (rien n'est forcé).
-- La fonctionnalité s'active donc au moment où cette migration est lancée.

ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS must_change_password boolean NOT NULL DEFAULT true;

-- Vérification (lecture seule) :
-- SELECT count(*) FILTER (WHERE must_change_password) AS a_changer, count(*) AS total FROM public.profiles;
