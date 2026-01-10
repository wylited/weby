# Justfile for building Typst website

# Default recipe
default:
    @just --list

# Clean the dist directory
clean:
    @echo "Cleaning dist directory..."
    @rm -rf dist

# Build the website
build:
    @echo "Building website..."
    @just clean
    @mkdir -p dist
    # Compile index.typ to dist/index.html
    @typst compile --format html --features html src/index.typ dist/index.html
    # Compile other .typ files (excluding setup.typ) to subdirectories with index.html
    @for file in src/*.typ; do \
        if [ "$(basename "$file")" != "index.typ" ] && [ "$(basename "$file")" != "setup.typ" ]; then \
            name=$(basename "$file" .typ); \
            mkdir -p dist/"$name"; \
            typst compile --format html --features html "$file" dist/"$name"/index.html; \
        fi \
    done
    # Copy static assets
    @cp static/*.css static/favicon.ico dist/ 2>/dev/null || echo "No css files or favicon.ico to copy"
    # Fix cross-references in HTML files
    @just fix-refs

# Fix cross-references in generated HTML files
fix-refs:
    @echo "Fixing cross-references..."
    @chmod +x fix_refs.sh
    @./fix_refs.sh

# Serve the website locally for testing
serve: build
    @echo "Serving website at http://localhost:3000"
    @cd dist && python3 -m http.server 3000
