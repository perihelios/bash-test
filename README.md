# BashTest

## Installation
BashTest can be installed directly from the command line. Files will be
downloaded from the GitHub repo.

BashTest has a number of dependencies that you'll need to install in the usual
way for your Linux distribution (using the package manager). The names of the
packages vary according to which distro you use; common package names are listed
in brackets.

* [GNU Privacy Guard (GPG)](https://www.gnupg.org/) [gpg2, gnupg2]
* [curl](https://curl.haxx.se/) [curl]
* [jq](https://stedolan.github.io/jq/) (version 1.5 or later) [jq]
* grep, sed, find, and other standard Linux utilities

For security, files downloaded for or by BashTest will be verified with against
signature files using GPG. You'll need to add the Perihelios LLC key to your GPG
keystore.

```
gpg --keyserver pgp.mit.edu --recv-keys 547B76E4C0C322E8
```

Successful output will indicate that the key for
`Perihelios LLC <pgp@perihelios.com>` was imported.

Next, you'll need to create a directory that will hold your test scripts and
the scripts that form the BashTest "framework". This directory will be somewhere
inside the project containing the Bash scripts for which you're writing the
tests, and it can be named anything you want. `tests` or `.tests` (if you want
the directory to be "hidden"--see
[Should You Hide Your Tests?](#should-you-hide-your-tests)) are great choices.
Everything after this point will be inside this new directory, so you'll change
directories into it right after you create it.

```
mkdir tests
cd tests
```

Then, you'll need to download bootstrap script and its GPG signature file (see
[Bootstrap Script](#bootstrap-script) for more details.) You'll use the
signature file to verify the bootstrap script. You can use `curl`, `wget`, or
your browser for downloading; since `curl` is a required dependency of BashTest,
you should already have it installed and can easily use it. You can name the
bootstrap script anything you want; `run-tests.sh` seems quite suitable.

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

BashTest depends on settings contained in a JSON file, `test-settings.json`,
that lives in your tests directory, alongside the bootstrap script (see
[Test Settings](#test-settings) for details). One setting that's required to be
in the file is the version of BashTest you want to run. This version helps
the BashTest bootstrap script download the runner script from GitHub, if it's
not already found in a local cache. It also "locks" the version of BashTest
you're using, so your tests don't suddenly break if someone blunders and
introduces a change to BashTest that isn't compatible with your tests.

You can create this settings file automatically, with default settings (locking
the version of the runner scripts to whatever is latest at this time). This
version of the runner scripts will also be downloaded, verified with GPG, and
cached so they're ready for use.

```
./run-tests.sh --init
```

BashTest stores the runner scripts it downloads in a hidden directory,
`.runners`, under your tests directory. This script caching speeds up running
your tests, and also allows you to run "offline" (BashTest, itself, will have no
need to connect to the Internet) after the scripts are cached. There's normally
no reason to check this directory into your source repo, since the bootstrap
script will automatically download the correct runner scripts on each
developer's machine. You will normally only commit `run-tests.sh` (or whatever
you named the bootstrap script) and `test-settings.json` to your source repo.
BashTest also stores data from the execution of your tests in a hidden
directory, `.execution`, under your tests directory. You do not want to commit
this directory to your source repo.

To avoid committing unwanted files to your source repo, use the appropriate
mechanism for your source repo software to exclude these directories. For Git,
that's just a `.gitignore` file.

```
echo .runner >>.gitignore
echo .execution >>.gitignore
```

Installation is finished! Enjoy using BashTest.

