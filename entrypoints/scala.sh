#!/bin/bash

declare -gx SOURCEDIR
SOURCEDIR=$(dirname "$0")
readonly SOURCEDIR

# shellcheck disable=SC1091
# shellcheck source=util.sh
source "${SOURCEDIR}/util.sh"

declare -gx BASE
BASE="$(pwd)"
readonly BASE

snyk_sbtfile(){
  set_debug

  local manifest
  manifest=$(basename "$1")
  local project_path
  project_path=$(dirname "$1")
  
  local prefix
  prefix=${project_path#"${SNYK_TARGET}"}

  cd "${project_path}" || exit
  
  if [[ -f ".snyk.d/prep.sh" ]]; then
    use_custom
  else
    timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    ( echo "${timestamp}| sbt dependencyTree for ${prefix}/${manifest}: $(sbt dependencyTree -Dsbt.log.noformat=true)" >> "${SNYK_LOG_FILE}" ) 2>&1 | tee -a "${SNYK_LOG_FILE}"

    if grep -qE -e "snyk-sbt-plugin.*UNRESOLVED DEPENDENCIES" "${SNYK_LOG_FILE}"; then
      # The dependency resolution plugin that snyk uses for Scala does not exit
      # with an error code when there are unresolved dependencies (e.g.,
      # private Artifactory deps), so we need to force Snyk to treat this case
      # as a failure.
      return 1
    fi
  fi

  run_snyk "${manifest}" "sbt" "${prefix}/${manifest}"

  cd "${BASE}" || exit
}

scala::main() {
  declare -x SNYK_LOG_FILE

  cmdline "$@"

  set_debug
  
  SNYK_IGNORES=""
  snyk_excludes "${SNYK_TARGET}" SNYK_IGNORES
  readonly SNYK_IGNORES

  local sbtfiles

  set -o noglob
  readarray -t sbtfiles < <(sort_manifests "$(find "${SNYK_TARGET}" -type f -name "build.sbt" $SNYK_IGNORES)")
  set +o noglob

  for sbtfile in "${sbtfiles[@]}"; do
    snyk_sbtfile "${sbtfile}"
  done

  output_json

  if [[ "${SNYK_JSON_STDOUT}" == 1 ]]; then
    stdout_json
  fi

  if [[ "${SNYK_TEST_COUNT}" == 1 ]]; then
    stdout_test_count
  fi

}

scala::main "$@"

