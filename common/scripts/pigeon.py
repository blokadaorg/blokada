#!/usr/bin/env python3
import os
import glob
import shutil
import subprocess
import re
import argparse

def run_pigeon(file, output_base, generate_android, base_cmd):
    """
    Runs the pigeon command for the given schema file.
    Generates:
      - Dart output always (goes to lib/src/platform...).
      - Either Android or iOS native files based on generate_android.
    """
    base = os.path.basename(file)
    name, _ = os.path.splitext(base)
    name_lower = name.lower()

    # Insert a slash before every uppercase letter and convert to lowercase.
    # This mimics: sed 's/\([A-Z]\)/\/\1/g' | tr '[:upper:]' '[:lower:]'
    dart_path = re.sub(r'([A-Z])', r'/\1', name).lower()
    print(f"Computed dart path: {dart_path}")

    # Split the base command (e.g., "fvm flutter pub" or "dart") into parts.
    base_cmd_list = base_cmd.split()
    # Build the common part of the pigeon command.
    command = base_cmd_list + [
        "run", "pigeon",
        "--input", file,
        "--dart_out", f"lib/src/platform{dart_path}/channel.pg.dart"
    ]

    # Append native-specific output based on the flag.
    if generate_android:
        # Generate Android files.
        native_dir = os.path.join(output_base, "android")
        command.extend([
            "--kotlin_out", os.path.join(native_dir, f"{name}.kt"),
            "--kotlin_package", f"channel.{name_lower}"
        ])
    else:
        # Generate iOS files.
        native_dir = os.path.join(output_base, "ios")
        command.extend([
            "--swift_out", os.path.join(native_dir, f"{name}.swift")
        ])

    print(f"Running command: {' '.join(command)}")
    subprocess.run(command, check=True)

def main():
    parser = argparse.ArgumentParser(
        description="Sync and generate files using pigeon and build_runner."
    )
    parser.add_argument(
        "--output", "-o",
        type=str,
        default="./build/pigeon",
        help="Base output path for generated native files (iOS/Android). Default: ./build/pigeon"
    )
    parser.add_argument(
        "--android",
        action="store_true",
        help="Generate Android files. If not specified, iOS files are generated."
    )
    parser.add_argument(
        "--cmd",
        type=str,
        default="dart",
        help="Base command to use for running pigeon. E.g., 'fvm flutter pub' or 'dart' (default)."
    )
    args = parser.parse_args()

    output_base = args.output

    print("Syncing generated files...")
    print("Running pigeon...")

    # Determine the native output directory based on the platform.
    native_platform = "android" if args.android else "ios"
    native_dir = os.path.join(output_base, native_platform)

    # Remove the native output directory if it exists.
    if os.path.exists(native_dir):
        shutil.rmtree(native_dir)
    os.makedirs(native_dir, exist_ok=True)

    # Process each Dart file in libgen/
    schema_files = glob.glob("libgen/*.dart")
    if not schema_files:
        print("No schema files found in libgen/")
    for file in schema_files:
        run_pigeon(file, output_base, args.android, args.cmd)

    print("Done")

if __name__ == "__main__":
    main()
