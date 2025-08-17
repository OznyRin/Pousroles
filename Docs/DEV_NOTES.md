# DEV NOTES — Changelog & TODO

## Changelog
- 2025-08-17
  - Init dépôt Git + Git LFS (images/sons).
  - .gitignore ajouté (Godot 4 + OS + Temp + build/).


## TODO (atomique, sans casser l’existant)
- Style: passer progressivement toutes les récupérations de nœuds en **typage explicite** (pas de `:=` sur Variant).
- Unifier `AccountManager`/`NetworkManager` : **autoloads only** (retirer instances locales si encore présentes).
- TableGame:
  - Dés multi (d6/d20) synchronisés (RPC).
  - Tokens multi (1 par joueur), synchro de position & ownership.

 
- CharacterSheet ARIA:
  - Compléter champs & persistance JSON via `CharacterManager`.
- Tests LAN à chaque ajout réseau (host/client).
- Docs: tenir à jour ce fichier et `PROJECT_SUMMARY.md` à chaque commit.

## Notes ouvertes
- Ports / ENet : port local par défaut 24545 (à documenter si modifié).
- UX TableSetup : confirmer l’écriture immédiate des invités/rôles dans JSON table + user.
