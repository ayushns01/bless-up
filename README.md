# ACT.X Token

An upgradeable ERC-20 rewards token for the BlessUP referral ecosystem, deployed on Base L2.

| Component | Version |
|-----------|---------|
| Solidity | 0.8.28 |
| Foundry | v1.5.1 |
| OpenZeppelin Upgradeable | 5.5.0 |

---

## Overview

ACT.X is a fixed-supply ERC-20 token with:
- **100,000,000 ACTX** total supply (minted once at deployment)
- **Transaction tax** (0-10%) sent to reservoir for ecosystem recycling
- **Reward distribution** from pre-funded pool with replay protection
- **UUPS upgradeability** with 48-hour timelock protection
- **Role-based access control** for granular permissions

---

## Deployed Contracts (Sepolia)


| **Token Proxy** | `0x7F6A84e2971016E515bda7b2948A8583985aF624` | [View](https://sepolia.etherscan.io/address/0x7F6A84e2971016E515bda7b2948A8583985aF624) |

| **TimelockController** | `0x2e01317084250bf05dFa01feEf349bEEEF2BA5b4` | [View](https://sepolia.etherscan.io/address/0x2e01317084250bf05dFa01feEf349bEEEF2BA5b4) |

| **Implementation** | `0xB05278D719c03D48be45A2Fe16b800EE3C5efB03` | [View](https://sepolia.etherscan.io/address/0xB05278D719c03D48be45A2Fe16b800EE3C5efB03) |

Gas Used: 0.00436 ETH (~$10 at current prices)

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        ERC1967 Proxy                            │
│                    (Deployed Contract)                          │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                       ACTXToken.sol                             │
│  ┌─────────────────┐  ┌─────────────────┐  ┌────────────────┐   │
│  │ ERC20Upgradeable│  │ AccessControl   │  │ UUPSUpgradeable│   │
│  └─────────────────┘  └─────────────────┘  └────────────────┘   │
│  ┌─────────────────┐  ┌─────────────────┐                       │
│  │ ERC20Pausable   │  │ ACTXStorageV1   │                       │
│  └─────────────────┘  └─────────────────┘                       │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                    TimelockController                           │
│                 (48-hour upgrade delay)                         │
└─────────────────────────────────────────────────────────────────┘
```

---

## Token Economics

| Parameter | Value |
|-----------|-------|
| Name | ACT.X |
| Symbol | ACTX |
| Total Supply | 100,000,000 ACTX |
| Decimals | 18 |
| Max Tax Rate | 10% (1000 basis points) |
| Default Tax Rate | 2% (200 basis points) |

### Token Flow

```
Treasury (100M ACTX at deployment)
         │
         ├─── Transfer to Users ──────► 2% tax to Reservoir
         │
         ├─── Fund Reward Pool ───────► Tokens held by contract
         │
         └─── Distribute Rewards ─────► Transfer from contract (replay-protected)
```

---

## Roles & Permissions

| Role | Permissions |
|------|-------------|
| `DEFAULT_ADMIN_ROLE` | Manage roles, fund reward pool |
| `REWARD_MANAGER_ROLE` | Distribute rewards (with rewardId) |
| `TAX_ADMIN_ROLE` | Set tax rate, reservoir address, exemptions |
| `PAUSER_ROLE` | Emergency pause/unpause transfers |
| `UPGRADER_ROLE` | Authorize upgrades (pre-timelock only) |

---

## Security Features

### Upgrade Protection
1. **Pre-timelock:** Requires `UPGRADER_ROLE` (treasury multi-sig)
2. **Post-timelock:** Only `TimelockController` can upgrade
3. **48-hour delay:** All upgrades require waiting period
4. **One-time lock:** `setTimelockController()` cannot be called twice

### Replay Protection
Every reward distribution requires a unique `rewardId` (bytes32):
```solidity
function distributeReward(address recipient, uint256 amount, bytes32 rewardId)
```
- `rewardId` is tracked on-chain in `usedRewardIds` mapping
- Duplicate `rewardId` reverts with `RewardIdAlreadyUsed`
- Backend should generate: `keccak256(userId + activityId + timestamp)`

### Storage Safety
- EIP-7201 namespaced storage pattern
- `__gap[50]` reserved for future storage slots
- No storage collisions across upgrades

---

## Quick Start

### Prerequisites
- [Foundry](https://book.getfoundry.sh/getting-started/installation)
- Git

### Installation

```bash
git clone https://github.com/ayushns01/act.x-token.git
cd act.x-token
forge install
```

### Build

```bash
forge build
```

### Test

```bash
# Run all tests
forge test -vv

# Run with gas reporting
forge test --gas-report

# Run specific test file
forge test --match-path test/unit/ACTXToken.t.sol -vv
```

### Coverage

```bash
forge coverage --report summary
```

---

## Deployment

### Environment Setup

Create `.env` file:
```env
PRIVATE_KEY=your_deployer_private_key
TREASURY_ADDRESS=0x...  # Must be a multi-sig (e.g., Safe)
RESERVOIR_ADDRESS=0x...
INITIAL_TAX_RATE=200    # 2% in basis points
BASE_RPC_URL=https://mainnet.base.org
BASESCAN_API_KEY=your_api_key
```

### Deploy with Timelock (Recommended)

```bash
source .env
forge script script/DeployWithTimelock.s.sol --rpc-url $BASE_RPC_URL --broadcast --verify
```

This deploys:
1. ACTXToken implementation
2. ERC1967 Proxy
3. TimelockController (48-hour delay)
4. Sets timelock as upgrade controller

### Upgrade Process

```bash
# 1. Schedule upgrade (starts 48-hour countdown)
forge script script/UpgradeACTX.s.sol --rpc-url $BASE_RPC_URL --broadcast

# 2. Wait 48 hours

# 3. Execute upgrade
forge script script/UpgradeACTX.s.sol:ExecuteUpgrade --rpc-url $BASE_RPC_URL --broadcast
```

---

## Project Structure

```
bless-up/
├── src/
│   ├── ACTXToken.sol           # Main upgradeable token
│   ├── Vesting.sol             # 4-year cliff vesting
│   ├── Airdrop.sol             # Merkle + KYC airdrop
│   ├── interfaces/
│   │   ├── IACTXToken.sol
│   │   ├── IAirdrop.sol
│   │   └── IVesting.sol
│   ├── libraries/
│   │   └── Errors.sol          # Custom errors
│   └── storage/
│       └── ACTXStorageV1.sol   # Namespaced storage
├── test/
│   ├── unit/                   # 60 unit tests
│   ├── fuzz/                   # 5 fuzz tests
│   └── invariant/              # 4 invariant tests
├── script/
│   ├── DeployACTX.s.sol        # Basic deployment
│   ├── DeployWithTimelock.s.sol# Production deployment
│   ├── DeployBonus.s.sol       # Vesting + Airdrop
│   └── UpgradeACTX.s.sol       # Upgrade scripts
├── docs/
│   ├── OFFCHAIN_INTEGRATION.md # Backend integration guide
│   └── SECURITY.md             # Security architecture
└── audit/
    └── gas-snapshot.txt        # Gas benchmarks
```

---

## Testing

### Results

```
Ran 69 tests: 69 passed, 0 failed

╭────────────────────────┬────────┬────────┬─────────╮
│ Test Suite             │ Passed │ Failed │ Skipped │
╞════════════════════════╪════════╪════════╪═════════╡
│ ACTXTokenTest          │ 38     │ 0      │ 0       │
│ ACTXTokenFuzzTest      │ 5      │ 0      │ 0       │
│ ACTXTokenInvariantTest │ 4      │ 0      │ 0       │
│ AirdropTest            │ 12     │ 0      │ 0       │
│ VestingTest            │ 10     │ 0      │ 0       │
╰────────────────────────┴────────┴────────┴─────────╯
```

### Coverage

| File | Line | Branch | Function |
|------|------|--------|----------|
| ACTXToken.sol | 100.00% | 98.99% | 100.00% |
| ACTXStorageV1.sol | 100.00% | 100.00% | 100.00% |
| Airdrop.sol | 81.48% | 77.78% | 100.00% |
| Vesting.sol | 86.79% | 84.75% | 80.00% |

### Invariants Enforced

```solidity
invariant_TotalSupplyExactly100M()    // totalSupply() == 100M (never changes)
invariant_RewardPoolNeverNegative()   // rewardPoolBalance >= 0
invariant_TaxRateNeverExceedsMax()    // taxRate <= 1000 (10%)
invariant_ReservoirAddressNeverZero() // reservoir != address(0)
```

### Fuzz Test Configuration

```toml
[profile.default.fuzz]
runs = 1000

[profile.default.invariant]
runs = 256
depth = 15
```

---

## Integration

### Distributing Rewards (Backend)

```javascript
// Generate unique rewardId
const rewardId = ethers.keccak256(
  ethers.solidityPacked(
    ['address', 'string', 'uint256'],
    [userAddress, activityId, Date.now()]
  )
);

// Check if already used (idempotency)
const isUsed = await token.isRewardIdUsed(rewardId);
if (isUsed) {
  console.log('Reward already distributed');
  return;
}

// Distribute reward
const tx = await token.distributeReward(userAddress, amount, rewardId);
await tx.wait();
```

### Event Listeners

```javascript
token.on('RewardDistributed', (recipient, amount, rewardId) => {
  console.log(`Reward ${rewardId}: ${amount} to ${recipient}`);
  markRewardComplete(rewardId);
});

token.on('TaxCollected', (from, to, taxAmount, netAmount) => {
  console.log(`Tax: ${taxAmount} from ${from}`);
});
```

See [OFFCHAIN_INTEGRATION.md](docs/OFFCHAIN_INTEGRATION.md) for complete backend guide.

---

## Gas Costs

| Operation | Gas |
|-----------|-----|
| Transfer (with tax) | ~99,000 |
| Transfer (tax exempt) | ~59,000 |
| Distribute Reward | ~94,000 |
| Fund Reward Pool | ~59,000 |
| Set Tax Rate | ~26,000 |

---

## Contracts

### Core

| Contract | Description |
|----------|-------------|
| `ACTXToken.sol` | Main upgradeable ERC-20 token |
| `ACTXStorageV1.sol` | Namespaced storage (EIP-7201) |

### Bonus (Non-upgradeable)

| Contract | Description |
|----------|-------------|
| `Vesting.sol` | 4-year linear vesting with 1-year cliff |
| `Airdrop.sol` | Merkle tree airdrop with KYC verification |

---

## Security

### Audit Status
- [ ] Internal review complete
- [ ] External audit pending

### Known Considerations
1. **Multi-sig not enforced on-chain** — Treasury address MUST be a Safe multi-sig
2. **Tax can be set to 0%** — Intentional for flexibility
3. **Vesting/Airdrop use Ownable** — Simpler governance for non-upgradeable contracts

See [SECURITY.md](docs/SECURITY.md) for full security architecture.

---

## Dependencies

| Package | Version |
|---------|---------|
| OpenZeppelin Contracts Upgradeable | 5.5.0 |
| Forge Std | Latest |
| Solidity | 0.8.28 |

---

## License

MIT License — see [LICENSE](LICENSE)

---

## Contributing

1. Fork the repository
2. Create feature branch (`git checkout -b feature/amazing-feature`)
3. Run tests (`forge test`)
4. Commit changes (`git commit -m 'Add amazing feature'`)
5. Push to branch (`git push origin feature/amazing-feature`)
6. Open Pull Request

---

## Contact

- **Project:** BlessUP
- **Token:** ACT.X (ACTX)
- **Network:** Base L2
