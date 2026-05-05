#!/usr/bin/env bash
# ===========================================================================
# run_tests.sh — Tests automatiques pour le Puzzle de Bix
#
# Usage :
#   bash run_tests.sh              # compile + tous les tests
#   bash run_tests.sh --no-compile # tests seulement (binaire deja present)
# ===========================================================================

# -e  : quitter immediatement en cas d'erreur non rattrapee
# -u  : traiter les variables non definies comme une erreur
# -o pipefail : un pipe echoue si l'une de ses commandes echoue
set -euo pipefail

# ---------------------------------------------------------------------------
# Couleurs ANSI utilisees dans les messages du script
# ---------------------------------------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
RESET='\033[0m'

# Compteurs globaux de tests passes et echoues
PASS=0
FAIL=0
# Tableau des noms de tests ayant echoue (affiche dans le resume final)
ERRORS=()

# Nombre maximum d'etats errones affiches par test (evite les murs de texte)
MAX_STATES_SHOWN=3

# ---------------------------------------------------------------------------
# Detection automatique du dossier contenant les fichiers de carte (.txt)
# On cherche d'abord "examples/", puis "maps/", et on le cree si absent.
# ---------------------------------------------------------------------------
if   [ -d "examples" ]; then MAPS_DIR="examples"
elif [ -d "maps"     ]; then MAPS_DIR="maps"
else
    echo -e "${YELLOW}Aucun dossier 'examples/' ni 'maps/' trouve — creation de 'maps/'.${RESET}"
    mkdir -p maps
    MAPS_DIR="maps"
fi

# ---------------------------------------------------------------------------
# compile : compile puzzle.c avec gcc et les sanitizers actives.
# En cas d'echec, affiche les erreurs/warnings de facon lisible et quitte.
# ---------------------------------------------------------------------------
compile() {
    echo -e "\n${BOLD}╔══════════════════════════════════╗"
    echo -e "║         COMPILATION              ║"
    echo -e "╚══════════════════════════════════╝${RESET}"

    local compiler_output
    # -Werror transforme les warnings en erreurs pour forcer un code propre
    if compiler_output=$(gcc -Wall -Wextra -Werror \
                             -fsanitize=address,undefined \
                             -g -o puzzle puzzle.c 2>&1); then
        echo -e "${GREEN}  OK — aucun warning, aucune erreur${RESET}\n"
    else
        echo -e "${RED}  ECHEC — le programme ne compile pas !\n${RESET}"
        echo -e "${BOLD}Erreurs :${RESET}"
        # Colorise chaque ligne selon son niveau (error / warning / note)
        while IFS= read -r line; do
            if   [[ "$line" == *"error:"*   ]]; then echo -e "  ${RED}ERR  ${RESET}$line"
            elif [[ "$line" == *"warning:"* ]]; then echo -e "  ${YELLOW}WARN ${RESET}$line"
            elif [[ "$line" == *"note:"*    ]]; then echo -e "  ${DIM}NOTE ${RESET}$line"
            else                                     echo -e "       $line"
            fi
        done <<< "$compiler_output"
        echo ""
        exit 1
    fi
}

# ---------------------------------------------------------------------------
# normalize : nettoie la sortie brute du programme avant comparaison.
#   - supprime les sequences d'echappement ANSI (couleurs, deplacement curseur)
#   - supprime les lignes entierement vides
#   - supprime les titres decoratifs de type "=== ... ==="
# Utilisee en pipe : commande | normalize  ou  normalize < fichier
# ---------------------------------------------------------------------------
normalize() {
    sed \
        -e 's/\x1B\[[0-9;]*[A-Za-z]//g' \
        -e 's/\x1B[HF]//g' \
    | grep -v '^$' \
    | grep -v '^=== .*===$'
}

# ---------------------------------------------------------------------------
# cmd_direction <lettre> : retourne le nom lisible d'une commande.
# Exemple : cmd_direction f  =>  "est ->"
# ---------------------------------------------------------------------------
cmd_direction() {
    case "$1" in
        e) echo "nord ^" ;;
        d) echo "sud v"  ;;
        s) echo "ouest <";;
        f) echo "est >"  ;;
        r) echo "reset"  ;;
        x) echo "abandon";;
        *) echo "?"      ;;
    esac
}

# ---------------------------------------------------------------------------
# cmd_timeline <all_cmds> <active_idx> : affiche la sequence de commandes
# sur une seule ligne avec surlignage de la commande active.
#
#   all_cmds   : chaine de toutes les commandes (ex : "esdf")
#   active_idx : -1 = etat initial, >= 0 = index 0-base de la commande
#
# Exemple de rendu :  Commandes : [INIT] e s -d- f
#   (commandes passees en grise, commande active entre crochets en rouge,
#    commandes futures en texte normal)
# ---------------------------------------------------------------------------
cmd_timeline() {
    local all_cmds="$1"
    local active_idx="$2"
    local len="${#all_cmds}"

    printf "  ${CYAN}Commandes :${RESET} "

    # Affiche l'etat initial, surligne si active_idx == -1
    if [ "$active_idx" -lt 0 ]; then
        printf "${BOLD}[INIT]${RESET}"
    else
        printf "${DIM}[INIT]${RESET}"
    fi

    # Parcourt chaque commande et applique le style appropriate
    for (( i=0; i<len; i++ )); do
        local ch="${all_cmds:$i:1}"
        if [ "$i" -lt "$active_idx" ]; then
            # Commande deja jouee : grisee
            printf " ${DIM}%s${RESET}" "$ch"
        elif [ "$i" -eq "$active_idx" ]; then
            # Commande ayant produit l'etat errone : en rouge entre crochets
            printf " ${BOLD}${RED}[%s]${RESET}" "$ch"
        else
            # Commande future : texte normal
            printf " %s" "$ch"
        fi
    done
    printf "\n"

    # Affiche le detail de la commande active (numero, lettre, direction)
    if [ "$active_idx" -ge 0 ] && [ "$active_idx" -lt "$len" ]; then
        local ch="${all_cmds:$active_idx:1}"
        printf "  ${CYAN}-> Cmd #%d : ${BOLD}'%s'${RESET}${CYAN} = %s${RESET}\n" \
            "$(( active_idx + 1 ))" "$ch" "$(cmd_direction "$ch")"
    fi
}

# ---------------------------------------------------------------------------
# block_lines <fichier> <debut> <fin> : extrait les lignes [debut, fin]
# d'un fichier (indices 1-bases, inclusifs).
# Retourne une chaine vide si la plage est hors des limites du fichier.
# Utilise awk pour un acces efficace sans charger tout le fichier en memoire.
# ---------------------------------------------------------------------------
block_lines() {
    local file="$1"
    local start="$2"
    local end="$3"
    awk "NR>=$start && NR<=$end" "$file"
}

# ---------------------------------------------------------------------------
# _state_header_dim <state_idx> <all_cmds> : affiche un en-tete discret
# (grise) pour un etat correct utilise comme contexte dans le diff.
#   state_idx == 0 => etat initial (avant toute commande)
#   state_idx  > 0 => etat produit par la commande a l'index state_idx-1
# ---------------------------------------------------------------------------
_state_header_dim() {
    local s="$1"
    local all_cmds="$2"
    local cmd_idx=$(( s - 1 ))

    if [ "$s" -eq 0 ]; then
        printf "  ${DIM}| Etat initial${RESET}\n"
    else
        local ch="${all_cmds:$cmd_idx:1}"
        printf "  ${DIM}| Etat #%d — '%s' -> %s${RESET}\n" \
            "$s" "$ch" "$(cmd_direction "$ch")"
    fi
}

# ---------------------------------------------------------------------------
# _show_ctx_state <s> <exp_f> <map_height> <all_cmds> : affiche un etat
# CORRECT en mode contexte (grise, compact) pour donner du recul avant
# un etat errone.
#   s          : index de l'etat (0 = initial)
#   exp_f      : fichier contenant tous les etats attendus concatenes
#   map_height : nombre de lignes d'une carte (taille d'un etat)
#   all_cmds   : chaine de toutes les commandes du test
# ---------------------------------------------------------------------------
_show_ctx_state() {
    local s="$1"
    local exp_f="$2"
    local map_height="$3"
    local all_cmds="$4"

    # Calcul de la plage de lignes correspondant a cet etat dans exp_f
    local ls=$(( s * map_height + 1 ))
    local le=$(( ls + map_height - 1 ))
    local block
    block=$(block_lines "$exp_f" "$ls" "$le")

    _state_header_dim "$s" "$all_cmds"

    # Affiche chaque ligne de l'etat avec son numero de ligne source (grise)
    for (( row=1; row<=map_height; row++ )); do
        local ln=$(( ls + row - 1 ))
        local line
        line=$(printf '%s' "$block" | sed -n "${row}p")
        printf "  ${DIM}%4d  %s${RESET}\n" "$ln" "$line"
    done
    echo -e "  ${DIM}     OK${RESET}"
}

# ---------------------------------------------------------------------------
# _show_fail_state <s> <exp_f> <got_f> <map_height> <all_cmds> : affiche
# un etat ERRONE en detail avec diff cote-a-cote et timeline des commandes.
#   s          : index de l'etat errone
#   exp_f      : fichier de la sortie attendue
#   got_f      : fichier de la sortie obtenue
#   map_height : nombre de lignes d'une carte
#   all_cmds   : chaine de toutes les commandes du test
# ---------------------------------------------------------------------------
_show_fail_state() {
    local s="$1"
    local exp_f="$2"
    local got_f="$3"
    local map_height="$4"
    local all_cmds="$5"
    local col=42   # largeur de chaque colonne du diff cote-a-cote

    # Plage de lignes de cet etat dans les fichiers exp et got
    local ls=$(( s * map_height + 1 ))
    local le=$(( ls + map_height - 1 ))
    local exp_block got_block
    exp_block=$(block_lines "$exp_f" "$ls" "$le")
    got_block=$(block_lines "$got_f" "$ls" "$le")

    local cmd_idx=$(( s - 1 ))

    # En-tete de l'etat errone : indique la commande responsable
    if [ "$s" -eq 0 ]; then
        echo -e "  ${BOLD}${YELLOW}+- Etat initial <- PREMIER ECHEC${RESET}"
    else
        local ch="${all_cmds:$cmd_idx:1}"
        echo -e "  ${BOLD}${YELLOW}+- Etat #${s} — commande '${ch}' -> $(cmd_direction "$ch")  <- ECHEC${RESET}"
        # Affiche la timeline uniquement si des commandes sont disponibles
        [ -n "$all_cmds" ] && cmd_timeline "$all_cmds" "$cmd_idx"
    fi

    # En-tetes des colonnes du diff
    printf "\n  ${BOLD}%4s  ${GREEN}%-*s${RESET}  ${BOLD}${RED}%-*s${RESET}\n" \
        "LN" "$col" "ATTENDU" "$col" "OBTENU"
    printf "  %s\n" "$(printf '%0.s-' $(seq 1 $((col * 2 + 10))))"
    # Compare ligne par ligne : vert si identique (grise), rouge si different
    for (( row=1; row<=map_height; row++ )); do
        local ln=$(( ls + row - 1 ))
        local exp_line got_line
        exp_line=$(printf '%s' "$exp_block" | sed -n "${row}p")
        got_line=$(printf '%s' "$got_block" | sed -n "${row}p")

        if [ "$exp_line" = "$got_line" ]; then
            # Ligne correcte : affichee en grise pour alleger la lecture
            printf "  ${DIM}%4d  %-*s  %-*s${RESET}\n" \
                "$ln" "$col" "$exp_line" "$col" "$got_line"
        else
            # Ligne incorrecte : attendu en vert, obtenu en rouge
            printf "  %4d  ${GREEN}%-*s${RESET}  ${RED}%-*s${RESET}\n" \
                "$ln" "$col" "$exp_line" "$col" "$got_line"
        fi
    done

    # Signale si le nombre de lignes obtenues ne correspond pas a l'attendu
    local exp_cnt got_cnt
    exp_cnt=$(printf '%s\n' "$exp_block" | wc -l)
    got_cnt=$(printf '%s\n' "$got_block" | wc -l)
    if   [ "$got_cnt" -lt "$exp_cnt" ]; then
        echo -e "  ${RED}  -> Seulement $got_cnt ligne(s) affichee(s) sur $exp_cnt attendues${RESET}"
    elif [ "$got_cnt" -gt "$exp_cnt" ]; then
        echo -e "  ${RED}  -> $got_cnt lignes affichees, $exp_cnt attendues${RESET}"
    fi
}

# ---------------------------------------------------------------------------
# pretty_diff <exp_f> <got_f> <map_height> <all_cmds> <input_file> :
# compare les deux sorties etat par etat et affiche un rapport lisible.
#
# Pour chaque etat errone (jusqu'a MAX_STATES_SHOWN), on affiche :
#   - les 2 etats corrects qui precedent (grise, compact) comme contexte
#   - l'etat errone en detail avec diff cote-a-cote et timeline
#
# Un separateur "..." est insere si des etats de contexte sont sautes
# entre deux groupes d'erreurs.
# ---------------------------------------------------------------------------
pretty_diff() {
    local exp_f="$1"
    local got_f="$2"
    local map_height="${3:-7}"
    local all_cmds="${4:-}"
    local input_file="${5:-}"

    # Nombre total de lignes dans chaque fichier
    local total_exp total_got
    total_exp=$(wc -l < "$exp_f")
    total_got=$(wc -l < "$got_f")

    # Nombre d'etats (chaque etat occupe map_height lignes)
    local n_states_exp=$(( (total_exp + map_height - 1) / map_height ))
    local n_states_got=$(( (total_got + map_height - 1) / map_height ))
    # On prend le max pour ne pas ignorer les etats en trop dans got
    local n_states=$(( n_states_exp > n_states_got ? n_states_exp : n_states_got ))

    local n_fail=0       # nombre total d'etats errones trouves
    local n_shown=0      # nombre d'etats errones deja affiches
    local last_ctx_shown=-1   # index du dernier etat de contexte affiche

    for (( s=0; s<n_states; s++ )); do
        local ls=$(( s * map_height + 1 ))
        local le=$(( ls + map_height - 1 ))

        local exp_block got_block
        exp_block=$(block_lines "$exp_f" "$ls" "$le")
        got_block=$(block_lines "$got_f" "$ls" "$le")

        # Si les blocs sont identiques, cet etat est correct : on passe
        [ "$exp_block" = "$got_block" ] && continue

        n_fail=$(( n_fail + 1 ))
        # Si on a deja atteint la limite d'affichage, on compte mais on n'affiche plus
        [ $n_shown -ge $MAX_STATES_SHOWN ] && continue
        n_shown=$(( n_shown + 1 ))

        echo ""

        # -- Contexte : affiche les 2 etats corrects qui precedent l'erreur --
        # On ne re-affiche pas les etats deja montres comme contexte precedent.
        local ctx_start=$(( s - 2 ))
        [ $ctx_start -lt 0 ] && ctx_start=0

        local first_ctx=1   # vaut 1 avant d'avoir affiche le premier bloc de contexte
        for (( c=ctx_start; c<s; c++ )); do
            # Saute les etats de contexte deja affiches lors d'un echec precedent
            [ $c -le $last_ctx_shown ] && continue

            # Insere "..." uniquement avant le premier nouveau bloc de contexte
            # (pas entre deux blocs de contexte consecutifs du meme groupe)
            if [ $first_ctx -eq 1 ] && [ $last_ctx_shown -ge 0 ]; then
                echo -e "  ${DIM}  ...${RESET}"
            fi
            first_ctx=0

            _show_ctx_state "$c" "$exp_f" "$map_height" "$all_cmds"
            last_ctx_shown=$c
        done

        # -- Affiche l'etat errone en detail --
        _show_fail_state "$s" "$exp_f" "$got_f" "$map_height" "$all_cmds"
        last_ctx_shown=$s
    done

    # Message si certains echecs n'ont pas ete affiches (limite MAX_STATES_SHOWN)
    if [ $n_fail -gt $MAX_STATES_SHOWN ]; then
        local hidden=$(( n_fail - MAX_STATES_SHOWN ))
        echo -e "\n  ${DIM}... et $hidden autre(s) etat(s) incorrect(s) non affiches ...${RESET}"
    fi

    # Resume chiffre : lignes/etats attendus vs obtenus, nombre d'echecs
    echo ""
    echo -e "  ${BOLD}Resume :${RESET}"
    printf "  ${DIM}%-30s %d lignes (%d etats)${RESET}\n" \
        "Attendu :"  "$total_exp" "$n_states_exp"
    printf "  ${DIM}%-30s %d lignes (%d etats)${RESET}\n" \
        "Obtenu :"   "$total_got" "$n_states_got"
    if [ $n_fail -gt 0 ]; then
        printf "  ${RED}%-30s %d / %d${RESET}\n" \
            "Etats incorrects :" "$n_fail" "$n_states"
    fi
    echo ""
}

# ---------------------------------------------------------------------------
# show_sanitizer <san_file> : affiche un extrait du rapport AddressSanitizer
# ou UndefinedBehaviorSanitizer ecrit sur stderr par le programme.
# Seules les lignes pertinentes sont conservees (type d'erreur, ligne source,
# resume) pour eviter de noyer l'utilisateur sous des traces de pile brutes.
# ---------------------------------------------------------------------------
show_sanitizer() {
    local san_file="$1"
    echo -e "  ${BOLD}${RED}SANITIZER — erreur memoire ou comportement indefini detecte :${RESET}"

    # Filtre les lignes utiles et extrait le numero de ligne dans puzzle.c
    grep -E "(ERROR:|WRITE|READ|#[0-9].*puzzle\.c|SUMMARY)" "$san_file" \
    | head -15 \
    | while IFS= read -r line; do
        local ln_num
        # Recupere le numero de ligne de puzzle.c s'il est present
        ln_num=$(echo "$line" | grep -oP 'puzzle\.c:\K[0-9]+' || true)
        if   [[ "$line" == SUMMARY* ]]; then
            # Ligne de resume : mise en evidence maximale
            echo -e "  ${RED}${BOLD}$line${RESET}"
        elif [[ -n "$ln_num" ]]; then
            # Ligne avec reference a puzzle.c : indique le numero de ligne
            echo -e "  ${RED}$line${RESET}  ${YELLOW}<-- puzzle.c ligne $ln_num${RESET}"
        else
            # Autre ligne de contexte : grisee
            echo -e "  ${DIM}$line${RESET}"
        fi
    done
    echo ""
}

# ---------------------------------------------------------------------------
# run_test <nom> <carte> <input> <expected> : execute un test.
#
#   nom      : identifiant du test (utilise pour les fichiers temporaires)
#   carte    : chemin vers le fichier de carte .txt
#   input    : fichier de commandes a envoyer sur stdin du programme
#   expected : fichier de sortie de reference (apres normalisation)
#
# Le programme est lance avec un timeout de 10 secondes.
# La sortie est normalisee avant comparaison pour ignorer les differences
# de couleurs ANSI et de lignes vides.
# ---------------------------------------------------------------------------
run_test() {
    local name="$1"
    local map="$2"
    local input="$3"
    local expected="$4"
    # Fichiers temporaires pour les sorties normalisees
    local actual_f="/tmp/bix_actual_${name}.txt"
    local exp_f="/tmp/bix_expected_${name}.txt"
    local san_f="/tmp/bix_sanitizer_${name}.txt"   # rapport sanitizer (stderr)

    # Lit la hauteur de la carte dans la premiere ligne du fichier (champ H)
    local map_height
    map_height=$(head -1 "$map" | awk '{print $2}')

    # Concatene toutes les commandes du fichier input en une seule chaine
    # (pour l'affichage de la timeline et le comptage)
    local all_cmds
    all_cmds=$(tr -d '\n' < "$input")

    # En-tete du test avec recap de la sequence de commandes
    echo -e "\n${BOLD}+- TEST : ${CYAN}${name}${RESET}${BOLD} -- carte : ${map}  (${map_height} lignes/etat)${RESET}"
    echo -e "${BOLD}|  Sequence :${RESET} ${all_cmds}  ${DIM}(${#all_cmds} commande(s))${RESET}"

    # Lance le programme avec un timeout et capture stderr pour le sanitizer
    ./puzzle "$map" < "$input" 2>"$san_f" \
        | normalize > "$actual_f" || true        | normalize > "$actual_f" || true
    # Normalise aussi la reference pour que la comparaison soit juste
    normalize < "$expected" > "$exp_f"

    if diff -q "$actual_f" "$exp_f" > /dev/null 2>&1; then
        echo -e "${BOLD}+- ${GREEN}PASS${RESET} — sortie identique a l'attendu"
        PASS=$((PASS + 1))
    else
        echo -e "${BOLD}+- ${RED}FAIL${RESET}"
        FAIL=$((FAIL + 1))
        ERRORS+=("$name")

        # Affiche le diff detaille etat par etat
        pretty_diff "$exp_f" "$actual_f" "$map_height" "$all_cmds" "$input"

        # Si le sanitizer a produit une sortie, l'afficher
        [ -s "$san_f" ] && show_sanitizer "$san_f"
    fi
}

# ---------------------------------------------------------------------------
# summary : affiche le bilan final et quitte avec le code adequat.
# Retourne 0 si tous les tests sont passes, 1 sinon.
# ---------------------------------------------------------------------------
summary() {
    local total=$((PASS + FAIL))
    echo -e "\n${BOLD}╔══════════════════════════════════╗"
    echo -e "║           RESULTATS              ║"
    echo -e "╚══════════════════════════════════╝${RESET}\n"

    if [ $FAIL -gt 0 ]; then
        # Liste les tests echoues avant le score global
        for e in "${ERRORS[@]}"; do echo -e "  ${RED}FAIL  $e${RESET}"; done
        echo ""
        echo -e "  ${RED}${BOLD}$PASS / $total — des bugs a corriger !${RESET}\n"
        exit 1
    else
        echo -e "  ${GREEN}${BOLD}$PASS / $total — tout est bon, bien joue !${RESET}\n"
    fi
}

# ---------------------------------------------------------------------------
# Point d'entree du script
# ---------------------------------------------------------------------------
echo -e "${BOLD}${CYAN}"
echo " ██████╗ ██╗██╗  ██╗"
echo " ██╔══██╗██║╚██╗██╔╝"
echo " ██████╔╝██║ ╚███╔╝ "
echo " ██╔══██╗██║ ██╔██╗ "
echo " ██████╔╝██║██╔╝ ██╗"
echo -e " ╚═════╝ ╚═╝╚═╝  ╚═╝  Tests automatiques${RESET}"
echo -e " ${DIM}Maps dans : ${MAPS_DIR}/${RESET}"

# Compile sauf si --no-compile est passe en argument
if [[ "${1:-}" != "--no-compile" ]]; then
    compile
fi

echo -e "${BOLD}╔══════════════════════════════════╗"
echo -e "║            TESTS                 ║"
echo -e "╚══════════════════════════════════╝${RESET}"

# Lance chaque test : nom, carte, fichier d'entree, fichier de reference
run_test "incomplete-map"  "${MAPS_DIR}/incomplete-map.txt"  "tests/incomplete-map/input.txt"  "tests/incomplete-map/expected.txt"
run_test "level1"          "${MAPS_DIR}/level1.txt"          "tests/level1/input.txt"          "tests/level1/expected.txt"
run_test "level2"          "${MAPS_DIR}/level2.txt"          "tests/level2/input.txt"          "tests/level2/expected.txt"

summary
