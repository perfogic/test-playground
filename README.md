# Cross-Chain Rating (Hyperlane)

Reference implementation that pushes borrower ratings from Ethereum to Arbitrum via Hyperlane. The destination contract exposes a conservative `getBorrowerLTV(address)` view with Aave-style loan-to-value bands.

The code is intentionally stripped down to highlight security-leaning patterns (origin verification, replay protection, and timestamp sanity checks) over production ergonomics.

## Architecture

1. **RatingSender (Ethereum)** receives signed-off borrower scores from an allow-listed rater.
2. Sender ABI-encodes `(borrower, score, timestamp, borrowerNonce)` and calls the Hyperlane `IMailbox` plus `IInterchainGasPaymaster`.
3. **RatingConsumer (Arbitrum)** is wired as a Hyperlane recipient. The mailbox calls `handle(originDomain, originSender, message)` which verifies the origin pair, enforces freshness, and persists the score.
4. Downstream protocols (e.g., Aave) call `getBorrowerLTV(borrower)` to obtain the currently valid LTV bucket, falling back to the safest tier when the rating is missing or stale.

```
Rater → RatingSender (ETH) → Hyperlane Mailbox/IGP → RatingConsumer (ARB) → LTV query
```

### LTV Bands

| Score band | LTV (basis points) |
|------------|-------------------|
| `score >= 80` | `7500` |
| `50 <= score < 80` | `6000` |
| else / missing / stale | `4000` |

## Repository Layout

```
src/
  RatingSender.sol               # Ethereum-side dispatcher
  RatingConsumer.sol             # Arbitrum-side recipient
  interfaces/
    IMailbox.sol
    IMessageRecipient.sol
    IInterchainGasPaymaster.sol

test/
  RatingSender.t.sol             # Sender unit tests with mailbox + IGP mocks
  RatingConsumer.t.sol           # Consumer unit tests
  TestCrosschain.t.sol           # End-to-end flow stitched together with mocks
  mocks/
    MockMailbox.t.sol
    MockIGP.t.sol
    IHyperlaneRecipient.sol
```

## Contracts

### RatingSender (source chain)

- Constructor wires immutable `IMailbox`, `IInterchainGasPaymaster`, and whitelists an initial destination domain.
- Admin (`owner`) can:
  - `setDomain(uint32 domain, bool allowed)` to toggle outbound domains.
  - `setConsumer(uint32 domain, address consumer)` to register the destination RatingConsumer per domain.
  - `setRater(address rater, bool allowed)` to curate the set of off-chain feeders.
- Authorized raters call `dispatchRating(domain, borrower, score, destGasLimit)`:
  - Validates domain, borrower, and score range (0–100).
  - Encodes `(borrower, score, timestamp, borrowerNonce)` and submits it to the mailbox.
  - Forwards the exact `msg.value` to both `dispatch` and `payForGas` (see “Next steps” in PR comments if you want smarter fee splits).
  - Increments `borrowersNonce[borrower]` to catch duplicates at the source.
  - Emits `RatingDispatched`.

### RatingConsumer (destination chain)

- Constructor pins immutable `mailbox`, `originDomain`, `authorizedSender`, and `MAX_AGE` (seconds).
- Storage per borrower: `rating`, `timestamp`, and `nonce`.
- `handle(originDomain, originSender, message)` (callable only by the mailbox):
  - Verifies origin/sender pair.
  - Decodes the message payload and reverts on:
    - Stale timestamps (`block.timestamp > ts + MAX_AGE`).
    - Non-increasing timestamps.
    - Out-of-order nonces (simple replay/rollback protection).
  - Updates the borrower entry and emits `RatingUpdated`.
- `getBorrowerLTV(borrower)` returns the tiered LTV basis points with a safe 40% fallback.
- `getBorrowerRating(borrower)` exposes the raw tuple `(score, nonce, timestamp)`.
- `setOwner(newOwner)` lets the current owner rotate ownership; other admin controls (origin/domain) can be layered on if needed.

## Deployment / Integration Flow

1. **Deploy RatingConsumer (Arbitrum)**
   - Params: destination mailbox address, Ethereum domain ID, placeholder authorized sender, max age.
   - Record the consumer address for later wiring on the source chain.
2. **Deploy RatingSender (Ethereum)**
   - Params: source mailbox, IGP, default destination domain.
   - Register the consumer with `setConsumer(domain, consumerAddr)`.
   - Whitelist raters via `setRater(rater, true)`.
3. **Finalize origin binding**
   - Update the consumer’s `authorizedSender` (constructor argument or via a custom setter if you extend the contract) so it matches the deployed sender.
4. **Operational flow**
   - Rater calls `dispatchRating` with borrower, score, and desired destination gas limit while providing the funds Hyperlane needs.
   - Relayer executes the Hyperlane delivery; the consumer records the score.
   - Lending protocols query `getBorrowerLTV` before extending collateralized credit.

## Security Considerations

- **Source chain**
  - `onlyAuthorizedRater` gating and per-borrower nonces prevent unauthorized dispatches and simple duplicates.
  - Admin actions are limited to the owner; there is no notion of multi-sig here.
- **Destination chain**
  - `onlyMailbox` ensures Hyperlane is the sole caller.
  - `(originDomain, originSender)` checking adds defense-in-depth on top of the ISM guarantees.
  - Timestamp freshness and monotonicity avoid stale/rollback attacks; stale or missing ratings default to the lowest LTV band.
  - Emits `RatingUpdated` for off-chain monitoring.
- **Replay resilience** is split between source (increasing nonce) and destination (timestamp and nonce checks).

## Development

Prerequisites: [Foundry](https://book.getfoundry.sh/).

```bash
forge build          # compile contracts
forge test -vv       # run unit + e2e suites
forge fmt            # format Solidity files
```

All canonical tests live under `test/` and cover:
- Sender happy-path dispatch, parameter validation, and admin gates.
- Consumer handling logic, including origin validation, stale detection, and mailbox-only access.
- Cross-chain wiring through the mocked mailbox + IGP plumbing.

## Notes

- Hyperlane interfaces here are trimmed down for teaching purposes; production deployments should vendor audited interfaces directly from Hyperlane.
- Message fee logic is simplified (the same `msg.value` is sent to both `dispatch` and `payForGas`). Adjust if you need finer control.
- Replace the “Architecture Diagram” placeholder with your actual diagram when documenting integrations.
