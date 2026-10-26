import { useRef, useState } from 'react'
import { useAccount, useSwitchChain } from 'wagmi'
import { ConnectKitButton } from 'connectkit'
import { CheckCircle2, ExternalLink, Loader2 } from 'lucide-react'
import { CHAIN, CHAIN_ID, USDC_ADDRESS, VAULT_ADDRESS, txUrl, usdcAbi, vaultAbi } from '../lib/vault'
import { formatToken, parseAmountInput, toInputText } from '../lib/format'
import { useTx } from '../lib/useTx'
import type { VaultData } from '../lib/useVaultData'

type Mode = 'deposit' | 'withdraw'

export function ActionCard({ data }: { data: VaultData }) {
  const { address, chainId, isConnected } = useAccount()
  const { switchChain, isPending: isSwitching } = useSwitchChain()
  const [mode, setMode] = useState<Mode>('deposit')
  const [text, setText] = useState('')

  const amount = parseAmountInput(text)
  const approving = useRef(false)
  const tx = useTx(() => {
    data.refresh()
    // Keep the typed amount after an approval so the next click can deposit it.
    if (approving.current) approving.current = false
    else setText('')
  })
  const busy = tx.isPending || tx.isConfirming

  const wrongChain = isConnected && chainId !== CHAIN_ID
  const balance = mode === 'deposit' ? data.usdcBalance : data.shares
  const needsApproval =
    mode === 'deposit' && amount !== undefined && (data.allowance ?? 0n) < amount

  let problem: string | undefined
  if (amount !== undefined) {
    if (amount === 0n) problem = 'Enter an amount above zero.'
    else if (balance !== undefined && amount > balance) {
      problem = mode === 'deposit' ? 'Not enough USDC in your wallet.' : 'More than your vault balance.'
    } else if (mode === 'deposit' && data.paused) problem = 'Deposits are paused. You can still withdraw.'
    else if (mode === 'deposit' && data.maxDeposit !== undefined && amount > data.maxDeposit) {
      problem = `Only ${formatToken(data.maxDeposit)} USDC of room left in the vault.`
    }
  } else if (text !== '') problem = 'Use a number with up to 6 decimals.'

  const ready = amount !== undefined && !problem && !busy

  const onSubmit = () => {
    if (!address || amount === undefined) return
    tx.reset()
    approving.current = mode === 'deposit' && needsApproval
    if (approving.current) {
      tx.write({ address: USDC_ADDRESS, abi: usdcAbi, functionName: 'approve', args: [VAULT_ADDRESS, amount], chainId: CHAIN_ID })
      return
    }
    tx.write({
      address: VAULT_ADDRESS,
      abi: vaultAbi,
      functionName: mode,
      args: [amount, address],
      chainId: CHAIN_ID,
    })
  }

  const label = mode === 'deposit' ? (needsApproval ? 'Approve USDC' : 'Deposit') : 'Withdraw'

  return (
    <section className="glass-card rounded-3xl p-5">
      <div className="mb-4 grid grid-cols-2 gap-1 rounded-2xl p-1" style={{ background: 'var(--surface-muted)' }} role="tablist">
        {(['deposit', 'withdraw'] as const).map((m) => (
          <button
            key={m}
            role="tab"
            aria-selected={mode === m}
            onClick={() => {
              setMode(m)
              setText('')
              tx.reset()
            }}
            className="focus-ring min-h-11 rounded-xl text-sm font-semibold capitalize transition-colors"
            style={{
              background: mode === m ? 'var(--surface-strong)' : 'transparent',
              color: mode === m ? 'var(--ink)' : 'var(--muted)',
              boxShadow: mode === m ? '0 1px 4px rgba(18,45,69,0.1)' : 'none',
            }}
          >
            {m}
          </button>
        ))}
      </div>

      <div className="glass-inner rounded-2xl p-4">
        <input
          inputMode="decimal"
          aria-label={`${mode} amount in USDC`}
          value={text}
          onChange={(event) => setText(event.target.value.replace(/[^0-9.]/g, ''))}
          placeholder="0.00"
          disabled={busy}
          className="display w-full bg-transparent text-4xl font-bold tabular-nums outline-none placeholder:text-slate-300"
          style={{ color: 'var(--ink)' }}
        />
        <div className="mt-2 flex items-center justify-between">
          <span className="text-xs" style={{ color: 'var(--subtle)' }}>USDC</span>
          <button
            disabled={balance === undefined || balance === 0n}
            onClick={() => balance !== undefined && setText(toInputText(balance))}
            className="focus-ring min-h-8 text-xs font-semibold disabled:opacity-40"
            style={{ color: 'var(--accent-hover)' }}
          >
            {balance !== undefined ? `Balance: ${formatToken(balance)} · Max` : 'Balance unavailable'}
          </button>
        </div>
      </div>

      {problem && <p className="mt-3 text-xs" style={{ color: 'var(--danger)' }} role="alert">{problem}</p>}

      <div className="mt-4">
        {!isConnected ? (
          <ConnectKitButton.Custom>
            {({ show }) => (
              <button
                onClick={show}
                className="focus-ring min-h-12 w-full rounded-2xl text-sm font-semibold text-white"
                style={{ background: 'var(--accent)' }}
              >
                Connect Wallet
              </button>
            )}
          </ConnectKitButton.Custom>
        ) : wrongChain ? (
          <button
            onClick={() => switchChain({ chainId: CHAIN_ID })}
            disabled={isSwitching}
            className="focus-ring min-h-12 w-full rounded-2xl text-sm font-semibold text-white disabled:opacity-40"
            style={{ background: 'var(--accent)' }}
          >
            Switch to {CHAIN.name}
          </button>
        ) : (
          <button
            disabled={!ready}
            onClick={onSubmit}
            className="focus-ring min-h-12 w-full rounded-2xl text-sm font-semibold text-white transition-all active:scale-[0.99] disabled:cursor-not-allowed disabled:opacity-40"
            style={{ background: 'var(--accent)' }}
          >
            {tx.isPending ? (
              <span className="flex items-center justify-center gap-2"><Loader2 className="size-4 animate-spin" /> Confirm in wallet...</span>
            ) : tx.isConfirming ? (
              <span className="flex items-center justify-center gap-2"><Loader2 className="size-4 animate-spin" /> Confirming...</span>
            ) : (
              label
            )}
          </button>
        )}
      </div>

      {needsApproval && isConnected && !wrongChain && (
        <p className="mt-3 text-xs text-pretty" style={{ color: 'var(--muted)' }}>
          Step 1 of 2: approve exactly this amount of USDC. Then deposit.
        </p>
      )}

      {tx.errorMessage && <p className="mt-3 text-xs" style={{ color: 'var(--danger)' }} role="alert">{tx.errorMessage}</p>}

      {tx.isSuccess && tx.hash && (
        <div className="glass-inner mt-4 rounded-2xl p-4">
          <div className="flex items-center gap-1.5 text-sm font-semibold" style={{ color: 'var(--success)' }}>
            <CheckCircle2 className="size-4" /> Confirmed
          </div>
          <a
            href={txUrl(tx.hash)}
            target="_blank"
            rel="noreferrer"
            className="focus-ring mt-2 inline-flex items-center gap-1 text-xs"
            style={{ color: 'var(--accent-hover)' }}
          >
            View on explorer <ExternalLink className="size-3" />
          </a>
        </div>
      )}
    </section>
  )
}
