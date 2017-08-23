#!/bin/bash
# A simple script for dealing with build flavors.
#
# Syntax:
# ./make-flavor.sh flavor variant make-targets-to-run
#
# Notes:
# - A symlink ./makef exists for easier invocation.
# - Providing "all" as flavor name will execute specified
#   targets for each flavor sequentially.
# - Providing "all" as variant will execute specified
#   targets for specified flavour(s) for each variant.
#
# Examples:
# ./makef all all unin
# ./makef all release unin 
# ./makef preview release ass in

function legacy {
    export FLAVOR=Legacy
    export PACKAGE=""
}

function prod {
    export FLAVOR=Prod
    export PACKAGE=".alarm"
}

function dev {
    export FLAVOR=Dev
    export PACKAGE=".dev"
}

function debug {
    export VARIANT=Debug
}

function release {
    export VARIANT=Release
}

function firebase {
    export VARIANT=Firebase
}

function run {
    if [ "$1" = "prod" ]; then
        prod
        make ${*:3}
    elif [ "$1" = "dev" ]; then
        dev
        make ${*:3}
    elif [ "$1" = "all" ]; then
	prod
        make ${*:3}
	dev
        make ${*:3}
    else
        >&2 echo "Unknown flavor: $1. Usage: ./makef flavor (d|r|f) targets to execute"
        exit 1
    fi
}

if [ "$2" = "d" ]; then
    debug
    run $@
elif [ "$2" = "r" ]; then
    release
    run $@
elif [ "$2" = "f" ]; then
    firebase
    run $@
elif [ "$2" = "all" ]; then
    debug
    run $@
    release
    run $@
    firebase
    run $@
else
    >&2 echo "Unknown variant: $2. Usage: ./makef flavor (d|r|f) targets to execute"
    exit 1
fi
