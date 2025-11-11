#!/usr/bin/env python3
"""
VaultChain Africa Automation Script
-----------------------------------
A unified automation pipeline for:
  • Dependency auto-detection and installation
  • Build, clean, and test cycle
  • Local blockchain management via Anvil
  • Smart contract deployment and artifact capture

All logs are stored under: vc_automation/logs/
"""
from web3 import Web3
import os
import sys
import subprocess
import datetime
import time
import re
import json
from pathlib import Path
from typing import Optional
import shutil

# ======================================================================
# === GLOBAL SETUP ===
# ======================================================================
PROJECT_ROOT = Path(__file__).resolve().parent.parent
VC_DIR = PROJECT_ROOT / "vc_automation"
LOGS_DIR = VC_DIR / "logs"
DEPLOYMENTS_DIR = VC_DIR / "deployments"
TRANSACTIONS_DIR = VC_DIR / "transactions"
REQUIREMENTS_FILE = PROJECT_ROOT / "requirements.txt"

LOGS_DIR.mkdir(parents=True, exist_ok=True)
DEPLOYMENTS_DIR.mkdir(parents=True, exist_ok=True)
TRANSACTIONS_DIR.mkdir(parents=True, exist_ok=True)

TIMESTAMP = datetime.datetime.now().strftime("%Y-%m-%d_%H-%M-%S")
LOG_FILE = LOGS_DIR / f"automation_{TIMESTAMP}.log"

# ======================================================================
# === BASIC LOGGING ===
# ======================================================================
def log(msg: str):
    """Write a message to both console and log file."""
    print(msg)
    with open(LOG_FILE, "a", encoding="utf-8") as f:
        f.write(msg + "\n")

# ======================================================================
# === DEPENDENCY MANAGEMENT ===
# ======================================================================
def ensure_requirements_and_install():
    CORE_PKGS = ["psutil", "colorama", "web3", "requests"]
    this_script = Path(__file__).read_text(encoding="utf-8", errors="ignore")

    imports = re.findall(r"^(?:from|import)\s+([a-zA-Z0-9_\.]+)", this_script, re.MULTILINE)
    required_packages = sorted(set(
        [i.split('.')[0] for i in imports if i not in ('os', 'sys', 'subprocess', 'datetime', 'time', 're', 'json', 'pathlib')]
    ))

    for p in CORE_PKGS:
        if p not in required_packages:
            required_packages.append(p)

    log(f"[+] Detected Python packages to ensure: {', '.join(required_packages)}")

    if not REQUIREMENTS_FILE.exists():
        with open(REQUIREMENTS_FILE, "w", encoding="utf-8") as f:
            for pkg in required_packages:
                f.write(pkg + "\n")
        log("Created new requirements.txt file.")
    else:
        try:
            existing = {l.strip() for l in REQUIREMENTS_FILE.read_text(encoding="utf-8", errors="ignore").splitlines() if l.strip()}
        except UnicodeDecodeError:
            existing = set()
        new_pkgs = [pkg for pkg in required_packages if pkg not in existing]
        if new_pkgs:
            with open(REQUIREMENTS_FILE, "a", encoding="utf-8") as f:
                for pkg in new_pkgs:
                    f.write(pkg + "\n")
            log(f"Updated requirements.txt with: {', '.join(new_pkgs)}")

    installed, already = [], []
    for pkg in required_packages:
        try:
            __import__(pkg)
            already.append(pkg)
        except ImportError:
            log(f"Installing missing package: {pkg}")
            subprocess.check_call([sys.executable, "-m", "pip", "install", pkg])
            installed.append(pkg)

    if installed:
        log(f"Installed new packages: {', '.join(installed)}")
    else:
        log("All required packages already installed.")

# ======================================================================
# === UTILITY HELPERS ===
# ======================================================================
def is_process_running_by_name_contains(name_fragment: str) -> bool:
    import psutil
    for proc in psutil.process_iter(attrs=["name", "cmdline"]):
        try:
            if name_fragment.lower() in proc.info["name"].lower():
                return True
        except (psutil.NoSuchProcess, psutil.AccessDenied, KeyError):
            continue
    return False

def run_command(cmd: list, cwd: Path = PROJECT_ROOT, capture: bool = True, timeout: int = 300) -> tuple:
    log(f"$ {' '.join(cmd)}")
    try:
        proc = subprocess.run(
            cmd,
            cwd=str(cwd),
            capture_output=capture,
            text=True,
            check=False,
            timeout=timeout
        )
        if proc.stdout:
            log(proc.stdout.strip())
        if proc.stderr:
            log(proc.stderr.strip())
        return proc.returncode, proc.stdout, proc.stderr
    except subprocess.TimeoutExpired:
        log(f"Command timed out after {timeout} seconds: {' '.join(cmd)}")
        return 124, "", "Timeout expired"
    except Exception as e:
        log(f"Exception running command {cmd}: {str(e)}")
        return 1, "", str(e)

def try_find_deploy_script() -> Optional[Path]:
    candidates = [
        PROJECT_ROOT / "backend" / "script" / "Deploy.s.sol",
        PROJECT_ROOT / "backend" / "scripts" / "Deploy.s.sol",
        PROJECT_ROOT / "script" / "Deploy.s.sol",
        PROJECT_ROOT / "scripts" / "Deploy.s.sol"
    ]
    for c in candidates:
        if c.exists():
            return c
    return None

# ======================================================================
# === STAGE 1: BUILD & TEST ===
# ======================================================================
def stage_1_build_and_test():
    log("=" * 70)
    log("STAGE 1: Build and test smart contracts")
    log(f"Started at {datetime.datetime.now().isoformat()}")
    log("=" * 70)

    run_command(["forge", "--version"])
    run_command(["anvil", "--version"])
    run_command(["forge", "clean"])
    run_command(["forge", "build"])
    run_command(["forge", "test", "-vv"])

    log("Stage 1 completed successfully.")

# ======================================================================
# === STAGE 2: ANVIL MANAGEMENT ===
# ======================================================================
def stage_2_ensure_anvil(start_if_missing: bool = True,
                         anvil_port: int = 8545,
                         chain_id: int = 31337,
                         timeout_seconds: int = 30) -> None:
    log("=" * 70)
    log("STAGE 2: Ensure local Anvil chain")
    log(f"Started at {datetime.datetime.now().isoformat()}")
    log("=" * 70)

    if is_process_running_by_name_contains("anvil"):
        log("Detected running Anvil instance. Reusing it.")
        return

    if not start_if_missing:
        log("Anvil not running and start_if_missing=False. Exiting Stage 2.")
        return

    anvil_log = LOGS_DIR / f"anvil_{TIMESTAMP}.log"

    try:
        subprocess.run(['which', 'anvil'], check=True, stdout=subprocess.DEVNULL)
    except subprocess.CalledProcessError:
        log("'anvil' executable not found in PATH. Please install Foundry or add it to PATH.")
        return

    log(f"Launching Anvil (port={anvil_port}, chain-id={chain_id})")

    try:
        proc = subprocess.Popen(
            ["anvil", "--port", str(anvil_port), "--chain-id", str(chain_id)],
            stdout=open(anvil_log, "w", encoding="utf-8"),
            stderr=subprocess.STDOUT,
            cwd=str(PROJECT_ROOT)
        )

        start_time = time.time()
        while not is_process_running_by_name_contains("anvil"):
            if time.time() - start_time > timeout_seconds:
                log("Anvil failed to start within timeout period.")
                proc.kill()
                return
            time.sleep(1)

        log(f"Anvil started successfully. Log: {anvil_log}")
    except Exception as e:
        log(f"Failed to start Anvil: {str(e)}")

# ======================================================================
# === STAGE 3: DEPLOYMENT ===
# ======================================================================
def stage_3_deploy_and_capture(rpc_url: str = "http://127.0.0.1:8545",
                               chain_id: int = 31337,
                               dry_run: bool = False,
                               timeout_seconds: int = 600) -> Optional[str]:
    log("=" * 70)
    log("STAGE 3: Deploy contracts and capture artifacts")
    log(f"Started at {datetime.datetime.now().isoformat()}")
    log("=" * 70)

    deploy_script = try_find_deploy_script()
    if not deploy_script:
        log("No Deploy.s.sol found. Skipping Stage 3.")
        return None

    chain_folder = DEPLOYMENTS_DIR / str(chain_id)
    chain_folder.mkdir(parents=True, exist_ok=True)

    if dry_run:
        log("Dry-run enabled: skipping actual broadcast deployment.")
        return None

    cmd = [
        "forge", "script", str(deploy_script),
        "--rpc-url", rpc_url,
        "--broadcast",
        "--chain-id", str(chain_id)
    ]

    log(f"Executing deployment: {' '.join(cmd)}")

    try:
        result = subprocess.run(
            cmd,
            cwd=str(PROJECT_ROOT),
            capture_output=True,
            text=True,
            check=False,
            timeout=timeout_seconds
        )

        stdout = result.stdout or ""
        stderr = result.stderr or ""

        # Save raw deploy logs
        deploy_log_path = LOGS_DIR / f"deploy_raw_{TIMESTAMP}.log"
        with open(deploy_log_path, "w", encoding="utf-8") as fh:
            fh.write(stdout + "\n" + stderr)

        deployed_contracts = {}
        tx_hashes = []

        # --- Parse lines like: DeployedContract:ContractName:0x...
        for line in stdout.splitlines():
            # Strip ANSI codes and whitespace
            line_clean = re.sub(r'\x1b\[[0-9;]*m', '', line).strip()
            if line_clean.startswith("DeployedContract:"):
                try:
                    _, contract_name, address = line_clean.split(":")
                    deployed_contracts[contract_name] = address
                except ValueError:
                    log(f"Warning: Could not parse deployment line: {line_clean}")
            elif "Transaction hash:" in line_clean:
                tx_hashes.append(line_clean.split("Transaction hash:")[1].strip())

        if deployed_contracts:
            json_path = chain_folder / f"deployment_summary_{TIMESTAMP}.json"
            with open(json_path, "w", encoding="utf-8") as f:
                json.dump(deployed_contracts, f, indent=4)
            log(f"Saved deployment summary to {json_path}")

            # Print a clear summary to console
            log("\n=== Contracts Deployed ===")
            for name, addr in deployed_contracts.items():
                log(f"{name:25} -> {addr}")
            log("=========================\n")
        else:
            log("No deployed contracts detected. Ensure Deploy.s.sol prints 'DeployedContract:ContractName:0x...' for each contract.")

        if tx_hashes:
            tx_log = TRANSACTIONS_DIR / f"tx_{TIMESTAMP}.log"
            with open(tx_log, "w", encoding="utf-8") as f:
                for tx in tx_hashes:
                    f.write(tx + "\n")
            log(f"Saved transaction hashes to {tx_log}")

        log("Deployment stage completed successfully.")

    except subprocess.TimeoutExpired:
        log(f"Deployment timed out after {timeout_seconds} seconds.")
        return None
    except FileNotFoundError:
        log("'forge' executable not found in PATH. Please install Foundry and try again.")
        return None
    except Exception as e:
        log(f"Unexpected error during deployment: {str(e)}")
        return None

    return chain_folder

# ======================================================================
# === CLEANUP PREVIOUS DEPLOYMENTS / LOGS ===
# ======================================================================
def clean_previous_deployments():
    if LOGS_DIR.exists():
        shutil.rmtree(LOGS_DIR)
    if DEPLOYMENTS_DIR.exists():
        shutil.rmtree(DEPLOYMENTS_DIR)
    if TRANSACTIONS_DIR.exists():
        shutil.rmtree(TRANSACTIONS_DIR)

    # Recreate directories
    LOGS_DIR.mkdir(parents=True, exist_ok=True)
    DEPLOYMENTS_DIR.mkdir(parents=True, exist_ok=True)
    TRANSACTIONS_DIR.mkdir(parents=True, exist_ok=True)

    log("Cleared old logs, deployments, and transaction artifacts.")


    # ======================================================================
# === STAGE 4: POST-DEPLOY SETUP ===
# ======================================================================
def stage_4_post_deploy_setup(chain_folder: Path,
                              rpc_url: str = "http://127.0.0.1:8545",
                              admin_private_key: str = "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80",
                              operator_address: str = "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266",
                              test_member_address: str = "0x70997970C51812dc3A010C7d01b50e0d17dc79C8") -> None:
    """
    Grant operator role, register a test member, update KYC, and verify.
    """
    if not chain_folder:
        log("No deployment folder provided. Skipping Stage 4.")
        return

    deployment_summary = chain_folder / f"deployment_summary_{TIMESTAMP}.json"
    if not deployment_summary.exists():
        log(f"No deployment summary found at {deployment_summary}. Cannot proceed.")
        return

    with open(deployment_summary, "r", encoding="utf-8") as f:
        deployed_contracts = json.load(f)

    loan_manager_address = deployed_contracts.get("LoanManager")
    if not loan_manager_address:
        log("LoanManager address not found in deployment summary. Skipping Stage 4.")
        return

    # Operator role hash in Solidity (replace with actual if different)
    OPERATOR_ROLE_HASH = Web3.keccak(text="OPERATOR_ROLE").hex()



    # Grant OPERATOR_ROLE to operator_address
    log(f"Computed OPERATOR_ROLE hash: {OPERATOR_ROLE_HASH}")
    run_command([
        "cast", "send", loan_manager_address,
        "grantRole(bytes32,address)", OPERATOR_ROLE_HASH, operator_address,
        "--rpc-url", rpc_url,
        "--private-key", admin_private_key
    ])

    
    # Verify OPERATOR_ROLE assignment
    log(f"Verifying if {operator_address} has OPERATOR_ROLE")
    code, stdout, _ = run_command([
        "cast", "call", loan_manager_address,
        "hasRole(bytes32,address) returns (bool)", OPERATOR_ROLE_HASH, operator_address,
        "--rpc-url", rpc_url
    ])
    log(f"Operator role assigned: {stdout.strip()}")


    # Register test member (you may need to adapt the registration function & parameters)
    log(f"Registering test member {test_member_address}")
    run_command([
        "cast", "send", loan_manager_address,
        "registerMember(address)", test_member_address,
        "--rpc-url", rpc_url,
        "--private-key", operator_address
    ])

    # Update KYC for test member
    log(f"Updating KYC for {test_member_address} to 1 (verified)")
    run_command([
        "cast", "send", loan_manager_address,
        "updateKyc(address,uint8)", test_member_address, "1",
        "--rpc-url", rpc_url,
        "--private-key", operator_address
    ])

    # Verify isRegistered
    log(f"Verifying if {test_member_address} is registered")
    code, stdout, _ = run_command([
        "cast", "call", loan_manager_address,
        "isRegistered(address) returns (bool)", test_member_address,
        "--rpc-url", rpc_url
    ])
    log(f"isRegistered: {stdout.strip()}")

# ======================================================================
# === MAIN PIPELINE ===
# ======================================================================
def main():
    clean_previous_deployments()
    log("=== VaultChain Africa Automation Bootstrap ===")
    ensure_requirements_and_install()
    stage_1_build_and_test()
    stage_2_ensure_anvil()
    chain_folder = stage_3_deploy_and_capture()  # Capture deployment folder
    stage_4_post_deploy_setup(chain_folder)      # Run post-deploy setup
    log(f"All automation stages completed. Logs stored at: {LOG_FILE}")

if __name__ == "__main__":
    main()



# Usage: python vc_automation/vc_automation.py
