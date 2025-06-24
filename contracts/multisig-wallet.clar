;; Core Multisig Wallet Implementation

;; Private functions

;; Check if a principal is a valid wallet owner
(define-private (is-owner (user principal))
  (default-to false (get active (map-get? wallet-owners { owner: user })))
)

;; Verify the number of signatures meets the transaction requirement
(define-private (validate-signatures (tx-id uint) (signatures (list 10 principal)))
  (let (
    (transaction (unwrap! (map-get? wallet-transactions { tx-id: tx-id }) ERR-TRANSACTION-NOT-FOUND))
    (required-signatures (get required-signatures transaction))
  )
    (asserts! (>= (len signatures) required-signatures) ERR-INSUFFICIENT-SIGNATURES)
    (ok true)
  )
)

;; Public functions

;; Initialize a new multisig wallet and add initial owners
(define-public (initialize-wallet (initial-owners (list 10 principal)) (required-signatures uint))
  (let (
    (caller tx-sender)
  )
    ;; Validate inputs
    (asserts! (> (len initial-owners) u1) ERR-INVALID-TRANSACTION)
    (asserts! (<= (len initial-owners) MAX-OWNERS) ERR-OWNER-LIMIT-REACHED)
    (asserts! (and (>= required-signatures MIN-SIGNATURES) (<= required-signatures MAX-SIGNATURES)) ERR-INVALID-TRANSACTION)
    
    ;; Add initial owners
    (map add-owner initial-owners)
    
    ;; Set wallet configuration
    (map-set wallet-config 
      { config-key: "required-signatures" } 
      { value: required-signatures }
    )
    
    (ok true)
  )
)

;; Add a new owner to the wallet
(define-public (add-owner (new-owner principal))
  (let (
    (caller tx-sender)
    (current-owners (var-get total-owners))
  )
    ;; Only existing owners can add new owners
    (asserts! (is-owner caller) ERR-UNAUTHORIZED)
    (asserts! (< current-owners MAX-OWNERS) ERR-OWNER-LIMIT-REACHED)
    (asserts! (not (is-owner new-owner)) ERR-OWNER-EXISTS)
    
    ;; Add new owner
    (map-set wallet-owners 
      { owner: new-owner }
      {
        priority: PRIORITY-STANDARD,
        active: true,
        added-at: block-height
      }
    )
    
    (var-set total-owners (+ current-owners u1))
    
    (ok true)
  )
)

;; Propose a new transaction
(define-public (propose-transaction (destination principal) (amount uint) (required-signatures uint))
  (let (
    (caller tx-sender)
    (tx-id (var-get next-transaction-id))
  )
    ;; Only wallet owners can propose transactions
    (asserts! (is-owner caller) ERR-UNAUTHORIZED)
    
    ;; Create transaction
    (map-set wallet-transactions 
      { tx-id: tx-id }
      {
        destination: destination,
        amount: amount,
        signatures: (list),
        executed: false,
        created-at: block-height,
        required-signatures: required-signatures
      }
    )
    
    (var-set next-transaction-id (+ tx-id u1))
    
    (ok tx-id)
  )
)

;; Sign a proposed transaction
(define-public (sign-transaction (tx-id uint))
  (let (
    (caller tx-sender)
    (transaction (unwrap! (map-get? wallet-transactions { tx-id: tx-id }) ERR-TRANSACTION-NOT-FOUND))
  )
    ;; Only wallet owners can sign
    (asserts! (is-owner caller) ERR-UNAUTHORIZED)
    (asserts! (not (get executed transaction)) ERR-TRANSACTION-ALREADY-EXECUTED)
    
    ;; Add signature
    (map-set wallet-transactions 
      { tx-id: tx-id }
      (merge transaction {
        signatures: (unwrap-panic (as-max-len? (append (get signatures transaction) caller) u10))
      })
    )
    
    (ok true)
  )
)

;; Execute a transaction if enough signatures are collected
(define-public (execute-transaction (tx-id uint))
  (let (
    (caller tx-sender)
    (transaction (unwrap! (map-get? wallet-transactions { tx-id: tx-id }) ERR-TRANSACTION-NOT-FOUND))
  )
    ;; Validate signatures and transaction state
    (try! (validate-signatures tx-id (get signatures transaction)))
    (asserts! (not (get executed transaction)) ERR-TRANSACTION-ALREADY-EXECUTED)
    
    ;; Mark transaction as executed and transfer funds
    (map-set wallet-transactions 
      { tx-id: tx-id }
      (merge transaction { executed: true })
    )
    
    (stx-transfer? (get amount transaction) tx-sender (get destination transaction))
  )
)

;; Read-only functions

;; Get transaction details
(define-read-only (get-transaction (tx-id uint))
  (map-get? wallet-transactions { tx-id: tx-id })
)

;; Check if a principal is a wallet owner
(define-read-only (is-wallet-owner (user principal))
  (is-owner user)
)

;; Get total number of wallet owners
(define-read-only (get-total-owners)
  (var-get total-owners)
)