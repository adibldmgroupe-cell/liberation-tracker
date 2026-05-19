# LDM Groupe — Suivi Libération PF v3

## Déploiement
1. Supprimer tout le contenu du repo GitHub
2. Uploader le contenu de ce dossier
3. Créer `.github/workflows/deploy.yml` manuellement si absent
4. Settings → Pages → Source : GitHub Actions
5. Secrets : VITE_SUPABASE_URL + VITE_SUPABASE_ANON_KEY
6. Exécuter `002_v2_updates.sql` dans Supabase SQL Editor
7. Importer SAP puis Historique
