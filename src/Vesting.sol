// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./libraries/Errors.sol";

contract Vesting is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    IERC20 public immutable token;

    uint256 public constant VESTING_DURATION = 4 * 365 days;
    uint256 public constant CLIFF_DURATION = 365 days;

    struct VestingSchedule {
        uint256 totalAmount;
        uint256 startTime;
        uint256 releasedAmount;
        bool revoked;
    }

    mapping(address => VestingSchedule) public schedules;
    address[] public beneficiaries;

    event VestingCreated(
        address indexed beneficiary,
        uint256 amount,
        uint256 startTime
    );
    event TokensReleased(address indexed beneficiary, uint256 amount);
    event VestingRevoked(address indexed beneficiary, uint256 unvestedAmount);

    constructor(address _token, address _owner) Ownable(_owner) {
        if (_token == address(0)) revert Errors.ZeroAddressNotAllowed();
        token = IERC20(_token);
    }

    function createVesting(
        address beneficiary,
        uint256 amount
    ) external onlyOwner {
        if (beneficiary == address(0)) revert Errors.ZeroAddressNotAllowed();
        if (amount == 0) revert Errors.ZeroAmountNotAllowed();
        if (schedules[beneficiary].totalAmount > 0) {
            revert Errors.BeneficiaryAlreadyExists(beneficiary);
        }

        token.safeTransferFrom(msg.sender, address(this), amount);

        schedules[beneficiary] = VestingSchedule({
            totalAmount: amount,
            startTime: block.timestamp,
            releasedAmount: 0,
            revoked: false
        });

        beneficiaries.push(beneficiary);

        emit VestingCreated(beneficiary, amount, block.timestamp);
    }

    function release() external nonReentrant {
        VestingSchedule storage schedule = schedules[msg.sender];

        if (schedule.totalAmount == 0) revert Errors.ZeroAmountNotAllowed();
        if (schedule.revoked) revert Errors.NoTokensToRelease();

        uint256 releasable = _releasableAmount(msg.sender);
        if (releasable == 0) revert Errors.NoTokensToRelease();

        schedule.releasedAmount += releasable;
        token.safeTransfer(msg.sender, releasable);

        emit TokensReleased(msg.sender, releasable);
    }

    function revoke(address beneficiary) external onlyOwner {
        VestingSchedule storage schedule = schedules[beneficiary];

        if (schedule.totalAmount == 0) revert Errors.ZeroAmountNotAllowed();
        if (schedule.revoked) revert Errors.NoTokensToRelease();

        uint256 vested = _vestedAmount(beneficiary);
        uint256 unvested = schedule.totalAmount - vested;

        schedule.revoked = true;

        if (unvested > 0) {
            token.safeTransfer(owner(), unvested);
        }

        emit VestingRevoked(beneficiary, unvested);
    }

    function releasableAmount(
        address beneficiary
    ) external view returns (uint256) {
        return _releasableAmount(beneficiary);
    }

    function vestedAmount(address beneficiary) external view returns (uint256) {
        return _vestedAmount(beneficiary);
    }

    function getSchedule(
        address beneficiary
    )
        external
        view
        returns (
            uint256 totalAmount,
            uint256 startTime,
            uint256 releasedAmount,
            uint256 vestedAmt,
            uint256 releasableAmt,
            bool revoked
        )
    {
        VestingSchedule storage schedule = schedules[beneficiary];
        return (
            schedule.totalAmount,
            schedule.startTime,
            schedule.releasedAmount,
            _vestedAmount(beneficiary),
            _releasableAmount(beneficiary),
            schedule.revoked
        );
    }

    function getBeneficiariesCount() external view returns (uint256) {
        return beneficiaries.length;
    }

    function _vestedAmount(
        address beneficiary
    ) internal view returns (uint256) {
        VestingSchedule storage schedule = schedules[beneficiary];

        if (schedule.totalAmount == 0 || schedule.revoked) {
            return schedule.releasedAmount;
        }

        uint256 elapsed = block.timestamp - schedule.startTime;

        if (elapsed < CLIFF_DURATION) {
            return 0;
        }

        if (elapsed >= VESTING_DURATION) {
            return schedule.totalAmount;
        }

        return (schedule.totalAmount * elapsed) / VESTING_DURATION;
    }

    function _releasableAmount(
        address beneficiary
    ) internal view returns (uint256) {
        VestingSchedule storage schedule = schedules[beneficiary];
        return _vestedAmount(beneficiary) - schedule.releasedAmount;
    }
}
