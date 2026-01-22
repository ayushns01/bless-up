// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

interface IVesting {
    event VestingCreated(
        address indexed beneficiary,
        uint256 amount,
        uint256 startTime
    );
    event TokensReleased(address indexed beneficiary, uint256 amount);
    event VestingRevoked(address indexed beneficiary, uint256 unvestedAmount);

    function createVesting(address beneficiary, uint256 amount) external;
    function release() external;
    function revoke(address beneficiary) external;
    function releasableAmount(
        address beneficiary
    ) external view returns (uint256);
    function vestedAmount(address beneficiary) external view returns (uint256);
}
