#!/usr/bin/env python3
import argparse
import re
import sys

def update_android_version(android_file, version_name, version_code):
    """
    Update the Android build file (e.g. build.gradle) by replacing:
      - versionName "old_value" with versionName "version_name"
      - versionCode old_value with versionCode version_code
    """
    try:
        with open(android_file, "r") as f:
            content = f.read()
    except Exception as e:
        sys.exit(f"Error reading Android file {android_file}: {e}")

    # Replace versionName (e.g., versionName "1.0.0")
    content = re.sub(
        r'versionName\s*"(.*?)"',
        f'versionName "{version_name}"',
        content
    )
    # Replace versionCode (e.g., versionCode 100)
    content = re.sub(
        r'versionCode\s*\d+',
        f'versionCode {version_code}',
        content
    )

    try:
        with open(android_file, "w") as f:
            f.write(content)
    except Exception as e:
        sys.exit(f"Error writing updated Android file {android_file}: {e}")

    print(f"[Android] Updated versionName to '{version_name}' and versionCode to {version_code} in {android_file}")

def update_ios_project_version(xcodeproj_file, version_name, version_code):
    """
    Update the Xcode project file (.pbxproj) by replacing:
      - CURRENT_PROJECT_VERSION with version_code
      - MARKETING_VERSION with version_name
    """
    try:
        with open(xcodeproj_file, "r") as f:
            content = f.read()
    except Exception as e:
        sys.exit(f"Error reading Xcode project file {xcodeproj_file}: {e}")

    # Update CURRENT_PROJECT_VERSION (a numeric value)
    content, count1 = re.subn(
        r'(CURRENT_PROJECT_VERSION\s*=\s*)(\d+)(\s*;)',
        lambda m: f"{m.group(1)}{version_code}{m.group(3)}",
        content
    )
    # Update MARKETING_VERSION (always outputting the new version in quotes)
    content, count2 = re.subn(
        r'(MARKETING_VERSION\s*=\s*)(?:"([^"]+)"|([^\s;]+))(\s*;)',
        lambda m: f'{m.group(1)}"{version_name}"{m.group(4)}',
        content
    )

    try:
        with open(xcodeproj_file, "w") as f:
            f.write(content)
    except Exception as e:
        sys.exit(f"Error writing updated Xcode project file {xcodeproj_file}: {e}")

    print(f"[iOS] Updated CURRENT_PROJECT_VERSION to {version_code} and MARKETING_VERSION to '{version_name}' in {xcodeproj_file}")

def main():
    parser = argparse.ArgumentParser(
        description="Update Android and iOS project versions using provided version name and version code."
    )
    parser.add_argument(
        "--android-file",
        required=True,
        help="Path to the Android build file (e.g., app/build.gradle) containing versionName and versionCode."
    )
    parser.add_argument(
        "--xcodeproj-file",
        required=True,
        help="Path to the Xcode project file (e.g., MyApp.xcodeproj/project.pbxproj) containing CURRENT_PROJECT_VERSION and MARKETING_VERSION."
    )
    parser.add_argument(
        "--version-name",
        required=True,
        help="Version name (e.g., 1.2.3 or 1.2.3/debug, where only the part before '/' will be used)."
    )
    parser.add_argument(
        "--version-code",
        type=int,
        required=True,
        help="Version code (an integer)."
    )

    args = parser.parse_args()

    # Remove any suffix after a "/" from the version name (e.g., "1.2.3/debug" becomes "1.2.3")
    clean_version_name = re.sub(r'/.*', '', args.version_name)

    # Add constant to our version code to be above legacy builds
    code = 668000000 + args.version_code

    update_android_version(args.android_file, clean_version_name, code)
    update_ios_project_version(args.xcodeproj_file, clean_version_name, code)

if __name__ == "__main__":
    main()
