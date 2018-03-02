#!/bin/bash
# A simple script to copy translations
#
# Syntax:
# ./translation.sh source-path app-path web-path
#
# Notes:
# - source-path - Where the translations package (unpacked) resides
# - app-path - Where is Blokada app repo
# - gscore-path - Where is gscore lib repo
# - web-path - Where is Blokada website repo

langs="es fr pl cs de nl ms it hu ru zh-rTW tr pt-rBR pt-rPT hr in"
xml="filter main notification tunnel update"
pages="cleanup.html contribute.html credits.html cta.html donate.html help.html intro.html obsolete.html patron.html updated.html"
props="filters.properties"

l=""
x=""

function runXml {
    cp "$src/strings_$x.xml/values-$l/strings_$x.xml" "$app/app/src/main/res/values-$l/"
}

function runXmlGscore {
    cp "$src/strings_gscore.xml/values-$l/strings_$x.xml" "$gscore/src/main/res/values-$l/"
}

function runPages {
    rm "$web/api/v3/content/$l/$x"
    cp "$src/$x/$l.html" "$web/api/v3/content/$l/$x"
}

function runProps {
    rm "$web/api/v3/content/$l/$x"
    cp "$src/$x/$l.properties" "$web/api/v3/content/$l/$x"
}

function runIndex {
    cp "$src/index.html/$l.html" "$web/$l/index.html"
}


src=$1
app=$2
gscore=$3
web=$4

echo "source: $src"
echo "app: $app"
echo "gscore: $gscore"
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
	runXmlGscore
	i=$(echo $i | sed -e "s/-r/-/g")
	for j in $pages; do
            l="$i"
	    x="$j"
	    runPages
	done
	runIndex
	i=$(echo $i | sed -e "s/-/_/g")
	for j in $props; do
            l="$i"
	    x="$j"
	    runProps
	done
    done
else
    echo "Cancelled"
fi
