// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "./storage/ACTXStorageV1.sol";
import "./libraries/Errors.sol";
import "./interfaces/IACTXToken.sol";

contract ACTXToken is
    Initializable,
    ERC20Upgradeable,
    ERC20PausableUpgradeable,
    AccessControlUpgradeable,
    UUPSUpgradeable,
    ACTXStorageV1,
    IACTXToken
{
    bytes32 public constant REWARD_MANAGER_ROLE =
        keccak256("REWARD_MANAGER_ROLE");
    bytes32 public constant TAX_ADMIN_ROLE = keccak256("TAX_ADMIN_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address treasury,
        address reservoir,
        uint16 initialTaxRate
    ) public initializer {
        if (treasury == address(0)) revert Errors.ZeroAddressNotAllowed();
        if (reservoir == address(0)) revert Errors.ZeroAddressNotAllowed();
        if (initialTaxRate > MAX_TAX_RATE) {
            revert Errors.TaxRateExceedsMaximum(initialTaxRate, MAX_TAX_RATE);
        }

        __ERC20_init("ACT.X", "ACTX");
        __ERC20Pausable_init();
        __AccessControl_init();

        _grantRole(DEFAULT_ADMIN_ROLE, treasury);
        _grantRole(UPGRADER_ROLE, treasury);
        _grantRole(PAUSER_ROLE, treasury);
        _grantRole(TAX_ADMIN_ROLE, treasury);

        StorageV1 storage $ = _getStorageV1();
        $.taxRateBasisPoints = initialTaxRate;
        $.reservoirAddress = reservoir;
        $.taxExempt[treasury] = true;
        $.taxExempt[reservoir] = true;

        _mint(treasury, TOTAL_SUPPLY);
    }

    function taxRateBasisPoints() external view returns (uint16) {
        return _getStorageV1().taxRateBasisPoints;
    }

    function reservoirAddress() external view returns (address) {
        return _getStorageV1().reservoirAddress;
    }

    function rewardPoolBalance() external view returns (uint256) {
        return _getStorageV1().rewardPoolBalance;
    }

    function isTaxExempt(address account) external view returns (bool) {
        return _getStorageV1().taxExempt[account];
    }

    function distributeReward(
        address recipient,
        uint256 amount
    ) external onlyRole(REWARD_MANAGER_ROLE) {
        if (recipient == address(0)) revert Errors.ZeroAddressNotAllowed();
        if (amount == 0) revert Errors.ZeroAmountNotAllowed();

        StorageV1 storage $ = _getStorageV1();
        if (amount > $.rewardPoolBalance) {
            revert Errors.InsufficientRewardPool(amount, $.rewardPoolBalance);
        }

        $.rewardPoolBalance -= amount;
        _mint(recipient, amount);

        emit RewardDistributed(recipient, amount);
    }

    function fundRewardPool(
        uint256 amount
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (amount == 0) revert Errors.ZeroAmountNotAllowed();

        StorageV1 storage $ = _getStorageV1();
        _burn(msg.sender, amount);
        $.rewardPoolBalance += amount;

        emit RewardPoolFunded(amount);
    }

    function setTaxRate(uint16 newRate) external onlyRole(TAX_ADMIN_ROLE) {
        if (newRate > MAX_TAX_RATE) {
            revert Errors.TaxRateExceedsMaximum(newRate, MAX_TAX_RATE);
        }

        StorageV1 storage $ = _getStorageV1();
        uint16 oldRate = $.taxRateBasisPoints;
        $.taxRateBasisPoints = newRate;

        emit TaxRateUpdated(oldRate, newRate);
    }

    function setReservoir(
        address newReservoir
    ) external onlyRole(TAX_ADMIN_ROLE) {
        if (newReservoir == address(0)) revert Errors.ZeroAddressNotAllowed();

        StorageV1 storage $ = _getStorageV1();
        address oldReservoir = $.reservoirAddress;
        $.reservoirAddress = newReservoir;

        emit ReservoirUpdated(oldReservoir, newReservoir);
    }

    function setTaxExempt(
        address account,
        bool exempt
    ) external onlyRole(TAX_ADMIN_ROLE) {
        if (account == address(0)) revert Errors.ZeroAddressNotAllowed();
        _getStorageV1().taxExempt[account] = exempt;
    }

    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    function _update(
        address from,
        address to,
        uint256 value
    ) internal override(ERC20Upgradeable, ERC20PausableUpgradeable) {
        if (from == address(0) || to == address(0)) {
            super._update(from, to, value);
            return;
        }

        StorageV1 storage $ = _getStorageV1();

        if ($.taxExempt[from] || $.taxRateBasisPoints == 0) {
            super._update(from, to, value);
            return;
        }

        uint256 taxAmount = (value * $.taxRateBasisPoints) / 10000;
        uint256 netAmount = value - taxAmount;

        super._update(from, $.reservoirAddress, taxAmount);
        super._update(from, to, netAmount);

        emit TaxCollected(from, to, taxAmount, netAmount);
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyRole(UPGRADER_ROLE) {}
}
