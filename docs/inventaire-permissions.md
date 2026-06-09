# Inventaire des permissions — Phase 1 (énumération)

> But : recenser **toutes** les actions de l'app + **toutes** les pages, pour que chacune soit
> gérée par le système de permissions à **2 niveaux** : (A) **voir la page**, (B) **faire l'action**.
>
> Légende : ✅ clé existe **et** appliquée · 🟡 clé existe mais **pas appliquée partout** ·
> 🆕 clé **à créer** · ⚙️ contrôlée aujourd'hui par `requiresAdmin` (tout-ou-rien).

---

## 0. Authentification (hors matrice)
| Page | Route | Note |
|---|---|---|
| Connexion | `/login` | public |
| Changement mot de passe | `/changer-mot-de-passe` | self (1er login) |

---

## A. NIVEAU « VOIR LA PAGE » (à ajouter au garde-fou du routeur)

> Aujourd'hui : soit tout utilisateur connecté, soit `requiresAdmin` (admin only). On veut une clé `voir_*` par page.

| Page | Route | Accès actuel | Clé « voir » proposée |
|---|---|---|---|
| Tableau de bord | `dashboard` | connecté | `voir_dashboard` ✅ |
| Lots (table) | `lots` | connecté | `voir_lots` ✅ |
| Détail lot | `lots/:id` | connecté | `voir_lots` ✅ |
| Parcours (circuit/AQL/doc) | `lots/:lotId/...` | connecté | `voir_lots` ✅ |
| Planifier | `planifier` | connecté | `voir_planification` 🆕 |
| Tâches | `tasks` | connecté | `voir_taches` 🆕 |
| Notifications | `notifications` | connecté | `voir_notifications` 🆕 |
| Produits (vue) | `products`, `products/:id` | connecté | `voir_produits` 🆕 |
| Matrice péremption | `peremption` | connecté | `voir_peremption` 🆕 |
| Évaluation péremption | `peremption/:productId` | connecté | `voir_peremption` 🆕 |
| Schéma flux production | `production/flux` | connecté | `voir_production_schema` 🆕 |
| PDP production | `production/pdp` | connecté | `voir_pdp` 🆕 |
| TRS Live | `tracking/trs` | connecté | `voir_trs_live` 🆕 |
| TRS Analytics | `tracking/analytics` | connecté | `voir_trs_analytics` 🆕 |
| Suivi PDP Fab | `tracking/pdp-fab` | connecté | `voir_suivi_fab` 🆕 |
| Suivi TRS Cond | `tracking/trs-sessions` | connecté | `voir_suivi_cond` 🆕 |
| Réf. produits/SAP | `admin/referentiel` | ⚙️ admin | `voir_referentiel` 🆕 |
| Catalogue produits | `admin/products` | ⚙️ admin | `voir_admin_produits` 🆕 |
| Flux produits | `admin/flux` | ⚙️ admin | `voir_admin_flux` 🆕 |
| Ateliers/machines | `admin/ateliers` | ⚙️ admin | `voir_admin_ateliers` 🆕 |
| Équipements cond. | `admin/equipements` | ⚙️ admin | `voir_admin_equipements` 🆕 |
| Types d'arrêt | `admin/arret-types` | ⚙️ admin | `voir_admin_arrets` 🆕 |
| Shifts & équipes | `admin/shifts` | ⚙️ admin | `voir_admin_shifts` 🆕 |
| Délais documentaires | `admin/deadlines` | ⚙️ admin | `voir_admin_delais` 🆕 |
| Comptes utilisateurs | `admin/users` | ⚙️ admin | `voir_admin_comptes` 🆕 |
| Permissions | `admin/permissions` | ⚙️ admin | `voir_admin_permissions` 🆕 |

---

## B. ACTIONS — Workflow LOT (table lots inline, masse, détail, parcours, tâches)

> Déjà couvert par le catalogue actuel (✅). Mêmes clés partout (table inline = masse = détail = tâches).

### B1. Circuits OF/OC
| Action | Clé |
|---|---|
| Mettre en circuit OF / OC | `mettre_en_circuit_of` / `_oc` ✅ |
| Valider quantités OF / OC (stock) | `valider_quantites_of` / `_oc` ✅ |
| Valider OF / OC (AQ) | `valider_of` / `valider_oc` ✅ |
| Autoriser lancement (DT) | `autoriser_lancement` ✅ |
| Remettre à production (AQ DAP) | `remettre_ordre_production` ✅ |
| AR circuit (étapes intermédiaires) | `accuser_reception_circuit` ✅ |
| AR réception OF / OC | `accuser_reception_of` / `_oc` ✅ |

### B2. Documents (IF/IC/DA PC/DA Micro/CCL/RVP)
| Action | Clé |
|---|---|
| Émettre IF/IC/DA PC/DA Micro/RVP | `emettre_if` / `_ic` / `_da_pc` / `_da_micro` / `emettre_rvp` ✅ |
| Émettre / transmettre CCL (AQ) | `emettre_ccl` ✅ |
| Vérifier IF/IC/DA/RVP (AQ) | `verifier_if` / `_ic` / `_da_pc` / `_da_micro` / `verifier_rvp` ✅ |
| Approuver IF/IC/DA/RVP (DT) | `approuver_if` / `_ic` / `_da_pc` / `_da_micro` / `approuver_rvp` ✅ |
| Libérer via CCL (DT) | `approuver_ccl` ✅ |
| Libérer le lot | `liberer_lot` ✅ |
| Retourner un document | `retourner_document` ✅ |
| Rectifier / réémettre | `rectifier_document` ✅ |
| AR document | `accuser_reception_document` ✅ |

### B3. MàJ documentaires & Clôture SAP
| Action | Clé |
|---|---|
| Émettre MàJ IF/IC/Nmcl OF/Nmcl OC | `emettre_maj_if` / `_ic` / `_nmcl_of` / `_nmcl_oc` ✅ |
| Vérifier / Approuver MàJ | `verifier_maj_doc` / `approuver_maj_doc` ✅ |
| Clôture SAP OF/OC (émettre/valider/demander/confirmer) | `emettre_/valider_/demander_/confirmer_cloture_sap_of` (+`_oc`) ✅ |

### B4. AQL
| Action | Clé |
|---|---|
| Demander AQL Fab / Cond | `demander_aql_fab` / `_cond` ✅ |
| Réaliser AQL (conforme / non conforme) | `realiser_aql` ✅ |
| Relancer AQL | `demander_aql_fab` / `_cond` ✅ |
| AR demande AQL (AQ/LCQ) | `accuser_reception_aql_demande` ✅ |
| AR résultat AQL (Fab/Cond) | `accuser_reception_aql_resultat` ✅ |

### B5. Déviations
| Action | Clé |
|---|---|
| Déclarer une non-conformité | `declarer_nc` ✅ |
| Marquer bloquante | `dev_bloquer` ✅ (mapping corrigé) |
| Clôturer une déviation | `cloturer_deviation` ✅ |

### B6. Dates prévisionnelles / CRUD lot
| Action | Clé |
|---|---|
| Modifier dates lib LCQ/AQ/DT (masse **et** inline) | `modifier_planning` ✅ |
| Modifier un lot | `modifier_lot` ✅ |
| Supprimer un lot | `supprimer_lot` ✅ |

### B7. Données (modale) & export — table lots
| Action | Clé proposée |
|---|---|
| Vider/réimporter « Gestion lots » | `vider_donnees_lots` 🆕 |
| Vider « Module production » | `vider_donnees_production` 🆕 |
| Vider « Risque péremption » | `vider_donnees_peremption` 🆕 |
| Synchroniser GS (Réception PF / Historique) | `importer_donnees_gs` 🆕 |
| Exporter Excel / PDF | `exporter_lots` 🆕 (ou libre) |

---

## C. ACTIONS — Planification
| Page | Action | Clé |
|---|---|---|
| Planifier | Créer / planifier un lot | `creer_lot` ✅ |

---

## D. ACTIONS — Risque péremption
| Page | Action | Clé |
|---|---|---|
| Matrice | Saisir/éditer un critère (shelf life, montant forecast, promotion, marché…) | `evaluer_risque_peremption` 🟡 (vérifier que l'édition inline est bien gardée) |
| Matrice / Éval | Évaluer / réévaluer un produit | `evaluer_risque_peremption` ✅ |
| Matrice | Configurer pondérations & seuils | `configurer_risque_peremption` ✅ |
| Matrice | Action en masse (assigner critère / export) | `evaluer_risque_peremption` 🟡 |
| Matrice | « Lancer le circuit » (Phase 2) | `lancer_circuit_peremption` 🆕 |
| Matrice | Voir l'historique péremption | (lecture → `voir_peremption`) |

> ❓ À décider : « shelf life », « montant forecast », « historique » = **une** clé (`evaluer_risque_peremption`)
> ou **clés séparées** par critère ? (granularité)

---

## E. ACTIONS — Production / TRS
| Page | Action | Clé |
|---|---|---|
| Schéma / TRS Live / PDP / Suivi Fab | Démarrer session/suivi | `trs_demarrer` ✅ |
| TRS Live / Schéma | Saisir comptage | `trs_comptage` ✅ |
| Toutes | Déclarer un arrêt | `trs_arret` ✅ |
| Toutes | Clôturer session/suivi | `trs_cloturer` ✅ |
| PDP / Suivi Fab | Supprimer un suivi | `trs_supprimer_suivi` ✅ |
| Schéma / TRS | Déclarer une déviation (depuis la session) | `declarer_nc` 🟡 (à brancher ici) |
| PDP | Saisir le PDP en masse (planif. conditionnement) | `gerer_pdp` 🆕 |
| PDP | Recaler sur fin réelle / annuler une planif | `gerer_pdp` 🆕 |
| Schéma | Créer atelier/salle à la volée (référentiel) | `gerer_ateliers` 🆕 (voir F) |

---

## F. ACTIONS — Référentiels & Administration (aujourd'hui `requiresAdmin` ⚙️)
| Page | Actions | Clé proposée |
|---|---|---|
| Flux produits | Cocher/décocher une salle, importer GS, vider l'import, modifier/supprimer étape | `gerer_flux_produits` 🆕 |
| Ateliers/machines | Ajouter/modifier/(dés)activer atelier & processus, params salles, importer cadences & operations_master | `gerer_ateliers` 🆕 |
| Équipements cond. | Ajouter/modifier équipement | `gerer_equipements` 🆕 |
| Types d'arrêt | CRUD familles / sous-familles / types | `gerer_types_arret` 🆕 |
| Shifts & équipes | Ajouter/modifier/supprimer **shift**, ajouter/modifier/supprimer **équipe**, **affecter une équipe** à un shift (planning) | `gerer_shifts` 🆕 (+ option `affecter_equipe` 🆕) |
| Délais documentaires | Définir/modifier les délais par service | `gerer_delais` 🆕 |
| Catalogue produits | Créer/modifier/(dés)activer produit, importer GS produits | `gerer_produits` 🆕 |
| Réf. produits/SAP | Import/sync référentiel | `gerer_referentiel` 🆕 |
| Comptes utilisateurs | Créer/modifier/supprimer compte, reset MDP, activer/désactiver | `gerer_comptes` 🆕 ⚠️ (création de compte = action sensible) |
| Permissions | Modifier la matrice de permissions | `gerer_permissions` 🆕 ⚠️ |

---

## G. Divers
| Page | Action | Clé |
|---|---|---|
| Notifications | Marquer lu / tout lu | libre (lecture) ou `voir_notifications` |
| Dashboard | Voir KPI / timeline | `voir_kpi` / `voir_timeline` ✅ |

---

## Récapitulatif des clés à CRÉER (🆕)
**Voir la page** (~22) : `voir_planification, voir_taches, voir_notifications, voir_produits, voir_peremption,
voir_production_schema, voir_pdp, voir_trs_live, voir_trs_analytics, voir_suivi_fab, voir_suivi_cond,
voir_referentiel, voir_admin_produits, voir_admin_flux, voir_admin_ateliers, voir_admin_equipements,
voir_admin_arrets, voir_admin_shifts, voir_admin_delais, voir_admin_comptes, voir_admin_permissions`.

**Actions** (~14) : `vider_donnees_lots, vider_donnees_production, vider_donnees_peremption, importer_donnees_gs,
exporter_lots, lancer_circuit_peremption, gerer_pdp, gerer_flux_produits, gerer_ateliers, gerer_equipements,
gerer_types_arret, gerer_shifts, (affecter_equipe), gerer_delais, gerer_produits, gerer_referentiel,
gerer_comptes, gerer_permissions`.

## Points à arbitrer avant Phase 2
1. **Granularité péremption** : 1 clé `evaluer` ou clés par critère (shelf life / forecast / …) ?
2. **Granularité référentiels** : 1 clé par page (proposé) ou plus fin (ajouter vs supprimer vs importer) ?
3. **`affecter_equipe`** séparé de `gerer_shifts` ?
4. **Admin sensible** (`gerer_comptes`, `gerer_permissions`) : garder en plus le garde-fou `requiresAdmin` ?
5. **Vue vs action** : si on n'a pas `voir_x`, cache-t-on aussi l'entrée de menu (sidebar) ?
