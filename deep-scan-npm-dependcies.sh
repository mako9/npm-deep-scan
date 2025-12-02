#!/usr/bin/env sh
set -eu

# ---- Input: project path to scan ----
PROJECT_PATH="${1:-.}"

if [ ! -d "$PROJECT_PATH" ]; then
  echo "❌ Error: Provided path is not a directory: $PROJECT_PATH"
  exit 1
fi

echo "📁 Scanning project: $PROJECT_PATH"

# --- IoC definitions ---
# This file should be a plain text list of package names, one per line.
IOC_FILE="affected-packages.txt"
REPORT="deep-scan-report.json"

if [ ! -f "$IOC_FILE" ]; then
  echo "❌ $IOC_FILE not found in script directory."
  echo "   Please create it and add one package name per line."
  exit 1
fi

echo "📘 Loading IoC list from $IOC_FILE ..."
TOTAL_IOC=$(wc -l < "$IOC_FILE" | tr -d ' ')
echo "✔ Loaded $TOTAL_IOC IoCs."


# ---------- JSON report start ----------
{
  echo "{"
  echo "  \"timestamp\": \"$(date -Iseconds)\","
  echo "  \"scanned_path\": \"$(realpath "$PROJECT_PATH")\","
  echo "  \"total_iocs\": $TOTAL_IOC,"
  echo "  \"hits\": {"
} > "$REPORT"


# JSON list formatter
json_list() {
  first=1
  printf "["
  for item in $2; do
    if [ $first -eq 0 ]; then printf ", "; fi
    printf "\"%s\"" "$item"
    first=0
  done
  printf "]"
}


# -----------------------------------------
# 1. node_modules scan
# -----------------------------------------
echo "📦 Scanning node_modules ..."

NODE_HITS=""
if [ -d "$PROJECT_PATH/node_modules" ]; then
  while IFS= read -r pkg; do
    # Check if a directory with the package name exists
    if [ -d "$PROJECT_PATH/node_modules/$pkg" ]; then
      NODE_HITS="$NODE_HITS $pkg"
    fi
  done < "$IOC_FILE"
fi


# -----------------------------------------
# 2. package-lock.json
# -----------------------------------------
echo "🔐 Scanning package-lock.json ..."

LOCK_HITS=""
if [ -f "$PROJECT_PATH/package-lock.json" ]; then
  while IFS= read -r pkg; do
    # Grep for the package name as a key, e.g., "pkgname":
    # Using -q for quiet mode (faster, stops on first match)
    if grep -q "\"$pkg\"" "$PROJECT_PATH/package-lock.json"; then
      LOCK_HITS="$LOCK_HITS $pkg"
    fi
  done < "$IOC_FILE"
fi


# -----------------------------------------
# 3. yarn.lock
# -----------------------------------------
echo "🧵 Scanning yarn.lock ..."

YARN_HITS=""
if [ -f "$PROJECT_PATH/yarn.lock" ]; then
  while IFS= read -r pkg; do
    # Grep for the package name. Add "@" for better accuracy in yarn.lock
    if grep -q "$pkg@" "$PROJECT_PATH/yarn.lock"; then
      YARN_HITS="$YARN_HITS $pkg"
    fi
  done < "$IOC_FILE"
fi


# -----------------------------------------
# 4. pnpm-lock.yaml
# -----------------------------------------
echo "📦 Scanning pnpm-lock.yaml ..."

PNPM_HITS=""
if [ -f "$PROJECT_PATH/pnpm-lock.yaml" ]; then
  while IFS= read -r pkg; do
    # Grep for the package name followed by a colon
    if grep -q "$pkg:" "$PROJECT_PATH/pnpm-lock.yaml"; then
      PNPM_HITS="$PNPM_HITS $pkg"
    fi
  done < "$IOC_FILE"
fi


# -----------------------------------------
# 5. npm ls
# -----------------------------------------
echo "🌳 Running npm ls scans (may take a while) ..."

LS_HITS=""
while IFS= read -r pkg; do
  # Run npm ls for the specific package
  # We pipe to /dev/null to silence the command's output
  # The command will exit with 0 if found, 1 if not
  if (cd "$PROJECT_PATH" && npm ls "$pkg" --all >/dev/null 2>&1); then
    # Double-check... npm ls can be tricky.
    # We run it again, this time checking the output contains the package name
    if (cd "$PROJECT_PATH" && npm ls "$pkg" --all 2>/dev/null | grep -q "$pkg"); then
      LS_HITS="$LS_HITS $pkg"
    fi
  fi
done < "$IOC_FILE"


# ---------- Write JSON result ----------
{
  echo "    \"node_modules\": $(json_list node_modules "$NODE_HITS"),"
  echo "    \"npm_ls\": $(json_list npm_ls "$LS_HITS"),"
  echo "    \"package_lock\": $(json_list package_lock "$LOCK_HITS"),"
  echo "    \"yarn_lock\": $(json_list yarn_lock "$YARN_HITS"),"
  echo "    \"pnpm_lock\": $(json_list pnpm_lock "$PNPM_HITS")"
  echo "  }"
  echo "}"
} >> "$REPORT"

echo "✅ Scan complete."
echo "📄 Report saved to $REPORT"