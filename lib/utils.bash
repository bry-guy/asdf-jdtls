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

version_ge() {
  local left="$1"
  local right="$2"
  local first

  first=$(printf '%s\n%s\n' "$left" "$right" | sort_versions | tail -1)
  [[ "$first" == "$left" ]]
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
    grep -Eo "$pattern" |
    head -1
}

web_download_file() {
  local url="$1"
  local output_file="$2"

  echo "Downloading from $url..."
  curl "${CURL_OPTS[@]}" -o "$output_file" "$url" || fail "Could not download $url"
}

verify_sha256_file() {
  local checksum_file="$1"
  local target_file="$2"
  local expected actual line

  line=$(tr -d '\r' < "$checksum_file" | head -1)
  expected=$(printf '%s\n' "$line" | awk '{print $1}')

  if [ -z "$expected" ]; then
    fail "Checksum file $checksum_file is empty"
  fi

  if command -v sha256sum >/dev/null; then
    actual=$(sha256sum "$target_file" | awk '{print $1}')
  elif command -v shasum >/dev/null; then
    actual=$(shasum -a 256 "$target_file" | awk '{print $1}')
  else
    fail "Neither sha256sum nor shasum is available for checksum verification"
  fi

  [ "$expected" = "$actual" ]
}

web_download_and_verify_sha256() {
  local url="$1"
  local output_file="$2"
  local checksum_url="${url}.sha256"
  local checksum_file="${output_file}.sha256"

  web_download_file "$url" "$output_file"

  if curl "${CURL_OPTS[@]}" -o "$checksum_file" "$checksum_url"; then
    echo "Verifying SHA256 checksum..."
    (cd "$(dirname "$output_file")" && verify_sha256_file "$(basename "$checksum_file")" "$(basename "$output_file")") || fail "Checksum verification failed for $output_file"
  else
    echo "Checksum not available at $checksum_url, skipping verification."
  fi
}

# ---- JDTLS release metadata ----

jdtls_releases_url() {
  echo "https://download.eclipse.org/jdtls/milestones/?d"
}

jdtls_release_dir_url() {
  local version="$1"
  echo "https://download.eclipse.org/jdtls/milestones/${version}/"
}

jdtls_list_versions() {
  web_list_versions_from_html "$(jdtls_releases_url)" "'/jdtls/milestones/\([0-9][^']*\)'"
}

jdtls_latest_version() {
  jdtls_list_versions | tail -1
}

jdtls_min_java_for_version() {
  local version="$1"

  if version_ge "$version" "1.55.0"; then
    echo 21
  elif version_ge "$version" "1.0.0"; then
    echo 17
  else
    echo 11
  fi
}

jdtls_latest_compatible_version() {
  local java_major="$1"
  local version
  local compatible=""

  while IFS= read -r version; do
    if [ "$(jdtls_min_java_for_version "$version")" -le "$java_major" ]; then
      compatible="$version"
    fi
  done < <(jdtls_list_versions)

  [ -n "$compatible" ] || fail "Could not find a JDTLS release compatible with Java ${java_major}"
  echo "$compatible"
}

jdtls_resolve_version() {
  local requested="$1"

  case "$requested" in
    latest)
      jdtls_latest_version
      ;;
    latest-java*)
      local java_major="${requested#latest-java}"
      [[ "$java_major" =~ ^[0-9]+$ ]] || fail "Invalid Java selector: $requested"
      jdtls_latest_compatible_version "$java_major"
      ;;
    latest-compatible)
      local java_major
      java_major=$(java_detect_major) || fail "latest-compatible requires a detectable Java runtime"
      jdtls_latest_compatible_version "$java_major"
      ;;
    *)
      echo "$requested"
      ;;
  esac
}

jdtls_find_archive_name() {
  local version="$1"
  local url
  url=$(jdtls_release_dir_url "$version")

  web_find_file "$url?d" "jdt-language-server-${version}-[0-9]+\\.tar\\.gz"
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

java_path() {
  if command -v java >/dev/null; then
    command -v java
  elif [ -n "${JAVA_HOME:-}" ] && [ -x "$JAVA_HOME/bin/java" ]; then
    echo "$JAVA_HOME/bin/java"
  else
    return 1
  fi
}

java_ensure() {
  local java_bin
  java_bin=$(java_path) || fail "java not found in path and JAVA_HOME is unset or invalid."
  echo "Found java: $java_bin"
}

java_detect_major() {
  local java_bin
  local version_line
  local version_string

  java_bin=$(java_path) || return 1
  version_line=$("$java_bin" -version 2>&1 | head -1)
  version_string=$(printf '%s\n' "$version_line" | sed -E 's/.*version "([^"]+)".*/\1/')

  if [[ "$version_string" =~ ^1\.([0-9]+)\..*$ ]]; then
    echo "${BASH_REMATCH[1]}"
  elif [[ "$version_string" =~ ^([0-9]+)(\..*)?$ ]]; then
    echo "${BASH_REMATCH[1]}"
  else
    return 1
  fi
}

java_check_compatibility() {
  local jdtls_version="$1"
  local min_java
  local detected_java

  min_java=$(jdtls_min_java_for_version "$jdtls_version")
  detected_java=$(java_detect_major || true)

  if [ -z "$detected_java" ]; then
    echo "Warning: could not detect a Java runtime. JDTLS $jdtls_version requires Java $min_java+."
    return 0
  fi

  if [ "$detected_java" -lt "$min_java" ]; then
    return 1
  fi

  return 0
}
