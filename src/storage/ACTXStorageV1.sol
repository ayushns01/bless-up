// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

abstract contract ACTXStorageV1 {
    uint16 public constant MAX_TAX_RATE = 1000;
    uint256 public constant TOTAL_SUPPLY = 100_000_000 ether;

    struct StorageV1 {
        uint16 taxRateBasisPoints;
        address reservoirAddress;
        uint256 rewardPoolBalance;
        mapping(address => bool) taxExempt;
    }

    bytes32 private constant STORAGE_LOCATION =
        0x997ad894186312e0dcd9dd5c3f2020fcc1c091277f5bfb2f013a2ead9041bf00;

    function _getStorageV1() internal pure returns (StorageV1 storage $) {
        assembly {
            $.slot := STORAGE_LOCATION
        }
    }

    uint256[50] private __gap;
}
