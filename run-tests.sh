#!/bin/bash

unset ROOT
unset SETTINGS_FILE_NAME
unset SETTINGS_FILE
unset PROJECT
unset GPG_KEY_ID
unset GPG_KEY_UID
unset RUNNER_PACKAGE_NAME

ROOT=$(readlink -f "$(dirname "$0")")
SETTINGS_FILE_NAME=testbasher-settings.json
SETTINGS_FILE="$ROOT/$SETTINGS_FILE_NAME"
PROJECT=perihelios/total-garbage
GPG_KEY_ID=547B76E4C0C322E8
GPG_KEY_UID="Perihelios LLC <pgp@perihelios.com>"
RUNNER_PACKAGE_NAME=dummy.tar.gz

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

getSettingsVersion() {
	if [ ! -f "$SETTINGS_FILE" ]; then
		fail "ERROR: $SETTINGS_FILE_NAME not found in $ROOT"
	fi

	local version
	version=`jq -r .version "$SETTINGS_FILE" 2>/dev/null`

	if [ $? -ne 0 ]; then
		fail "ERROR: Failed to parse $SETTINGS_FILE as JSON"
	fi

	if [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
		fail "ERROR: Improper version \"$version\" specified in $SETTINGS_FILE"
	fi

	echo "$version"
}

ensureGpgKeyInKeystore() {
	if ! gpg --list-keys $GPG_KEY_ID >/dev/null 2>&1; then
		fail "ERROR: GPG key for \"$GPG_KEY_UID\" (key ID $GPG_KEY_ID) not found in keystore; did you import it?"
	fi
}

init() {
	local version

	if [ -e "$ROOT/testbasher-settings.json" ]; then
		fail "ERROR: testbasher-settings.json already exists in $ROOT"
	fi

	version=`getLatestVersion` || exit $?

	echo -e "{\n  \"version\": \"$version\"\n}" > "$ROOT/testbasher-settings.json"

	ensureRunnerPresent
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

download() {
	local url="$1"
	local localFile="$2"
	local downloadDescription="$3"
	local httpCode
	local errorMessage

	IFS=$'\t' read -r errorMessage httpCode < <(curl -s -S --fail --connect-timeout 15 -w '%{http_code}\n' -o "$localFile" "$url" 2>&1 | sed ':a;N;s/\n/\t/;ta')

	if [ -z "$httpCode" ]; then
		httpCode="$errorMessage"
	fi

	case "$httpCode" in
		200)
		;;
		3[0-9][0-9])
			fail "ERROR: Unexpected redirect ($httpCode) trying to download $downloadDescription from $url"
		;;
		404)
			fail "ERROR: Could not find $downloadDescription at $url"
		;;
		*)
			fail "ERROR: Failed to download $downloadDescription from $url - $errorMessage"
		;;
	esac
}

ensureRunnerPresent() {
	local version
	version=`getSettingsVersion` || exit $?

	local runnerDir="$ROOT/.runner/$version"

	if [ ! -d "$runnerDir" ]; then
		local runnerDownloadDir="$ROOT/.runner/download"
		local runnerDownloadPackage="$runnerDownloadDir/$RUNNER_PACKAGE_NAME"
		local runnerDownloadPackageSig="$runnerDownloadPackage.asc"

		rm -rf "$runnerDownloadDir"
		mkdir -p "$runnerDownloadDir"

		local githubPrefix="https://raw.githubusercontent.com/$PROJECT/$version"

		download "$githubPrefix/$RUNNER_PACKAGE_NAME" "$runnerDownloadPackage" "test runner version $version"
		download "$githubPrefix/$RUNNER_PACKAGE_NAME.asc" "$runnerDownloadPackageSig" "GPG signature for test runner version $version"

		if gpg --verify "$runnerDownloadPackageSig" "$runnerDownloadPackage" >/dev/null 2>&1; then
			tar -xzf "$runnerDownloadPackage" -C "$runnerDownloadDir"
			rm "$runnerDownloadPackage" "$runnerDownloadPackageSig"
			mv "$runnerDownloadDir" "$runnerDir"
		else
			fail "ERROR: SECURITY! Downloaded runner script FAILED GPG VERIFICATION!" >&2
		fi
	fi
}

if checkForInit "$@"; then
	exit 0
fi
