// generate-and-sign.js
const { ethers } = require("ethers");
const bip39 = require("bip39");
const crypto = require("crypto");
const scrypt = require("scrypt-js"); // optional, you can use crypto.scryptSync

async function generateMemberWallet({ memberId, passwordForKeystore }) {
  // 1. Create mnemonic
  const mnemonic = bip39.generateMnemonic(128); // 12 words (128 bits entropy) or use 256 bits for 24 words
  // 2. Derive wallet using ethers (uses BIP39 + BIP44 default path m/44'/60'/0'/0/0)
  const wallet = ethers.Wallet.fromMnemonic(mnemonic);
  console.log("address:", wallet.address);

  // 3. Create an encrypted JSON keystore (ethers uses AES-128-CTR + scrypt)
  // WARNING: Protect password; do not use email etc. Use user-supplied strong password OR use KMS-managed key.
  const encryptedJson = await wallet.encrypt(passwordForKeystore, { scrypt: { N: 1 << 18 } }); // adjust scrypt params to desired difficulty
  // Store encryptedJson in DB (NOT mnemonic nor plaintext private key)
  // Or better: store encryptedJson in vault backed by KMS.

  // 4. Show mnemonic to admin or to user once (if custodial, maybe display to admin for backup)
  // Display the mnemonic exactly once — instruct user to copy/store offline securely.

  return { mnemonic, address: wallet.address, encryptedJson };
}

// Signing example (sign an arbitrary message using wallet private key)
async function signMessageWithEncryptedKeystore(encryptedJson, password, message) {
  const wallet = await ethers.Wallet.fromEncryptedJson(encryptedJson, password);
  const signature = await wallet.signMessage(ethers.utils.toUtf8Bytes(message));
  return signature;
}

// Example usage
(async () => {
  const password = "a-strong-password-should-be-provided-or-derived-securely";
  const { mnemonic, address, encryptedJson } = await generateMemberWallet({
    memberId: "member-123",
    passwordForKeystore: password,
  });

  console.log("MNEMONIC (show once):", mnemonic); // show once
  const sig = await signMessageWithEncryptedKeystore(encryptedJson, password, "Welcome to VaultChain");
  console.log("signature:", sig);
})();
