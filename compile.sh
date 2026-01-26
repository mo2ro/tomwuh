#!/bin/bash

HTML_FILE="ahh.html"
OUTPUT_FILE="ui.section"

if [ ! -f "$HTML_FILE" ]; then
    echo "Error: $HTML_FILE not found"
    exit 1
fi

SCRIPT=$(sed -n '/<script>/,/<\/script>/p' "$HTML_FILE" | sed '/<script>/d; /<\/script>/d')
# Try to use npx terser for robust JS minification. If terser is not available,
# fall back to the previous lightweight sed-based minifier.
TMP_JS=$(mktemp /tmp/ahh_script.XXXXXX.js)
TMP_MIN=$(mktemp /tmp/ahh_script.min.XXXXXX.js)
printf '%s' "$SCRIPT" > "$TMP_JS"
if command -v npx >/dev/null 2>&1; then
    npx --yes terser "$TMP_JS" -c -m -o "$TMP_MIN" 2>/dev/null || \
        (echo "terser failed, falling back to simple minify" >&2 && cp "$TMP_JS" "$TMP_MIN")
else
    echo "npx not found — falling back to simple minifier" >&2
    cp "$TMP_JS" "$TMP_MIN"
fi
SCRIPT_MINIFIED=$(cat "$TMP_MIN")
SCRIPT_B64=$(printf '%s' "$SCRIPT_MINIFIED" | base64 -w0)
rm -f "$TMP_JS" "$TMP_MIN"

STYLE=$(sed -n '/<style>/,/<\/style>/p' "$HTML_FILE" | sed '/<style>/d; /<\/style>/d')
# Use a proper CSS minifier via npx (clean-css-cli). Fall back to a simple minify if npx or the tool isn't available.
TMP_CSS=$(mktemp /tmp/ahh_style.XXXXXX.css)
TMP_CSS_MIN=$(mktemp /tmp/ahh_style.min.XXXXXX.css)
printf '%s' "$STYLE" > "$TMP_CSS"
if command -v npx >/dev/null 2>&1; then
    npx --yes clean-css-cli "$TMP_CSS" -o "$TMP_CSS_MIN" 2>/dev/null || \
        (echo "clean-css-cli failed, falling back to simple minify" >&2 && cp "$TMP_CSS" "$TMP_CSS_MIN")
else
    echo "npx not found — falling back to simple minifier for CSS" >&2
    cp "$TMP_CSS" "$TMP_CSS_MIN"
fi
STYLE_MINIFIED=$(cat "$TMP_CSS_MIN" | tr -d '\n' | sed 's/  */ /g; s/ *{ */{/g; s/ *} */}/g; s/ *: */:/g; s/ *; */;/g; s/ *, */,/g')
STYLE_B64=$(echo -n "$STYLE_MINIFIED" | base64 -w0)
rm -f "$TMP_CSS" "$TMP_CSS_MIN"

HTML=$(sed -n '/<body>/,/<\/body>/p' "$HTML_FILE" | sed '/<body>/d; /<\/body>/d; /<style>/,/<\/style>/d; /<script>/,/<\/script>/d')
HTML_B64=$(echo -n "$HTML" | base64 -w0)

cat > "$OUTPUT_FILE" << EOF
      document.head.querySelector('style').remove();
      document.head.appendChild(Object.assign(document.createElement('style'), {innerText:atob("$STYLE_B64")}));
      document.body.innerHTML = atob('$HTML_B64')
      let uri = URL.createObjectURL(new Blob([atob("$SCRIPT_B64")]))
      document.head.appendChild(Object.assign(document.createElement('script'), {src:uri}))
EOF

echo "✓ Compilation complete!"
echo "✓ Output written to: $OUTPUT_FILE"
