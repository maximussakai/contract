import { useEffect, useRef } from 'react'
import { useWaitForTransactionReceipt, useWriteContract } from 'wagmi'
import { parseTxError } from './format'

/**
 * Single contract write with honest state: wallet prompt, confirmation, result.
 * Calls onSuccess once per confirmed transaction.
 */
export function useTx(onSuccess?: () => void) {
  const { writeContract, data: hash, isPending, error, reset } = useWriteContract()
  const { isLoading: isConfirming, isSuccess, error: receiptError } = useWaitForTransactionReceipt({ hash })
  const handled = useRef<string | undefined>(undefined)

  useEffect(() => {
    if (isSuccess && hash && handled.current !== hash) {
      handled.current = hash
      onSuccess?.()
    }
  }, [isSuccess, hash, onSuccess])

  const failure = error ?? receiptError
  return {
    write: writeContract,
    hash,
    isPending,
    isConfirming,
    isSuccess,
    errorMessage: failure ? parseTxError(failure) : undefined,
    reset,
  }
}
