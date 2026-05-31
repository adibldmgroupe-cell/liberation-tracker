# THEMES.md — Référence des thèmes visuels
# Liberation Tracker

Chaque thème est défini par ses variables CSS dans `src/styles/themes.css`
et appliqué via `html[data-theme="..."]`.

Le thème actif est persisté dans `localStorage` (`tracking_theme`)
et géré par `src/composables/useTheme.js`.

---

## ☀️ Jour — `data-theme="day"`

> Référence : AdminFluxPage (Référentiel → Flux produits)

| Variable | Valeur | Rôle |
|---|---|---|
| `--th-bg` | `#ffffff` | Fond principal |
| `--th-bg2` | `#f9fafb` | Fond secondaire (inputs, tableaux) |
| `--th-bg3` | `#f3f4f6` | Fond tertiaire (hover, separators) |
| `--th-border` | `#e5e7eb` | Bordures standard |
| `--th-text` | `#111827` | Texte principal |
| `--th-text2` | `#6b7280` | Texte secondaire |
| `--th-text3` | `#9ca3af` | Labels discrets / placeholders |
| `--th-input-bg` | `#ffffff` | Fond inputs |
| `--th-topbar` | `#ffffff` | Fond topbar / header |
| `--th-sidebar` | `#0a0a0a` | Fond sidebar |
| `--th-accent` | `#7c3aed` | Accent principal (violet) |
| `--th-font` | `'Inter', sans-serif` | Police |
| `--th-font-size` | `13px` | Taille de base |

**Hiérarchie typographique :**
| Élément | Taille | Poids |
|---|---|---|
| Titre page | 18px | 800 |
| Titre modal | 14px | 800 |
| Corps / boutons | 12px | 400–600 |
| Recherche | 13px | 400 |
| Codes / chips | 11px | 700–800 |
| Labels | 10px | 700 |
| Tiny chips | 9px | 700 |

**Accents secondaires :**
| Usage | Valeur |
|---|---|
| Bouton action principal | `#7c3aed` fond, `#fff` texte |
| Hover | `#6d28d9` |
| Fond badges violet | `#ede9fe` fond, `#7c3aed` texte |
| Pivot accent (bordure machine) | `#ede9fe` / `#7c3aed` 2px |
| Erreur | `#ef4444` |
| Succès | `#059669` |

**Pages couvertes (layout + couleurs validés) :**
- ✅ AdminRefPage (barre d'onglets)
- ✅ ProductsCatalogPage — layout restructuré pattern AdminFluxPage
- ✅ AdminAteliersPage — layout restructuré ✅
- ⏳ AdminFluxPage (référence, déjà correct)
- ✅ AdminShiftsPage — layout restructuré ✅
- ✅ AdminArretTypesPage — layout restructuré ✅

---

## 🌙 Deep-Night — `data-theme="night"`

> Référence : ProductionFlowPage (SCHÉMA FLUX PRODUCTION) — mode nuit base

| Variable | Valeur | Rôle |
|---|---|---|
| `--th-bg` | `#0a0a1e` | Fond principal |
| `--th-bg2` | `#12122a` | Fond secondaire (panneaux, inputs) |
| `--th-bg3` | `#1a1a3e` | Fond tertiaire (hover, dropdowns) |
| `--th-border` | `#2a2a4a` | Bordures |
| `--th-text` | `#e2e8f0` | Texte principal |
| `--th-text2` | `#9ca3af` | Texte secondaire |
| `--th-text3` | `#4b5563` | Labels discrets |
| `--th-input-bg` | `#12122a` | Fond inputs |
| `--th-topbar` | `#0f0f23` | Fond topbar / header |
| `--th-sidebar` | `#07071a` | Fond sidebar |
| `--th-accent` | `#7c7cff` | Accent principal (violet électrique) |
| `--th-font` | `'Inter', sans-serif` | Police |
| `--th-font-size` | `13px` | Taille de base |

**Accents secondaires (hardcodés) :**
| Usage | Valeur |
|---|---|
| Bouton action principal (save, add) | `#7c3aed` |
| Bouton action hover | `#6d28d9` |
| Focus input / accent fort | `#7c7cff` |
| Succès / sessions actives | `#10b981` |
| Erreur | `#ef4444` |
| Avertissement | `#f59e0b` |

**Pages couvertes (couleurs) :**
- ✅ AdminRefPage (barre d'onglets)
- ✅ ProductsCatalogPage — layout restructuré ✅
- ✅ AdminAteliersPage — layout restructuré ✅
- ✅ AdminFluxPage (référence)
- ✅ AdminShiftsPage — layout restructuré ✅
- ✅ AdminArretTypesPage — layout restructuré ✅

---

## 🏭 Workshop — `data-theme="workshop"`

> Référence : ProductionFlowPage (SCHÉMA FLUX PRODUCTION) — `[data-theme="workshop"]`
> ✅ Validé

| Variable | Valeur | Rôle |
|---|---|---|
| `--th-bg` | `#161616` | Fond principal |
| `--th-bg2` | `#1e1e1e` | Fond secondaire (panneaux, inputs) |
| `--th-bg3` | `#1c1c1c` | Fond tertiaire (hover, dropdowns) |
| `--th-border` | `#2a2a2a` | Bordures |
| `--th-text` | `#f0f0f0` | Texte principal |
| `--th-text2` | `#888888` | Texte secondaire |
| `--th-text3` | `#555555` | Labels discrets |
| `--th-input-bg` | `#1e1e1e` | Fond inputs |
| `--th-topbar` | `#0e0e0e` | Fond topbar / header |
| `--th-sidebar` | `#111111` | Fond sidebar |
| `--th-accent` | `#ff9800` | Accent principal (orange) |
| `--th-font` | `'Inter', sans-serif` | Police |
| `--th-font-size` | `13px` | Taille de base |

**Accents secondaires (hardcodés) :**
| Usage | Valeur |
|---|---|
| Bouton action principal (save, add) | `#ff9800` fond, `#000` texte |
| Bouton action hover | `#e65100` |
| Sélection active (pivot, tree) | `#2a1500` fond orange sombre |
| Succès / sessions actives | `#10b981` |
| Erreur | `#ef4444` |

**Pages couvertes (couleurs) :**
- ✅ AdminRefPage (barre d'onglets)
- ✅ ProductsCatalogPage — layout restructuré ✅
- ✅ AdminAteliersPage — layout restructuré ✅
- ✅ AdminFluxPage (référence)
- ✅ AdminShiftsPage — layout restructuré ✅
- ✅ AdminArretTypesPage — layout restructuré ✅
