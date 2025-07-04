#!/usr/bin/env python3
"""
Convert domains list to declarativeNetRequest rules format for Safari Web Extension.

Supports wildcard domains format (*.domain.com) from URLs or local files.
"""

import json
import urllib.request
import sys
import os
import argparse
from urllib.parse import urlparse

def download_or_read_domains(source):
    """Download domains from URL or read from local file."""
    parsed = urlparse(source)

    if parsed.scheme in ('http', 'https'):
        print(f"Downloading domains from {source}...")
        try:
            with urllib.request.urlopen(source) as response:
                content = response.read().decode('utf-8')
            return content
        except Exception as e:
            print(f"Error downloading from {source}: {e}")
            sys.exit(1)
    else:
        # Treat as local file
        print(f"Reading domains from {source}...")
        try:
            with open(source, 'r', encoding='utf-8') as f:
                content = f.read()
            return content
        except Exception as e:
            print(f"Error reading file {source}: {e}")
            sys.exit(1)

def parse_domains(content):
    """Parse domains from wildcard format, removing comments and wildcards."""
    domains = []

    for line in content.splitlines():
        line = line.strip()
        # Skip comments, empty lines, and other non-domain lines
        if line.startswith('#') or line.startswith('!') or not line:
            continue

        # Handle different formats
        if line.startswith('*.'):
            # Wildcard format: *.domain.com -> domain.com
            domain = line[2:]
            domains.append(domain)
        elif line.startswith('||') and line.endswith('^'):
            # ABP format: ||domain.com^ -> domain.com
            domain = line[2:-1]
            domains.append(domain)
        elif '.' in line and not line.startswith('127.0.0.1') and not line.startswith('0.0.0.0'):
            # Plain domain format
            # Skip if it looks like a hosts file entry
            parts = line.split()
            if len(parts) == 1:
                domains.append(line)
            elif len(parts) >= 2 and parts[0] in ('127.0.0.1', '0.0.0.0'):
                # Hosts file format: 127.0.0.1 domain.com
                domains.append(parts[1])

    return domains

def create_declarative_rules(domains, rule_id_prefix="oisd"):
    """Convert domains to declarativeNetRequest rules.

    Each rule follows the declarativeNetRequest format:
    - id: unique identifier (1-based)
    - priority: rule priority (higher = more important)
    - action: what to do (block, allow, etc.)
    - condition: when to apply the rule
      - urlFilter: domain pattern (||domain format blocks domain and subdomains)
      - resourceTypes: what types of resources to block
    """
    rules = []

    # Resource types to block
    resource_types = [
        "main_frame",
        "sub_frame",
        "stylesheet",
        "script",
        "image",
        "font",
        "xmlhttprequest",
        "ping",
        "media",
        "websocket",
        "other"
    ]

    for i, domain in enumerate(domains, 1):
        rule = {
            "id": i,
            "priority": 1,
            "action": {"type": "block"},
            "condition": {
                "urlFilter": f"||{domain}",
                "resourceTypes": resource_types
            }
        }
        rules.append(rule)

    return rules

def main():
    """Main function."""
    parser = argparse.ArgumentParser(
        description='Convert domains list to declarativeNetRequest rules for Safari Web Extension',
        epilog='''
Examples:
  %(prog)s https://small.oisd.nl/domainswild oisd-small.json
  %(prog)s https://big.oisd.nl/domainswild oisd-big.json
  %(prog)s local-domains.txt custom-rules.json
        ''',
        formatter_class=argparse.RawDescriptionHelpFormatter
    )

    parser.add_argument('source',
                       help='URL or local file path containing domains list')
    parser.add_argument('output',
                       help='Output JSON file name (e.g., oisd-small.json)')
    parser.add_argument('--max-rules',
                       type=int,
                       default=150000,
                       help='Maximum number of rules (default: 150000 for Safari)')
    parser.add_argument('--output-dir',
                       default='ios/BlockaWebExtension/Resources/rules',
                       help='Output directory')

    args = parser.parse_args()

    # Download/read and parse domains
    content = download_or_read_domains(args.source)
    domains = parse_domains(content)

    print(f"Parsed {len(domains)} domains")

    # Check Safari Web Extension limit
    if len(domains) > args.max_rules:
        print(f"Warning: {len(domains)} domains exceeds limit of {args.max_rules}")
        print("Consider using a smaller list or increasing the limit")
        sys.exit(1)

    # Convert to declarativeNetRequest rules
    rules = create_declarative_rules(domains)

    # Output path
    output_file = os.path.join(args.output_dir, args.output)

    # Ensure output directory exists
    os.makedirs(args.output_dir, exist_ok=True)

    # Write JSON file
    with open(output_file, 'w') as f:
        json.dump(rules, f, indent=2)

    print(f"✅ Generated {len(rules)} rules in {output_file}")

    # Show next steps
    print("\nNext steps:")
    print(f"1. Update manifest.json to include the '{os.path.basename(args.output)}' ruleset")
    print("2. Build the iOS project to include the updated rules")
    print("3. Test the Safari Web Extension with the new rules")

if __name__ == "__main__":
    main()
