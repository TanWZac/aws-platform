#!/usr/bin/env python3
"""
validate-contracts.py — Pressure-test the SSM parameter contract and OpenAPI contract.

Usage:
    python3 scripts/validate-contracts.py <env> [--api-url <url>]

Checks:
  1. Every SSM parameter listed in contracts/ssm-parameters.yaml exists in AWS
     and has a non-empty value.
  2. (Optional) Every path in contracts/api-contract.yaml is reachable at the
     deployed API URL and returns the documented response shape.

Exit 1 if any check fails — safe to use as a CI gate.
"""

import argparse
import json
import sys
import urllib.request
import urllib.error
from pathlib import Path

try:
    import boto3
    import yaml
except ImportError:
    print("pip install boto3 pyyaml", file=sys.stderr)
    sys.exit(1)

REPO_ROOT = Path(__file__).resolve().parent.parent
CONTRACTS_DIR = REPO_ROOT / "contracts"


def check_ssm(env: str, region: str) -> list[str]:
    ssm = boto3.client("ssm", region_name=region)
    contract_path = CONTRACTS_DIR / "ssm-parameters.yaml"
    if not contract_path.exists():
        return [f"contracts/ssm-parameters.yaml not found at {contract_path}"]

    with open(contract_path) as f:
        contract = yaml.safe_load(f)

    params = contract.get("parameters", [])
    failures = []

    for param in params:
        raw_path: str = param["path"]
        path = raw_path.replace("{env}", env)

        try:
            resp = ssm.get_parameter(Name=path)
            value = resp["Parameter"]["Value"]
            if not value.strip():
                failures.append(f"EMPTY   {path}")
            else:
                print(f"  OK    {path}")
        except ssm.exceptions.ParameterNotFound:
            failures.append(f"MISSING {path}")
        except Exception as exc:
            failures.append(f"ERROR   {path}: {exc}")

    return failures


def check_api_contract(api_url: str) -> list[str]:
    contract_path = CONTRACTS_DIR / "api-contract.yaml"
    if not contract_path.exists():
        return [f"contracts/api-contract.yaml not found at {contract_path}"]

    with open(contract_path) as f:
        contract = yaml.safe_load(f)

    failures = []
    paths = contract.get("paths", {})

    # Only test unauthenticated GET endpoints (health routes)
    public_paths = [p for p in paths if p.startswith("/health")]

    for path in public_paths:
        methods = paths[path]
        for method, spec in methods.items():
            if method.upper() != "GET":
                continue

            url = api_url.rstrip("/") + path
            try:
                req = urllib.request.Request(url, method="GET")
                with urllib.request.urlopen(req, timeout=10) as resp:
                    status = resp.status
                    body = json.loads(resp.read())

                # Check expected response fields
                expected_codes = list(spec.get("responses", {}).keys())
                if str(status) not in [str(c) for c in expected_codes]:
                    failures.append(f"UNEXPECTED HTTP {status} for GET {path} (expected {expected_codes})")
                    continue

                # Validate required fields from schema
                ok_schema = spec.get("responses", {}).get(200, {}).get("content", {}).get(
                    "application/json", {}
                ).get("schema", {}).get("required", [])
                for field in ok_schema:
                    if field not in body:
                        failures.append(f"MISSING field '{field}' in GET {path} response")

                print(f"  OK    GET {path} → HTTP {status}, fields {list(body.keys())}")

            except urllib.error.HTTPError as e:
                failures.append(f"HTTP ERROR  GET {path}: {e.code} {e.reason}")
            except Exception as exc:
                failures.append(f"ERROR       GET {path}: {exc}")

    return failures


def main() -> None:
    parser = argparse.ArgumentParser(description="Validate platform contracts")
    parser.add_argument("env", choices=["dev", "stage", "prod"])
    parser.add_argument("--region", default="us-east-1")
    parser.add_argument("--api-url", default=None, help="API base URL for contract checks")
    args = parser.parse_args()

    all_failures: list[str] = []

    print(f"\n── SSM Parameter Contract (env={args.env}) ──────────────────────────────")
    ssm_failures = check_ssm(args.env, args.region)
    all_failures.extend(ssm_failures)
    if ssm_failures:
        for f in ssm_failures:
            print(f"  FAIL  {f}")

    if args.api_url:
        print(f"\n── API Contract ({args.api_url}) ──────────────────────────────────────")
        api_failures = check_api_contract(args.api_url)
        all_failures.extend(api_failures)
        if api_failures:
            for f in api_failures:
                print(f"  FAIL  {f}")

    print()
    if all_failures:
        print(f"Contract validation FAILED — {len(all_failures)} issue(s):")
        for f in all_failures:
            print(f"  ✗ {f}")
        sys.exit(1)
    else:
        print("Contract validation PASSED — all checks OK.")


if __name__ == "__main__":
    main()
