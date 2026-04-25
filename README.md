<div align="center">

# Bix Puzzle — ICC-C 2025-2026

<p>
  <img src="https://img.shields.io/badge/EPFL-ICC--C-red?style=for-the-badge" alt="EPFL ICC-C">
  <img src="https://img.shields.io/badge/Langage-C-00599C?style=for-the-badge&logo=c&logoColor=white" alt="Langage C">
  <img src="https://img.shields.io/badge/Statut-Mini--projet-blueviolet?style=for-the-badge" alt="Statut">
</p>

_Un mini-jeu de puzzle en console où Bix pousse des blocs, évite les trous, et vise le goal._

</div>

---

## Aperçu rapide

> **Objectif :** atteindre la case `!` (goal) avec Bix (`@`) en manipulant intelligemment les blocs.

### Légende de la carte

| Symbole | Signification |
|:--:|---|
| ` ` (espace) | Sol |
| `x` | Bloc fixe |
| `*` | Bloc déplaçable |
| `+` | Bloc déplaçable une seule fois |
| `o` | Trou |
| `!` | Goal |
| `@` | Bix (affichage en jeu) |

### Commandes clavier

| Touche | Action |
|:--:|---|
| `e` | Nord ⬆ |
| `d` | Sud ⬇ |
| `s` | Ouest ⬅ |
| `f` | Est  |
| `r` | Reset de la partie |
| `x` | Abandon / quitter |

---

## Règles du jeu

- Bix se déplace sur les **cases libres** (sol, trous, goal).
- Si une case voisine contient un bloc déplaçable (`*` ou `+`) et que la case derrière est libre, Bix pousse le bloc.
- Un bloc poussé dans un trou disparaît.
- Un bloc `+` devient fixe après un déplacement (s’il ne tombe pas dans un trou).
- Si Bix tombe dans un trou, la carte est réinitialisée.
- Si Bix atteint le goal : **victoire** 

---

##  Format des fichiers de carte

```txt
W H
posx posy
<ligne 1>
<ligne 2>
...
<ligne H>
```

- `W H` : dimensions de la grille.
- `posx posy` : position initiale de Bix.
- Les lignes de carte ont une longueur max `W` (les caractères manquants sont traités comme des espaces).
- La première ligne correspond au haut de la carte (`y = H - 1`).

---

##  Compilation & exécution

### Compiler

```bash
gcc -std=c11 -Wall -Wextra -g -fsanitize=address,undefined puzzle.c -o puzzle
```

### Lancer

```bash
# carte par défaut
./puzzle

# carte depuis fichier
./puzzle examples/level1.txt
```

---

##  Structure du repo

```txt
.
├── puzzle.c
├── bix-puzzle.pdf
├── examples/
│   ├── level1.txt
│   ├── level2.txt
│   ├── level3.txt
│   ├── map1.txt
│   └── ...
└── examples.zip
```

---

##  Conseils qualité (ICC)

- Compiler fréquemment avec `-Wall -Wextra`.
- Tester avec sanitizers (`address`, `undefined`).
- Garder un code lisible, indenté, factorisé.
- Préparer des tests unitaires via des cartes simples et ciblées.

---

##  Cadre académique

> Projet **individuel** (section GM, avril 2026).  
> Respecter strictement les consignes de rendu, d’anonymat et d’intégrité académique.

---

<div align="center">

###  _Push, Think, Solve._

**Bix compte sur toi.**

</div>
