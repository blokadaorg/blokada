#!/bin/bash
# A simple script to copy translations
#
# Syntax:
# ./translation.sh source-path app-path web-path
#
# Notes:
# - source-path - Where the translations package (unpacked) resides
# - app-path - Where is Blokada app repo
# - web-path - Where is Blokada website repo

langs="es pt fr pl cs de nl"
xml="filter main notification tunnel update"
pages="donate.html help.html"
props="strings_repo.properties strings_store.properties strings_filters.properties"

l=""
x=""

function runXml {
    cp "$src/strings_$x.xml/values-$l/strings_$x.xml" "$app/libui/src/main/res/values-$l/"
}

function runPages {
    cp "$src/$x/$l.html" "$web/content/$l/$x"
}

function runProps {
    cp "$src/$x/$l.properties" "$web/content/$l/$x"
}

function runIndex {
    cp "$src/index.html/$l.html" "$web/$l/index.html"
}


src=$1
app=$2
web=$3

echo "source: $src"
echo "app: $app"
echo "web: $web"
echo "languages: $langs"
echo "xml: $xml"
echo "pages: $pages"
echo "properties: $props"
echo ""

read -p "Continue? (y/n) " choice
if [ "$choice" = "y" ]; then
    echo "Running..."
    for i in $langs; do
	for j in $xml; do
            l="$i"
	    x="$j"
	    runXml
	done
	for j in $pages; do
            l="$i"
	    x="$j"
	    runPages
	done
	for j in $props; do
            l="$i"
	    x="$j"
	    runProps
	done
	runIndex
    done
else
    echo "Cancelled"
fi
