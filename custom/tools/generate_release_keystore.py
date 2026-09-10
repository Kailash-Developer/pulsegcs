#!/usr/bin/env python3
"""
PulseGCS Release Keystore Generation Script
Generates an industry-standard PKCS12 RSA 4096-bit release keystore for PulseGCS Android builds.

Features:
  - Interactive questionnaire mode (default when run in terminal)
  - Explicit prompts for Organization (Company), OU, App Name (CN), City (L), State (ST), Country (C), and Password
  - Non-interactive / Batch mode via CLI arguments or environment variables
"""

import argparse
import getpass
import os
import subprocess
import sys


def parse_arguments():
    parser = argparse.ArgumentParser(
        description="Generate a PKCS12 RSA 4096-bit release keystore for PulseGCS Android builds."
    )
    parser.add_argument(
        "--non-interactive", "--batch",
        action="store_true",
        dest="non_interactive",
        help="Run without interactive prompts (uses CLI arguments and environment variables)."
    )
    parser.add_argument(
        "--keystore",
        default=None,
        help="Path where the keystore file will be saved. Default: custom/deploy/android/pulsegcs-release.keystore"
    )
    parser.add_argument(
        "--alias",
        default=os.environ.get("PULSEGCS_KEY_ALIAS", "pulsegcs-release"),
        help="Keystore alias name. Default: pulsegcs-release"
    )
    parser.add_argument(
        "-p", "--password",
        default=os.environ.get("PULSEGCS_KEYSTORE_PASSWORD"),
        help="Keystore and key password. If not provided in non-interactive mode, defaults to environment variable."
    )
    parser.add_argument(
        "--o", "--org",
        dest="org",
        default=os.environ.get("PULSEGCS_CERT_O"),
        help="Organization / Company Name (O) (e.g. SkyX, Acme Corp)"
    )
    parser.add_argument(
        "--ou",
        default=os.environ.get("PULSEGCS_CERT_OU"),
        help="Organizational Unit / Department (OU) (e.g. Engineering, Flight Systems)"
    )
    parser.add_argument(
        "--cn",
        default=os.environ.get("PULSEGCS_CERT_CN"),
        help="Common Name / Application Name (CN) (e.g. PulseGCS)"
    )
    parser.add_argument(
        "--l", "--locality",
        dest="locality",
        default=os.environ.get("PULSEGCS_CERT_L"),
        help="City / Locality (L) (e.g. Toronto, Markham, Austin)"
    )
    parser.add_argument(
        "--st", "--state",
        dest="state",
        default=os.environ.get("PULSEGCS_CERT_ST"),
        help="State / Province (ST) (e.g. Ontario, Texas, California)"
    )
    parser.add_argument(
        "--c", "--country",
        dest="country",
        default=os.environ.get("PULSEGCS_CERT_C"),
        help="2-letter Country Code (C) (e.g. CA, US, IN, GB)"
    )
    parser.add_argument(
        "--validity",
        type=int,
        default=10000,
        help="Validity period in days (default: 10000 days / ~27 years)"
    )
    parser.add_argument(
        "--keysize",
        type=int,
        default=4096,
        help="RSA key size in bits (default: 4096)"
    )
    parser.add_argument(
        "-f", "--force",
        action="store_true",
        help="Overwrite existing keystore file if it already exists."
    )
    return parser.parse_args()


def prompt_user(field_name, description, default=None, required=False):
    """Prompts the user for a certificate field with explanation."""
    prompt_str = f"  {field_name} - {description}"
    if default:
        prompt_str += f" [{default}]"
    prompt_str += ": "

    while True:
        val = input(prompt_str).strip()
        if not val and default:
            return default
        if not val and required:
            print(f"    * Error: {field_name} is required. Please provide a value.")
            continue
        return val


def collect_dn_and_password(args):
    """Collects certificate DN components and password, interactively or via CLI/env."""
    is_interactive = not args.non_interactive and sys.stdin.isatty()

    if is_interactive:
        print("\n" + "=" * 65)
        print("   PulseGCS Android Release Keystore Generator")
        print("=" * 65)
        print("Please provide the certificate ownership & organization details.")
        print("These identify who created and signed the Android APK.\n")

        # 1. Organization / Company Name
        org = prompt_user(
            "Company / Organization (O)",
            "Your legal company or team name",
            default=args.org or "SkyX",
            required=True
        )

        # 2. Organizational Unit
        ou = prompt_user(
            "Organizational Unit (OU)",
            "Department or division",
            default=args.ou or "Engineering"
        )

        # 3. Common Name / App Name
        cn = prompt_user(
            "Common Name (CN)",
            "App or publisher name",
            default=args.cn or "PulseGCS",
            required=True
        )

        # 4. City / Locality
        locality = prompt_user(
            "City / Locality (L)",
            "City where the company/publisher is based",
            default=args.locality or ""
        )

        # 5. State / Province
        state = prompt_user(
            "State / Province (ST)",
            "State, province, or region",
            default=args.state or ""
        )

        # 6. Country Code
        while True:
            country = prompt_user(
                "Country Code (C)",
                "2-letter ISO country code (e.g. CA, US, IN, GB, DE)",
                default=args.country or "CA",
                required=True
            ).upper()
            if len(country) == 2 and country.isalpha():
                break
            print("    * Error: Country code must be exactly 2 letters (e.g. CA, US, IN).")

        # 7. Password
        print("\n" + "-" * 65)
        print("Keystore Password Configuration:")
        print("  The password encrypts and protects the private key in the keystore.")
        print("  (Input will be hidden while typing)")
        print("-" * 65)

        password = args.password
        if not password:
            while True:
                p1 = getpass.getpass("  Enter Keystore Password (min 6 characters): ")
                if len(p1) < 6:
                    print("    * Error: Password must be at least 6 characters long.")
                    continue
                p2 = getpass.getpass("  Confirm Keystore Password: ")
                if p1 != p2:
                    print("    * Error: Passwords do not match. Please try again.")
                    continue
                password = p1
                break
        else:
            print("  (Using password provided via CLI argument / environment variable)")

    else:
        # Non-interactive / Automated batch mode
        org = args.org or "SkyX"
        ou = args.ou or "Engineering"
        cn = args.cn or "PulseGCS"
        locality = args.locality or ""
        state = args.state or ""
        country = (args.country or "CA").upper()
        password = args.password or "PulseGCS_Release_2026"

    # Assemble RFC 2253 Distinguished Name string
    dn_parts = []
    if cn:
        dn_parts.append(f"CN={cn}")
    if ou:
        dn_parts.append(f"OU={ou}")
    if org:
        dn_parts.append(f"O={org}")
    if locality:
        dn_parts.append(f"L={locality}")
    if state:
        dn_parts.append(f"ST={state}")
    if country:
        dn_parts.append(f"C={country}")

    dname = ", ".join(dn_parts)
    dn_dict = {
        "Company / Organization (O)": org,
        "Organizational Unit (OU)": ou,
        "Common Name / App Name (CN)": cn,
        "City / Locality (L)": locality or "(Not Specified)",
        "State / Province (ST)": state or "(Not Specified)",
        "Country Code (C)": country,
    }

    return dname, password, dn_dict, is_interactive


def main():
    args = parse_arguments()

    repo_root = os.path.abspath(os.path.join(os.path.dirname(__file__), "../.."))
    if args.keystore:
        keystore_path = os.path.abspath(args.keystore)
    else:
        keystore_path = os.path.join(repo_root, "custom", "deploy", "android", "pulsegcs-release.keystore")

    os.makedirs(os.path.dirname(keystore_path), exist_ok=True)

    if os.path.exists(keystore_path) and not args.force:
        print(f"\n[!] Keystore already exists at: {keystore_path}")
        if sys.stdin.isatty() and not args.non_interactive:
            choice = input("Do you want to overwrite it with a new key? [y/N]: ").strip().lower()
            if choice not in ("y", "yes"):
                print("Aborting. Existing keystore preserved.")
                return 0
        else:
            print("Use --force (or -f) to overwrite the existing keystore in batch mode.")
            return 1

    dname, password, dn_dict, is_interactive = collect_dn_and_password(args)

    # Print summary before writing
    print("\n" + "=" * 65)
    print("   Keystore Configuration Summary")
    print("=" * 65)
    for k, v in dn_dict.items():
        print(f"  {k:<30}: {v}")
    print(f"  {'Keystore Path':<30}: {keystore_path}")
    print(f"  {'Key Alias':<30}: {args.alias}")
    print(f"  {'Key Algorithm':<30}: RSA {args.keysize}-bit (SHA256withRSA)")
    print(f"  {'Validity Period':<30}: {args.validity} days (~{args.validity // 365} years)")
    print("=" * 65)

    if is_interactive:
        confirm = input("\nProceed with generating this release keystore? [Y/n]: ").strip().lower()
        if confirm in ("n", "no"):
            print("Aborted by user.")
            return 0

    if os.path.exists(keystore_path):
        os.remove(keystore_path)

    cmd = [
        "keytool",
        "-genkeypair",
        "-dname", dname,
        "-alias", args.alias,
        "-keystore", keystore_path,
        "-storetype", "PKCS12",
        "-keyalg", "RSA",
        "-keysize", str(args.keysize),
        "-sigalg", "SHA256withRSA",
        "-validity", str(args.validity),
        "-storepass", password,
        "-keypass", password,
    ]

    print("\nGenerating cryptographic keypair via keytool...")
    result = subprocess.run(cmd, capture_output=True, text=True)
    if result.returncode != 0:
        print(f"\n[ERROR] Key generation failed:\n{result.stderr}", file=sys.stderr)
        return 1

    print("\n" + "=" * 65)
    print("  [SUCCESS] PulseGCS Release Keystore Created Successfully!")
    print("=" * 65)
    print(f"Keystore file : {keystore_path}")
    print(f"Key Alias     : {args.alias}")
    print(f"Store Type    : PKCS12")
    print("\nTo use this key during release builds, export the following:")
    print(f'  export QT_ANDROID_KEYSTORE_PATH="{keystore_path}"')
    print(f'  export QT_ANDROID_KEYSTORE_ALIAS="{args.alias}"')
    print(f'  export QT_ANDROID_KEYSTORE_STORE_PASS="<your_password>"')
    print(f'  export QT_ANDROID_KEYSTORE_KEY_PASS="<your_password>"')
    print("=" * 65 + "\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
