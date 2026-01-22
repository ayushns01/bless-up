# Off-Chain Integration Guide

## Overview

The ACT.X token is designed for real-time micro-rewards. This document explains how backend systems should interact with the contract.

## Reward Distribution Flow

```
Backend System                    ACT.X Contract
     │                                  │
     ├── Generate unique rewardId ──────┤
     │   (UUID, activity hash, etc)     │
     │                                  │
     ├── Call distributeReward ─────────┤
     │   (recipient, amount, rewardId)  │
     │                                  │
     ├── Check isRewardIdUsed ──────────┤
     │   (before retrying)              │
     │                                  │
     └── Listen for RewardDistributed ──┘
         event for confirmation
```

## Replay Protection

Each reward distribution requires a unique `rewardId` (bytes32).

**Best Practices:**
- Generate from activity data: `keccak256(userId + activityId + timestamp)`
- Store used IDs in backend database
- Check `isRewardIdUsed(rewardId)` before calling

**If transaction fails:**
1. Check `isRewardIdUsed(rewardId)` — if true, reward was already sent
2. If false, safe to retry with same rewardId
3. Never generate new rewardId for retry — may cause double-reward

## RPC Node Requirements

| Requirement | Value |
|-------------|-------|
| Minimum nodes | 2 (primary + fallback) |
| Block confirmation | Wait 2-3 blocks |
| Request timeout | 10 seconds |
| Retry policy | 3 attempts with backoff |

**High-frequency rewards:**
- Use WebSocket subscriptions for events
- Batch small rewards where possible
- Consider off-peak timing for non-urgent rewards

## Error Handling

| Error | Cause | Action |
|-------|-------|--------|
| `RewardIdAlreadyUsed` | Replay attempt | Check DB, skip |
| `InsufficientRewardPool` | Pool empty | Fund pool, retry |
| `ZeroAddressNotAllowed` | Invalid recipient | Fix input |
| `AccessControl` | Wrong role | Check REWARD_MANAGER |

## Event Listeners

```javascript
// Listen for reward distributions
token.on("RewardDistributed", (recipient, amount, rewardId) => {
  console.log(`Reward ${rewardId} sent: ${amount} to ${recipient}`);
  markRewardComplete(rewardId);
});
```

## Latency Considerations

| Operation | Expected Time |
|-----------|---------------|
| Transaction submit | <1 second |
| Block inclusion | 2-3 seconds (Base L2) |
| Finality | ~12 seconds |

**Do NOT promise instant delivery** — show "pending" status until event confirmed.

## Security

- **Never expose private keys** in backend
- Use separate wallet for REWARD_MANAGER role
- Set transaction gas limits
- Monitor for unusual activity patterns
- Rate limit per-user rewards
