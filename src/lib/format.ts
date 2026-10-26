import { formatUnits, parseUnits } from 'viem'
import { TOKEN_DECIMALS } from './vault'

/** Format a raw 6-decimal USDC amount for display (2 to 6 fraction digits, trimmed). */
export function formatToken(raw: bigint | undefined): string {
  if (raw === undefined) return '0.00'
  const [whole, fraction = ''] = formatUnits(raw, TOKEN_DECIMALS).split('.')
  const trimmed = fraction.replace(/0+$/, '')
  const digits = trimmed.length < 2 ? trimmed.padEnd(2, '0') : trimmed
  const wholeFormatted = new Intl.NumberFormat('en-US').format(BigInt(whole))
  return `${wholeFormatted}.${digits}`
}

/** Parse user text into a raw amount. Returns undefined when the text is not a valid amount. */
export function parseAmountInput(text: string): bigint | undefined {
  if (!/^\d*\.?\d*$/.test(text) || text === '' || text === '.') return undefined
  const [, fraction = ''] = text.split('.')
  if (fraction.length > TOKEN_DECIMALS) return undefined
  return parseUnits(text, TOKEN_DECIMALS)
}

/** Raw amount to plain input text (no grouping), for Max buttons. */
export function toInputText(raw: bigint): string {
  return formatUnits(raw, TOKEN_DECIMALS)
}

export function shortAddress(address: string): string {
  return `${address.slice(0, 6)}...${address.slice(-4)}`
}

export function parseTxError(error: unknown): string | undefined {
  const message = (error instanceof Error ? error.message : String(error)).toLowerCase()
  if (message.includes('user rejected') || message.includes('user denied')) return undefined
  if (message.includes('insufficient funds')) return 'Not enough USDC for gas. Use Get test USDC in the sidebar.'
  if (message.includes('depositcapexceeded')) return 'This deposit would exceed the vault cap.'
  if (message.includes('enforcedpause')) return 'Deposits are paused.'
  if (message.includes('accesscontrol')) return 'Your wallet does not hold the role for this action.'
  if (message.includes('reverted')) return 'The transaction was rejected by the contract.'
  if (message.includes('network') || message.includes('timeout')) return 'Network issue. Check your connection and retry.'
  return 'Something went wrong. Please try again.'
}
