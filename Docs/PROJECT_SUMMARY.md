# Pousroles — Project Summary

## Stack & Règles
- **Moteur** : Godot 4.4 (GDScript)
- **Réseau** : ENet (LAN) pour MVP
- **Persistance** : JSON local (user://Data/Users, user://Data/Tables, user://Data/Characters)
- **Conventions code** :
  - Récupérer les nœuds **uniquement** via `find_child()` (pas de `%Node`, pas de chemins fixes).
  - **Pas d’opérateur ternaire** `? :` (interdit).
  - Éviter `:=` quand la source est un **Variant** (ex. `find_child`, `Dictionary[...]`) → typer explicitement et caster.
  - Séparation stricte : comptes / réseau / jeu.

## Autoloads (singleton)
- `AccountManager` → res://Scripts/AccountManager.gd
- `TableManager` → res://Scripts/TableManager.gd
- `NetworkManager` → res://Scripts/NetworkManager.gd
- `CharacterManager` → res://Scripts/CharacterManager.gd
- `Global` → res://Scripts/Global.gd

## Scène d’entrée
- **Main scene** : `res://Scenes/Login.tscn`

## Scènes clés
- `Login.tscn` → `LoginScreen.gd`
  - Connexion (email + mot de passe), bouton “Créer un compte”.
  - Navigue vers `CreateAccount.tscn` ou `MultiplayerMenu.tscn`.
- `CreateAccount.tscn` → `CreateAccountScreen.gd`
  - Création compte (email + pwd + pseudo).
- `MultiplayerMenu.tscn` → `MultiplayerMenu.gd`
  - Tables (création/renommage/suppression via popups intégrés).
  - Liste d’amis (ajout/affichage).
  - Tables invitées, Tables rejointes (accepter ou refuser)
  - Accès “TableRoom”
- `TableRoom.tscn` → `TableRoomScreen.gd`
  - Invitation d’amis + attribution des rôles (MJ/Joueur), persistance dans JSON.
- `TableGame.tscn` → `TableGame.gd`
  - **Chat réseau** (MVP actuel). Panneaux utilitaires (Dice/Scene manager) existants.
- `CharacterSheetScreen.tscn` → `CharacterSheetScreen.gd`
  - Fiche ARIA (6 onglets), UI posée.
- `Token.tscn` → `Token.gd`
  - Jeton mobile réseau (placeholder texture = `res://icon.svg`).
- `Scenes/Dev/ContractRunner.tscn` → `ContractCheck.gd`
  - Outil de vérification en dev.

## Flux UX (MVP)
1. **Login** → validation → **MultiplayerMenu**
2. **MultiplayerMenu** → gérer tables & amis → **TableSetup** (optionnel) → **Entrer** → **TableGame**
3. **TableGame** → chat réseau + futurs dés/tokens/map

## Stockage JSON attendu
- `user://Data/Users/user_<Username>.json` → compte (amis, tables créées/rejointes)
- `user://Data/Tables/table_<UUID>.json` → table (invités, rôles, etc.)
- `user://Data/Characters/character_<Name>.json` → fiches ARIA

## État validé (baseline)
- Chat réseau **fonctionnel** dans `TableGame`.
- Popups rename/delete table **fonctionnels** dans `MultiplayerMenu`.
- Texture token corrigée (→ `res://icon.svg`).

## Points de vigilance
- **Éviter les doublons** : à terme, ne plus instancier `AccountManager`/`NetworkManager` localement dans des scènes si les autoloads suffisent.
- Respect strict des conventions (find_child, typage explicite, pas de `? :`, pas de `:=` sur Variant).
