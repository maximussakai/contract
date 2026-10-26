import { ConnectKitButton } from 'connectkit'
import { ExternalLink, Lock } from 'lucide-react'
import { TokenUSDC } from '@web3icons/react'
import { ActionCard } from './components/ActionCard'
import { AdminPanel } from './components/AdminPanel'
import { useVaultData } from './lib/useVaultData'
import { addressUrl, VAULT_ADDRESS } from './lib/vault'
import { formatToken, shortAddress } from './lib/format'

export default function App() {
  const data = useVaultData()
  const { totalSupply, depositCap, shares, paused, isLoading } = data

  const fill =
    totalSupply !== undefined && depositCap !== undefined && depositCap > 0n
      ? Math.min(100, Number((totalSupply * 10_000n) / depositCap) / 100)
      : 0

  return (
    <div className="min-h-dvh px-4 pb-24 pt-6">
      <div className="mx-auto flex max-w-md flex-col gap-4">
        <header className="flex items-center justify-between">
          <div className="flex items-center gap-2">
            <TokenUSDC variant="branded" size={28} />
            <span className="display text-lg font-bold">Arc USDC Vault</span>
          </div>
          <ConnectKitButton />
        </header>

        <section className="glass-card rounded-3xl p-5">
          <div className="mb-3 flex items-center justify-between">
            <span className="text-xs font-semibold" style={{ color: 'var(--muted)' }}>Your vault balance</span>
            {paused && (
              <span
                className="flex items-center gap-1 rounded-full px-2 py-1 text-xs font-semibold"
                style={{ background: 'rgba(186,43,76,0.1)', color: 'var(--danger)' }}
              >
                <Lock className="size-3" /> Deposits paused
              </span>
            )}
          </div>
          <div className="flex items-baseline gap-1">
            <span className="display text-4xl font-bold tabular-nums">
              {data.shares === undefined ? (isLoading ? '...' : '0.00') : formatToken(shares)}
            </span>
            <span className="text-lg font-medium" style={{ color: 'var(--subtle)' }}>USDC</span>
          </div>
          <p className="mt-1.5 text-xs text-pretty" style={{ color: 'var(--muted)' }}>
            {data.shares === undefined ? 'Connect a wallet to see your balance.' : 'Redeemable 1:1 for USDC at any time.'}
          </p>

          <div className="mt-5">
            <div className="mb-1.5 flex items-center justify-between text-xs" style={{ color: 'var(--muted)' }}>
              <span>Vault total</span>
              <span className="tabular-nums">
                {formatToken(totalSupply)} / {formatToken(depositCap)} USDC
              </span>
            </div>
            <div
              className="h-2 overflow-hidden rounded-full"
              style={{ background: 'var(--surface-muted)' }}
              role="progressbar"
              aria-valuemin={0}
              aria-valuemax={100}
              aria-valuenow={Math.round(fill)}
              aria-label="Vault capacity used"
            >
              <div className="h-full rounded-full" style={{ width: `${fill}%`, background: 'var(--accent)' }} />
            </div>
          </div>
        </section>

        <ActionCard data={data} />
        <AdminPanel data={data} />

        <footer className="flex flex-col items-center gap-1 text-xs" style={{ color: 'var(--subtle)' }}>
          <a
            href={addressUrl(VAULT_ADDRESS)}
            target="_blank"
            rel="noreferrer"
            className="focus-ring mono inline-flex items-center gap-1"
          >
            Vault {shortAddress(VAULT_ADDRESS)} <ExternalLink className="size-3" />
          </a>
          <span className="text-pretty text-center">
            Arc Testnet. Need test USDC? Use Get test USDC in the sidebar.
          </span>
        </footer>
      </div>
    </div>
  )
}
