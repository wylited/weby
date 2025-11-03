#!/bin/bash
# Script to fix cross-references in HTML files

for file in dist/*.html dist/*/*.html; do
  if [ -f "$file" ]; then
    # Replace .html references with directory-style links (e.g., meta.html -> meta/)
    # but only for relative links (not starting with http, https, or #)
    # First, we need to remove the .html extension, then add the slash
    sed -i.bak 's/href="\([^"#:]*\)\.html"/href="\1\/"/g' "$file"
    # Clean up backup files
    rm "$file.bak"
  fi
done