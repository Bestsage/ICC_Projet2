#!/usr/bin/env bash
# ===========================================================================
# run_tests.sh — Tests automatiques pour le Puzzle de Bix
#
# Usage :
#   bash run_tests.sh              # compile + tous les tests
#   bash run_tests.sh --no-compile # tests seulement (binaire deja present)
# ===========================================================================

set -euo pipefail

# ---------------------------------------------------------------------------
# Couleurs
# ---------------------------------------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
RESET='\033[0m'

PASS=0
FAIL=0
ERRORS=()

# ---------------------------------------------------------------------------
# Detection automatique du dossier des cartes
# ---------------------------------------------------------------------------
if   [ -d "examples" ]; then MAPS_DIR="examples"
elif [ -d "maps"     ]; then MAPS_DIR="maps"
else
    echo -e "${YELLOW}Aucun dossier 'examples/' ni 'maps/' trouve — creation de 'maps/'.${RESET}"
    mkdir -p maps
    MAPS_DIR="maps"
fi

# ---------------------------------------------------------------------------
# compile
# ---------------------------------------------------------------------------
compile() {
    echo -e "\n${BOLD}╔══════════════════════════════════╗"
    echo -e "║         COMPILATION              ║"
    echo -e "╚══════════════════════════════════╝${RESET}"

    local compiler_output
    if compiler_output=$(gcc -Wall -Wextra -Werror \
                             -fsanitize=address,undefined \
                             -g -o puzzle puzzle.c 2>&1); then
        echo -e "${GREEN}  OK — aucun warning, aucune erreur${RESET}\n"
    else
        echo -e "${RED}  ECHEC — le programme ne compile pas !\n${RESET}"
        echo -e "${BOLD}Erreurs :${RESET}"
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
# normalize : supprime ANSI, lignes vides absolues, titres decoratifs
# ---------------------------------------------------------------------------
normalize() {
    sed \
        -e 's/\x1B\[[0-9;]*[A-Za-z]//g' \
        -e 's/\x1B[HF]//g' \
    | grep -v '^$' \
    | grep -v '^=== .*===$'
}

# ---------------------------------------------------------------------------
# cmd_direction : traduit une lettre de commande en mot lisible
# ---------------------------------------------------------------------------
cmd_direction() {
    case "$1" in
        e) echo "nord ↑" ;;
        d) echo "sud ↓"  ;;
        s) echo "ouest ←";;
        f) echo "est →"  ;;
        r) echo "reset"  ;;
        x) echo "abandon";;
        *) echo "?"      ;;
    esac
}

# ---------------------------------------------------------------------------
# state_context : affiche le contexte d'un etat donne
#
# Args: line_num  map_height  all_cmds  input_file
#
# Calcule dans quel etat on est (initial / apres commande N)
# et quelle ligne de l'input a declenche cette commande.
# ---------------------------------------------------------------------------
state_context() {
    local line_num="$1"
    local map_height="$2"
    local all_cmds="$3"
    local input_file="$4"

    # Ligne dans le board (1-indexed au sein de l'etat courant)
    local row_in_state=$(( (line_num - 1) % map_height + 1 ))
    # Numero d'etat (0 = affichage initial, 1 = apres cmd 1, ...)
    local state_idx=$(( (line_num - 1) / map_height ))
    # Commande qui a produit cet etat (0-indexed dans all_cmds)
    local cmd_idx=$(( state_idx - 1 ))

    printf "  ${CYAN}${BOLD}┄ Etat #%d${RESET}" "$state_idx"
    printf "${CYAN} (ligne %d/%d de cet etat)${RESET}" "$row_in_state" "$map_height"

    if [ "$cmd_idx" -lt 0 ]; then
        printf "${CYAN} — affichage initial${RESET}\n"
    elif [ "$cmd_idx" -lt "${#all_cmds}" ]; then
        local cmd_char="${all_cmds:$cmd_idx:1}"
        local direction
        direction=$(cmd_direction "$cmd_char")

        # Retrouver sur quelle ligne de l'input file cette commande se trouve
        # et a quelle position dans cette ligne
        local found_line found_col found_content
        read -r found_line found_col found_content < <(awk -v target="$cmd_idx" '
            BEGIN { total = 0 }
            {
                n = length($0)
                if (total + n > target) {
                    col = target - total + 1
                    print NR, col, $0
                    exit
                }
                total += n
            }
        ' "$input_file")

        printf "${CYAN} — commande #%d : ${BOLD}'%s'${RESET}${CYAN} (%s)${RESET}\n" \
            "$(( cmd_idx + 1 ))" "$cmd_char" "$direction"
        printf "  ${DIM}   ligne %d de l'input, position %d : '%s'${RESET}\n" \
            "${found_line:-?}" "${found_col:-?}" "${found_content:-?}"
    else
        printf "${CYAN} — fin de partie${RESET}\n"
    fi
}

# ---------------------------------------------------------------------------
# pretty_diff : affiche un diff cote-a-cote colore avec contexte de jeu
#
# Args: exp_f  got_f  map_height  all_cmds  input_file
# ---------------------------------------------------------------------------
pretty_diff() {
    local exp_f="$1"
    local got_f="$2"
    local map_height="${3:-7}"
    local all_cmds="${4:-}"
    local input_file="${5:-}"
    local col=40

    local total_exp total_got n_missing n_extra
    total_exp=$(wc -l < "$exp_f")
    total_got=$(wc -l < "$got_f")
    n_missing=$(diff "$got_f" "$exp_f" | grep -c '^>' || true)
    n_extra=$(  diff "$got_f" "$exp_f" | grep -c '^<' || true)

    # En-tete
    printf "\n  ${BOLD}%-4s  %-*s  %-*s${RESET}\n" \
        "LN" $col "ATTENDU (correct)" $col "OBTENU (ton programme)"
    printf "  %s\n" "$(printf '─%.0s' $(seq 1 $((col * 2 + 8))))"

    # Diff cote-a-cote dans un fichier temporaire numerote
    local sidebyside="/tmp/bix_sidebyside_$$.txt"
    diff -y --width=$(( col * 2 + 6 )) --expand-tabs \
        "$exp_f" "$got_f" \
    | nl -ba -nrz -w4 > "$sidebyside" || true

    local CTX=3
    local total_rows
    total_rows=$(wc -l < "$sidebyside")

    # Indices des lignes qui ont un marqueur d'erreur (|, <, >)
    local error_lines
    error_lines=$(grep -nE '  [|<>]  |  <$' "$sidebyside" | cut -d: -f1)

    if [ -z "$error_lines" ]; then
        echo -e "  ${DIM}(aucune difference detectee)${RESET}"
    else
        local prev_end=0
        local prev_state=-1

        while IFS= read -r errln; do
            local start=$(( errln - CTX ))
            local end=$(( errln + CTX ))
            [ $start -lt 1 ] && start=1
            [ $end -gt $total_rows ] && end=$total_rows

            # Numero d'etat de cette erreur
            local cur_state=$(( (errln - 1) / map_height ))

            # Separateur + contexte si on saute des lignes
            if [ $start -gt $(( prev_end + 1 )) ] && [ $prev_end -gt 0 ]; then
                local skipped=$(( start - prev_end - 1 ))
                echo -e "  ${DIM}       ··· $skipped ligne(s) identique(s) ···${RESET}"
            fi

            # Afficher le contexte de jeu au debut d'un nouvel etat
            if [ "$cur_state" -ne "$prev_state" ] && \
               [ "$draw_from" -le "$end" 2>/dev/null ] || \
               [ $start -gt $(( prev_end )) ]; then
                if [ -n "$all_cmds" ] && [ -n "$input_file" ]; then
                    state_context "$errln" "$map_height" "$all_cmds" "$input_file"
                fi
                prev_state=$cur_state
            fi

            # N'afficher que ce qui n'a pas encore ete affiche
            local draw_from=$(( prev_end + 1 ))
            [ $draw_from -lt $start ] && draw_from=$start

            if [ $draw_from -le $end ]; then
                sed -n "${draw_from},${end}p" "$sidebyside" \
                | while IFS= read -r line; do
                    local ln="${line:0:4}"
                    local body="${line:5}"
                    if   [[ "$body" =~ [[:space:]][[:space:]]'<'$ ]]; then
                        printf "  ${DIM}%s${RESET}  ${GREEN}%s${RESET}\n" "$ln" "$body"
                    elif [[ "$body" =~ [[:space:]][[:space:]]'>'[[:space:]] ]]; then
                        printf "  ${DIM}%s${RESET}  ${RED}%s${RESET}\n"   "$ln" "$body"
                    elif [[ "$body" =~ [[:space:]][[:space:]]'|'[[:space:]] ]]; then
                        printf "  ${DIM}%s${RESET}  ${YELLOW}%s${RESET}\n" "$ln" "$body"
                    else
                        printf "  ${DIM}%s  %s${RESET}\n" "$ln" "$body"
                    fi
                done
                prev_end=$end
            fi
        done <<< "$error_lines"

        if [ $prev_end -lt $total_rows ]; then
            local remaining=$(( total_rows - prev_end ))
            echo -e "  ${DIM}       ··· $remaining ligne(s) identique(s) en fin de fichier ···${RESET}"
        fi
    fi

    rm -f "$sidebyside"

    # Resume chiffre
    echo ""
    echo -e "  ${BOLD}Resume :${RESET}"
    printf "  ${DIM}%-25s %s${RESET}\n" "Lignes attendues :"  "$total_exp"
    printf "  ${DIM}%-25s %s${RESET}\n" "Lignes obtenues :"   "$total_got"
    [ "$n_missing" -gt 0 ] && \
        echo -e "  ${GREEN}  Manquantes (vertes) : ${n_missing} — ton programme n'affiche pas ces lignes${RESET}"
    [ "$n_extra" -gt 0 ] && \
        echo -e "  ${RED}  En trop (rouges)    : ${n_extra} — ton programme affiche des lignes de trop${RESET}"
    echo ""
}

# ---------------------------------------------------------------------------
# show_sanitizer
# ---------------------------------------------------------------------------
show_sanitizer() {
    local san_file="$1"
    echo -e "  ${BOLD}${RED}SANITIZER — erreur memoire ou comportement indefini detecte :${RESET}"

    grep -E "(ERROR:|WRITE|READ|#[0-9].*puzzle\.c|SUMMARY)" "$san_file" \
    | head -15 \
    | while IFS= read -r line; do
        local ln_num
        ln_num=$(echo "$line" | grep -oP 'puzzle\.c:\K[0-9]+' || true)
        if   [[ "$line" == SUMMARY* ]]; then
            echo -e "  ${RED}${BOLD}$line${RESET}"
        elif [[ -n "$ln_num" ]]; then
            echo -e "  ${RED}$line${RESET}  ${YELLOW}<-- puzzle.c ligne $ln_num${RESET}"
        else
            echo -e "  ${DIM}$line${RESET}"
        fi
    done
    echo ""
}

# ---------------------------------------------------------------------------
# run_test <nom> <carte> <input> <expected>
# ---------------------------------------------------------------------------
run_test() {
    local name="$1"
    local map="$2"
    local input="$3"
    local expected="$4"
    local actual_f="/tmp/bix_actual_${name}.txt"
    local exp_f="/tmp/bix_expected_${name}.txt"
    local san_f="/tmp/bix_sanitizer_${name}.txt"

    echo -e "\n${BOLD}┌─ TEST : ${CYAN}${name}${RESET}${BOLD} ── carte : ${map}${RESET}"

    # Hauteur de la map (2eme champ de la 1ere ligne du fichier carte)
    local map_height
    map_height=$(head -1 "$map" | awk '{print $2}')

    # Toutes les commandes a plat (concatenation des lignes sans \n)
    local all_cmds
    all_cmds=$(tr -d '\n' < "$input")

    timeout 10 ./puzzle "$map" < "$input" 2>"$san_f" \
        | normalize > "$actual_f" || true
    normalize < "$expected" > "$exp_f"

    if diff -q "$actual_f" "$exp_f" > /dev/null 2>&1; then
        echo -e "${BOLD}└─ ${GREEN}PASS${RESET} — sortie identique a l'attendu"
        PASS=$((PASS + 1))
    else
        echo -e "${BOLD}└─ ${RED}FAIL${RESET}"
        FAIL=$((FAIL + 1))
        ERRORS+=("$name")

        pretty_diff "$exp_f" "$actual_f" "$map_height" "$all_cmds" "$input"

        [ -s "$san_f" ] && show_sanitizer "$san_f"
    fi
}

# ---------------------------------------------------------------------------
# summary
# ---------------------------------------------------------------------------
summary() {
    local total=$((PASS + FAIL))
    echo -e "\n${BOLD}╔══════════════════════════════════╗"
    echo -e "║           RESULTATS              ║"
    echo -e "╚══════════════════════════════════╝${RESET}\n"

    if [ $FAIL -gt 0 ]; then
        for e in "${ERRORS[@]}"; do echo -e "  ${RED}FAIL  $e${RESET}"; done
        echo ""
        echo -e "  ${RED}${BOLD}$PASS / $total — des bugs a corriger !${RESET}\n"
        exit 1
    else
        echo -e "  ${GREEN}${BOLD}$PASS / $total — tout est bon, bien joue !${RESET}\n"
    fi
}

# ---------------------------------------------------------------------------
# Point d'entree
# ---------------------------------------------------------------------------
echo -e "${BOLD}${CYAN}"
echo " ██████╗ ██╗██╗  ██╗"
echo " ██╔══██╗██║╚██╗██╔╝"
echo " ██████╔╝██║ ╚███╔╝ "
echo " ██╔══██╗██║ ██╔██╗ "
echo " ██████╔╝██║██╔╝ ██╗"
echo -e " ╚═════╝ ╚═╝╚═╝  ╚═╝  Tests automatiques${RESET}"
echo -e " ${DIM}Maps dans : ${MAPS_DIR}/${RESET}"

if [[ "${1:-}" != "--no-compile" ]]; then
    compile
fi

echo -e "${BOLD}╔══════════════════════════════════╗"
echo -e "║            TESTS                 ║"
echo -e "╚══════════════════════════════════╝${RESET}"

run_test "incomplete-map"  "${MAPS_DIR}/incomplete-map.txt"  "tests/incomplete-map/input.txt"  "tests/incomplete-map/expected.txt"
run_test "level1"          "${MAPS_DIR}/level1.txt"          "tests/level1/input.txt"          "tests/level1/expected.txt"
run_test "level2"          "${MAPS_DIR}/level2.txt"          "tests/level2/input.txt"          "tests/level2/expected.txt"

summary