# AgentGate — Proof-of-Agent Badges for Agent ID Holders

**AgentGate** is a live dApp on BNB Chain built around **Agent ID**
(the on-chain identity of Binance Agentic Wallets, `name.ai`).
It issues a **soulbound badge** to Agent ID holders and keeps a simple,
public **reputation score** for each Agent ID, earned by checking in.

- Contract (BNB Chain mainnet): **0x73529eb493b374e201ef81c5a26dd0ade8835138**
- Agent ID contract (SPACE ID): 0x60b9262456de011f7d15a54cdd8c48baaa8b022f
- Token: AgentGate Badge (AGB), ERC-721, non-transferable
- Built for the **Binance Wallet × BNB Chain Agent ID Hackathon** (Nov–Dec 2026)

## How Agent ID is used (core logic)

Agent ID is not decoration here — it is the key the whole product turns on:

1. **Claim** — `claimBadge(agentIdTokenId)` verifies on-chain that
   `ownerOf(agentIdTokenId) == msg.sender` on the official Agent ID
   contract. The badge is bound to that specific Agent ID
   (token id = `uint256(keccak256(label))`, e.g. the hash of `"novia"`
   for `novia.ai`).
2. **One badge per Agent ID, one per wallet.** Agent IDs are
   non-transferable and limited to one per user, so a badge is a
   Sybil-resistant proof that a wallet belongs to a named agent.
3. **Reputation** — badge holders `checkIn()` once per day. Points
   accrue to the badge, i.e. to the Agent ID behind it.
4. **Composable reads** — any other contract can call
   `isVerifiedAgent(address)` and `pointsOfAgent(agentIdTokenId)` to
   gate features or weight rewards by proven agent reputation.

## Safety properties

- **Free forever.** No function accepts payment; there is no mint
  price, no sale, and no promise of returns — only BNB gas for the
  user's own transactions.
- **No owner, no admin.** The contract has no owner and no privileged
  functions at all: nobody can mint, pause, freeze, reassign badges,
  or withdraw anything. The Agent ID contract address is `immutable`.
- **Soulbound.** Every transfer and approval path reverts.
- **No credential collection, no wallet pairing codes, no QR login.**
  The web page uses the visitor's own wallet extension/app directly.
- Source is fully open (MIT) and verification is published on-chain
  explorers (see the contract page).

## Use it

You need a wallet that holds an Agent ID (claim one in the Binance
App: Wallet → Agent ID). Then, on the project web page:

1. Connect your wallet (BNB Chain).
2. Enter your Agent ID name (e.g. `novia` for `novia.ai`).
3. Claim your badge (one transaction, gas only).
4. Come back daily and check in to grow your Agent ID's reputation.

## Repository layout

- `src/AgentGate.sol` — the contract (single file, no dependencies)
- `test/AgentGate.t.sol` — Foundry tests (9/9 passing)
- `docs/index.html` — the claim / check-in web page (GitHub Pages)
- `SUBMISSION.md` — hackathon submission fields

## Build & test

```sh
forge build
forge test
```

Deployment was permissionless via the canonical CREATE2 deployer
(0x4e59b44847b379578588920cA78FbF26c0B4956C), salt
`keccak256("agentgate.novia.ai.v1")`, because the contract has no
owner — the deployer keeps no privileges of any kind.

## License

MIT
