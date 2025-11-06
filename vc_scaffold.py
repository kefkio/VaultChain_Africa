#!/usr/bin/env python3
"""
VaultChain Africa Contract Scaffolding

Usage:
    python vc_scaffold.py [--force]

Options:
    --force     Overwrite existing contract files
"""

import os
import sys
from pathlib import Path

CURRENT_DIR = Path.cwd()
PROJECT_ROOT = CURRENT_DIR

# Locate project root
while not (PROJECT_ROOT / "vc_scaffold.py").exists() and PROJECT_ROOT.parent != PROJECT_ROOT:
    PROJECT_ROOT = PROJECT_ROOT.parent

if not (PROJECT_ROOT / "vc_scaffold.py").exists():
    print("❌ Could not find vc_scaffold.py in any parent folder.")
    sys.exit(1)

# -----------------------------
# Contract scaffolding
# -----------------------------
def create_contract(contract_name, folder, force=False):
    folder_path = PROJECT_ROOT / "backend/contracts" / folder
    os.makedirs(folder_path, exist_ok=True)
    path = folder_path / f"{contract_name}.sol"

    if path.exists() and not force:
        print(f"⚠️ Skipped: {contract_name}.sol already exists in {folder_path}")
        return

    content = f"""// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract {contract_name} {{
    event Initialized(address indexed owner);

    constructor() {{
        emit Initialized(msg.sender);
    }}
}}
"""
    with open(path, "w") as f:
        f.write(content)
    print(f"✅ Created: {contract_name}.sol in {folder_path}")


def scaffold_all(force=False):
    modules = {
        "pool": ["PoolVaultERC4626", "PoolAccounting"],
        "loan": ["LoanManager", "LoanLogicFixed"],
        "marketplace": ["Marketplace", "CollateralVaultERC20", "CollateralVaultERC721"],
        "oracle": ["OracleAggregator"],
        "treasury": ["Treasury", "ReserveFund"]
    }
    for folder, contracts in modules.items():
        for contract in contracts:
            create_contract(contract, folder, force=force)

if __name__ == "__main__":
    force_flag = "--force" in sys.argv
    scaffold_all(force=force_flag)
    print("✅ All contract templates scaffolded.")
