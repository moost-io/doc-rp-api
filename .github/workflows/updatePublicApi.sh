#!/usr/bin/env bash

mkdir -p build
cd build || exit
pwd

readonly microservices="ms-gp-events ms-gp-pushnotifications ms-gp-auth"
read -a msArray <<< "${microservices}"
inputsOfMergeJson=()
for ms in "${msArray[@]}"
do
  echo "Import openapi.json of ${ms}..."
  mkdir -p "${ms}"
  openapiFile="${ms}/openapi.json"
  curl -s -o "${openapiFile}" "https://moost-io.github.io/${ms}/openapi/openapi.json"
  inputsOfMergeJson+=("{'inputFile': '${openapiFile}','operationSelection': {'includeTags': ['PublicAPI']}}")
done

echo "Generate merge config for Public API..."
openapiInputsJson=$(IFS=, ; echo "${inputsOfMergeJson[*]}")
readonly openapiMergeResultFile="openapi.json"
readonly openapiMergeConfigFile="openapi-merge-config.json"
readonly openapiMergeConfigJson="{'inputs': [${openapiInputsJson}],'output': '${openapiMergeResultFile}'}"
echo "${openapiMergeConfigJson}" > "${openapiMergeConfigFile}"

echo "Generate openapi.json of Public API..."
npx openapi-merge-cli --config "${openapiMergeConfigFile}"

cp "${openapiMergeResultFile}" ../../../docs/openapi/ || exit
cd ../../..

echo "Push to Git if Public API changed..."
git add "docs/openapi/${openapiMergeResultFile}"
set +e  # Grep succeeds with nonzero exit codes to show results.
git status | egrep '(modified|new file):' | grep "${openapiMergeResultFile}"
if [ $? -eq 0 ]
then
  set -e
  git config --global user.name "GitHub-CI-Workflow"
  git config --global user.email "GitHub.CI.Workflow@moost.io"
  git commit -m "Update Public API"
  git push
else
  set -e
  echo "No change"
fi
