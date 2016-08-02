#!/bin/bash

unset ROOT PROJECT
ROOT=$(readlink -f "$(dirname "$0")")
PROJECT=perihelios/total-garbage

fail() {
	local message="$1"

	echo "$message" >&2
	exit 2
}

getLatestVersion() {
	local response
	response=`curl -s -S --fail https://api.github.com/repos/$PROJECT/tags 2>&1`

	if [ $? -ne 0 ]; then
		fail "ERROR: Failed to get tags for project $PROJECT from GitHub - $response"
	fi

	local versions
	versions=`jq -r '.[].name' <<<"$response" 2>/dev/null`

	if [ $? -ne 0 ]; then
		fail "ERROR: Failed to parse response from GitHub as JSON while looking for tags on project $PROJECT"
	fi

	sort -rn -t . -k1,1 -k2,2 -k3,3 <<<"$versions" | head -1
}

init() {
	local version

	if [ -e "$ROOT/testbasher-settings.json" ]; then
		fail "ERROR: testbasher-settings.json already exists in $ROOT"
	fi

	version=`getLatestVersion` || exit $?

	echo -e "{\n  \"version\": \"$version\"\n}" > "$ROOT/testbasher-settings.json"
}

checkForInit() {
	local i

	if [ $# -eq 1 ]; then
		if [ "$1" = "--init" ]; then
			init
			return 0
		fi
	elif [ $# -gt 0 ]; then
		for ((i=1; i<=$#; i++)); do
			if [ "${!i}" = "--init" ]; then
				fail "ERROR: --init option cannot be used with any other arguments"
			fi
		done
	fi

	return 1
}

checkForInit "$@"
