#!/usr/bin/env bash

set -euo pipefail

JDTLS_RELEASES_URL="https://download.eclipse.org/jdtls/milestones/?d"
GH_REPO="https://github.com/eclipse/eclipse.jdt.ls"

fail() {
  echo -e "asdf-jdtls: $*" >&2
  exit 1
}

curl_opts=(-fsSL)

if [ -n "${GITHUB_API_TOKEN:-}" ]; then
  curl_opts=("${curl_opts[@]}" -H "Authorization: token $GITHUB_API_TOKEN")
fi

# Fetch all available versions from JDTLS releases page
list_all_versions() {
  local versions
  versions=$(curl "${curl_opts[@]}" "$JDTLS_RELEASES_URL" | 
             grep -o "<a href='/jdtls/milestones/[0-9][^']*'>" | 
             sed -n "s|.*'/jdtls/milestones/\([0-9][^']*\)'.*|\1|p")
  
  echo "$versions"
}

# Sort versions
sort_versions() {
  sed 'h; s/[+-]/./g; s/.p\([[:digit:]]\)/.z\1/; s/$/.z/; G; s/\n/ /' |
    LC_ALL=C sort -t. -k 1,1 -k 2,2n -k 3,3n -k 4,4n -k 5,5n | awk '{print $2}'
}

download_release() {
  local version="$1"
  local download_path="$2"
  local archive_url
  local archive_file
  local version_page_url="https://download.eclipse.org/jdtls/milestones/${version}/"
  
  echo "* Examining JDTLS release $version..."
  
  # Get the directory listing to find the correct tar.gz file
  local file_name
  file_name=$(curl "${curl_opts[@]}" "$version_page_url" | 
              grep -o "jdt-language-server-${version}-[0-9]\{12\}.tar.gz" | 
              head -1)
  
  if [ -z "$file_name" ]; then
    # Try alternate pattern with just the version number
    file_name=$(curl "${curl_opts[@]}" "$version_page_url" | 
                grep -o "jdt-language-server-${version}.tar.gz" | 
                head -1)
  fi
  
  if [ -z "$file_name" ]; then
    fail "Could not find JDTLS release file for version $version"
  fi
  
  # Construct download URL
  archive_url="https://www.eclipse.org/downloads/download.php?file=/jdtls/milestones/${version}/${file_name}"
  archive_file="${download_path}/jdtls-${version}.tar.gz"
  
  echo "* Downloading JDTLS release $version file: $file_name"
  curl "${curl_opts[@]}" -o "$archive_file" "$archive_url" || fail "Could not download $archive_url"
}

install_version() {
  local install_type="$1"
  local version="$2"
  local install_path="$3"
  local download_path="${install_path}/download"
  local archive_file="${download_path}/jdtls-${version}.tar.gz"
  
  if [ "$install_type" != "version" ]; then
    fail "asdf-jdtls supports release installs only"
  fi
  
  mkdir -p "$download_path"
  download_release "$version" "$download_path"
  
  echo "* Installing JDTLS version $version..."
  
  mkdir -p "$install_path"
  
  # Extract in the install directory
  tar -xzf "$archive_file" -C "$install_path" || fail "Could not extract $archive_file"
  
  # Make the jdtls wrapper script executable
  local wrapper_path="${plugin_dir}/bin/jdtls"
  
  # Create bin directory and copy the wrapper script
  mkdir -p "${install_path}/bin"
  cp "$wrapper_path" "${install_path}/bin/jdtls"
  chmod +x "${install_path}/bin/jdtls"
  
  # Clean up download directory
  rm -rf "$download_path"
  
  echo "* JDTLS $version installation complete!"
}

