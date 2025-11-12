// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;


import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "../core/interfaces/IFeeManager.sol";
import "./InternalSmartWallet.sol";

contract Relayer is ReentrancyGuard {
    bytes32 public DOMAIN_SEPARATOR;
    bytes32 public constant META_TX_TYPEHASH = keccak256(
        "MetaTransaction(address from,address to,bytes data,uint256 nonce,uint256 fee)"
    );

    mapping(address => uint256) public nonces;
    IFeeManager public feeManager;

    event MetaTxExecuted(address indexed from, address indexed to, uint256 fee, uint256 nonce);

    constructor(address _feeManager) {
        require(_feeManager != address(0), "Invalid FeeManager");
        feeManager = IFeeManager(_feeManager);

        DOMAIN_SEPARATOR = keccak256(abi.encode(
            keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
            keccak256("WalletRelayer"),
            keccak256("1"),
            block.chainid,
            address(this)
        ));
    }

    function executeMetaTx(
        address from,
        address to,
        bytes calldata data,
        uint256 fee,
        uint8 v, bytes32 r, bytes32 s
    ) external nonReentrant {
        require(verifyMetaTx(from, to, data, fee, v, r, s), "Invalid signature");

        // ✅ Update state before external call
        nonces[from]++;
        feeManager.recordFee(from, fee);

        // ✅ Execute via smart wallet
        InternalSmartWallet(from).execute(to, data);

        emit MetaTxExecuted(from, to, fee, nonces[from] - 1);
    }

    function verifyMetaTx(
        address from,
        address to,
        bytes calldata data,
        uint256 fee,
        uint8 v, bytes32 r, bytes32 s
    ) public view returns (bool) {
        bytes32 structHash = keccak256(abi.encode(
            META_TX_TYPEHASH,
            from,
            to,
            keccak256(data),
            nonces[from],
            fee
        ));

        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR, structHash));
        return ecrecover(digest, v, r, s) == from;
    }
}