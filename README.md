# Bix Puzzle — ICC Projet 2

Jeu de puzzle en terminal en C : on déplace **Bix** (`@`) sur une grille pour atteindre le **goal** (`!`) en poussant des blocs.

## Vue d’ensemble du code

Le projet est concentré dans `puzzle.c` :

- **Zone fournie (à ne pas modifier)**  
  Lecture/validation d’une carte (`rawmap_t`), création de carte brute (`make_rawmap`), lecture fichier (`read_map_file`), libération (`free_rawmap`).
- **Zone implémentée**  
  - Structure de jeu `game_t` (grille, dimensions, position de Bix, goal, carte d’origine).
  - Enum `cell_type_t` pour typer les cellules (sol, bloc fixe, bloc mobile, trou, goal…).
  - Initialisation (`create_game`) à partir de `rawmap_t`.
  - Boucle de jeu dans `main` avec commandes clavier.
  - Logique de déplacement/poussée (`appliquer_commande`, `push_bloc`).
  - Réinitialisation (`reset`) et affichage coloré ANSI (`print_game`).

## Règles actuellement implémentées

### Légende

| Symbole | Rôle |
|---|---|
| ` ` | Sol |
| `x` / `X` | Bloc fixe |
| `*` | Bloc déplaçable |
| `+` | Bloc déplaçable une fois (devient fixe après poussée réussie) |
| `o` | Trou |
| `!` | Goal |
| `@` | Bix (affichage) |

### Contrôles

| Touche | Action |
|---|---|
| `e` | Monter |
| `d` | Descendre |
| `s` | Gauche |
| `f` | Droite |
| `r` | Reset de la map |
| `x` | Quitter |

### Comportement

- Bix se déplace sur sol, trou, goal.
- Si Bix entre dans un trou : reset.
- Si Bix atteint le goal : victoire.
- Bix peut pousser `*` et `+` si la case derrière est compatible.
- Un `+` poussé sur sol devient bloc fixe.
- Un bloc poussé dans un trou disparaît.

## Format des maps

```txt
W H
posx posy
<ligne 1>
...
<ligne H>
```

- `W H` : largeur/hauteur.
- `posx posy` : position initiale de Bix.
- Une ligne plus courte que `W` est complétée comme du sol.

## Compilation et exécution

```bash
gcc -std=c11 -Wall -Wextra -g -fsanitize=address,undefined puzzle.c -o puzzle
./puzzle
# ou
./puzzle examples/level1.txt
```

## Arborescence

```txt
.
├── puzzle.c
├── puzzle_original.c
├── examples/
├── bix-puzzle.pdf
└── README.md
```

## Améliorations proposées

1. **Corriger l’indexation de grille dans les déplacements**
   - Vérifier systématiquement l’ordre `[y][x]` pour éviter les accès inversés.
2. **Sécuriser davantage les bornes**
   - Vérifier que la case “derrière le bloc poussé” reste dans la carte avant lecture/écriture.
3. **Validation stricte des maps**
   - Rejeter explicitement les caractères invalides et les cartes sans/avec plusieurs goals.
4. **Améliorer l’UX terminal**
   - Messages de victoire/défaite plus lisibles, aide des commandes affichée en permanence.
5. **Ajouter des tests automatisés**
   - Cas de déplacement simple, poussée, chute dans trou, reset, victoire, bords de carte.
6. **Séparer le code**
   - Découper en modules (`map.c`, `game.c`, `render.c`) pour faciliter maintenance et tests.
7. **Uniformiser le style**
   - Harmoniser noms, orthographe des messages, commentaires, conventions de formatage.
