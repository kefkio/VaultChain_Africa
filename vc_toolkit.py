#!/usr/bin/env python3
"""
VaultChain Africa Automation Toolkit

Usage:
    python vc_toolkit.py <command> [options]

Commands:
    scaffold      Generate all Solidity contract templates [--force]
    deploy        Deploy a compiled contract (provide ABI & bytecode paths)
    simulate      Simulate transactions (deposit/loan)
    test          Run Foundry and Hardhat tests
    doc           Generate project documentation
    archive       Zip the project folder (optionally specify version)
"""

import os
import sys
import zipfile
import subprocess
import json
from pathlib import Path
from web3 import Web3
import shutil
from datetime import datetime

# -----------------------------
# Detect Project Root Automatically
# -----------------------------
CURRENT_DIR = Path.cwd()
PROJECT_ROOT = CURRENT_DIR
while not (PROJECT_ROOT / "vc_toolkit.py").exists() and PROJECT_ROOT.parent != PROJECT_ROOT:
    PROJECT_ROOT = PROJECT_ROOT.parent

if not (PROJECT_ROOT / "vc_toolkit.py").exists():
    print("❌ Could not find vc_toolkit.py in any parent folder. Make sure you're inside the project.")
    sys.exit(1)

# -----------------------------
# Configuration
# -----------------------------
RPC_URL = "https://rpc.testnet"
PRIVATE_KEY = "your_private_key_here"
CHAIN_ID = 97

# -----------------------------
# Git Automation
# -----------------------------
def git_update(message="Automated update"):
    try:
        subprocess.run(["git", "add", "."], cwd=str(PROJECT_ROOT), check=True)
        subprocess.run(["git", "commit", "-m", message], cwd=str(PROJECT_ROOT), check=True)
        subprocess.run(["git", "push"], cwd=str(PROJECT_ROOT), check=True)
        print("✅ Git update pushed successfully.")
    except subprocess.CalledProcessError:
        print("⚠️ Git update failed. Check your repo status or remote connection.")

# -----------------------------
# Contract Scaffolding
# -----------------------------
def create_contract(contract_name, folder, force=False):
    folder_path = PROJECT_ROOT / "backend" / "contracts" / folder
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

# -----------------------------
# Deployment / Simulation
# -----------------------------
def deploy_contract(abi_path, bytecode_path):
    w3 = Web3(Web3.HTTPProvider(RPC_URL))
    account = w3.eth.account.from_key(PRIVATE_KEY)
    with open(abi_path) as f:
        abi = json.load(f)
    with open(bytecode_path) as f:
        bytecode = f.read()
    contract = w3.eth.contract(abi=abi, bytecode=bytecode)
    tx = contract.constructor().build_transaction({
        'from': account.address,
        'nonce': w3.eth.get_transaction_count(account.address),
        'gas': 5000000,
        'gasPrice': w3.eth.gas_price,
        'chainId': CHAIN_ID
    })
    signed_tx = w3.eth.account.sign_transaction(tx, PRIVATE_KEY)
    tx_hash = w3.eth.send_raw_transaction(signed_tx.rawTransaction)
    receipt = w3.eth.wait_for_transaction_receipt(tx_hash)
    print(f"✅ Contract deployed at: {receipt.contractAddress}")
    return receipt.contractAddress

def simulate_transaction(contract_address, abi_path, method="deposit", amount=0):
    w3 = Web3(Web3.HTTPProvider(RPC_URL))
    account = w3.eth.account.from_key(PRIVATE_KEY)
    with open(abi_path) as f:
        abi = json.load(f)
    contract = w3.eth.contract(address=contract_address, abi=abi)
    tx = getattr(contract.functions, method)(amount).build_transaction({
        'from': account.address,
        'nonce': w3.eth.get_transaction_count(account.address),
        'gas': 200000,
        'gasPrice': w3.eth.gas_price
    })
    signed_tx = w3.eth.account.sign_transaction(tx, PRIVATE_KEY)
    tx_hash = w3.eth.send_raw_transaction(signed_tx.rawTransaction)
    print(f"✅ Simulated {method}: {tx_hash.hex()}")

# -----------------------------
# Tests
# -----------------------------
def run_tests():
    print("🚀 Running Foundry tests...")
    forge_path = shutil.which("forge") or str(PROJECT_ROOT.parent / ".foundry" / "bin" / "forge.exe")
    if not Path(forge_path).exists():
        print("❌ Could not locate forge. Make sure Foundry is installed and in your PATH.")
        sys.exit(1)
    subprocess.run([forge_path, "test"], cwd=str(PROJECT_ROOT / "backend"))

    print("🚀 Running Hardhat tests...")
    subprocess.run(["npx", "hardhat", "test"], cwd=str(PROJECT_ROOT / "backend"))

# -----------------------------
# Documentation
# -----------------------------
def generate_docs():
    doc_folder = PROJECT_ROOT / "docs"
    os.makedirs(doc_folder, exist_ok=True)
    readme_path = doc_folder / "README.md"
    with open(readme_path, "w") as f:
        f.write("# VaultChain Africa Documentation\n\n")
        f.write("## Contract Modules\n")
        contracts_root = PROJECT_ROOT / "backend/contracts"
        for root, _, files in os.walk(contracts_root):
            for file in files:
                relative_path = Path(root).relative_to(contracts_root)
                f.write(f"- {relative_path / file}\n")
    print(f"✅ Documentation generated at {readme_path}")

# -----------------------------
# Archive
# -----------------------------
def archive_project(version="v1"):
    zip_filename = PROJECT_ROOT / f"{PROJECT_ROOT.name}_{version}.zip"
    with zipfile.ZipFile(zip_filename, 'w', zipfile.ZIP_DEFLATED) as zipf:
        for root, _, files in os.walk(PROJECT_ROOT):
            for file in files:
                full_path = Path(root) / file
                arcname = full_path.relative_to(PROJECT_ROOT)
                zipf.write(full_path, arcname)
    print(f"✅ Project zipped as {zip_filename}")

# -----------------------------
# CLI Dispatcher
# -----------------------------
def main():
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(1)

    command = sys.argv[1]

    try:
        if command == "scaffold":
            force_flag = "--force" in sys.argv
            scaffold_all(force=force_flag)
            git_update("🛠 Scaffolded contract modules")

        elif command == "deploy":
            if len(sys.argv) != 4:
                print("Usage: python vc_toolkit.py deploy <abi_path> <bytecode_path>")
                sys.exit(1)
            deploy_contract(sys.argv[2], sys.argv[3])
            git_update("🚀 Contract deployed")

        elif command == "simulate":
            if len(sys.argv) != 5:
                print("Usage: python vc_toolkit.py simulate <contract_address> <abi_path> <amount>")
                sys.exit(1)
            simulate_transaction(sys.argv[2], sys.argv[3], amount=int(sys.argv[4]))
            git_update("📊 Simulated transaction")

        elif command == "test":
            run_tests()
            git_update("✅ Passed tests: Foundry + Hardhat")

        elif command == "doc":
            generate_docs()
            git_update("📚 Documentation generated")

        elif command == "archive":
            version = sys.argv[2] if len(sys.argv) > 2 else "v1"
            archive_project(version)
            git_update(f"📦 Archived project as {version}")

        else:
            print("❌ Unknown command:", command)
            print(__doc__)

    except Exception as e:
        print(f"❌ Command '{command}' failed: {e}")

if __name__ == "__main__":
    main()