#!/bin/bash -u

unset ROOT
unset SETTINGS_FILE_NAME
unset SETTINGS_FILE
unset PROJECT
unset GPG_KEY_FINGERPRINT
unset GPG_KEY_SUBJECT
unset RUNNER_PACKAGE_NAME

ROOT=$(readlink -f "$(dirname "$0")")
SETTINGS_FILE_NAME=testbasher-settings.json
SETTINGS_FILE="$ROOT/$SETTINGS_FILE_NAME"
PROJECT=perihelios/total-garbage
GPG_KEY_FINGERPRINT=1F358F99E6314E45B4AAFA7F547B76E4C0C322E8
GPG_KEY_SUBJECT="Perihelios LLC <pgp@perihelios.com>"
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
	local gpgKeyFingerprint="$1"
	local gpgKeySubject="$2"

	if ! gpg --batch --no-tty --list-keys "$gpgKeyFingerprint" >/dev/null 2>&1; then
		fail "ERROR: GPG key for \"$gpgKeySubject\" (key ID/fingerprint $gpgKeyFingerprint) not found in keystore; did you import it?"
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

downloadVerified() {
	local url="$1"
	local localFile="$2"
	local downloadDescription="$3"
	local gpgKeyFingerprint="$4"
	local gpgKeySubject="$5"
	local signatureUrl="$url.asc"
	local signatureLocalFile="$localFile.asc"

	ensureGpgKeyInKeystore "$gpgKeyFingerprint" "$gpgKeySubject"

	download "$url" "$localFile" "$downloadDescription"
	download "$signatureUrl" "$signatureLocalFile" "$downloadDescription GPG signature"

	local verifyOutput
	verifyOutput=`gpg --batch --no-tty --status-fd 1 --verify "$signatureLocalFile" "$localFile" 2>/dev/null`

	if [ $? -ne 0 ]; then
		fail "ERROR: SECURITY! Downloaded file $localFile FAILED GPG VERIFICATION!"
	fi

	local line
	local verifiedWithFingerprint

	while IFS='' read -r line || [ -n "$line" ]; do
		if [[ "$line" =~ VALIDSIG\ ([0-9A-F]+) ]]; then
			verifiedWithFingerprint="${BASH_REMATCH[1]}"
			break
		fi
	done <<<"$verifyOutput"

	if [ ! "$verifiedWithFingerprint" == "$gpgKeyFingerprint" ]; then
		fail "ERROR: SECURITY! Downloaded file $localFile signed with unexpected GPG key $verifiedWithFingerprint; expected $gpgKeyFingerprint"
	fi

	rm -f "$signatureLocalFile"
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

		downloadVerified "$githubPrefix/$RUNNER_PACKAGE_NAME" "$runnerDownloadPackage" "test runner version $version" "$GPG_KEY_FINGERPRINT" "$GPG_KEY_SUBJECT"

		tar -xzf "$runnerDownloadPackage" -C "$runnerDownloadDir"
		rm "$runnerDownloadPackage"
		mv "$runnerDownloadDir" "$runnerDir"
	fi
}

if checkForInit "$@"; then
	exit 0
fi
