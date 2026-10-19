# Sourced by the tests of the words documents. Reads the documents only.
# shellcheck shell=bash

# entries FILE COLUMN: each word of a clankos document that lists words
# in a column, such as docs/words.txt or section 1 of docs/model.txt,
# with the text of its line, a tab between them, one a line. The word
# is in the columns from the fifth to COLUMN, where the text begins.
entries() {
    awk -v column="$2" '
        /^    [a-z]/ {
            if (word != "") print word "\t" text
            word = substr($0, 5, column - 5); sub(/ +$/, "", word)
            text = substr($0, column); next
        }
        /^          / && word != "" { sub(/^ +/, ""); text = text " " $0; next }
        { if (word != "") print word "\t" text; word = "" }
        END { if (word != "") print word "\t" text }
    ' "$1"
}

# bugflow_entries FILE: each word of bugflow's docs/words.md, in lower
# case, with the text of its line, a tab between them, one a line.
bugflow_entries() {
    awk '
        /^- \*\*[^*]*\.\*\*/ {
            if (word != "") print word "\t" text
            word = $0; sub(/^- \*\*/, "", word); sub(/\.\*\*.*/, "", word)
            word = tolower(word); text = $0; next
        }
        /^  / && word != "" { text = text " " $0; next }
        { if (word != "") print word "\t" text; word = "" }
        END { if (word != "") print word "\t" text }
    ' "$1"
}
