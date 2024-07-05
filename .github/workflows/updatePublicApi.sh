#!/usr/bin/env bash

mkdir -p build
cd build || exit
pwd


readonly microservices="ms-gp-auth ms-gp-pushnotifications ms-gp-events"
read -a msArray <<< "${microservices}"
# First add 'shared-openapi.json', as the first openapi.json defines title, description, etc. of the merged openapi.json
inputsOfMergeJson=("{'inputFile': '../shared-openapi.json','operationSelection': {'includeTags': ['PublicAPI']}}")
for ms in "${msArray[@]}"
do
  echo "Import openapi.json of ${ms}..."
  mkdir -p "${ms}"
  cd "${ms}"
  git init
  git remote add -f origin git@github.com:moost-io/${ms}.git
  git config core.sparseCheckout true
  echo "docs/openapi/openapi.json" >> .git/info/sparse-checkout
  git pull --quiet origin master
  cd -
  inputsOfMergeJson+=("{'inputFile': '${ms}/docs/openapi/openapi.json','operationSelection': {'includeTags': ['PublicAPI']}}")
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

