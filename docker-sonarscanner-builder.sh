#!/bin/bash
set -o pipefail

fail() {
  echo "$1" >&2
  exit 1
}

declare -a docker_images
for image in "${GHCR_IMAGE:-}" "${DOCKER_IMAGE:-}"; do
  [ -n "$image" ] && docker_images+=("$image")
done
if [ "${#docker_images[@]}" -eq 0 ]; then
  fail "DOCKER_IMAGE or GHCR_IMAGE must be set"
fi
primary_docker_image="${docker_images[0]}"

publish_tags() {
  local source_tag="$1"
  local image tag
  shift

  for tag in "$@"; do
    for image in "${docker_images[@]}"; do
      if [ "$image" != "$primary_docker_image" ] || [ "$tag" != "$source_tag" ]; then
        docker tag "${primary_docker_image}:${source_tag}" "${image}:${tag}" || return 1
      fi
      docker push "${image}:${tag}" || return 1
    done
  done
}

# go to directory of current file
cd "$(dirname "$0")" || fail "unable to change to the script directory"

echo "executing docker-sonarscanner-builder"

echo ""
echo "============================="
echo "retrieving current dotnet-sonarscanner version"
if ! current_dotnet_sonarscanner_version_major_minor_patch="$(curl -s 'https://www.nuget.org/packages/dotnet-sonarscanner' | perl -p -e 's/\r?\n/ /' | perl -p -e 's/.*<span\s+class\s*=\s*"\s*version-title\s*"\s*>\s*((\d+\.)*\d+)\s*<\/span>.*/\1/')"; then
  fail "retrieving current dotnet-sonarscanner version failed"
fi
current_dotnet_sonarscanner_version_major_minor="$(echo "$current_dotnet_sonarscanner_version_major_minor_patch" | perl -p -e 's/^(\d+\.\d+).*?$/\1/')"
current_dotnet_sonarscanner_version_major="$(echo "$current_dotnet_sonarscanner_version_major_minor" | perl -p -e 's/^(\d+).*?$/\1/')"
for version in "$current_dotnet_sonarscanner_version_major_minor_patch" "$current_dotnet_sonarscanner_version_major_minor" "$current_dotnet_sonarscanner_version_major"; do
  if [ -z "$version" ] || [ "${#current_dotnet_sonarscanner_version_major_minor_patch}" -le 2 ] || [ "${#version}" -ge 20 ]; then
    fail "verify current dotnet-sonarscanner version failed"
  fi
done
echo "current dotnet-sonarscanner version is $current_dotnet_sonarscanner_version_major_minor_patch"

echo ""
echo "============================="
echo "retrieving current sonarqube-sonarscanner version"
# source: https://docs.sonarsource.com/sonarqube/latest/analyzing-source-code/scanners/sonarscanner/
if ! current_sonarqube_sonarscanner_versions_json="$(curl -s 'https://downloads.sonarsource.com/sonarqube/update/scannercli.json' | jq -c '.versions | map(select(.archived == false))')"; then
  fail "retrieving current sonarqube-sonarscanner version failed"
fi

# initialize array
declare -a current_sonarqube_sonarscanner_versions

# process JSON data
current_sonarqube_sonarscanner_items="$(echo "$current_sonarqube_sonarscanner_versions_json" | jq -c '.[]')"
while read -r item; do
  # extract version and download URL version
  version=$(echo "$item" | jq -r '.version')
  downloadUrl=$(echo "$item" | jq -r '.downloadURL | map(select(.label == "Linux x64")) | .[0].url')

  # extract full version
  fullVersion=$(echo "$downloadUrl" | perl -nle 'print $1 if /sonar-scanner-cli-((?:\d+\.)*\d+)-linux-x64.zip/')

  # default to previous version if not found
  fullVersion=${fullVersion:-$version}

  # append to array
  current_sonarqube_sonarscanner_versions+=("$fullVersion")

  # output detailed information
  echo "Version: $version"
  echo "Download URL: $downloadUrl"
  echo "Full version: $fullVersion"
  echo
done <<< "$current_sonarqube_sonarscanner_items"

# sort versions
mapfile -t current_sonarqube_sonarscanner_versions < <(printf "%s\n" "${current_sonarqube_sonarscanner_versions[@]}" | sort -Vur)
latest_sonarqube_sonarscanner_version=${current_sonarqube_sonarscanner_versions[0]}

echo "current sonarqube-sonarscanner versions:"
for version in "${current_sonarqube_sonarscanner_versions[@]}"; do
  echo "  - $version"
done

latest_sonarqube_sonarscanner_version_major_minor_patch_build="$(echo "$latest_sonarqube_sonarscanner_version" | perl -p -e 's/^((\d+\.){3}\d+).*?$/\1/')"
latest_sonarqube_sonarscanner_version_major_minor_patch="$(echo "$latest_sonarqube_sonarscanner_version_major_minor_patch_build" | perl -p -e 's/^((\d+\.){2}\d+).*?$/\1/')"
latest_sonarqube_sonarscanner_version_major_minor="$(echo "$latest_sonarqube_sonarscanner_version_major_minor_patch" | perl -p -e 's/^(\d+\.\d+).*?$/\1/')"
latest_sonarqube_sonarscanner_version_major="$(echo "$latest_sonarqube_sonarscanner_version_major_minor" | perl -p -e 's/^(\d+).*?$/\1/')"
for version in "$latest_sonarqube_sonarscanner_version_major_minor_patch_build" "$latest_sonarqube_sonarscanner_version_major_minor_patch" "$latest_sonarqube_sonarscanner_version_major_minor" "$latest_sonarqube_sonarscanner_version_major"; do
  if [ -z "$version" ] || [ "${#latest_sonarqube_sonarscanner_version_major_minor_patch_build}" -le 2 ] || [ "${#version}" -ge 20 ]; then
    fail "verify current sonarqube-sonarscanner version failed"
  fi
done
echo "latest sonarqube-sonarscanner version is $latest_sonarqube_sonarscanner_version_major_minor_patch_build"

echo ""
echo "============================="
echo "retrieving active dotnet sdk versions"
# source: https://dotnetcli.blob.core.windows.net/dotnet/release-metadata/releases-index.json
if ! active_dotnet_versions="$(curl -fsS 'https://dotnetcli.blob.core.windows.net/dotnet/release-metadata/releases-index.json' | jq -r '."releases-index"[] | select(."support-phase" == "active" or ."support-phase" == "maintenance") | ."channel-version"' | sort -Vu)"; then
  fail "retrieving active dotnet sdk versions failed"
fi
mapfile -t active_dotnet_versions_array <<< "$active_dotnet_versions"
echo "active dotnet sdk versions are: (the last one is considered latest)"
for dotnet_version in "${active_dotnet_versions_array[@]}"; do
  [ -z "$dotnet_version" ] && continue
  echo "  - .NET $dotnet_version"
done

any_failed=0
latest_dotnet_version=""
for dotnet_version in "${active_dotnet_versions_array[@]}"; do
  [ -z "$dotnet_version" ] && continue
  echo ""
  echo "============================="
  echo "build for .NET $dotnet_version ..."
  latest_dotnet_version="${dotnet_version}"
  image_tags=(
    "net${dotnet_version}"
    "${latest_sonarqube_sonarscanner_version_major_minor_patch}-net${dotnet_version}"
    "${latest_sonarqube_sonarscanner_version_major_minor}-net${dotnet_version}"
    "${latest_sonarqube_sonarscanner_version_major}-net${dotnet_version}"
    "${current_dotnet_sonarscanner_version_major_minor_patch}-for-dotnet-net${dotnet_version}"
    "${current_dotnet_sonarscanner_version_major_minor}-for-dotnet-net${dotnet_version}"
    "${current_dotnet_sonarscanner_version_major}-for-dotnet-net${dotnet_version}"
  )
  if ! (
    docker build --pull --platform linux/amd64 \
      --build-arg "SONAR_SCANNER_VERSION=${latest_sonarqube_sonarscanner_version_major_minor_patch_build}" \
      --build-arg "DOTNET_SONAR_SCANNER_VERSION=${current_dotnet_sonarscanner_version_major_minor_patch}" \
      --build-arg "DOTNET_VERSION=${dotnet_version}" \
      --tag "${primary_docker_image}:${image_tags[0]}" \
      -f Dockerfile . \
      && publish_tags "${image_tags[0]}" "${image_tags[@]}"
  ); then
    echo "build for .NET $dotnet_version failed" >&2
    any_failed=1
    latest_dotnet_version=""
  fi
done
if [ -z "$latest_dotnet_version" ]; then
  fail "no latest can be pushed"
fi
echo ""
echo "============================="
echo "push latest ..."
if ! publish_tags "net${latest_dotnet_version}" latest; then
  fail "push latest failed"
fi
if [ "$any_failed" -ge 1 ]; then
  fail "at least one build failed"
fi

echo ""
echo "============================="
echo "============================="
echo "finished"
