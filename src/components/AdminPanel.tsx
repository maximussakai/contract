import { useState } from 'react'
import { useAccount } from 'wagmi'
import { Loader2, ShieldCheck } from 'lucide-react'
import { CHAIN_ID, VAULT_ADDRESS, vaultAbi } from '../lib/vault'
import { formatToken, parseAmountInput } from '../lib/format'
import { useTx } from '../lib/useTx'
import type { VaultData } from '../lib/useVaultData'

/** Shown only to wallets that hold at least one role. Each control needs its own role. */
export function AdminPanel({ data }: { data: VaultData }) {
  const { chainId } = useAccount()
  const [capText, setCapText] = useState('')
  const pauseTx = useTx(data.refresh)
  const capTx = useTx(() => {
    data.refresh()
    setCapText('')
  })

  if (!data.isAdmin && !data.isPauser && !data.isCapManager) return null

  const roles = [data.isAdmin && 'Admin', data.isPauser && 'Pauser', data.isCapManager && 'Cap manager']
    .filter(Boolean)
    .join(', ')
  const newCap = parseAmountInput(capText)
  const onChain = chainId === CHAIN_ID
  const pauseBusy = pauseTx.isPending || pauseTx.isConfirming
  const capBusy = capTx.isPending || capTx.isConfirming

  return (
    <section className="glass-card rounded-3xl p-5">
      <div className="mb-4 flex items-center gap-2">
        <ShieldCheck className="size-4" style={{ color: 'var(--accent-hover)' }} />
        <h2 className="text-sm font-semibold">Operator controls</h2>
      </div>
      <p className="mb-4 text-xs" style={{ color: 'var(--muted)' }}>Your roles: {roles}</p>

      {data.isPauser && (
        <div className="glass-inner mb-3 rounded-2xl p-4">
          <div className="text-xs font-semibold" style={{ color: 'var(--ink-2)' }}>
            Deposits are {data.paused ? 'paused' : 'open'}
          </div>
          <p className="mt-1 text-xs text-pretty" style={{ color: 'var(--muted)' }}>
            Pausing blocks new deposits only. Withdrawals always work.
          </p>
          <button
            disabled={!onChain || pauseBusy || data.paused === undefined}
            onClick={() => {
              pauseTx.reset()
              pauseTx.write({
                address: VAULT_ADDRESS,
                abi: vaultAbi,
                functionName: data.paused ? 'unpause' : 'pause',
                chainId: CHAIN_ID,
              })
            }}
            className="focus-ring mt-3 min-h-11 w-full rounded-xl text-sm font-semibold disabled:opacity-40"
            style={{ background: 'var(--surface-muted)', border: '1px solid var(--border)' }}
          >
            {pauseBusy ? <Loader2 className="mx-auto size-4 animate-spin" /> : data.paused ? 'Unpause deposits' : 'Pause deposits'}
          </button>
          {pauseTx.errorMessage && <p className="mt-2 text-xs" style={{ color: 'var(--danger)' }} role="alert">{pauseTx.errorMessage}</p>}
        </div>
      )}

      {data.isCapManager && (
        <div className="glass-inner rounded-2xl p-4">
          <div className="text-xs font-semibold" style={{ color: 'var(--ink-2)' }}>
            Deposit cap: {formatToken(data.depositCap)} USDC
          </div>
          <input
            inputMode="decimal"
            aria-label="New deposit cap in USDC"
            value={capText}
            onChange={(event) => setCapText(event.target.value.replace(/[^0-9.]/g, ''))}
            placeholder="New cap"
            disabled={capBusy}
            className="focus-ring mt-2 min-h-11 w-full rounded-xl bg-transparent px-3 text-sm tabular-nums outline-none"
            style={{ border: '1px solid var(--border)' }}
          />
          <button
            disabled={!onChain || capBusy || newCap === undefined}
            onClick={() => {
              if (newCap === undefined) return
              capTx.reset()
              capTx.write({
                address: VAULT_ADDRESS,
                abi: vaultAbi,
                functionName: 'setDepositCap',
                args: [newCap],
                chainId: CHAIN_ID,
              })
            }}
            className="focus-ring mt-3 min-h-11 w-full rounded-xl text-sm font-semibold text-white disabled:opacity-40"
            style={{ background: 'var(--accent)' }}
          >
            {capBusy ? <Loader2 className="mx-auto size-4 animate-spin" /> : 'Update cap'}
          </button>
          {capTx.errorMessage && <p className="mt-2 text-xs" style={{ color: 'var(--danger)' }} role="alert">{capTx.errorMessage}</p>}
        </div>
      )}
    </section>
  )
}
