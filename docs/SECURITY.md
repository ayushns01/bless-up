# Security

## Threat Model

### Adversaries
1. **External Attackers** — Attempting to steal tokens or manipulate contract state
2. **Compromised Reward Manager** — Malicious reward distributions
3. **Compromised Tax Admin** — Setting max tax rate, changing reservoir
4. **Compromised Upgrader** — Deploying malicious implementation

### Assets at Risk
- 100M ACTX token supply
- Reward pool balance
- Vesting schedules
- Airdrop allocations

### Attack Vectors Considered

| Vector | Mitigation |
|--------|------------|
| Reentrancy | ReentrancyGuard on Vesting/Airdrop; CEI pattern |
| Replay attacks | `rewardId` tracking in distributeReward() |
| Unauthorized upgrade | Timelock + one-time lock on setTimelockController() |
| Flash loan attacks | Not applicable (no borrowing) |
| Front-running | Tax-based, no sandwich opportunity |
| Storage collision | EIP-7201 namespaced storage |

---

## Trust Assumptions

> [!IMPORTANT]
> The following addresses MUST be multi-sig wallets (e.g., Safe)

| Role | Why Multi-sig Required |
|------|------------------------|
| Treasury (DEFAULT_ADMIN) | Controls role assignment, funds reward pool |
| Timelock Proposer | Can schedule upgrades |
| Timelock Executor | Can execute upgrades after delay |

**On-chain enforcement is NOT present.** Multi-sig requirement is an operational security control.

---

## Upgrade Safety

1. **Pre-timelock Phase:** UPGRADER_ROLE can upgrade directly
2. **Post-timelock Phase:** Only TimelockController can upgrade
3. **48-hour Delay:** All upgrades require waiting period
4. **One-time Lock:** `setTimelockController()` cannot be called twice

### Upgrade Process
```
1. Deploy new implementation
2. TimelockController.schedule() with 48-hour delay
3. Wait 48 hours
4. TimelockController.execute()
```

### Cancellation
If a malicious upgrade is scheduled, call `TimelockController.cancel()` before execution window.

---

## Incident Response

### If Exploit Detected

1. **Immediate:** Call `pause()` via PAUSER_ROLE
2. **Assess:** Determine scope and root cause
3. **Communicate:** Notify community via official channels
4. **Remediate:** 
   - If contract bug: schedule upgrade via timelock
   - If role compromise: revoke roles, rotate keys
5. **Resume:** Call `unpause()` after fix verified

### Emergency Contacts
- Treasury multi-sig signers
- Timelock proposers

---

## Known Limitations

1. **Multi-sig not enforced on-chain** — Treasury could be an EOA
2. **Tax can be set to 0%** — Intentional for flexibility
3. **Vesting/Airdrop not pausable** — Simpler design, relies on token pause
4. **No upgrade delay for initial deployment** — Timelock set post-deployment

---

## Audit Status

- [x] Internal review complete
- [ ] External audit pending
- [ ] Bug bounty program (planned)

---

## Responsible Disclosure

If you discover a vulnerability, please:
1. **Do NOT** create a public issue
2. Contact the team directly via security@example.com
3. Allow 90 days for remediation before disclosure
