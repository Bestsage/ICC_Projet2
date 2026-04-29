# Bix Puzzle — ICC Projet 2

Jeu de puzzle en **C** dans le terminal : guide **Bix** (`@`) jusqu'au goal (`!`) en poussant des blocs sur la grille.

```
xxxxxxxxxx
x     +! x
x  oo    x
x        x
x    *   x
x  x * + x
x  x     x
x    @   x
x        x
xxxxxxxxxx
```

---

## Table des matières

1. [Compilation & lancement](#compilation--lancement)
2. [Contrôles](#contrôles)
3. [Légende de la grille](#légende-de-la-grille)
4. [Règles du jeu](#règles-du-jeu)
5. [Format des maps](#format-des-maps)
6. [Tests automatiques](#tests-automatiques)
7. [Structure du code](#structure-du-code)
8. [Arborescence](#arborescence)

---

## Compilation & lancement

```bash
# Compiler
gcc -std=c11 -Wall -Wextra -g -fsanitize=address,undefined puzzle.c -o puzzle

# Lancer avec la map par défaut
./puzzle

# Lancer avec une map personnalisée
./puzzle examples/level1.txt
```

---

## Contrôles

| Touche | Action     |
| :----: | ---------- |
| `e`    | Monter     |
| `d`    | Descendre  |
| `s`    | Gauche     |
| `f`    | Droite     |
| `r`    | Reset      |
| `x`    | Quitter    |

> Plusieurs touches peuvent être enchaînées sur la même ligne de saisie (ex : `eeff`).

---

## Légende de la grille

| Symbole | Type                | Description                                         |
| :-----: | ------------------- | --------------------------------------------------- |
| `@`     | Bix                 | Le personnage que vous contrôlez                    |
| `!`     | Goal                | Objectif — victoire dès que Bix y entre             |
| ` `     | Sol                 | Case libre, Bix peut marcher dessus                 |
| `x`/`X` | Bloc fixe           | Immuable, ne peut pas être poussé                   |
| `*`     | Bloc mobile         | Peut être poussé indéfiniment                       |
| `+`     | Bloc à usage unique | Se fige après une seule poussée réussie             |
| `o`     | Trou                | Bix tombe dedans → reset automatique                |

---

## Règles du jeu

- **Déplacement** : Bix peut se déplacer sur le sol, le goal et les trous.
- **Trou** : si Bix marche dans un trou, la partie repart depuis le début.
- **Victoire** : Bix atteint la case `!`.
- **Poussée** : Bix pousse `*` ou `+` si la case derrière est libre (sol, goal ou trou).
- **Bloc `+`** : après une poussée réussie sur du sol, il devient un bloc fixe.
- **Bloc dans le trou** : le bloc disparaît et comble le trou.

---

## Format des maps

```
W H
posx posy
<ligne 1>
...
<ligne H>
```

| Champ       | Description                                           |
| ----------- | ----------------------------------------------------- |
| `W H`       | Largeur et hauteur de la grille                       |
| `posx posy` | Position initiale de Bix (indices 0-based)            |
| `<lignes>`  | Contenu de la grille — une ligne trop courte = du sol |

---

## Tests automatiques

Le script `run_tests.sh` compile le projet et vérifie automatiquement la sortie du programme contre des résultats de référence.

### Lancement

```bash
# Compiler puis lancer tous les tests
bash run_tests.sh

# Lancer les tests sans recompiler (binaire déjà présent)
bash run_tests.sh --no-compile
```

### Structure des tests

Chaque test se trouve dans `tests/<nom>/` et contient deux fichiers :

| Fichier        | Contenu                                                     |
| -------------- | ----------------------------------------------------------- |
| `input.txt`    | Séquence de commandes envoyées sur stdin (ex : `esdfx`)     |
| `expected.txt` | Sortie de référence attendue après normalisation             |

Les cartes utilisées par les tests sont lues dans `examples/` (ou `maps/` si absent).

Tests disponibles :

| Nom              | Carte                         | Description                              |
| ---------------- | ----------------------------- | ---------------------------------------- |
| `incomplete-map` | `examples/incomplete-map.txt` | Carte avec des lignes trop courtes       |
| `level1`         | `examples/level1.txt`         | Niveau 1 — déplacement simple            |
| `level2`         | `examples/level2.txt`         | Niveau 2 — poussée de blocs              |

### Fonctionnement interne

1. **Compilation** — `gcc` avec `-Wall -Wextra -Werror` et les sanitizers AddressSanitizer + UndefinedBehaviorSanitizer.
2. **Exécution** — le programme est lancé avec un timeout de 10 secondes ; `stderr` est capturé pour détecter les erreurs sanitizer.
3. **Normalisation** — les séquences ANSI (couleurs, déplacement curseur) et les lignes vides sont supprimées avant comparaison.
4. **Comparaison état par état** — la sortie est découpée en blocs de `H` lignes (hauteur de la carte) ; les écarts sont affichés côte à côte avec la timeline des commandes.
5. **Résumé final** — nombre de tests passés / échoués ; le script retourne le code 1 si au moins un test échoue.

---

## Structure du code

Tout le code se trouve dans `puzzle.c`, divisé en deux zones.

### Zone fournie *(à ne pas modifier)*

| Élément         | Rôle                                              |
| --------------- | ------------------------------------------------- |
| `rawmap_t`      | Structure brute lue depuis un fichier de carte    |
| `make_rawmap`   | Crée une `rawmap_t` depuis un tableau de chaînes  |
| `read_map_file` | Lit et valide un fichier de carte                 |
| `free_rawmap`   | Libère la mémoire d'une `rawmap_t`                |

### Zone implémentée

| Élément               | Rôle                                                       |
| --------------------- | ---------------------------------------------------------- |
| `cell_type_t`         | Enum des types de cellules (sol, blocs, trou, goal…)       |
| `game_t`              | État complet du jeu (grille, position Bix, goal, origine)  |
| `create_game`         | Initialise le jeu depuis une `rawmap_t`                    |
| `free_game`           | Libère la mémoire de la grille de jeu                      |
| `reset`               | Réinitialise la partie depuis la carte d'origine           |
| `push_bloc`           | Applique la logique de poussée d'un bloc                   |
| `appliquer_commande`  | Traite une touche et met à jour l'état du jeu              |
| `print_game`          | Affiche la grille dans le terminal                         |
| `main`                | Boucle principale : lecture des entrées, affichage, fin    |

---

## Arborescence

```
.
├── puzzle.c              # Code source principal
├── puzzle_original.c     # Version fournie (référence)
├── run_tests.sh          # Script de tests automatiques
├── bix-puzzle.pdf        # Énoncé du projet
├── examples/             # Maps de test et fichiers d'exemple
│   ├── level1.txt
│   ├── level2.txt
│   ├── level3.txt
│   └── ...
└── README.md
```
