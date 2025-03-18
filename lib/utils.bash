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
  
  local url="https://github.com/${repo}/archive/refs/tags/${version}.tar.gz"
  
  echo "Downloading source for ${repo} ${version}..."
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
  
  echo "Downloading from $url..."
  curl "${CURL_OPTS[@]}" -o "$output_file" "$url" || fail "Could not download $url"
}

# ---- Build functions ----

maven_build() {
  local current_path=$(pwd)
  local source_path="$1"
  
  # Change to the source directory
  cd "$source_path"
  
  # First try using the Maven wrapper
  if [ -f "./mvnw" ]; then
    chmod +x "./mvnw"
    echo "Building with Maven wrapper..."
    ./mvnw clean install -DskipTests || fail "Maven build failed"
  else
    # Fall back to system Maven
    if ! command -v mvn >/dev/null; then
      fail "Maven is required but not found"
    fi
    
    echo "Building with system Maven..."
    mvn clean install -DskipTests || fail "Maven build failed"
  fi

  cd "$current_path"
}

# ---- Java functions ----

java_ensure() {
    if command -v java >/dev/null; then
        echo "Found java in path."
    elif [ -n "${JAVA_HOME:-}" ]; then
        echo "Looking for java in JAVA_HOME."
        if [ ! -x "$JAVA_HOME/bin/java" ]; then
            fail "$JAVA_HOME/bin/java is not executable"
        fi
    else
        fail "java not found in path and $JAVA_HOME is unset."
    fi
}

