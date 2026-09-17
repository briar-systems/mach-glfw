#!/bin/sh
# pack symbol names, one per stdin line, into the body of a TOML string array
# laid out like the manifest's `symbols`: four-space indent, `"sym",` items
# joined by single spaces, a trailing comma on every line, and no line past
# WIDTH columns unless a single item is longer on its own.
#   tools/pack-symbols.sh [width] < names
set -eu

width=${1:-80}

awk -v width="$width" '
    NF == 0 { next }
    {
        item = "\"" $0 "\","
        if (line == "") {
            line = "    " item
        } else if (length(line) + 1 + length(item) > width) {
            print line
            line = "    " item
        } else {
            line = line " " item
        }
    }
    END { if (line != "") print line }
'
