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
rawmap_t make_default_rawmap() {
  /* Vous pouvez modifier cette carte par défaut si vous voulez.
   * N'hésitez pas à imiter cette fonction pour créer facilement des cartes
   * dans vos tests unitaires !
   */
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



/// on va utiliser une matrice d'uint8_t pour représenter la carte dans notre 
// programme, avec les valeurs suivantes :
/// 0 : sol
/// 1 : bloc fixe
/// 2 : bloc déplaçable
/// 3 : bloc déplaçable une seule fois
/// 4 : position de Bix 

typedef struct {
    uint8_t **cells; // matrice
    size_t width; // largeur
    size_t height; //hauteur
    int bix_x; // position x de bix
    int bix_y; // position y de bix
    int goal_x; 
    int goal_y; // le goal ne bouge jamais ! et il est unique 
    // on le stoque juste et on regarde si on dois le montrer ou gagne
    const rawmap_t *origin; // On stocke le "plan de base" ici

} game_t;

// on utilise un  type enum pour représenter les différents types de cellules possibles.
// ça evite de se rappeler que 0 c'est le sol, 1 c'est un bloc, etc ... 

typedef enum {
    CELL_SOL = 0,
    CELL_BLOC_FIXE = 1,
    CELL_BLOC_DEP = 2,
    CELL_BLOC_UNE_FOIS = 3,
    CELL_TROU = 4,
    CELL_GOAL = 5,
} cell_type_t;

// fonction pour créer l'espace de jeu

game_t create_game(const rawmap_t *rawmap){
  
  game_t jeu;

  // on prend les mesures du terrain

  jeu.width = rawmap->width;
  jeu.height = rawmap->height;
  jeu.bix_x = rawmap->posx;
  jeu.bix_y = jeu.height - 1 - rawmap->posy;
  jeu.origin = rawmap;
  // on se garde uin espace en memoire

  jeu.cells = (uint8_t **)malloc(jeu.height * sizeof(uint8_t *));
  if (jeu.cells == NULL){
    printf("erreur de memoire pendant le traitement de la grille");
    exit(1);
  }


  // création de la map
  for (size_t y = 0; y < jeu.height; y++){

    // on se garde de la memoire

    jeu.cells[y] = (uint8_t *)malloc(jeu.width * sizeof(uint8_t));
    if (jeu.cells[y] == NULL) {
      printf("erreur de memoire pendant le traitement de la ligne %zu \n", y);
      exit(1);
    }

    // on veut svoir combien de caractüres sont vraiment dans la str

    size_t length_line = strlen(rawmap->map_lines[y]);
    
    for (size_t x = 0; x < rawmap->width; x++){

      // si la ligne est pas assez longue, on ajoute du sol pour eviter les problèmes de map non finie

      if (x >= length_line) {

        jeu.cells[y][x] = CELL_SOL;
        continue;

      }

      // on récupüre le caractère  
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
          jeu.goal_x = x;
          jeu.goal_y = y;
          break;
        case ' ':
        default: // c'est un peu redondant avec la verification de la longuer de la ligne mais il prend plus de cas spéciaux
          jeu.cells[y][x] = CELL_SOL;
          break;
      }
    }
  }
  // faut poser la cell de bix sur la map encore 
  return jeu;
}

void free_game(game_t *jeu) { // libérer les allocations du jeu
  if (jeu->cells != NULL) {

    // on libère les lignes d'abord

    for (size_t y = 0; y < jeu->height; y++) {
      free(jeu->cells[y]);
    }
  
    // puis les pointeurs 


    free(jeu->cells);
    jeu->cells = NULL;
  }
}

void print_game(const game_t *jeu); // On annonce que la fonction existe
//-------------------------------------car reset est ecris avant elle

void reset(game_t *jeu) {
  const rawmap_t *backup = jeu->origin; // on choppe la map de base 
  free_game(jeu); //on libère l'espace de l'ancienne tentative 
  *jeu = create_game(backup); // on refais un espace de jeu
}

// juste pour verifier si une position appartient à l'espace de jeu
static bool en_jeu(int x, int y, const game_t *jeu) {
    // On renvoie directement le résultat de la condition logique (ET)
    return (x >= 0 && x < (int)jeu->width && y >= 0 && y < (int)jeu->height);
}

bool push_bloc(cell_type_t bloc, int py, int px,bool *doit_reset, game_t *jeu){

  if (!en_jeu(px, py, jeu)) return(0); // on verifie si on pousse dans les limites de la map

  if (bloc == CELL_BLOC_UNE_FOIS){
    if (jeu->cells[py][px] == CELL_GOAL){
      // gameover, on a fixé un bloc sur le goal
      //printf("mec t'est null recommence \n");
      //printf("tu a rendu le goal inaccessible\n"); texte commenté pour passer les tests auto 
      *doit_reset = true;
      return (1);
    }
    else if (jeu->cells[py][px] == CELL_TROU){
      // le bloc tombe dans le trou donc on ne fais rien
      return(1);
    }
    else if (jeu->cells[py][px] == CELL_SOL){
      jeu->cells[py][px] = CELL_BLOC_FIXE;
      return(1);
    }
    else {
      return(0);
      // si le bloc en px py n'est pas un bloc libre, on a rien fait, donc return 0
    }
  }
  else if (bloc == CELL_BLOC_DEP){
    if (jeu->cells[py][px] == CELL_TROU){
      // le bloc tombe dans le trou donc on ne fais rien
      return(1);
    }
    else if (jeu->cells[py][px] == CELL_SOL || jeu->cells[py][px] == CELL_GOAL){
      // on peut cacher le goal, c'est pas grave car la verification de victoire
      // c'est soit un goal visible 
      // soit le match des coordonées bix et goal
      
      jeu->cells[py][px] = CELL_BLOC_DEP;
      return(1);
    }
    else{
      return(0);
      // si le bloc en px py n'est pas un bloc libre, on a rien fait, donc return 0
    }
  }
  else {
    return (0);
    // si c'etait pas un bloc bougeable, on return 0
  }
}

void appliquer_commande(game_t *jeu, char cmd, bool *doit_reset) {
    
  int dx = 0, dy = 0;

  // Définir le vecteur de direction comme minecraft
  switch (cmd) {
      case 'e': dy = -1; break; // Nord
      case 'd': dy = 1;  break; // Sud
      case 's': dx = -1; break; // Ouest
      case 'f': dx = 1;  break; // Est
      default: return; // Touche ignorée
  }

  // on choppe ou se situe la case suivante de bix (cible)
  int cx = jeu->bix_x + dx;
  int cy = jeu->bix_y + dy;

  // on check si c'est ingame
  if (en_jeu(cx, cy, jeu)){

    // on chope le type de case 
    cell_type_t cible = jeu->cells[cy][cx];

    // déplacement simple :
    if (cible == CELL_SOL || cible == CELL_GOAL || cible == CELL_TROU) {
      
      if (cible == CELL_SOL){

        //jeu->cells[jeu->bix_y][jeu->bix_x] = CELL_SOL;
        // commenté car bix agirait comme un gomme


        // on update la position de bix
        jeu->bix_x = cx;
        jeu->bix_y = cy;

      }
      if (cible == CELL_GOAL){
        //  clear et beau screen de fin 
        printf("Bravo vous avez gagnié!");
        jeu->bix_x = cx;
        jeu->bix_y = cy;
        // l'arret de la boucle se fait après dans le while dans le main
      }
      if (cible == CELL_TROU){
        // screen de game over en texte plus beau que ça
        //printf("Mec t'est null recommence \n"); mais enlevé pour les tests
        // recommencer le la partie
        *doit_reset = true;
        }

      } 

    // si le bloc est bougeable, verifier ce qui est après et remplacer les bonnes cases
    else if (cible == CELL_BLOC_DEP || cible == CELL_BLOC_UNE_FOIS) {
  
      int px = cx + dx;
      int py = cy + dy;


      if (push_bloc(cible, py, px, doit_reset, jeu)){
        // si on a pu pousser le bloc bix prend la placxe de la cible
        jeu->cells[cy][cx] = CELL_SOL; // l'ancienne case du bloc deviens libre
        jeu->bix_x = cx; // on y met bix
        jeu->bix_y = cy;
        
      

        if(cx == jeu->goal_x && cy == jeu->goal_y){
          // victoire, bix a trouvé le goal sous un bloc
          printf("victoire, tu a déniché le goal");
        }

        // vu   u'on a poussé le bloc, on met du sol dessous, 
        jeu->cells[cy][cx] = CELL_SOL;
        //et pas besoin d'afficher le goal vu qu'on aurait déja gagné

      }   
    }
    // Si c'est un CELL_BLOC_FIXE, on n'a rien fait
  }
}

void print_game(const game_t *jeu){

  // a chaque frame, en efface l'ancienne map 
  printf("\033[2J\033[H");
  // titre
  printf("\033[1;35m=== LE PUZZLE DE BIX ===\033[0m\n\n");
  for (size_t y = 0; y < jeu->height; y++){
    for (size_t x = 0; x < jeu->width; x++){
      // faut que si c'est la case de bix, on le mette
      if(x == (size_t)jeu->bix_x && y == (size_t)jeu->bix_y){
        printf("\033[1;33m@\033[0m");
        // bix en jaune fluo
      }
      else{
        switch (jeu->cells[y][x]) {
          case CELL_BLOC_FIXE: 
            printf("\033[1;30mx\033[0m"); // Gris foncé
            break;
          case CELL_BLOC_DEP: 
            printf("\033[1;34m*\033[0m"); // Bleu
            break;
          case CELL_BLOC_UNE_FOIS: 
            printf("\033[1;36m+\033[0m"); // Cyan
            break;
          case CELL_TROU: 
            printf("\033[1;31mo\033[0m"); // Rouge (Attention, c'est le chiffre zéro !)
            break;
          case CELL_GOAL: 
            printf("\033[1;32m!\033[0m"); // Vert fluo
            break;
          case CELL_SOL:
          default: 
            printf(" "); // Espace vide classique
            break;
        }
      }
    }
    // retour a la ligne suivante
    printf("\n");
  }
  printf("\n"); // espace avant la commande
}


int main(int argc, char **argv) {
  // Choisir la carte par défaut, ou celle donnée en argument du programme
  rawmap_t rawmap = argc < 2 ? make_default_rawmap() : read_map_file(argv[1]);

  // créer le jeu
  game_t jeu = create_game(&rawmap); 
  

  // pour l'input du prof ( max 100 input)
  char input[100];

    bool game_on = true; // la variable d'activation du jeu est on
    bool abandon = false; // on met la variable d'abandon a false 

  // mainloop avant la victoire


  print_game(&jeu); // on lance le jeu pour la première fois

  while (game_on){

    if (fgets(input, sizeof(input), stdin) == NULL) {
        break; //on choppe l'input et on sors
    }

    // on parcoure les caractères un par uns
    for (int i = 0; input[i] != '\0' && input[i] != '\n'; i++) {
      
      char cmd = input[i];

      if(cmd == 'x'){
        print_game(&jeu); // le jeu dois s'afficher une dernière fois  
        printf("Abandon :-(");
        abandon = true;
        game_on = false; // on sortira du jeu
        break; // et on arrète de lire la boucle
      }
      else if (cmd == 'r'){
        reset(&jeu);
        break;
      }

      else if (cmd == 'e' || cmd == 'd' || cmd == 's' || cmd == 'f') {
        
        bool doit_reset = false;
                
        // on donne la touche a la fonction de mouvement
        appliquer_commande(&jeu, cmd, &doit_reset);

        // Si le reset est trigger pour nuimporte quelle raison
        if (doit_reset) {
          reset(&jeu);
          break; // On annule les touches suivantes car on a reset
        }

        // On réaffiche l'état
        print_game(&jeu);

        // dans le cas ou bix est arrivé au goal on aura deja le texte mais il faut quiter la boucle
        if (jeu.bix_x == jeu.goal_x && jeu.bix_y == jeu.goal_y) {
          game_on = false; // Fin de partie !
          break;
        }
      }
    }
  }
  if(abandon){
    printf("Abandon :-(\n");
  }
  else{
    printf("Bravo ! Tu as atteint le goal !\n");
  }

  // on verifie pourquoi on est sorti de la loop

  // libérer le jeu

  free_game (&jeu);

  // Ne pas oublier de libérer la carte brute.
  free_rawmap(&rawmap);

  return 0;
}
