# Arc USDC Vault

A USDC vault on Arc Testnet. You deposit USDC and receive vault shares at 1:1, then withdraw your USDC at any time, even when deposits are paused. A role-based admin setup (admin, pauser, cap manager) controls pausing and the total deposit cap. The contract is immutable and cannot move USDC that backs user shares.

Built with [Arc Studio](https://studio.arc.io)

## What you can do

- Deposit USDC and see your vault balance and the vault's capacity.
- Withdraw USDC to your own address whenever you like.
- If your wallet holds a role: pause or unpause deposits, or change the deposit cap.

## Deployment (Arc Testnet)

| Item | Value |
| --- | --- |
| Vault contract | `0x17b62bedc6c45d03fb61dfb5dc301f6731bf4b9a` |
| USDC | `0x3600000000000000000000000000000000000000` |
| Admin, pauser, cap manager | `0x8aaa6e659f4727d6da32d6bb424627d9731ce9bb` |
| Admin handover delay | 1 day |
| Initial deposit cap | 10 USDC |

The design, roles, and threat model are in [`contracts/ArcUsdcVault-design.md`](contracts/ArcUsdcVault-design.md).

## Tech stack

- Solidity 0.8.28, Foundry, OpenZeppelin Contracts
- React, TypeScript, Vite, Tailwind CSS
- wagmi, viem, ConnectKit

## Development

Prerequisites: [Bun](https://bun.sh), [Foundry](https://book.getfoundry.sh), and a browser wallet (for example MetaMask) on Arc Testnet with test USDC.

```bash
bun install
bun run dev            # start the app on http://localhost:5173
bun run contracts:build
bun run contracts:test # run the contract tests
bun run check          # lint and typecheck
```

### Environment variables

None.
