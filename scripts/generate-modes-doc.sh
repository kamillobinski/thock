#!/bin/bash

SOUNDS_DIR="./Thock/Resources/Sounds"
OUTPUT="./docs/MODES.md"
TMP=$(mktemp)

# Collect entries
find "$SOUNDS_DIR" -type d -mindepth 3 -maxdepth 3 | while read -r path; do
    brand=$(basename "$(dirname "$(dirname "$path")")")
    author=$(basename "$(dirname "$path")")
    mode=$(basename "$path")

    # Normalize
    brand_fmt=$(echo "$brand" | sed 's/_/ /g' | awk '{ for(i=1;i<=NF;++i) $i=toupper(substr($i,1,1)) tolower(substr($i,2)) }1')
    author_fmt="$author"
    mode_fmt=$(echo "$mode" | sed 's/_/ /g')

    echo "$brand_fmt|$author_fmt|$mode_fmt" >> "$TMP"
done

# Sort entries
sort "$TMP" -o "$TMP"

# Output to Markdown
{
    echo "<a name='readme-top'></a>"
    echo ""
    echo "# Thock Modes"
    echo ""
    echo "| Brand | Author | Mode |"
    echo "|-------|--------|------|"
    while IFS='|' read -r brand author mode; do
        echo "| $brand | $author | $mode |"
    done < "$TMP"
    echo ""
    echo "_Auto-Generated from folder structure at \`Thock/Resources/Sounds/\`_"
    echo ""
    echo "<p align='right'>(<a href='#readme-top'>back to top</a>)</p>"
} > "$OUTPUT"

# Cleanup
rm "$TMP"
