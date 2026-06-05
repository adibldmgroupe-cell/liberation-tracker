# CLAUDE.md — Règles projet Liberation Tracker

## Stack
- Vue 3 `setup()` — **toujours `var`**, jamais `const`/`let`
- Supabase (PostgREST) — ne throw jamais, toujours vérifier `res.error`
- GitHub Actions → GitHub Pages : **chaque `git push` déploie automatiquement**, sans demander

---

## DÉMARRAGE LOCAL (dev) — checklist anti-échec

> But : relancer l'app en local **sans fail** depuis une nouvelle session. Lire cette section AVANT de lancer.

### Environnement (PC verrouillé, pas d'admin)
- **Node portable** : `node` v24.16.0 dans `C:\Users\adib.nouar\nodejs`, déjà dans le PATH ; `npm.cmd` au même endroit.
- `node_modules` déjà installés (sinon `npm install`).
- Config preview prête : `.claude/launch.json` → `npm run dev`, port **5173** (runtimeExecutable = npm.cmd portable).
- Préférer l'outil **`preview_start`** (config `liberation-tracker`) pour lancer le serveur, pas Bash.

### `.env` à la racine — OBLIGATOIRE au runtime
Sans `.env` → **écran blanc silencieux** : `createClient()` lève `supabaseUrl is required.` au bootstrap.
App Vue jamais montée (`#app` vide), **aucune erreur** dans la console preview, **pas d'overlay Vite** → piège classique, ne pas chercher ailleurs.

Contenu (fichier **gitignoré**) :
```
VITE_SUPABASE_URL=https://okitrbcybiekuhzoyvvx.supabase.co
VITE_SUPABASE_ANON_KEY=<clé anon — NE PAS committer>
VITE_SUPABASE_SERVICE_KEY=<optionnel — seulement adminAuth / création-suppression comptes>
```
- Le `.env` **persiste sur le disque** entre les sessions → vérifier d'abord s'il existe (`Test-Path .env`) ; ne le recréer que s'il manque.
- URL dérivable du champ `ref` du JWT anon : `ref` → `https://<ref>.supabase.co`.
- Clé anon perdue → Supabase **Settings → API** (`anon public`), ou secrets GitHub du repo (`VITE_SUPABASE_*`, injectés au build CI par `deploy.yml`).
- ⚠️ Ne **jamais** committer le `.env` ni coller la clé dans un fichier versionné (dont ce CLAUDE.md) — cohérent avec le `.gitignore`.

### Séquence de lancement
1. Vérifier que `.env` existe (sinon le créer).
2. `preview_start` (ou `npm run dev`) → http://localhost:5173/liberation-tracker/
3. **Après création/modif du `.env`, redémarrer Vite (stop + start)** — il ne relit les variables qu'au démarrage.
4. Vérifier OK = **page de login affichée** + 0 erreur console.

### Vérifier seulement que ça COMPILE (sans secrets)
`npm run build` réussit même sans `.env` (les `import.meta.env.VITE_*` valent `undefined` mais ne sont pas exécutés au build) → test « est-ce que ça compile ? », ~7 s, 502 modules. Avertissements de taille de chunk (LotsPage, exceljs > 500 kB) = normaux, pas des erreurs.

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

## RÈGLE N°14 — Jamais d'agent pour lire des fichiers

Pour lire des fichiers, extraire du CSS, chercher des patterns → **toujours utiliser `Grep` ou `Read` directement**, jamais un agent `Explore` ou `general-purpose`.

| Tâche | Outil correct | À éviter |
|---|---|---|
| Extraire couleurs CSS d'un fichier | `Grep pattern="#[0-9a-fA-F]{3,6}"` | Agent Explore |
| Lire une section d'un fichier | `Read offset=X limit=Y` | Agent |
| Chercher une classe dans le code | `Grep pattern=".ma-classe"` | Agent |

**Pourquoi :** un agent pour une lecture simple coûte 50-150k tokens vs 2-5k pour un Grep. Résultat identique, coût 30× supérieur. Un agent se justifie uniquement pour du raisonnement multi-étapes ou des décisions conditionnelles complexes.

---

## RÈGLE N°15 — Checklist restructuration au pattern AdminFluxPage

Quand une page est restructurée pour adopter le pattern AdminFluxPage, **tous les éléments
"header" doivent être mis en violet immédiatement** — ne jamais laisser un gris par défaut.

### Palette violet AdminFluxPage (à appliquer partout)

| Élément | background | color | border |
|---|---|---|---|
| En-têtes tableau `th` | `#f5f3ff` | `#7c3aed` | `1px solid #ede9fe` |
| En-têtes cards `.card-hd` | `#f5f3ff` | `#7c3aed` | `1px solid #ede9fe` |
| En-têtes colonnes `.col-hd` | `#f5f3ff` | `#7c3aed` | `1px solid #ede9fe` |
| En-têtes grille `.pg-head` | `#f5f3ff` | `#7c3aed` | `1px solid #ede9fe` |
| En-têtes calendrier `.mth-head` | `#f5f3ff` | `#7c3aed` | `1px solid #ede9fe` |
| Titre de page `.fa-title` | — | `#1a1a2e` (jour) | — |

### Checklist avant de committer une restructuration

- [ ] Tous les `th` → `#f5f3ff / #7c3aed`
- [ ] Tous les `.card-hd` → `#f5f3ff / #7c3aed`
- [ ] Tous les `.col-hd`, `.pg-head`, `.mth-head` → `#f5f3ff / #7c3aed`
- [ ] Grep `themes.css` pour chaque classe modifiée (règle N°16 ci-dessous)
- [ ] **Badges de statut/rôle** : toujours ajouter les overrides night/workshop (voir règle N°15c)

---

## RÈGLE N°15c — Badges de statut/rôle : toujours override dark

Les couleurs pastel day (`#d1fae5`, `#fef3c7`, `#EAF3DE`, `#E6F1FB`…) **sont fluorescentes
sur fond sombre**. Tout badge de statut ou de rôle doit avoir ses overrides night/workshop.

### Pattern obligatoire pour tout badge coloré

```css
/* Day (scoped CSS) — pastel */
.badge-vert  { background: #d1fae5; color: #065f46; }
.badge-amber { background: #fef3c7; color: #92400e; }
.badge-bleu  { background: #ede9fe; color: #7c3aed; }

/* Night + Workshop (themes.css) — obligatoire */
html[data-theme="night"] .badge-vert,
html[data-theme="workshop"] .badge-vert  { background: rgba(52,211,153,.1); color: #6ee7b7; }

html[data-theme="night"] .badge-amber,
html[data-theme="workshop"] .badge-amber { background: rgba(251,191,36,.12); color: #fbbf24; }

html[data-theme="night"] .badge-bleu,
html[data-theme="workshop"] .badge-bleu  { background: var(--th-bg3); color: var(--th-accent); }
```

### Palette dark pour les couleurs sémantiques

| Couleur day | Night/Workshop fond | Night/Workshop texte |
|---|---|---|
| Vert (`#d1fae5`) | `rgba(52,211,153,.10)` | `#6ee7b7` |
| Amber/jaune (`#fef3c7`) | `rgba(251,191,36,.12)` | `#fbbf24` |
| Rouge (`#FCEBEB`) | `rgba(239,68,68,.12)` | `#fca5a5` |
| Violet (`#ede9fe`) | `var(--th-bg3)` | `var(--th-accent)` |
| Neutre (`#f3f4f6`) | `var(--th-bg3)` | `var(--th-text2)` |

---

## RÈGLE N°15b — `position: sticky` exige un conteneur scrollable

`position: sticky` sur un en-tête **ne fonctionne que si le conteneur parent** a :
- `overflow-y: auto` (ou `scroll`)
- une hauteur contrainte : `max-height: calc(100vh - Xpx)`

### Checklist avant tout `position: sticky` sur un en-tête

```css
/* ✅ TOUJOURS vérifier que le parent a : */
.conteneur {
  overflow-y: auto;
  max-height: calc(100vh - 220px); /* ajuster selon la hauteur du header page */
}

/* Puis l'en-tête peut être sticky : */
.th-ou-hd {
  position: sticky;
  top: 0;
  z-index: 2;
}
```

Si le conteneur n'a que `overflow-x: auto` sans `overflow-y`, le sticky ne fonctionne pas en vertical.

---

## RÈGLE N°16 — Cohérence scoped CSS ↔ themes.css

### Problème rencontré (mai 2026 — AdminShiftsPage)

`.pg-head` mis à jour en violet dans le scoped CSS du `.vue`, mais `themes.css` avait déjà
un override `html[data-theme="day"] .pg-head` en gris qui **écrasait silencieusement** le scoped CSS.

**Pourquoi :** `html[data-theme="day"] .class` a une spécificité `(0,2,1)` > scoped `(0,2,0)`.

### Règle à appliquer TOUJOURS

Avant de modifier une couleur dans un fichier `.vue` scoped, **vérifier si `themes.css` contient
un override pour la même classe** :

```bash
grep "nom-de-la-classe" src/styles/themes.css
```

Si un override existe → **mettre à jour les deux en même temps** :
1. Modifier le scoped CSS dans le `.vue`
2. Mettre à jour l'override correspondant dans `themes.css`

Ne jamais modifier l'un sans l'autre.

---

## RÈGLE CRITIQUE N°17 — Module Production / Schéma flux / TRS : origine des bugs

### Root cause commune (chantier mai-juin 2026)
Quasi TOUS les bugs du **Schéma Production** et de **Flux produits** venaient de **données dupliquées sans source unique de vérité**, aggravées par des **écritures bloquées en silence**. À retenir avant toute modif de ce module :

### 1. `operations_master` = SOURCE UNIQUE DE VÉRITÉ (liaison opération × machine)
Le n° d'opération de chaque machine + le périmètre des machines viennent **TOUJOURS** de `operations_master` (alimenté par le GS référentiel), **JAMAIS** de :
- `plan_rooms.op_number` (réplique qui DIVERGE — toutes les machines de conditionnement y avaient `op=310` → regroupement faux dans la vue pivot),
- `NODES_DEF` / `ARROWS_DEF` codés en dur dans `ProductionFlowPage` (avait créé un nœud fantôme « Formulation » absent du référentiel + flèches arbitraires).

→ Colonnes pivot, mapping op→salles du schéma, flèches : **dériver de `operations_master`** (`map room_code → op_number`). N'afficher que les salles présentes dans `operations_master` (sinon résidus `plan_rooms` : Cond. Sec., Réception Injectables…).
→ Le flux d'un produit = `product_flux` : `room_code` null = **flexible** (toutes les salles de l'op) ; `room_code` renseigné = **salle spécifique cochée** (prioritaire à l'affichage). Les machines de conditionnement d'un même flux sont des **alternatives** (jamais reliées entre elles : dernière étape fab → chacune).

### 2. RLS incomplet (voir règle N°13) — tables TRS créées hors migrations
`cadences`, `production_sessions`, `production_comptages`, `production_arrets`, `session_cadences` créées directement dans Supabase → policies INSERT/UPDATE souvent absentes → écriture bloquée EN SILENCE : INSERT sans policy → 403 ; UPDATE sans policy → **204 mais 0 ligne**. Symptôme : « ça marche en apparence mais rien n'est sauvé ». Migrations 020 (production_sessions) + 021 (cadences).

### 3. Échecs silencieux — toujours vérifier
Vérifier `res.error` après CHAQUE write Supabase. Suspecter un parseur qui ignore des lignes (`isNaN → continue`) quand des données « disparaissent ».

### 4. Parsing CSV : jamais `split(',')` naïf
Tout import GS doit utiliser un **vrai parseur de champs entre guillemets** (cf. `_parseLine` dans `services/googleSheets.js`). `split(',')` casse sur les descriptions à virgule (« ATOSTINE 10mg, COM PELLI ») → produits sautés.

### 5. Import GS vs cochage manuel (Flux produits)
Import = flux **en masse / flexible** (`room_code` null). Cochage manuel = **détail / salle spécifique**. Le ré-import ne doit **JAMAIS écraser les cochages** : ne (dé)synchroniser que les lignes flexibles (`.is('room_code', null)`). Seul « Vider l'import » efface tout.

### 6. Parité Schéma TRS ↔ TRS Live
Mêmes tables. L'équipement doit TOUJOURS être enrichi des params `plan_rooms` (numero_atelier, TO, pause…) via une fonction commune ; `selectNode` (Schéma) avait un fallback qui chargeait l'équipement **brut** (sans params) → modale à « — » / 0 et cadence introuvable. Charger en **batch** (pas de boucle séquentielle) pour réduire la fenêtre de race.

---

## RÈGLE CRITIQUE N°18 — Schéma DB versionné + origine de la partie Production

### Origine de la partie Production / TRS / Schéma flux
Ce module provient d'une **application incomplète développée par un tiers**, importée puis intégrée a posteriori. D'où la majorité des bugs : tables créées **directement dans Supabase (hors migrations)** → **RLS souvent absent/incomplet** (origine n°1 des bugs, cf. N°13/N°17), **table fantôme** (`catalogue_produits` référencée dans le code mais **inexistante** → 404 silencieux, supprimée du code), et **données dupliquées** (cf. règle N°17). → Avant de toucher ce module : **auditer la table** (existence, RLS, FK) avant de coder.

⚠️ **Correctif d'audit (02/06/2026 — export du schéma → `supabase/schema_reference.sql`)** : contrairement à l'estimation initiale, le module a en réalité **bien ses FK** (`production_sessions/_arrets/_comptages`, `session_cadences`, `suivi_*`, `shift_planning`, `objectifs_production`, `ateliers`, `arret_*`, `plan_rooms`…). **Seule `arret_conditionnement`** n'en avait aucune → FK `suivi_id`/`lot_id` ajoutées par **migration 024** ; son `equipement_id` était `uuid` au lieu de `bigint` → FK impossible → **corrigé par migration 031** (uuid→bigint + FK ; table vide → conversion sans perte). Depuis, le Schéma vue 1 (arrêt cond) écrit l'historique horodaté dans `arret_conditionnement` (en plus du motif dans `suivi_conditionnement.observation`). `sessions`/`arrets` = **fausse alerte** (jamais dans le code). Les liaisons par texte (`product_flux`, `cadences`, `equipment_cadences`) sont **volontairement sans FK** (souplesse import GS).

### Règle : tout schéma passe par une migration versionnée
- **Ne JAMAIS créer/modifier une table directement dans le SQL Editor Supabase** sans migration `NNN_xxx.sql` dans `supabase/migrations/`.
- Toute nouvelle table = `CREATE TABLE IF NOT EXISTS` + **les 4 policies RLS** (règle N°13) + les **FK** vers ses parents, dans la MÊME migration.
- Avant d'utiliser une table dans le code, **vérifier qu'elle existe** (un `from('x')` sur une table absente échoue en **404 silencieux**, masqué par les fallbacks).
- Le schéma doit rester **reproductible** depuis `supabase/migrations/` (audit juin 2026 : ~24 tables hors-migration → RLS oubliés + schéma non reproductible). **État au 02/06/2026** : RLS corrigé et nettoyé (migrations **020→023**, exactement 4 policies/table) ; schéma **versionné** dans `supabase/schema_reference.sql` ; FK manquantes traitées (**024**). Reste : enums non redéfinis hors migrations core, et redondances de schéma documentées dans 024 (à arbitrer, non bloquant).

---

## RÈGLE N°19 — Capitaliser les sélecteurs / chemins de test preview

À **chaque** nouveau sélecteur CSS ou chemin de clic découvert pendant un test preview
(Schéma Production, TRS Live, modales, autocomplete, cascade de selects…), l'ajouter
**immédiatement** dans `memory/trs-preview-test-playbook.md` (mémoire locale).
But : ne plus jamais re-tâtonner sur l'UI lors des prochains tests/dev.

Le playbook contient déjà : nav via `location.hash` (le clic sidebar échoue en plein écran) ;
Schéma → `button[title="Mode TRS OEE"]`, nœud = `g.flow-node` (dispatch click), boutons `.tdp-btn-*`,
modales `.trs-overlay` / `.trs-btn-save` / `.trs-btn-go`, autocomplete `.trs-auto-item` (mousedown) ;
TRS Live → boutons `.ab-*`, modales `.overlay` / `.btn-save` / `.btn-go`, autocomplete `.auto-item` ;
pièges → champ lot = `input[placeholder*="lot"]` (pas `[type=text]`), saisie via `dispatchEvent('input')`,
cascade arrêt asynchrone (~1,1 s entre selects), vues dupliquées (filtrer `offsetParent!==null`),
`loadAll` séquentiel lent (≥3 s après Démarrer/Clôturer).

---

## RÈGLE CRITIQUE N°20 — Flux production : 9 ROUTES RÉELLES (le n° d'op ≠ l'ordre du flux)

### Source de vérité du flux = les 9 routes pharma (PAS le tri par op_number)
Le **numéro d'opération ne reflète PAS l'ordre du procédé** : Remplissage gélules (op260) et
Mélange pâteux (op270) sont des **branches** (pas après Pelliculage). Trier les op de façon
croissante crée des **flèches/liaisons fausses** (ex. Pelliculage→Mélange pâteux, cond→fab).

**Les 9 routes possibles (forme sèche 1-8, semi-solide 9)** — codées en dur dans
`ProductionFlowPage.vue` (`FLOW_STAGES` étape→salles + `FLOW_EDGES` transitions) :
```
1. Pesée → Granulation → Mélange → Remplissage gélules → Cond
2. Pesée → Mélange → Remplissage gélules → Cond
3. Pesée → Granulation → Mélange → Compression → Cond
4. Pesée → Granulation → Mélange → Compression → Pelliculage → Cond
5. Pesée → Mélange → Compression → Cond
6. Pesée → Mélange → Compression → Pelliculage → Cond
7. Pesée → Compression → Pelliculage → Cond        (premix, comprimé pelliculé)
8. Pesée → Compression → Cond                       (premix, comprimé nu)
9. Pesée → Mélange pâteux (n200) → Cond R,T (c206)  (crème, gel, pommade)
```
**Salles/étape** : Pesée `p464,p471` · Granulation `n140,n425` · Mélange `n138,n137,n448` ·
Compression `n131,n128,n134,n445` · Pelliculage `n143,n429,n136` · Remplissage gélules `n436` ·
Mélange pâteux `n200` · Cond sec `c149,c148,c147,c146,c223,c220,c222` · Cond pâteux `c206`.
Hors flux : OTC `n101-105`, stockage `n155/n416`.

⚠️ Les flèches du Schéma se dérivent de `FLOW_EDGES`, **jamais** d'une agrégation par op
(`opTransitions`/`nodesByOp` abandonnés pour les flèches — commit ab29b94). Vérifié 12/12
flèches vers l'avant. Si on ajoute/retire une route → mettre à jour `FLOW_STAGES`/`FLOW_EDGES`.

---

## RÈGLE CRITIQUE N°21 — Lancement d'un lot : 2 contrôles obligatoires (BPF)

Tout point qui **lance un lot sur un équipement** (Schéma vue 1 `saveStart` + `trsDoStart`,
TRS Live `doStart`, PDP `saveSuiviCond`/`saveSuiviFab` + saisie en masse `bulkSave`) doit
appliquer **les 2 règles** avant d'insérer :

1. **Un seul lot en cours par machine/atelier — SAUF Pesée** (anti-mélange GMP).
   Pesée = `node.zone === 'pesee'` (ou atelier dont le nom ~ `/pes[ée]/i`). Bloquer si un
   suivi `En cours`/`Arrêt` existe déjà. Contrôle **en base** (pas seulement les données
   chargées) pour ne pas être contourné par un clic avant `loadLive`.

2. **Produit autorisé sur l'équipement via `product_flux`** (service **`src/services/flux.js`**) :
   `checkProductFluxRoom(code, roomCode, opNumber)` / `checkProductFluxEquipName(code, equipNom)`.
   Autorisé si **room_code spécifique coché** OU **flexible (room_code null) sur l'op sans salle
   spécifique imposée**. Sinon **bloqué**. **Fail-open réseau, fail-closed si pas de flux.**
   `product_flux.room_code` == `operations_master.room_code` (c149, n445, p464…).

Toujours réutiliser le service `flux.js` — ne jamais réécrire la logique de flux.

---

## RÈGLE CRITIQUE N°22 — Schéma : vue 1 (planif) ≠ TRS, et fin réelle / clôture auto

### a) Ne JAMAIS coupler la partie TRS et la vue 1 (planification)
- **Vue 1** (statut nœud, lots, Démarrer/Clôturer) lit UNIQUEMENT `suivi_conditionnement` /
  `suivi_fabrication` (+ `deviations`). `nodeStatus`/`getNodeLots` ne lisent QUE ces tables.
- **Mode TRS** (📊) lit `production_sessions` (via `loadTrsData`→`nodeTrs`, gardé par `trsMode`).
- Écritures séparées : TRS → `production_sessions` ; vue 1 → `suivi_*`. Ne jamais injecter
  `production_sessions` dans `getNodeLots` (bug corrigé : la vue 1 montrait des sessions TRS).
- `getNodeLots` (cond) doit joindre `lots(numero_lot,…)` pour afficher le **n° de lot**, pas `lot_id`.

### b) Fin réelle bidirectionnelle (par `lot_id`), recalage PDP manuel
- Saisie quotidienne par la planification. **Schéma Clôturer** (`suivi_conditionnement.date_fin`)
  ↔ **PDP `date_fin_reelle`** (`planification_conditionnement`) : `saveClose` propage vers le PDP,
  `savePdpReelle` propage vers le suivi (date seule, **pas** le statut, pour ne pas clôturer une
  session TRS active). Le décalage de l'aval reste **manuel** (bouton « 📌 Recaler sur réel ») ;
  retard = jours **ouvrés** (fin réelle − fin estimée, calendrier machine).

### c) Clôture auto fin de shift : détecter le RETARD, pas une fenêtre
- `autoStopCheck` (TrsLivePage) ferme **toute** session dont `fin de shift + 10 min` est **dépassée**
  (datetime réelle via `sessionShiftEnd`, gère le **shift de nuit** = fin ≤ début → +1 jour) →
  rattrape les sessions oubliées des jours précédents. Déclenché au montage + toutes les 60 s.
  Ne PAS faire `loadAll()` dans la boucle (mute `panels.value`) → figer la liste, recharger 1× après.
  ⚠️ Reste **client-side** (s'exécute quand la page/Mode Live est ouvert) — clôture 100 %
  non-attendue = cron serveur (non implémenté).

---

## RÈGLE CRITIQUE N°23 — Contrôle de séquence (anti-saut d'étape amont, traçabilité)

Quand le planificateur signale un lot sur une étape, il peut **oublier une étape amont**
(ex. saisit Granulation, puis saute Mélange et passe à Compression). Contrôle dans `flux.js` :
- `checkUpstreamStages(lotId, productCode, targetStage)` → `{ missing: [stageKeys] }` = étapes de
  **la route du produit** (`product_flux` → étapes via `ROOM_STAGE`/`OP_STAGE`), situées **avant**
  la cible (`STAGE_ORDER`), pour lesquelles le lot n'a **aucun** suivi (`suivi_fabrication`/
  `suivi_conditionnement`, mappés via `plan_rooms`). Variantes `checkUpstreamForEquip` / `checkUpstreamForAtelier`.
- Se base sur **la route DU PRODUIT** → un premix (saute Granulation/Mélange) ne déclenche **pas**
  de fausse alerte (ces étapes ne sont pas dans son `product_flux`).
- **Comportement = AVERTIR, pas bloquer** (`window.confirm` nommant les étapes manquantes +
  « Continuer quand même ? ») : l'étape a physiquement eu lieu, seul le **signalement** a été
  oublié → on laisse continuer (et saisir en rétroactif). Appliqué sur **Vue 1** (`saveStart`)
  **et PDP** (`saveSuiviCond`/`saveSuiviFab`, à la création), **PAS le TRS** (performance, sans
  lien avec vue 1/PDP — cf. règle N°22).

⚠️ `FLOW_STAGES`/`FLOW_EDGES`/`ROOM_STAGE`/`OP_STAGE`/`STAGE_ORDER` = **source unique dans
`services/flux.js`** (importés par ProductionFlowPage pour les flèches). Ne pas redéfinir ailleurs.

---

## RÈGLE N°24 — Modèle « Parcours » UI (« je clique, j'entre ») — STANDARD obligatoire

Tout workflow multi-étapes d'un lot (circuits, AQL, et à terme documents IF/IC/DA/CCL, RVP, MàJ,
clôture SAP…) doit suivre **le même modèle de parcours**. Référence : `CircuitDetailPage.vue` (circuit
OF/OC, 6 étapes) et `AqlDetailPage.vue` (AQL Fab/Cond, 4 étapes). Détail complet en mémoire locale
`memory/parcours-ui-pattern.md`.

⚠️ **Terme UI = « circuit » PARTOUT** (titre de section « **Étapes du circuit X** » sur circuits OF/OC,
AQL **et** documents IF/IC/DA/CCL) — **JAMAIS « parcours »** côté affichage. « Parcours » est seulement
le **nom interne** du pattern (ce fichier / la mémoire). Ne pas mélanger les deux mots à l'écran.
Nom complet d'un type entre **parenthèses** comme « IF (Instruction de fabrication) » :
DA = « (Dossier analytique) », AQL = « (Acceptable quality level) », RVP = « (Rapport de validation process) ».

### a) Carte compacte sur LotDetailPage (jamais d'étapes inline)
Grille `.dg` → carte cliquable qui **navigue** vers la page parcours :
```html
<div class="di di-act" @click="$router.push('/lots/'+lot.id+'/<thing>/'+type)">
  <div class="dind" :class="xxxInd(type)"></div>
  <div><div class="dn">{Label}</div><div class="ds" :class="xxxDsClass(type)">{xxxSummary(type)}</div></div>
</div>
```
Helpers : `xxxInd`→`ind-wait|ind-prog|ind-done|ind-ret` · `xxxSummary`→texte court · `xxxDsClass`→`ds-ok|ds-ret|''`.

### b) Page parcours dédiée (route `lots/:lotId/<thing>/:type`)
Calquer CircuitDetailPage/AqlDetailPage : `steps[{key,label,service}]`, état dérivé d'une entité,
`stepDone/currentStep/doneCount/stepIndClass/dsClass/stepStatus/stepClickable/stepClick`, **réutiliser
les services** (`validateOrder`, `requestAql`, `acknowledgeAql*`, `respondAql`…) + `await load()`,
`watch(()=>route.params… , ()=>location.reload())` (type/lotId figés à la création).
**Header UNIFIÉ obligatoire** (identique circuit/AQL/document) : `.lh` > `.lh-info` [`.lh-type` =
`.lt-short` (TYPE court gras) + `.lt-full` (**(nom complet entre parenthèses)**) ; `.lh-lot` = `.ll-num`
(n° lot) + `.ll-prod` (produit)] · `.lh-right` > `.ttl` = **STATUT** (`statusLabel`, jamais le type ni le
nom). Noms : OF (Ordre de fabrication), OC (Ordre de conditionnement), IF (Instruction de fabrication),
DA (Dossier analytique …), AQL (Acceptable quality level), RVP Fab/Cond/LCQ (Rapport de validation process).

### c) Thème/CSS IDENTIQUE (copier le `<style scoped>`, OK day/night/workshop)
`.dind` : ind-wait `#e8e8e8` · ind-prog `#7c3aed` (en cours) · ind-done `#1D9E75` (OK) · ind-ret/ko `#E24B4A` (KO).
`.ds`/`ds-ok #1D9E75`/`ds-ret #E24B4A` · `.ttl` badge violet MAJUSCULE · `.dc` `#BA7517` · `.di-act` hover `#f5f3ff` ·
étape à 2 issues → boutons inline `.btn-c`(vert)/`.btn-nc`(rouge)/`.btn-relance`(outline violet) · historique `.circ-hist`.

### d) Principes
- **Alternance action → AR** (`pending_ar_service` / `*_ar_pending` = service suivant qui accuse réception).
- **Admin bypass** `canPerform` (permissions.js l.18) → un compte admin déroule tout.
- **doneCount = total si statut terminal** (cohérence carte ↔ tuile KPI ↔ compteur ; cf. `ofV/ocV`).
- **Carte résumé, jamais le détail des étapes sur LotDetailPage.**
- **Action principale = CLIC sur l'étape active** (`.di-act`, `.ds` violet « ＋ Action ») — **JAMAIS** un bouton pleine largeur coloré (pas de « bande verte »). Action secondaire (retour/relance) = **petit** bouton (`.btn-ret` rouge / `.btn-relance` violet) ; étape à 2 issues exclusives = `.btn-c`/`.btn-nc`. Multi-stage (AR puis valider) = clics successifs.

---

## RÈGLE CRITIQUE N°25 — Harmonisation UI : INTERDICTION de négliger le moindre détail

Quand une page/un composant est aligné sur un pattern existant (parcours N°24, palette
AdminFluxPage N°15, badges N°15c…), l'harmonisation doit être **TOTALE**. Aucun détail
d'**affichage, de layout ou de style** ne doit rester divergent. **Un seul** élément hors-charte
(bande de bouton, couleur de lien, badge, espacement, bordure, indicateur, hover) =
harmonisation **NON terminée**. « À peu près pareil » = pas harmonisé.

### Tout doit matcher la page de référence — comparer ÉLÉMENT PAR ÉLÉMENT
- **Layout** : même structure de balises/classes (ex. étapes verticales `.dg/.di`, pas de flow
  horizontal ; carte résumé cliquable, pas le détail inline).
- **Couleurs** : violet `#7c3aed` (actif/en cours), vert `#1D9E75` (OK), rouge `#E24B4A` (KO/retour),
  gris `#999`. **Aucun bleu résiduel**, aucune palette parallèle.
- **Actions** : clic sur l'étape (« ＋ Action » violet), **jamais** de bouton pleine largeur ;
  secondaire = **petit** bouton (cf. N°24).
- **Badges/chips** : `.ttl` violet MAJUSCULE + overrides night/workshop (N°15c).
- **Indicateurs** `.dind` (ind-wait/prog/done/ret) · **Historique** `.circ-hist` (pas de timeline) ·
  **Compteur** `.dc` · **Hover, espacements, bordures, responsive** identiques.

### Vérifier le RENDU CALCULÉ, pas seulement le CSS scopé
`themes.css` (`html[data-theme] .x`, spécificité (0,2,1)) écrase **silencieusement** le scoped (0,2,0)
— règle N°16. **TOUJOURS** confirmer en preview avec `getComputedStyle(el).color` (jour **ET** nuit
**ET** atelier) et comparer à la page de référence — jamais se fier au seul `.vue`. Bugs vécus :
`.bc` resté bleu (2 règles concurrentes), bande verte de bouton plein.

### Avant de déclarer « harmonisé » : comparaison côte à côte OBLIGATOIRE
Ouvrir la page de référence ET la page harmonisée, comparer chaque élément (retour, badge, étapes,
boutons, historique, hover, responsive PC + smartphone, 3 thèmes). Tout écart se corrige **AVANT** de committer.

---

## Déploiement

- Push sur `main` → GitHub Actions build + deploy GitHub Pages automatiquement
- **Toujours commiter ET pusher automatiquement** après chaque modification, sans demander de confirmation
- Ne jamais attendre la validation de l'utilisateur pour `git add / git commit / git push`
- Après push, attendre ~2 min et faire Ctrl+Shift+R pour vider le cache navigateur
