#!/usr/bin/env bash

# Patches the Gradle Tooling API bundled with jdtls.
#
# jdtls bundles Buildship (Eclipse Gradle integration) which includes a
# Gradle Tooling API jar. Buildship uses this to spawn Gradle daemons for
# project import. If the bundled version is too old, it spawns a daemon
# with a Groovy/ASM that can't handle newer Java class file versions
# (e.g., Tooling API 8.9 → Gradle 8.9 → Groovy 3.0.21 → no Java 25).
#
# This script replaces the bundled Tooling API with a newer version while
# preserving OSGi compatibility with Buildship's version constraint.

set -euo pipefail

# The Gradle version whose Tooling API we want to use.
GRADLE_TOOLING_API_VERSION="9.2.1"
GRADLE_TOOLING_API_URL="https://repo.gradle.org/gradle/libs-releases/org/gradle/gradle-tooling-api/${GRADLE_TOOLING_API_VERSION}/gradle-tooling-api-${GRADLE_TOOLING_API_VERSION}.jar"

# Buildship's Require-Bundle constraint is [8.9.0, 8.10.0), so we label
# the replacement jar as 8.9.1 to satisfy it.
OSGI_BUNDLE_VERSION="8.9.1.gradle-${GRADLE_TOOLING_API_VERSION}"

patch_tooling_api() {
  local install_path="$1"
  local plugins_dir="${install_path}/plugins"

  # Find the existing Tooling API jar
  local old_jar
  old_jar=$(find "$plugins_dir" -maxdepth 1 -name 'org.gradle.toolingapi_*.jar' | head -1)

  if [ -z "$old_jar" ]; then
    echo "No bundled Gradle Tooling API jar found, skipping patch."
    return 0
  fi

  local old_name
  old_name=$(basename "$old_jar")

  # Check if the bundled version is already 9.x+
  if [[ "$old_name" =~ org\.gradle\.toolingapi_9\. ]]; then
    echo "Bundled Tooling API is already 9.x, skipping patch."
    return 0
  fi

  echo "Patching Gradle Tooling API: ${old_name} → ${GRADLE_TOOLING_API_VERSION}..."

  local tmpdir
  tmpdir=$(mktemp -d)
  trap "rm -rf '$tmpdir'" RETURN

  local new_jar_name="org.gradle.toolingapi_${OSGI_BUNDLE_VERSION}.jar"

  # Download the new Tooling API
  echo "  Downloading gradle-tooling-api-${GRADLE_TOOLING_API_VERSION}..."
  curl -fsSL -o "${tmpdir}/tooling-api.jar" "$GRADLE_TOOLING_API_URL" \
    || { echo "Warning: Failed to download Tooling API ${GRADLE_TOOLING_API_VERSION}, skipping patch."; return 0; }

  # Extract the old manifest's Export-Package header to reuse it
  local old_exports
  old_exports=$(_extract_export_packages "$old_jar" "$tmpdir")

  # Build the new OSGi manifest
  _write_manifest "${tmpdir}/MANIFEST.MF" "$old_exports"

  # Repackage: copy the downloaded jar and replace its manifest
  cp "${tmpdir}/tooling-api.jar" "${tmpdir}/${new_jar_name}"
  mkdir -p "${tmpdir}/meta/META-INF"
  _fold_manifest "${tmpdir}/MANIFEST.MF" > "${tmpdir}/meta/META-INF/MANIFEST.MF"
  (cd "${tmpdir}/meta" && zip -q "${tmpdir}/${new_jar_name}" META-INF/MANIFEST.MF)

  # Swap jars
  rm -f "$old_jar"
  cp "${tmpdir}/${new_jar_name}" "${plugins_dir}/${new_jar_name}"

  # Update config.ini references across all platform configs
  _update_config_ini "$install_path" "$old_name" "$new_jar_name"

  echo "  Tooling API patched successfully."
}

_extract_export_packages() {
  local jar="$1"
  local tmpdir="$2"

  # Extract manifest, unfold continuation lines, grab Export-Package value
  unzip -p "$jar" META-INF/MANIFEST.MF > "${tmpdir}/old-manifest.txt"
  # Unfold: lines starting with a space are continuations
  perl -0pe 's/\r?\n //g' "${tmpdir}/old-manifest.txt" > "${tmpdir}/old-manifest-unfolded.txt"
  grep '^Export-Package:' "${tmpdir}/old-manifest-unfolded.txt" | sed 's/^Export-Package: //' || true
}

_write_manifest() {
  local output="$1"
  local exports="$2"

  # If we couldn't extract exports, generate them from the 9.2.1 jar
  if [ -z "$exports" ]; then
    exports="org.gradle.tooling;version=\"${OSGI_BUNDLE_VERSION}\""
  fi

  cat > "$output" << MANIFEST
Manifest-Version: 1.0
Bundle-ManifestVersion: 2
Bundle-Name: Gradle Tooling API
Bundle-Vendor: Gradle Inc.
Bundle-SymbolicName: org.gradle.toolingapi
Bundle-Version: ${OSGI_BUNDLE_VERSION}
Bundle-ClassPath: .
Bundle-RequiredExecutionEnvironment: JavaSE-1.8
Import-Package: org.slf4j;version="1.7.2"
Export-Package: ${exports}
MANIFEST
}

_fold_manifest() {
  # MANIFEST.MF requires lines ≤ 72 bytes, with continuation lines
  # starting with a single space character.
  local file="$1"
  awk '{
    line = $0
    while (length(line) > 70) {
      print substr(line, 1, 70)
      line = " " substr(line, 71)
    }
    print line
  }' "$file"
}

_update_config_ini() {
  local install_path="$1"
  local old_name="$2"
  local new_name="$3"

  find "$install_path" -name 'config.ini' | while read -r config; do
    if grep -q "$old_name" "$config"; then
      sed -i.bak "s|${old_name}|${new_name}|g" "$config"
      rm -f "${config}.bak"
    fi
  done
}
