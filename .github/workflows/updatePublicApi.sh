#!/usr/bin/env bash

mkdir -p "build"
cd build || exit
pwd

readonly microservices="ms-gp-events ms-gp-pushnotifications"
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

echo "Generate merge config..."
openapiInputsJson=$(IFS=, ; echo "${inputsOfMergeJson[*]}")
readonly openapiMergeJson="{'inputs': [${openapiInputsJson}],'output': 'openapi.json'}"
readonly openapiMergeConfigFile="openapi-merge-config.json"
echo "${openapiMergeJson}" > "${openapiMergeConfigFile}"

echo "Generate Public API..."
npx openapi-merge-cli --config "${openapiMergeConfigFile}"

echo "Clean up"
#rm -rf "${buildDir}"