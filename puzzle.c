#include <stdio.h>
#include <stdbool.h>
#include <stdlib.h>
#include <assert.h>
#include <memory.h>
#include <string.h>
#include <stdint.h>


// --- NE PAS MODIFIER A PARTIR D'ICI ---

/* Structure pour le contenu "brut" lu depuis le fichier de carte.
 * La carte est de taille (width x height).
 * La position initiale de Bix est (posx, posy), indices basés sur 0.
 *
 * map_lines est un tableau de `height` chaînes de caractères.
 *
 * Attention, les lignes sont dans l'ordre d'apparition du fichier. Donc
 * l'indice 0 est la ligne tout en haut, qui devrait avoir l'ordonnée
 * `height - 1` dans la carte.
 *
 * Deuxième attention : la longueur des lignes peut être plus courte que
 * `width`. Si elle est plus courte, il faut supposer que des espaces (donc du
 * "sol") se trouve au-delà de la fin de la chaîne de caractères.
 *
 * Troisième attention : rien ne dit que les lignes elles-mêmes soient
 * correctes. Peut-être qu'elles contiennent des caractères invalides.
 */
typedef struct rawmap {
  size_t width;
  size_t height;
  int posx;
  int posy;
  char **map_lines; // an array of strings
} rawmap_t;

/* Crée une carte brute à partir d'un contenu constant.
 * C'est utile pour la carte par défaut, mais surtout pour vos tests unitaires.
 * Utilisez cette fonction dans vos tests unitaires pour obtenir une carte de
 * base que vous pouvez tester.
 * Regardez `make_default_rawmap()` pour savoir comment utiliser cette fonction.
 */
rawmap_t make_rawmap(size_t width, size_t height, int posx, int posy, const char *lines[]) {
  rawmap_t map;
  map.width = width;
  map.height = height;
  map.posx = posx;
  map.posy = posy;

  // Allocate the array of line strings
  map.map_lines = (char **) calloc(map.height, sizeof(char *));

  // Read map.height lines
  for (size_t line_index = 0; line_index < map.height; line_index++) {
    const char *line = lines[line_index];
    size_t len = strlen(line);
    map.map_lines[line_index] = (char *) calloc(len + 1, sizeof(char));
    strncpy(map.map_lines[line_index], line, len);
  }

  return map;
}

/* Fonction interne qui signale une erreur de format majeure dans le fichier.
 * Ne pas appeler cette fonction vous-même. Elle est appelée par `read_map_file`.
 */
void error_bad_map_file(FILE *f, char **lines, size_t line_count, size_t line_no) {
  if (lines != NULL) {
    for (size_t i = 0; i < line_count; i++)
      free(lines[i]);
    free(lines);
  }

  fclose(f);

  printf("Erreur de format dans le fichier à la ligne %lu\n", line_no);
  exit(1);
}

/* Lit le contenu d'un fichier de carte de manière "brute".
 * Si un argument a été donné au programme (avec `./puzzle <fichier-carte.txt>`)
 * alors c'est le fichier <fichier-carte.txt> qui est lu. Sinon, par défaut
 * c'est le fichier `default-map.txt` qui est lu (très utile si vous devez
 * déboguer votre programme, car c'est ce fichier qui sera alors lu).
 *
 * Le résultat est une `rawmap_t`. Voir sa documentation pour le contenu. Il
 * doit être libéré avec `free_rawmap`.
 *
 * En cas d'erreur de lecture majeure (qui ne permettrait pas de construire une
 * rawmap_t valable), un message est affiché à l'écran et le programme est
 * immédiatement arrêté. Le code qui appelle read_map_file sait donc que le
 * rawmap_t renvoyé est valable.
 */
rawmap_t read_map_file(const char *file_name) {
  // Open the file
  FILE *map_file = fopen(file_name, "r");
  if (map_file == NULL) {
    printf("On dirait que le fichier '%s' n'existe pas.\n", file_name);
    exit(1);
  }

  rawmap_t map;

  // Read width, height, posx and posy
  if (fscanf(map_file, "%lu %lu", &map.width, &map.height) < 2)
    error_bad_map_file(map_file, NULL, 0, 1);
  if (fscanf(map_file, "%d %d", &map.posx, &map.posy) < 2)
    error_bad_map_file(map_file, NULL, 0, 2);

  size_t line_buf_len = map.width + 2; // 1 for \n and 1 for \0
  char line[line_buf_len];
  memset(line, 0, line_buf_len); // just in case any of the fgets fails

  // Throw away the rest of the line after the second fscanf
  if (fgets(line, line_buf_len, map_file) == NULL)
    error_bad_map_file(map_file, NULL, 0, 2);

  // Allocate the array of line strings
  map.map_lines = (char **) calloc(map.height, sizeof(char *));

  // Read map.height lines
  for (size_t line_index = 0; line_index < map.height; line_index++) {
    if (fgets(line, line_buf_len, map_file) == NULL)
      error_bad_map_file(map_file, map.map_lines, line_index, 3 + line_index);
    size_t len = strlen(line);
    if (len == 0 || line[len - 1] != '\n')
      error_bad_map_file(map_file, map.map_lines, line_index, 3 + line_index);
    map.map_lines[line_index] = (char *) calloc(len + 1, sizeof(char));
    strncpy(map.map_lines[line_index], line, len);
  }

  fclose(map_file);

  return map;
}

void free_rawmap(rawmap_t *map) {
  for (size_t i = 0; i < map->height; i++)
    free(map->map_lines[i]);
  free(map->map_lines);
}

// --- FIN DE LA ZONE A NE PAS MODIFIER - ECRIVEZ VOTRE PROGRAMME CI-DESSOUS ---



//----------------------------------------------------------------------------//



/* Crée la carte brute par défaut, si on ne donne pas de nom de fichier au
 * programme.
 *
 * La carte doit être libérée avec free_rawmap.
 */
rawmap_t make_default_rawmap(void) {
  /* Carte de base pour mes tests. */
  const char *lines[] = {
    "xxxxxxxxxx",
    "x     +! x",
    "x  oo    x",
    "x        x",
    "x    *   x",
    "x  x * + x",
    "x  x     x",
    "x        x",
    "x        x",
    "xxxxxxxxxx",
  };
  return make_rawmap(10, 10, 1, 1, lines);
}



/// Représentation interne de la carte dans une matrice d'uint8_t.

typedef struct {
    uint8_t **cells;
    size_t width;
    size_t height;
    int bix_x;
    int bix_y;
    int goal_x; 
    int goal_y;
    // Carte d'origine conservée pour réinitialiser l'état avec 'r' ou lors d'une chute.
    const rawmap_t *origin;

} game_t;

// Types de cellules utilisés dans la grille.

typedef enum {
    CELL_SOL,
    CELL_BLOC_FIXE,
    CELL_BLOC_DEP,
    CELL_BLOC_UNE_FOIS,
    CELL_TROU,
    CELL_GOAL,
} cell_type_t;

/*
Initialise l'état du jeu à partir d'une carte brute (rawmap_t).
Gère la conversion des caractères en types de cellules.
Alloue de la mémoire pour l'état du jeu.
ATTENTION! doit être libéré avec free_game.
*/

game_t create_game(const rawmap_t *rawmap) {
  game_t jeu;

  jeu.width = rawmap->width;
  jeu.height = rawmap->height;
  jeu.bix_x = rawmap->posx;
  jeu.bix_y = (int)jeu.height - 1 - rawmap->posy;
  jeu.origin = rawmap;
  jeu.goal_x = -1; // Valeur par défaut si aucun goal n'est trouvé
  jeu.goal_y = -1;


  //création de l'espace memoire pour la map
  jeu.cells = (uint8_t **)malloc(jeu.height * sizeof(uint8_t *));
  if (jeu.cells == NULL) {
    printf("erreur de memoire pendant le traitement de la grille\n");
    exit(1);
  }
  for (size_t y = 0; y < jeu.height; y++) {
    jeu.cells[y] = (uint8_t *)malloc(jeu.width * sizeof(uint8_t));
    if (jeu.cells[y] == NULL) {
      printf("erreur de memoire pendant le traitement de la ligne %zu \n", y);
      exit(1);
    }

    size_t length_line = strlen(rawmap->map_lines[y]);
    
    for (size_t x = 0; x < rawmap->width; x++) {

      // Si la ligne est trop courte, le reste est traité comme du sol.
      if (x >= length_line) {
        jeu.cells[y][x] = CELL_SOL;
        continue;
      }

      char c = rawmap->map_lines[y][x];
      switch (c) {
        case 'X':
        case 'x':
          jeu.cells[y][x] = CELL_BLOC_FIXE;
          break;
        case '*':
          jeu.cells[y][x] = CELL_BLOC_DEP;
          break;
        case '+':
          jeu.cells[y][x] = CELL_BLOC_UNE_FOIS;
          break;
        case 'o':
          jeu.cells[y][x] = CELL_TROU;
          break;
        case '!':
          jeu.cells[y][x] = CELL_GOAL;
          jeu.goal_x = (int)x;
          jeu.goal_y = (int)y; 

          break;
        case ' ':
        default:
          jeu.cells[y][x] = CELL_SOL;
          break;
      }
    }
  }
  // Bix est affiché séparément au rendu.
  return jeu;
}

// Libère la mémoire allouée par la grille du jeu.

void free_game(game_t *jeu) {
  if (jeu->cells != NULL) {
    // de la meme manière qu'on s'est reservé la memoire, on la free 
    for (size_t y = 0; y < jeu->height; y++) {
      free(jeu->cells[y]);
    }
    free(jeu->cells);
    jeu->cells = NULL;
  }
}

// Déclaration anticipée de print_game pour reset()
void print_game(const game_t *jeu); 


// Réinitialise le jeu à son état de départ en utilisant la structure rawmap_t conservée.
 
void reset(game_t *jeu) {
  const rawmap_t *backup = jeu->origin; // Je garde la carte d'origine avant reset.
  free_game(jeu); // Libération de l'état courant.
  *jeu = create_game(backup); // Reconstruction de l'état de départ.
}


// Vérifie si les coordonnées (x, y) se trouvent bien dans les limites de la carte.
static bool en_jeu(int x, int y, const game_t *jeu) {
    return (x >= 0 && x < (int)jeu->width && y >= 0 && y < (int)jeu->height);
}

/**
Tente de pousser un bloc de type `bloc` sur la case de destination (px, py).
Retourne 'true' si le bloc a bien été déplacé, 'false' sinon.
Note : Le reset de la carte (si chute du bloc/Bix) est géré dans appliquer_commande.
 */
static bool push_bloc(cell_type_t bloc, int py, int px, game_t *jeu) {

  if (!en_jeu(px, py, jeu)) return false;

  if (bloc == CELL_BLOC_UNE_FOIS){
    if (jeu->cells[py][px] == CELL_GOAL){
      // Le bloc fixe deviens BLOC_FIXE sur le goal
      // l'utilisateur a la charge du reset
      jeu->cells[py][px] = CELL_BLOC_FIXE;
      return true;
    }
    else if (jeu->cells[py][px] == CELL_TROU){
      // Le trou absorbe le bloc.
      // donc on return un true et le jeu fera avancer bix sur l'ancien bloc
      return true;
    }
    else if (jeu->cells[py][px] == CELL_SOL){
      jeu->cells[py][px] = CELL_BLOC_FIXE;
      return true;
    }
    else {
      return false;
    }
  }
  else if (bloc == CELL_BLOC_DEP){
    if (jeu->cells[py][px] == CELL_TROU){
      return true;
    }
    else if (jeu->cells[py][px] == CELL_SOL || jeu->cells[py][px] == CELL_GOAL){
      // on pourrait cache le goal mais pas grave car on connais les coordonées du goal
      jeu->cells[py][px] = CELL_BLOC_DEP;
      return true;
    }
    else{
      return false;
    }
  }
  else {
    return false;
  }
}

/*
Applique une commande de déplacement de Bix.
Renseigne la variable pointée par `doit_reset` à 'true' si le déplacement 
entraîne une chute dans un trou qui exige par la suite la réinitialisation de la carte.
*/

void appliquer_commande(game_t *jeu, char cmd, bool *doit_reset) {
    
  int dx = 0, dy = 0;

  // Conversion de la commande en déplacement.
  switch (cmd) {
      case 'e': dy = -1; break;
      case 'd': dy = 1;  break;
      case 's': dx = -1; break;
      case 'f': dx = 1;  break;
      default: return;
  }

  // Case visée par le déplacement.
  int cx = jeu->bix_x + dx;
  int cy = jeu->bix_y + dy;

  // Vérification des bornes.
  if (en_jeu(cx, cy, jeu)){

    // Lecture du type de cellule visée.
    cell_type_t cible = jeu->cells[cy][cx];

    if (cible == CELL_SOL || cible == CELL_GOAL || cible == CELL_TROU) {
      
      if (cible == CELL_SOL || cible == CELL_GOAL){
        // Bix peut avancer.
        jeu->bix_x = cx;
        jeu->bix_y = cy;

      }
      if (cible == CELL_TROU){
        // on ne fais pas le mouvement, mais reset direct
        *doit_reset = true;
      }
    } 
    // mouvement avec bloc
    else if (cible == CELL_BLOC_DEP || cible == CELL_BLOC_UNE_FOIS) {
      
      // Case de destination du bloc.
      int px = cx + dx;
      int py = cy + dy;


      if (push_bloc(cible, py, px, jeu)){ // push_bloc gère la destination du bloc
        jeu->cells[jeu->bix_y][jeu->bix_x] = CELL_SOL;
        jeu->bix_x = cx;
        jeu->bix_y = cy;
        jeu->cells[cy][cx] = CELL_SOL;
      }   
    }
    // Un bloc fixe bloque le déplacement.
  }
}

/*
Affiche l'état visuel courant de la carte dans le terminal.
*/
void print_game(const game_t *jeu) {

  // Affichage complet de la carte à chaque tour.
  for (size_t y = 0; y < jeu->height; y++){
    for (size_t x = 0; x < jeu->width; x++){
      // Bix passe par-dessus la case courante.
      if(x == (size_t)jeu->bix_x && y == (size_t)jeu->bix_y){
        printf("@");
      }
      else{
        switch (jeu->cells[y][x]) {
          case CELL_BLOC_FIXE: 
            printf("x");
            break;
          case CELL_BLOC_DEP: 
            printf("*");
            break;
          case CELL_BLOC_UNE_FOIS: 
            printf("+");
            break;
          case CELL_TROU: 
            printf("o");
            break;
          case CELL_GOAL: 
            printf("!");
            break;
          case CELL_SOL:
          default: 
            printf(" ");
            break;
        }
      }
    }
    printf("\n");
  }
  printf("\n");
}

void test_code(void) {

  // repère bien les cases dans la carte et hors de la carte.
  rawmap_t r1 = make_rawmap(2, 2, 1, 0, (const char *[]){"  ", " @"});
  game_t g1 = create_game(&r1);
  assert(en_jeu(0, 0, &g1) == true); // coin bas-gauche -> dedans
  assert(en_jeu(-1, 0, &g1) == false); // a gauche -> dehors
  assert(en_jeu(2, 0, &g1) == false); // a droite hors largeur -> dehors

  // Tests push_bloc()
  rawmap_t r2 = make_rawmap(3, 3, 1, 0, (const char *[]){"   ", "   ", " @ "});
  game_t g2 = create_game(&r2);
  int dst_y = 1, dst_x = 2;

  // poser un bloc de type dep sur du sol -> devient CELL_BLOC_DEP
  g2.cells[dst_y][dst_x] = CELL_SOL;
  assert(push_bloc(CELL_BLOC_DEP, dst_y, dst_x, &g2) == 1);
  assert(g2.cells[dst_y][dst_x] == CELL_BLOC_DEP);

  // poser un bloc de type dep sur un trou -> absorbé (retourne 1)
  g2.cells[dst_y][dst_x] = CELL_TROU;
  assert(push_bloc(CELL_BLOC_DEP, dst_y, dst_x, &g2) == 1);

  // poser un bloc de type une fois sur sol devient bloc fixe
  g2.cells[dst_y][dst_x] = CELL_SOL;
  assert(push_bloc(CELL_BLOC_UNE_FOIS, dst_y, dst_x, &g2) == 1);
  assert(g2.cells[dst_y][dst_x] == CELL_BLOC_FIXE);

  // bloc dep posé sur goal cache le goal
  g2.cells[dst_y][dst_x] = CELL_GOAL;
  assert(push_bloc(CELL_BLOC_DEP, dst_y, dst_x, &g2) == 1);
  assert(g2.cells[dst_y][dst_x] == CELL_BLOC_DEP);

  // bloc une fois sur goal devient bloc fixe
  g2.cells[dst_y][dst_x] = CELL_GOAL;
  assert(push_bloc(CELL_BLOC_UNE_FOIS, dst_y, dst_x, &g2) == true);
  assert(g2.cells[dst_y][dst_x] == CELL_BLOC_FIXE);

  // Test reset()
  rawmap_t r3 = make_rawmap(3, 3, 1, 0, (const char *[]){"   ", "   ", " @ "});
  game_t g3 = create_game(&r3);
  g3.cells[1][1] = CELL_BLOC_DEP; // modification
  reset(&g3);
  assert(g3.cells[1][1] == CELL_SOL);

  // create_game doit trouver le goal s'il y en a un
  rawmap_t r4 = make_rawmap(2, 2, 0, 0, (const char *[]){"! ", " @"});
  game_t g4 = create_game(&r4);
  assert(g4.goal_x >= 0 && g4.goal_x < (int)g4.width);
  assert(g4.goal_y >= 0 && g4.goal_y < (int)g4.height);
  assert(g4.bix_y == 1);

  // Test appliquer_commande()
  rawmap_t r5 = make_rawmap(3, 3, 1, 0, (const char *[]){" ! ", " * ", "   "});
  game_t g5 = create_game(&r5);
  bool doit_reset = false;
  
  appliquer_commande(&g5, 'n', &doit_reset);
  assert(g5.bix_y == 2);
  
  appliquer_commande(&g5, 'f', &doit_reset);
  assert(g5.bix_x == 2 && g5.bix_y == 2);
  
  appliquer_commande(&g5, 's', &doit_reset);
  assert(g5.bix_x == 1 && g5.bix_y == 2);
  
  appliquer_commande(&g5, 'd', &doit_reset);
  assert(g5.bix_y == 2);

  appliquer_commande(&g5, 'e', &doit_reset);
  assert(g5.bix_y == 1); 
  assert(g5.cells[0][1] == CELL_BLOC_DEP);
  
  appliquer_commande(&g5, 'e', &doit_reset);
  assert(g5.bix_y == 1);

  // Test trou + goal direct
  rawmap_t r6 = make_rawmap(3, 3, 1, 1, (const char *[]){" ! ", "   ", " o "});
  game_t g6 = create_game(&r6);
  
  appliquer_commande(&g6, 'd', &doit_reset);
  assert(doit_reset == true);
  
  reset(&g6);
  g6.bix_y = 1; doit_reset = false; // mouvement artificiel de bix
  
  appliquer_commande(&g6, 'e', &doit_reset);
  assert(g6.bix_y == 0 && g6.bix_x == 1); 

  free_game(&g1); 
  free_rawmap(&r1);

  free_game(&g2); 
  free_rawmap(&r2);

  free_game(&g3); 
  free_rawmap(&r3);

  free_game(&g4); 
  free_rawmap(&r4);

  free_game(&g5); 
  free_rawmap(&r5);

  free_game(&g6); 
  free_rawmap(&r6);

}

int main(int argc, char **argv) {
  test_code();

  rawmap_t rawmap = argc < 2 ? make_default_rawmap() : read_map_file(argv[1]);

  game_t jeu = create_game(&rawmap); 
  
  char input[100]; 

  bool game_on = true; 
  bool victoire = false; 

  print_game(&jeu); // Premier affichage pour vérifier la carte.

  // si bix commence sur le goal on gagne direct
  if (jeu.bix_x == jeu.goal_x && jeu.bix_y == jeu.goal_y) {
    victoire = true;
    game_on = false;
  }
  while (game_on) {

    if (fgets(input, sizeof(input), stdin) == NULL) {
        break; // Plus d'entrée, donc arrêt.
    }

    for (int i = 0; input[i] != '\0' && input[i] != '\n'; i++) {
      
      char cmd = input[i];

      if(cmd == 'x'){
        print_game(&jeu); // Dernier affichage avant abandon.
        game_on = false; // Fin de la partie.
        break; // Fin du traitement de la ligne.
      }
      else if (cmd == 'r'){
        reset(&jeu);
        print_game(&jeu);
      }

      else if (cmd == 'e' || cmd == 'd' || cmd == 's' || cmd == 'f') {
        
        bool doit_reset = false;
                
        // Application de la commande de déplacement.
        appliquer_commande(&jeu, cmd, &doit_reset);

        // Si je tombe dans un trou, je reset.
        if (doit_reset) {
          reset(&jeu);
        }

        // Affichage de l'état courant.
        print_game(&jeu);

        if (jeu.bix_x == jeu.goal_x && jeu.bix_y == jeu.goal_y) {
          // Victoire détectée après l'affichage.
          victoire = true;
          game_on = false;
          break;
        }

      }
    }
  }
  // Message de fin.
  if (victoire) {
    printf("Bravo ! Tu as atteint le goal !\n");
  } else {
    printf("Abandon :-(\n");
  }
  // Nettoyage de la mémoire.
  free_game (&jeu);
  free_rawmap(&rawmap);
  return 0;
}