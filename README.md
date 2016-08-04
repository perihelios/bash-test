# TestBasher

## Installation
TestBasher can be installed directly from the command line. Files will be
downloaded from the GitHub repo.

TestBasher has a number of dependencies that you'll need to install in the usual
way for your Linux distribution (using the package manager). The names of the
packages vary according to which distro you use; common package names are listed
in brackets.

* [GNU Privacy Guard (GPG)](https://www.gnupg.org/) [gpg2, gnupg2]
* [curl](https://curl.haxx.se/) [curl]
* [jq](https://stedolan.github.io/jq/) (version 1.5 or later) [jq]
* grep, sed, find, and other standard Linux utilities

For security, files downloaded for, or by, TestBasher will be verified against
signature files using GPG. You'll need to add the Perihelios LLC key to your GPG
keystore.

```
gpg --keyserver pgp.mit.edu --recv-keys 547B76E4C0C322E8
```

Successful output will indicate that the key for
`Perihelios LLC <pgp@perihelios.com>` was imported.

Next, you'll need to create a directory that will hold your test scripts and
the scripts that form the TestBasher "framework". This directory will be
somewhere inside the project containing the Bash scripts for which you're
writing the tests, and it can be named anything you want. `tests` or `.tests`
(if you want the directory to be "hidden"--see
[Should You Hide Your Tests?](#should-you-hide-your-tests)) are great choices.
Everything after this point will be inside this new directory, so you'll change
directories into it right after you create it.

```
mkdir tests
cd tests
```

Then, you'll need to download the bootstrap script and its GPG signature file
(see [Bootstrap Script](#bootstrap-script) for more details). You'll use the
signature file to verify the bootstrap script. You can use `curl`, `wget`, or
your browser for downloading; since `curl` is a required dependency of
TestBasher, you should already have it installed and can easily use it. You can
name the bootstrap script anything you want; `run-tests.sh` seems quite suitable.

```
curl -o run-tests.sh.asc https://raw.githubusercontent.com/perihelios/bash-test/master/run-tests.sh.asc
curl -o run-tests.sh https://raw.githubusercontent.com/perihelios/bash-test/master/run-tests.sh
gpg --verify run-tests.sh.asc run-tests.sh
```

Successful output will indicate that there was a good signature from
`Perihelios LLC <pgp@perihelios.com>`; there *may* be a warning that the key is
not certified with a trusted signature, but this is not a problem in this case.

The script needs to be executable, so set the permissions to allow it to run.

```
chmod +x run-tests.sh
```

TestBasher depends on settings contained in a JSON file, `test-settings.json`,
that lives in your tests directory, alongside the bootstrap script (see
[Test Settings](#test-settings) for details). One setting that's required to be
in the file is the version of TestBasher you want to run. This version helps
the TestBasher bootstrap script download the runner script from GitHub, if it's
not already found in a local cache. It also "locks" the version of TestBasher
you're using, so your tests don't suddenly break if someone blunders and
introduces a change to TestBasher that isn't compatible with your tests.

You can create this settings file automatically, with default settings. The
version of the runner scripts will be set to the latest available. The runner
scripts will also be downloaded, verified with GPG, and cached, so they are
ready for use.

```
./run-tests.sh --init
```

TestBasher stores the runner scripts it downloads in a hidden directory,
`.runners`, under your tests directory. This caching speeds up running your
tests, and also allows you to run "offline" (TestBasher, itself, will have no
need to connect to the Internet after the scripts are cached). There's normally
no reason to check this directory into your source repo, since the bootstrap
script will automatically download the correct runner scripts on each developer's
machine. You will normally only commit `run-tests.sh` (or whatever you named the
bootstrap script) and `test-settings.json` to your source repo.

TestBasher also stores data from the execution of your tests in a hidden
directory, `.execution`, under your tests directory. You do not want to commit
this directory to your source repo.

To avoid committing unwanted files to your source repo, use the appropriate
mechanism for your source repo software to exclude these two directories. For
Git, that's just a `.gitignore` file.

```
echo .runner >>.gitignore
echo .execution >>.gitignore
```

Installation is finished! Enjoy using TestBasher.

## Runners
A *runner* is a plugin for TestBasher that executes (runs) tests. Even the
default runner is implemented as a plugin. The bootstrap script (`run-tests.sh`,
or whatever you decided to call it) is responsible for downloading or locating
the runner you've configured in your `testbasher-settings.json` file. It then
invokes the runner, passing its arguments to the runner's entry script; all
responsibility for running the tests is delegated to that runner.

### An Example Runner
At its simplest, a runner consists of three things:

 * A manifest file written in JSON
 * A GPG signature file for the JSON manifest file
 * A shell script

Let's look at an example:

**my-runner.json**
```
{
	"entryPoint": "start-here.sh",
	"files": [
		{
			"url": "http://example.com/testbasher/runner/start-here-${version}.sh",
			"localPath": "start-here.sh",
			"sha256hash": "7d869044f50caa5aa1de7b783e001df190eaec24902729a1d64e532998a24bff"
		}
	]
}
```

**my-runner.json.asc**
```
-----BEGIN PGP SIGNATURE-----
Version: GnuPG v2

.
.
.
-----END PGP SIGNATURE-----
```

**start-here-1.7.sh**
```
#!/bin/bash
echo 'Hello!'
```

The manifest, `my-runner.json`, can be named whatever you want. It will be
published at some URL, like `http://example.com/testbasher/1.7/my-runner.json`.
The GPG signature file must be named like the manifest file, just with a
trailing `.asc` extension. Its URL must be the same as that of the manifest,
except the additional extension:
`http://example.com/testbasher/my-runner.json.asc`. (The URL of the manifest
will be provided to the TestBasher bootstrap script in its settings file, and
the bootstrap script will look for the signature file by appending `.asc` to the
manifest file URL.)

TestBasher's bootstrap script will download the manifest and its signature, and
then verify the manifest against its signature using GPG. The key used to make
the signature must already be installed in the user's GPG keystore. If signature
verification fails, the runner plugin is considered invalid and will not be
used.

The entry script in our example says, "Hello!" and exits--obviously not much of
a test runner. The important thing to notice is how it gets downloaded and
verified based on the manifest.

According to the manifest, a file (our entry script) lives at the URL
`http://example.com/testbasher/runner/start-here-${version}.sh`. As you have
doubtless guessed, `${version}` is a variable; it will automatically be replaced
by the `version` property in `testbasher-settings.json` before the URL is used
to download the file. The manifest also says this file should be put in the
local path `start-here.sh`, even though the file's name in the URL is different
(because the version number is part of the filename in the URL). This path is
always relative to some directory where TestBasher has chosen to place the files
after downloading (plugins should not care where their files are placed).

The file has one remaining property in the manifest: `sha256hash`, which must
match the SHA-256 checksum of the file after it is downloaded, or the plugin
will be considered invalid. This provides GPG signing security for all files in
the plugin, without needing a GPG signature for every file: The manifest
specifies the hash of all the other files composing the plugin, and the
manifest, itself, is signed with a GPG key.

Notice that the `localPath` property of the file matches the higher-level
`entryPoint` property in the manifest. The bootstrap script needs to know what
script to invoke in the plugin when delegating to it. There could be many
scripts in a runner, with all kinds of names, depending on how the developer has
chosen to organize their code; the bootstrap script will call only one,
specified by `entryPoint`, and that file *must* exist after all the plugin files
specified in the manifest are downloaded and renamed according to their
`localPath` rules, or the plugin is viewed as invalid and will not be invoked.

