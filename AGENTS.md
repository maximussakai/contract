# [App Name]

> Built with Arc Studio - money-powered apps in minutes

This is the **project memory** - what Arc Studio remembers about building this app. It helps future agents (or humans) understand and extend the project.

---

## What This App Does

[Brief description of what the app does and its primary use case]

## Tech Stack

- Frontend: React 18, Vite, TypeScript, Tailwind CSS
- Web3: wagmi v2, viem v2, ConnectKit
- Contracts: Solidity 0.8.28 + Foundry. Sources in `contracts/`, unit tests in `contracts/test/*.t.sol`. Build with `bun run contracts:build` (`forge build`), test with `bun run contracts:test` (`forge test`).
- Wallet: injected (MetaMask, etc.)
- Chain: Arc Testnet (Chain ID: 5042002, imported from `viem/chains`)
- Token: USDC (6 decimals) (Address: 0x3600000000000000000000000000000000000000, Chain: Arc Testnet)
- Toasts: Sonner

## Key Files

- `src/App.tsx` - Main application logic
- `src/components/` - UI components
- `src/config.ts` - wagmi config (chains, connectors, transports)

## To Run

```bash
bun install
bun run dev
```

## Deployments
- ArcUsdcVault (Arc Testnet, chain 5042002): 0x17b62bedc6c45d03fb61dfb5dc301f6731bf4b9a
  - Underlying USDC: 0x3600000000000000000000000000000000000000
  - Admin / pauser / cap manager: 0x8aaa6e659f4727d6da32d6bb424627d9731ce9bb
  - Admin handover delay: 1 day. Initial deposit cap: 10 USDC (10000000 units).
  - Spec: contracts/ArcUsdcVault-design.md. Tests: contracts/test/ (run `forge test`).
