import { useCallback } from 'react'
import { useAccount, useReadContracts } from 'wagmi'
import {
  CAP_MANAGER_ROLE,
  CHAIN_ID,
  DEFAULT_ADMIN_ROLE,
  PAUSER_ROLE,
  USDC_ADDRESS,
  VAULT_ADDRESS,
  usdcAbi,
  vaultAbi,
} from './vault'

const vault = { address: VAULT_ADDRESS, abi: vaultAbi, chainId: CHAIN_ID } as const

/** Live vault, wallet, and role state. Every value comes from a chain read. */
export function useVaultData() {
  const { address } = useAccount()
  const account = address ?? '0x0000000000000000000000000000000000000000'

  const { data, isLoading, refetch } = useReadContracts({
    contracts: [
      { ...vault, functionName: 'totalSupply' },
      { ...vault, functionName: 'depositCap' },
      { ...vault, functionName: 'paused' },
      { ...vault, functionName: 'maxDeposit' },
      { ...vault, functionName: 'balanceOf', args: [account] },
      { address: USDC_ADDRESS, abi: usdcAbi, chainId: CHAIN_ID, functionName: 'balanceOf', args: [account] },
      { address: USDC_ADDRESS, abi: usdcAbi, chainId: CHAIN_ID, functionName: 'allowance', args: [account, VAULT_ADDRESS] },
      { ...vault, functionName: 'hasRole', args: [DEFAULT_ADMIN_ROLE, account] },
      { ...vault, functionName: 'hasRole', args: [PAUSER_ROLE, account] },
      { ...vault, functionName: 'hasRole', args: [CAP_MANAGER_ROLE, account] },
    ],
    query: { refetchInterval: 15_000 },
  })

  const refresh = useCallback(() => {
    void refetch()
  }, [refetch])

  const value = <T,>(index: number): T | undefined => {
    const item = data?.[index]
    return item && item.status === 'success' ? (item.result as T) : undefined
  }

  const connected = Boolean(address)
  return {
    isLoading,
    refresh,
    totalSupply: value<bigint>(0),
    depositCap: value<bigint>(1),
    paused: value<boolean>(2),
    maxDeposit: value<bigint>(3),
    shares: connected ? value<bigint>(4) : undefined,
    usdcBalance: connected ? value<bigint>(5) : undefined,
    allowance: connected ? value<bigint>(6) : undefined,
    isAdmin: connected && value<boolean>(7) === true,
    isPauser: connected && value<boolean>(8) === true,
    isCapManager: connected && value<boolean>(9) === true,
  }
}

export type VaultData = ReturnType<typeof useVaultData>
