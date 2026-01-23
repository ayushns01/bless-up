// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/// @title ACTXStorageV1
/// @notice Namespaced storage for ACTXToken using EIP-7201 pattern
/// @dev Storage slot derived as: keccak256(abi.encode(uint256(keccak256("actx.storage.v1")) - 1)) & ~bytes32(uint256(0xff))
abstract contract ACTXStorageV1 {
    uint16 public constant MAX_TAX_RATE = 1000;
    uint256 public constant TOTAL_SUPPLY = 100_000_000 ether;

    struct StorageV1 {
        uint16 taxRateBasisPoints;
        address reservoirAddress;
        uint256 rewardPoolBalance;
        mapping(address => bool) taxExempt;
        mapping(bytes32 => bool) usedRewardIds;
        address timelockController;
    }

    /// @dev EIP-7201 storage location: keccak256(abi.encode(uint256(keccak256("actx.storage.v1")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant STORAGE_LOCATION =
        0x997ad894186312e0dcd9dd5c3f2020fcc1c091277f5bfb2f013a2ead9041bf00;

    function _getStorageV1() internal pure returns (StorageV1 storage $) {
        assembly {
            $.slot := STORAGE_LOCATION
        }
    }

    uint256[50] private __gap;
}
