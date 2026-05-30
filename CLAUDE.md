# CLAUDE.md — Règles projet Liberation Tracker

## Stack
- Vue 3 `setup()` — **toujours `var`**, jamais `const`/`let`
- Supabase (PostgREST) — ne throw jamais, toujours vérifier `res.error`
- GitHub Actions → GitHub Pages : **chaque `git push` déploie automatiquement**, sans demander

---

## RÈGLE CRITIQUE N°1 — Schéma table `lots`

La table `lots` **N'A PAS** de colonnes `prod_desc` ni `prod_code`.

```
lots : id, numero_lot, product_id, num_document_sap, quantite,
       statut_sap, statut_operationnel, date_enregistrement,
       date_declaration, date_liberation, ddf, ddp, is_lot_validation
```

Pour obtenir la description produit → **toujours 3 étapes** :
```js
// 1. Requête lots → product_id
var res = await supabase.from('lots').select('id,numero_lot,product_id').in('id', ids)
// 2. Requête products → description/code_article
var pRes = await supabase.from('products').select('id,code_article,description').in('id', prodIds)
// 3. Enrichir le map JS
l.prod_desc = p.description || p.code_article
l.prod_code = p.code_article
```

**Jamais** `.select('prod_desc')` ou `.select('prod_code')` sur `lots` → erreur silencieuse.

---

## RÈGLE CRITIQUE N°2 — Jamais de jointure PostgREST `!inner`

La syntaxe `lots!inner(id,numero_lot,...)` **échoue silencieusement** → retourne un tableau vide sans erreur.

```js
// ❌ INTERDIT
supabase.from('liberation_documents').select('id, lots!inner(numero_lot)')

// ✅ TOUJOURS : requête source → getLotsMap séparé
var res = await supabase.from('liberation_documents').select('id,lot_id,...')
var lotsMap = await getLotsMap(res.data.map(d => d.lot_id))
```

Le helper `getLotsMap` est défini dans TasksPage et doit être réutilisé partout.

---

## RÈGLE CRITIQUE N°3 — Cohérence badge ↔ page

Quand un badge affiche N tâches, la page correspondante **doit appliquer exactement les mêmes filtres**.

Erreur commise : AppLayout comptait sans filtre `type_document`, TasksPage filtrait par types spécifiques → badge=300, page=0.

**Toujours vérifier** : chaque filtre du badge existe dans la page et vice-versa.

---

## RÈGLE CRITIQUE N°4 — Documents : filtre `pending_ar_service IS NULL`

Un document avec `pending_ar_service` non null **appartient à la catégorie AR uniquement**, pas à "Documents à traiter".

```js
// ✅ Requêtes docs category — toujours ajouter :
.is('pending_ar_service', null)
```

Sans ce filtre, le même document apparaît en double (dans AR ET dans Docs).

Dans LotsPage le même principe s'applique :
```js
if (d.pending_ar_service) {
  // montrer AR uniquement
  return // bloquer les autres actions
}
```

---

## RÈGLE N°5 — Flux documentaire complet

Chaque service a **toutes** ses actions, pas seulement "valider" :

| Service | Statut doc | Actions disponibles |
|---------|-----------|-------------------|
| AQ | `emis` / `verification_aq` | ✓ Valider AQ→DT **ET** ↩ Retourner à l'émetteur (motif) |
| DT | `approuve_aq` | ✓ Approuver DT **ET** ↩ Retourner à AQ (motif) |
| Émetteur | `retour_emetteur` | ↑ Rectifier / Réémettre |

Les retours nécessitent un **motif** → pattern `needsMotif` avec textarea inline.

Ne jamais implémenter seulement le chemin "happy path" — le retour fait partie du flux normal.

---

## RÈGLE N°6 — Audit trail : tables à mettre à jour

Pour chaque action documentaire, **3 tables** minimum :

```js
// 1. liberation_documents (statut + pending_ar_service)
await supabase.from('liberation_documents').update({statut:'approuve_aq', pending_ar_service:'dt', updated_at:n}).eq('id', docId)

// 2. document_movements (audit trail)
await supabase.from('document_movements').insert({
  document_id, action:'approbation', from_service:'aq', to_service:'dt', performed_by:uid, performed_at:n
})

// 3. Notification au service destinataire
await createNotification('dt', lotId, docId, 'Lot X — IF vérifié AQ → DT', 'document_transmis')
```

Pour AR (accusé réception) → `lot_events` (pas `document_movements`) :
```js
await supabase.from('lot_events').insert({lot_id, event_type:'ar_document', description:'IF — Accusé réception', triggered_by:uid, created_at:n})
```

**Toujours copier** exactement les appels de LotsPage, ne jamais réinventer.

---

## RÈGLE N°7 — Permissions : imports obligatoires

Toute page qui exécute des actions métier doit importer :
```js
import { canPerform, loadPermissions, getPermissionForEtape } from '../services/permissions'
import { createNotification } from '../services/notifications'
```

Et appeler `await loadPermissions(userService.value)` au début de `load()`.

Clés de permissions :
- `verifier_if`, `verifier_ic`, `verifier_da_pc`... (AQ vérifie)
- `approuver_if`, `approuver_ic`... (DT approuve)
- `emettre_if`, `emettre_ic`... (émetteur émet/réémet)
- `retourner_document` (AQ ou DT retourne)
- `accuser_reception_document`, `accuser_reception_circuit`
- `accuser_reception_aql_demande`, `accuser_reception_aql_resultat`
- `realiser_aql`

---

## RÈGLE N°8 — Mise à jour instantanée après action

Après une action, **mettre à jour le state Vue localement** sans reload complet.

Pattern :
```js
// 1. Supprimer l'item de sa catégorie courante
removeCatItem(item, cat)

// 2. Si l'action crée un item dans une autre catégorie → l'ajouter immédiatement
addToDocsCatAfterAr(item) // exemple : après AR, doc passe dans "Documents à traiter"
```

Ne jamais laisser un utilisateur devoir rafraîchir manuellement après une action.

---

## RÈGLE N°9 — Vue 3 setup() : règles de codage

```js
// ✅ TOUJOURS
var loading = ref(false)
var items = ref([])
var total = computed(function(){ return items.value.length })
var load = async function() { ... }

// ❌ JAMAIS
const loading = ref(false)  // pas de const
let items = []               // pas de let, pas de tableau brut non-ref
```

Retourner explicitement tout ce que le template utilise :
```js
return { loading, items, total, load, doAction, SVC_LABELS_ALL }
```

---

## RÈGLE N°10 — Vérifier le schéma avant de coder

Avant d'utiliser une colonne inconnue, toujours vérifier avec SQL Editor Supabase :
```sql
SELECT column_name FROM information_schema.columns
WHERE table_name = 'ma_table' ORDER BY ordinal_position;
```

Colonnes confirmées :
- `lots` : pas de prod_desc/prod_code → utiliser `product_id` → `products`
- `liberation_documents` : `id, type_document, statut, lot_id, is_applicable, service_emetteur, pending_ar_service, emitted_at, emitted_by, approved_at, updated_at, motif_retour`
- `document_movements` : `document_id, action, from_service, to_service, motif_retour, performed_by, performed_at`
- `lot_events` : `lot_id, event_type, description, triggered_by, created_at`
- `orders_of / orders_oc` : `id, lot_id, statut, etape_circuit, pending_ar_service, updated_at`
- `aql_inspections` : `id, lot_id, type, resultat, requested_at, inspected_at, inspected_by, request_ar_pending, result_ar_pending`
- `deviations` : `id, lot_id, statut, bloquante, numero_dn, description, declared_at, declared_service, declared_by, updated_at`
- `profiles` : `id, prenom, nom, service, is_active`
- `products` : `id, code_article, description`

---

## SVC_MAP — correspondance type document → service émetteur

```js
var SVC_MAP = {
  'if': 'fabrication',
  'ic': 'conditionnement',
  'da_pc': 'lcq',
  'da_micro': 'lcq',
  'maj_if': 'fabrication',
  'maj_ic': 'conditionnement',
  'maj_nmcl_of': 'planification',
  'maj_nmcl_oc': 'planification'
}
```

---

## Circuit flow

```js
var FLOW = ['planification', 'stock', 'aq', 'dt', 'aq_dap']
var AR_NEXT = { planification:'stock', stock:'aq', aq:'dt', dt:'aq_dap' }
```

Quand une étape est validée → `pending_ar_service = AR_NEXT[etape]` + `etape_circuit` avance.

---

## RÈGLE CRITIQUE N°11 — INTERDICTION ABSOLUE de `--theirs` / `--ours` lors d'un merge

### Bug commis (27 mai 2026 — commit 0564697)
Un merge entre la branche worktree `claude/heuristic-lewin-3d4125` et `main` a utilisé
`git checkout --theirs` pour résoudre les conflits. La branche worktree contenait des versions
**simplistes et anciennes** des fichiers. Résultat : toutes les fonctionnalités développées
sur `main` ont été **silencieusement écrasées** :

| Fichier | Lignes main (correct) | Lignes après merge (écrasé) | Perdu |
|---|---|---|---|
| `LotDetailPage.vue` | 717 | 323 | −394 lignes de fonctionnalités |
| `LotsPage.vue` | 1977 | 664 | −1313 lignes de fonctionnalités |
| `DocumentDetailPage.vue` | 367 | 240 | −127 lignes |
| `permissions.js` | 83 | 59 | −24 lignes |

### Règle à respecter ABSOLUMENT

```
❌ JAMAIS :
  git checkout --theirs <fichier>
  git checkout --ours <fichier>
  git merge -X theirs
  git merge -X ours

✅ TOUJOURS en cas de conflit :
  1. git diff <fichier>  — lire et comprendre chaque conflit
  2. Garder TOUTES les fonctionnalités des deux côtés (merge manuel)
  3. Si un fichier a été enrichi sur main (plus de lignes), main gagne TOUJOURS
  4. Vérifier le nombre de lignes avant/après : si ça diminue fortement → DANGER
```

### Vérification obligatoire avant tout commit de merge

```bash
# Avant de committer un merge, vérifier que les fichiers clés n'ont pas rétréci :
git diff HEAD~1 --stat
# Si un fichier perd plus de 50 lignes → STOP, investiguer avant de committer
```

### Comment détecter et corriger
```bash
# Trouver le merge base et comparer les versions
git merge-base <parent1> <parent2>
git show <mergebase>:<fichier> | wc -l   # taille d'origine
git show <parent1>:<fichier> | wc -l     # taille branche A
git show <parent2>:<fichier> | wc -l     # taille branche B
# Restaurer la bonne version :
git checkout <bon_commit> -- <fichier>
```

---

## RÈGLE CRITIQUE N°12 — Migrations SQL : enum PostgreSQL en 2 transactions séparées

### Bug rencontré (mai 2026 — migration 011_ccl_circuit.sql)

```
ERROR: 55P04: unsafe use of new value "ccl" of enum type doc_type
HINT: New enum values must be committed before they can be used.
```

### Cause

PostgreSQL **interdit** d'utiliser une valeur d'enum ajoutée par `ALTER TYPE ADD VALUE`
dans la **même transaction** que des `INSERT`/`UPDATE`/`SELECT` qui l'utilisent.
Dans Supabase SQL Editor, tout le contenu d'un seul bloc d'exécution est une transaction.

### Règle à respecter ABSOLUMENT

Quand une migration ajoute une valeur à un type enum **ET** utilise cette valeur,
**toujours la séparer en 2 fichiers / 2 exécutions distinctes** :

```sql
-- Fichier NNN_xxx_enum.sql  (exécuter EN PREMIER, seul)
ALTER TYPE mon_enum ADD VALUE IF NOT EXISTS 'nouvelle_valeur';

-- Fichier NNN+1_xxx_data.sql  (exécuter APRÈS, dans une 2e exécution)
INSERT INTO ma_table (..., type_col) VALUES (..., 'nouvelle_valeur');
UPDATE ma_table SET type_col = 'nouvelle_valeur' WHERE ...;
```

### Procédure dans Supabase SQL Editor

1. **Exécution 1** — coller et lancer uniquement l'`ALTER TYPE`
2. **Exécution 2** — coller et lancer le reste (permissions, INSERT, UPDATE)

### Nommage des fichiers de migration

```
011_ccl_circuit.sql   ← ALTER TYPE uniquement
012_ccl_data.sql      ← Permissions + INSERT + UPDATE
```

Ne jamais combiner `ALTER TYPE ADD VALUE` et des DML qui utilisent la nouvelle valeur
dans un même fichier SQL exécuté d'un seul coup.

---

## RÈGLE CRITIQUE N°13 — RLS Supabase : 4 policies obligatoires à la création

### Bug rencontré (31 mai 2026 — table `suivi_conditionnement`)

```
new row violates row-level security policy for table "suivi_conditionnement"
```

### Root cause

La table avait `ENABLE ROW LEVEL SECURITY` mais aucune policy `FOR INSERT`.  
Supabase bloque **silencieusement toute écriture** si aucune policy d'écriture n'existe, même pour un utilisateur authentifié. Le SELECT peut fonctionner (policy existante ou accès par défaut), mais INSERT/UPDATE/DELETE sont refusés par défaut dès que RLS est activé sans policy explicite.

### CAPA — Règle à appliquer ABSOLUMENT

Chaque fois qu'une table est créée avec RLS, **toujours ajouter immédiatement les 4 policies** dans la même migration :

```sql
ALTER TABLE ma_table ENABLE ROW LEVEL SECURITY;

CREATE POLICY "rls_ma_table_select" ON ma_table FOR SELECT TO authenticated USING (true);
CREATE POLICY "rls_ma_table_insert" ON ma_table FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "rls_ma_table_update" ON ma_table FOR UPDATE TO authenticated USING (true);
CREATE POLICY "rls_ma_table_delete" ON ma_table FOR DELETE TO authenticated USING (true);
```

Ne jamais écrire `ENABLE ROW LEVEL SECURITY` sans les 4 policies qui suivent dans la même migration.

### Diagnostic rapide si un INSERT échoue avec RLS

```sql
SELECT policyname, cmd FROM pg_policies WHERE tablename = 'ma_table';
-- Si INSERT absent → ajouter la policy FOR INSERT
```

---

## Déploiement

- Push sur `main` → GitHub Actions build + deploy GitHub Pages automatiquement
- **Toujours commiter ET pusher automatiquement** après chaque modification, sans demander de confirmation
- Ne jamais attendre la validation de l'utilisateur pour `git add / git commit / git push`
- Après push, attendre ~2 min et faire Ctrl+Shift+R pour vider le cache navigateur
