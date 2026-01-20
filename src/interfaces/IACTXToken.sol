// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

interface IACTXToken {
    event RewardDistributed(
        address indexed recipient,
        uint256 amount,
        bytes32 indexed activityId
    );

    event TaxCollected(
        address indexed from,
        address indexed to,
        uint256 taxAmount,
        uint256 netAmount
    );

    event TaxRateUpdated(uint16 oldRate, uint16 newRate);

    event ReservoirUpdated(address oldReservoir, address newReservoir);

    event RewardPoolFunded(uint256 amount);

    function taxRateBasisPoints() external view returns (uint16);

    function reservoirAddress() external view returns (address);

    function rewardPoolBalance() external view returns (uint256);

    function isTaxExempt(address account) external view returns (bool);

    function distributeReward(
        address recipient,
        uint256 amount,
        bytes32 activityId
    ) external;

    function fundRewardPool(uint256 amount) external;

    function setTaxRate(uint16 newRate) external;

    function setReservoir(address newReservoir) external;

    function setTaxExempt(address account, bool exempt) external;
}
