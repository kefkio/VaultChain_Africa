// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract TimelockController is AccessControl, ReentrancyGuard {
    bytes32 public constant TIMELOCK_ADMIN_ROLE = keccak256("TIMELOCK_ADMIN_ROLE");
    bytes32 public constant PROPOSER_ROLE       = keccak256("PROPOSER_ROLE");
    bytes32 public constant EXECUTOR_ROLE       = keccak256("EXECUTOR_ROLE");

    uint256 private constant _DONE_TIMESTAMP = uint256(1);

    event CallScheduled(
        bytes32 indexed id,
        uint256 indexed index,
        address target,
        uint256 value,
        bytes data,
        bytes32 predecessor,
        uint256 delay
    );
    event CallExecuted(
        bytes32 indexed id,
        uint256 indexed index,
        address target,
        uint256 value,
        bytes data
    );
    event Cancelled(bytes32 indexed id);
    event MinDelayChange(uint256 oldDuration, uint256 newDuration);

    struct Operation {
        uint256 timestamp;
    }

    mapping(bytes32 => Operation) private _operations;
    uint256 private _minDelay;

    constructor(
        uint256 minDelay,
        address[] memory proposers,
        address[] memory executors,
        address admin
    ) {
        address actualAdmin = admin == address(0) ? msg.sender : admin;

        _grantRole(DEFAULT_ADMIN_ROLE, actualAdmin);
        _grantRole(TIMELOCK_ADMIN_ROLE, actualAdmin);

        for (uint256 i = 0; i < proposers.length; i++) {
            _grantRole(PROPOSER_ROLE, proposers[i]);
        }
        for (uint256 i = 0; i < executors.length; i++) {
            _grantRole(EXECUTOR_ROLE, executors[i]);
        }

        _setMinDelay(minDelay);
    }

    function getMinDelay() public view returns (uint256) {
        return _minDelay;
    }

    function updateDelay(uint256 newDelay) external onlyRole(TIMELOCK_ADMIN_ROLE) {
        uint256 oldDelay = _minDelay;
        _setMinDelay(newDelay);
        emit MinDelayChange(oldDelay, newDelay);
    }

    function _setMinDelay(uint256 newDelay) internal {
        _minDelay = newDelay;
    }

    function hashOperation(
        address target,
        uint256 value,
        bytes calldata data,
        bytes32 predecessor,
        bytes32 salt
    ) public pure returns (bytes32) {
        return keccak256(abi.encode(target, value, data, predecessor, salt));
    }

    function isOperationPending(bytes32 id) public view returns (bool) {
        Operation storage op = _operations[id];
        return op.timestamp > 0 && op.timestamp != _DONE_TIMESTAMP && block.timestamp < op.timestamp;
    }

    function isOperationReady(bytes32 id) public view returns (bool) {
        Operation storage op = _operations[id];
        return op.timestamp > 0 && op.timestamp != _DONE_TIMESTAMP && block.timestamp >= op.timestamp;
    }

    function isOperationDone(bytes32 id) public view returns (bool) {
        Operation storage op = _operations[id];
        return op.timestamp == _DONE_TIMESTAMP;
    }

    function schedule(
        address target,
        uint256 value,
        bytes calldata data,
        bytes32 predecessor,
        bytes32 salt,
        uint256 delay
    ) external onlyRole(PROPOSER_ROLE) {
        require(delay >= getMinDelay(), "TimelockController: insufficient delay");

        bytes32 id = hashOperation(target, value, data, predecessor, salt);
        require(_operations[id].timestamp == 0, "TimelockController: operation already scheduled");

        uint256 timestamp = block.timestamp + delay;
        _operations[id].timestamp = timestamp;

        emit CallScheduled(id, 0, target, value, data, predecessor, delay);
    }

    function cancel(bytes32 id) external onlyRole(TIMELOCK_ADMIN_ROLE) {
        require(!isOperationDone(id), "TimelockController: operation already done");
        require(_operations[id].timestamp != 0, "TimelockController: unknown operation");

        delete _operations[id];
        emit Cancelled(id);
    }

    function execute(
        address target,
        uint256 value,
        bytes calldata data,
        bytes32 predecessor,
        bytes32 salt
    ) external payable nonReentrant onlyRole(EXECUTOR_ROLE) {
        bytes32 id = hashOperation(target, value, data, predecessor, salt);

        require(isOperationReady(id), "TimelockController: operation is not ready");
        require(predecessor == bytes32(0) || isOperationDone(predecessor), "TimelockController: missing dependency");

        _operations[id].timestamp = _DONE_TIMESTAMP;

        (bool success, ) = target.call{value: value}(data);
        require(success, "TimelockController: underlying transaction reverted");

        emit CallExecuted(id, 0, target, value, data);
    }
}
