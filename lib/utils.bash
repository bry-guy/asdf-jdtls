#!/usr/bin/env bash

set -euo pipefail

# ---- Error handling ----

fail() {
  echo -e "ERROR: $*" >&2
  exit 1
}

# ---- Common curl setup ----

CURL_OPTS=(-fsSL)
if [ -n "${GITHUB_API_TOKEN:-}" ]; then
  CURL_OPTS=("${CURL_OPTS[@]}" -H "Authorization: token $GITHUB_API_TOKEN")
fi

sort_versions() {
  sed 'h; s/[+-]/./g; s/.p\([[:digit:]]\)/.z\1/; s/$/.z/; G; s/\n/ /' |
    LC_ALL=C sort -t. -k 1,1 -k 2,2n -k 3,3n -k 4,4n -k 5,5n | awk '{print $2}'
}

# ---- GitHub functions ----

github_list_tags() {
  local repo="$1"
  
  git ls-remote --tags --refs "https://github.com/${repo}.git" |
    grep -o 'refs/tags/.*' |
    cut -d/ -f3- |
    sed 's/^v//' |
    sort_versions
}

github_download_source() {
  local repo="$1"
  local version="$2"
  local output_file="$3"
  
  # Add 'v' prefix to tag if not present and if it's not already in the tag
  local tag_prefix
  if [[ "$version" != v* ]]; then
    tag_prefix="v$version"
  else
    tag_prefix="$version"
  fi
  
  local url="https://github.com/${repo}/archive/refs/tags/${tag_prefix}.tar.gz"
  
  echo "* Downloading source for ${repo} ${version}..."
  curl "${CURL_OPTS[@]}" -o "$output_file" "$url" || fail "Could not download $url"
}

# ---- Web download functions ----

web_list_versions_from_html() {
  local url="$1"
  local pattern="$2"
  
  curl "${CURL_OPTS[@]}" "$url" |
    grep -o "$pattern" |
    sed -n "s|.*$pattern.*|\1|p" |
    sort_versions
}

web_find_file() {
  local url="$1"
  local pattern="$2"
  
  curl "${CURL_OPTS[@]}" "$url" |
    grep -o "$pattern" |
    head -1
}

web_download_file() {
  local url="$1"
  local output_file="$2"
  
  echo "* Downloading from $url..."
  curl "${CURL_OPTS[@]}" -o "$output_file" "$url" || fail "Could not download $url"
}

# ---- Build functions ----

maven_build() {
  local source_path="$1"
  
  # Change to the source directory
  cd "$source_path"
  
  # First try using the Maven wrapper
  if [ -f "./mvnw" ]; then
    chmod +x "./mvnw"
    echo "* Building with Maven wrapper..."
    ./mvnw clean install -DskipTests || fail "Maven build failed"
  else
    # Fall back to system Maven
    if ! command -v mvn >/dev/null; then
      fail "Maven is required but not found"
    fi
    
    echo "* Building with system Maven..."
    mvn clean install -DskipTests || fail "Maven build failed"
  fi
}

# ---- Java functions ----

java_ensure() {
  if [ -n "${JAVA_HOME:-}" ]; then
    if [ ! -x "$JAVA_HOME/bin/java" ]; then
      fail "JAVA_HOME is set but $JAVA_HOME/bin/java is not executable"
    fi
  elif ! command -v java >/dev/null; then
    fail "Java is required but not found. Set JAVA_HOME or ensure java is in PATH."
  fi
}

java_get_exe() {
  if [ -n "${JAVA_HOME:-}" ]; then
    echo "$JAVA_HOME/bin/java"
  else
    command -v java
  fi
}
