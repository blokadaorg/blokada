#!/usr/bin/python3

'''
This file is part of Blokada.

Blokada is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

Blokada is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with Blokada.  If not, see <https://www.gnu.org/licenses/>.

Copyright © 2020 Blocka AB. All rights reserved.

@author Karol Gusak (karol@blocka.net)
'''

'''
Manages translations for Android and iOS.
'''

import sys
import os
import getopt
import glob
import shutil
import re
import subprocess
from os import path

def main(argv):
    def usage():
        print("usage: translate -r <repo-dir> -a action")
        print("Default repo dir is ../../translate")
        print("Actions: export import import-ios import-android sync-android ")
        print("Default action is 'export'")
        print("The canonical source for strings is iOS")

    print("Translate v0.2")

    # parse command line options
    base_path = "."
    config = {
        "repo_dir": "../../translate",
        "action": "export",
        "langs": ["pl", "de", "es", "it", "hi", "ru", "bg", "tr", "ja", "id", "cs", "zh-Hant", "ar", "fi", "ro", "pt-BR", "fr", "hu", "nl"],
        "langs-android": {
            "id": "in",
            "zh-Hant": "zh",
	    "pt-BR": "b+pt+BR"
        }
    }

    try:
        opts, _ = getopt.getopt(argv, "r:a:")
    except getopt.GetoptError:
        print("  Bad parameters")
        usage()
        return 1

    for opt, arg in opts:
        if opt == "-r":
            config["repo_dir"] = arg
        elif opt == "-a":
            config["action"] = arg
        else:
            print("  Unknown argument: %s" % opt)
            usage()
            return 2

    if config["action"] not in ["export", "import", "import-ios", "import-android", "sync-android"]:
        print("  Unknown action")
        usage()
        return 1

    print(config)

    repo = path.join(base_path, config["repo_dir"])
    if config["action"] == "export":
        export(repo)
    elif config["action"] == "import":
        iosImport(repo, config["langs"])
        androidImport(repo, config["langs"], config["langs-android"])
    elif config["action"] == "import-ios":
        iosImport(repo, config["langs"])
    elif config["action"] == "import-android":
        androidImport(repo, config["langs"], config["langs-android"])
    elif config["action"] == "sync-android":
        androidSyncSources()

    print("Done")

def export(repo):
    dest_dir = f"{repo}/fem/"
    print(f"Exporting iOS strings to: {dest_dir}")
    for file in glob.glob(r"../ios/IOS/Assets/en.lproj/*.strings"):
        print(file)
        shutil.copy(file, dest_dir)

def iosImport(repo, langs):
    print(f"Importing strings to iOS from: {repo}")
    for lang in langs:
        print(f"Importing: {lang}")
        try:
            shutil.rmtree(f"../ios/IOS/Assets/{lang}.lproj")
        except:
            pass
        try:
            shutil.copytree(f"{repo}/build/fem/{lang}.lproj", f"../ios/IOS/Assets/{lang}.lproj")
        except:
            pass

def androidSyncSources():
    print("Syncing Android strings with iOS")

    if not os.path.exists("../android/app/src/main/assets/translations/root"):
        os.makedirs("../android/app/src/main/assets/translations/root")

    subprocess.call("./convert.py -i ../ios/IOS/Assets/en.lproj/Ui.strings -o ../android/app/src/main/res/values/strings_ui.xml", shell = True)
    subprocess.call("./convert.py -i ../ios/IOS/Assets/en.lproj/PackTags.strings -o ../android/app/src/main/assets/translations/root/tags.json -f \"json\"", shell = True)
    subprocess.call("./convert.py -i ../ios/IOS/Assets/en.lproj/Packs.strings -o ../android/app/src/main/assets/translations/root/packs.json -f \"json\"", shell = True)

def androidImport(repo, langs, langs_android):
    print(f"Importing strings to Android from: {repo}")
    for lang in langs:
        print(f"Importing {lang}")
        alang = langs_android.get(lang, lang)

        if not os.path.exists(f"../android/app/src/translations/res/values-{alang}"):
            os.makedirs(f"../android/app/src/translations/res/values-{alang}")
        if not os.path.exists(f"../android/app/src/main/assets/translations/{lang}"):
            os.makedirs(f"../android/app/src/main/assets/translations/{lang}")

        subprocess.call(f"./convert.py -i {repo}/build/fem/{lang}.lproj/PackTags.strings -o ../android/app/src/main/assets/translations/{lang}/tags.json -f \"json\"", shell = True)
        subprocess.call(f"./convert.py -i {repo}/build/fem/{lang}.lproj/Packs.strings -o ../android/app/src/main/assets/translations/{lang}/packs.json -f \"json\"", shell = True)
        subprocess.call(f"./convert.py -i {repo}/build/fem/{lang}.lproj/Ui.strings -o ../android/app/src/main/assets/translations/{lang}/ui.json -f \"json\"", shell = True)
        subprocess.call(f"./convert.py -i {repo}/build/fem/{lang}.lproj/Ui.strings -o ../android/app/src/translations/res/values-{alang}/strings_ui.xml -f \"xml\"", shell = True)

def outputAsAndroidXml(output_file, strings):
    with open(output_file, "w") as f:
        f.write("<resources>\n")
        for key in strings:
            f.write(f"    <string name=\"{makeAndroidKey(key)}\">{makeAndroidValue(strings[key])}</string>\n")
        f.write("</resources>\n")

def outputAsJson(output_file, strings):
    with open(output_file, "w") as f:
        f.write("{ \"strings\": {\n")
        count = 0
        for key in strings:
            count += 1
            f.write(f"    \"{key}\": \"{strings[key]}\"")
            if count < len(strings):
                f.write(",")
            f.write("\n")
        f.write("} }\n")

def makeAndroidKey(line):
    line = remove_chars(line, keep=ascii_letters + ' ')
    line = line.replace(" ", "_")
    return line.lower()

def makeAndroidValue(line):
    line = line.replace("&", "&amp;")
    line = line.replace("'", "\\'")
    return line

def remove_chars(input_string, keep):
    return ''.join([_ for _ in input_string if _ in keep])


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
