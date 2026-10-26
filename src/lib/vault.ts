import { keccak256, parseAbi, toBytes } from 'viem'
import { arcTestnet } from 'viem/chains'

/** Deployed ArcUsdcVault on Arc Testnet. */
export const VAULT_ADDRESS = '0x17b62bedc6c45d03fb61dfb5dc301f6731bf4b9a' as const

/** Arc USDC predeploy, ERC-20 view (6 decimals). */
export const USDC_ADDRESS = '0x3600000000000000000000000000000000000000' as const

/** Both the USDC ERC-20 view and the vault share token use 6 decimals. */
export const TOKEN_DECIMALS = 6

export const CHAIN = arcTestnet
export const CHAIN_ID = arcTestnet.id

export const EXPLORER_URL = arcTestnet.blockExplorers.default.url

export const PAUSER_ROLE = keccak256(toBytes('PAUSER_ROLE'))
export const CAP_MANAGER_ROLE = keccak256(toBytes('CAP_MANAGER_ROLE'))
export const DEFAULT_ADMIN_ROLE =
  '0x0000000000000000000000000000000000000000000000000000000000000000' as const

export const vaultAbi = parseAbi([
  'function deposit(uint256 amount, address receiver)',
  'function withdraw(uint256 amount, address receiver)',
  'function setDepositCap(uint256 newCap)',
  'function pause()',
  'function unpause()',
  'function paused() view returns (bool)',
  'function depositCap() view returns (uint256)',
  'function totalSupply() view returns (uint256)',
  'function balanceOf(address account) view returns (uint256)',
  'function maxDeposit() view returns (uint256)',
  'function hasRole(bytes32 role, address account) view returns (bool)',
])

export const usdcAbi = parseAbi([
  'function balanceOf(address account) view returns (uint256)',
  'function allowance(address owner, address spender) view returns (uint256)',
  'function approve(address spender, uint256 amount) returns (bool)',
])

export function txUrl(hash: string) {
  return `${EXPLORER_URL}/tx/${hash}`
}

export function addressUrl(address: string) {
  return `${EXPLORER_URL}/address/${address}`
}
