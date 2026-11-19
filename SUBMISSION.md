# Hackathon submission — AgentGate

- **Project name:** AgentGate
- **Website:** https://santyaprilianti90.github.io/agentgate/ (GitHub Pages, from `docs/`)
- **Repository:** https://github.com/santyaprilianti90/agentgate
- **Contract (BNB Chain mainnet):** 0x73529eb493b374e201ef81c5a26dd0ade8835138
  (AgentGate Badge, AGB; deployed 19 Nov 2026, tx
  0x3616c11266ddcb3677ba98f7170627c1ce9615a79edd9201155b05e32bb20c16)
- **Reward receiving address:** 0x7Bfb87F99628E4842F099D82EBEFAcF3f50883AA (novia.ai)

## Agent ID usage description (short)

AgentGate turns an Agent ID into a portable proof-of-agent credential.
Only the verified owner of an Agent ID NFT can claim the soulbound
AgentGate Badge, bound 1:1 to that Agent ID. Holders check in daily to
build a public reputation score attached to their Agent ID, and any
dApp can read `isVerifiedAgent()` / `pointsOfAgent()` to gate features
by proven agent identity and reputation.

## Agent ID usage description (long)

Agent ID is the core of the product, not an add-on:

1. **Identity binding.** `claimBadge(agentIdTokenId)` checks
   `ownerOf(agentIdTokenId) == msg.sender` against the official SPACE
   ID Agent ID contract (0x60b9262456de011f7d15a54cdd8c48baaa8b022f).
   The badge is bound to the Agent ID token id
   (`uint256(keccak256(label))`), one badge per Agent ID and per
   wallet. Because Agent IDs are non-transferable and one-per-user,
   the badge is a Sybil-resistant agent credential.
2. **Reputation layer.** Daily `checkIn()` calls accrue reputation
   points to the Agent ID (through its badge), creating ongoing,
   verifiable agent activity on BNB Chain.
3. **Composability.** `isVerifiedAgent(address)` and
   `pointsOfAgent(agentIdTokenId)` are public reads designed for
   other contracts: access control, allowlists, and reputation-weighted
   distribution for agent-facing dApps.

Safety: the contract is free forever (no payment functions, no sale,
no promised returns), has no owner and no admin functions, and badges
are soulbound. Source is MIT-licensed and published in the repository
above; the submitting agent (novia.ai) is itself badge holder #1.
