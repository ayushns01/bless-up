# Security Implementations

This document details where and how each security mitigation is implemented in the ACTX Token codebase.

---

## 1. Reentrancy Protection

**Mitigation:** ReentrancyGuard on Vesting/Airdrop; CEI pattern

### Implementation

| File | Line | Description |
|------|------|-------------|
| `src/Vesting.sol` | L7 | Imports `ReentrancyGuard` |
| `src/Vesting.sol` | L10 | Contract inherits `ReentrancyGuard` |
| `src/Vesting.sol` | L63 | `release()` uses `nonReentrant` modifier |
| `src/Airdrop.sol` | L8 | Imports `ReentrancyGuard` |
| `src/Airdrop.sol` | L11 | Contract inherits `ReentrancyGuard` |
| `src/Airdrop.sol` | L49 | `claim()` uses `nonReentrant` modifier |

### How It Works

1. **ReentrancyGuard:** OpenZeppelin's `ReentrancyGuard` uses a mutex lock that prevents a function from being called again before the first execution completes.

2. **CEI Pattern (Checks-Effects-Interactions):** State changes occur **before** external calls:

```solidity
// Vesting.sol - release()
function release() external nonReentrant {
    // CHECKS
    if (schedule.totalAmount == 0) revert Errors.ZeroAmountNotAllowed();
    if (schedule.revoked) revert Errors.NoTokensToRelease();
    
    // EFFECTS (state updated BEFORE transfer)
    schedule.releasedAmount += releasable;
    
    // INTERACTIONS (external call last)
    token.safeTransfer(msg.sender, releasable);
}
```

---

## 2. Replay Attack Prevention

**Mitigation:** `rewardId` tracking in `distributeReward()`

### Implementation

| File | Line | Description |
|------|------|-------------|
| `src/storage/ACTXStorageV1.sol` | L15 | `usedRewardIds` mapping declared |
| `src/ACTXToken.sol` | L82-98 | `distributeReward()` checks and marks IDs |
| `src/ACTXToken.sol` | L100-102 | `isRewardIdUsed()` view function |

### How It Works

```solidity
function distributeReward(
    address recipient,
    uint256 amount,
    bytes32 rewardId
) external onlyRole(REWARD_MANAGER_ROLE) {
    // Check if rewardId was already used
    if ($.usedRewardIds[rewardId]) {
        revert Errors.RewardIdAlreadyUsed(rewardId);
    }
    
    // Mark as used BEFORE distribution
    $.usedRewardIds[rewardId] = true;
    
    // Distribute reward
    $.rewardPoolBalance -= amount;
    _transfer(address(this), recipient, amount);
}
```

Each reward distribution requires a unique `bytes32` identifier. Once used, the ID is permanently marked, preventing:
- Double-claiming the same reward
- Replaying signed reward authorizations

---

## 3. Unauthorized Upgrade Protection

**Mitigation:** Timelock + one-time lock on `setTimelockController()`

### Implementation

| File | Line | Description |
|------|------|-------------|
| `src/ACTXToken.sol` | L27 | `UPGRADE_TIMELOCK_DELAY` constant (48 hours) |
| `src/ACTXToken.sol` | L183-203 | `_authorizeUpgrade()` logic |
| `src/ACTXToken.sol` | L214-224 | `setTimelockController()` one-time lock |
| `src/storage/ACTXStorageV1.sol` | L16 | `timelockController` address stored |

### How It Works

**Two-Phase Upgrade Authorization:**

```solidity
function _authorizeUpgrade(address newImplementation) internal override {
    StorageV1 storage $ = _getStorageV1();
    
    if ($.timelockController == address(0)) {
        // PHASE 1: Pre-timelock deployment
        // Only UPGRADER_ROLE can upgrade (for initial setup)
        if (!hasRole(UPGRADER_ROLE, msg.sender)) {
            revert Errors.UnauthorizedUpgrade(msg.sender);
        }
    } else {
        // PHASE 2: Post-timelock (permanent)
        // ONLY the timelock contract can upgrade
        if (msg.sender != $.timelockController) {
            revert Errors.UnauthorizedUpgrade(msg.sender);
        }
    }
}
```

**One-Time Lock:**

```solidity
function setTimelockController(address _timelock) external onlyRole(DEFAULT_ADMIN_ROLE) {
    if (_timelock == address(0)) revert Errors.ZeroAddressNotAllowed();
    
    StorageV1 storage $ = _getStorageV1();
    
    // CRITICAL: Can only be set once
    if ($.timelockController != address(0)) {
        revert Errors.UnauthorizedAccess(msg.sender, DEFAULT_ADMIN_ROLE);
    }
    
    $.timelockController = _timelock;
    emit TimelockControllerSet(_timelock);
}
```

Once the timelock is set, it **cannot be changed**, ensuring:
- All upgrades require 48-hour delay
- Community can review proposed upgrades
- Malicious upgrades can be cancelled before execution

---

## 4. Flash Loan Attack Protection

**Mitigation:** Not applicable (no borrowing)

### Why It's Not a Risk

The ACTX token contract does not implement:
- Flash loan functionality
- Borrowing/lending mechanisms
- Atomic borrow-and-repay operations

Without these features, there's no attack vector for flash loan exploits. The contract is a standard ERC20 token with tax and reward mechanics.

---

## 5. Front-Running / Sandwich Attack Protection

**Mitigation:** Tax-based, no sandwich opportunity

### Implementation

| File | Line | Description |
|------|------|-------------|
| `src/ACTXToken.sol` | L160-179 | `_update()` transfer hook with tax |
| `src/storage/ACTXStorageV1.sol` | L8 | `MAX_TAX_RATE` = 1000 (10%) |

### How It Works

```solidity
function _update(
    address from,
    address to,
    uint256 value
) internal override(ERC20Upgradeable, ERC20PausableUpgradeable) {
    // Skip tax for minting/burning
    if (from == address(0) || to == address(0)) {
        super._update(from, to, value);
        return;
    }

    StorageV1 storage $ = _getStorageV1();

    // Skip tax for exempt addresses
    if ($.taxExempt[from] || $.taxRateBasisPoints == 0) {
        super._update(from, to, value);
        return;
    }

    // Calculate and apply tax
    uint256 taxAmount = (value * $.taxRateBasisPoints) / 10000;
    uint256 netAmount = value - taxAmount;

    super._update(from, $.reservoirAddress, taxAmount);  // Tax to reservoir
    super._update(from, to, netAmount);                  // Net to recipient
}
```

**Why Sandwiching Is Unprofitable:**

In a typical sandwich attack:
1. Attacker front-runs: BUY (pays tax)
2. Victim transaction executes
3. Attacker back-runs: SELL (pays tax again)

With up to 10% tax on each leg, the attacker loses money on both transactions, making the attack economically unviable.

---

## 6. Storage Collision Prevention

**Mitigation:** EIP-7201 namespaced storage

### Implementation

| File | Line | Description |
|------|------|-------------|
| `src/storage/ACTXStorageV1.sol` | L6-7 | EIP-7201 documentation |
| `src/storage/ACTXStorageV1.sol` | L21-22 | `STORAGE_LOCATION` constant |
| `src/storage/ACTXStorageV1.sol` | L24-28 | `_getStorageV1()` function |

### How It Works

```solidity
/// @dev EIP-7201 storage location: 
/// keccak256(abi.encode(uint256(keccak256("actx.storage.v1")) - 1)) & ~bytes32(uint256(0xff))
bytes32 private constant STORAGE_LOCATION =
    0x997ad894186312e0dcd9dd5c3f2020fcc1c091277f5bfb2f013a2ead9041bf00;

function _getStorageV1() internal pure returns (StorageV1 storage $) {
    assembly {
        $.slot := STORAGE_LOCATION
    }
}
```

**Traditional vs Namespaced Storage:**

| Approach | Risk |
|----------|------|
| Sequential slots (0, 1, 2...) | New variables in upgrades can overwrite existing data |
| EIP-7201 namespaced | Storage at hash-derived slot, impossible to collide |

The storage location is derived from:
```
keccak256(abi.encode(uint256(keccak256("actx.storage.v1")) - 1)) & ~bytes32(uint256(0xff))
```

This ensures:
- Deterministic, unique storage location
- No collision with inherited contracts (OpenZeppelin)
- Safe to add new storage in future versions (V2, V3, etc.)

---

## Summary Table

| Attack Vector | Mitigation | Primary File(s) |
|---------------|------------|-----------------|
| Reentrancy | `nonReentrant` modifier + CEI | Vesting.sol, Airdrop.sol |
| Replay Attacks | `usedRewardIds` mapping | ACTXToken.sol |
| Unauthorized Upgrade | Timelock + one-time lock | ACTXToken.sol |
| Flash Loans | N/A (no borrowing) | - |
| Front-running | Tax on transfers | ACTXToken.sol |
| Storage Collision | EIP-7201 namespaced storage | ACTXStorageV1.sol |

---

## References

- [EIP-7201: Namespaced Storage Layout](https://eips.ethereum.org/EIPS/eip-7201)
- [OpenZeppelin ReentrancyGuard](https://docs.openzeppelin.com/contracts/5.x/api/utils#ReentrancyGuard)
- [OpenZeppelin UUPS Upgradeable](https://docs.openzeppelin.com/contracts/5.x/api/proxy#UUPSUpgradeable)
- [Checks-Effects-Interactions Pattern](https://docs.soliditylang.org/en/latest/security-considerations.html#re-entrancy)
