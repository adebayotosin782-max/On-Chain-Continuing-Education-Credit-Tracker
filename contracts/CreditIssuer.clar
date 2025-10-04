(define-non-fungible-token cec-nft uint)

(define-data-var last-token-id uint u0)
(define-data-var issuance-fee uint u100)
(define-data-var authority-contract (optional principal) none)
(define-data-var max-credits-per-user uint u100)
(define-data-var min-credits uint u1)

(define-constant ERR-NOT-AUTHORIZED u100)
(define-constant ERR-INVALID-COURSE-HASH u101)
(define-constant ERR-INVALID-PROFESSIONAL u102)
(define-constant ERR-INVALID-CREDITS u103)
(define-constant ERR-INVALID-TIMESTAMP u104)
(define-constant ERR-USER-NOT-REGISTERED u105)
(define-constant ERR-COURSE-NOT-APPROVED u106)
(define-constant ERR-ISSUER-NOT-VERIFIED u107)
(define-constant ERR-INVALID-DESCRIPTION u108)
(define-constant ERR-INVALID-CATEGORY u109)
(define-constant ERR-INVALID-EXPIRATION u110)
(define-constant ERR-TOKEN-ALREADY-EXISTS u111)
(define-constant ERR-MAX-CREDITS-EXCEEDED u112)
(define-constant ERR-INVALID-FEE u113)
(define-constant ERR-AUTHORITY-NOT-SET u114)
(define-constant ERR-INVALID-UPDATE u115)
(define-constant ERR-INVALID-STATUS u116)
(define-constant ERR-INVALID-LOCATION u117)
(define-constant ERR-INVALID-PROVIDER u118)
(define-constant ERR-INVALID-VERIFIER u119)
(define-constant ERR-INVALID-SIGNATURE u120)

(define-map CreditDetails
  { token-id: uint }
  { 
    professional: principal, 
    course-hash: (buff 32), 
    credits: uint, 
    timestamp: uint,
    description: (string-utf8 256),
    category: (string-utf8 50),
    expiration: uint,
    status: bool,
    location: (string-utf8 100),
    provider: principal
  }
)

(define-map CreditsByProfessional
  { professional: principal }
  { total-credits: uint, token-ids: (list 100 uint) }
)

(define-map ApprovedIssuers principal bool)
(define-map Signatures { token-id: uint } (buff 65))

(define-read-only (get-credit-details (token-id uint))
  (map-get? CreditDetails { token-id: token-id })
)

(define-read-only (get-credits-by-professional (professional principal))
  (map-get? CreditsByProfessional { professional: professional })
)

(define-read-only (is-issuer-approved (issuer principal))
  (default-to false (map-get? ApprovedIssuers issuer))
)

(define-read-only (get-last-token-id)
  (ok (var-get last-token-id))
)

(define-private (validate-course-hash (hash (buff 32)))
  (if (is-eq (len hash) u32)
      (ok true)
      (err ERR-INVALID-COURSE-HASH))
)

(define-private (validate-professional (prof principal))
  (if (not (is-eq prof tx-sender))
      (ok true)
      (err ERR-INVALID-PROFESSIONAL))
)

(define-private (validate-credits (credits uint))
  (if (and (>= credits (var-get min-credits)) (<= credits u1000))
      (ok true)
      (err ERR-INVALID-CREDITS))
)

(define-private (validate-timestamp (ts uint))
  (if (>= ts block-height)
      (ok true)
      (err ERR-INVALID-TIMESTAMP))
)

(define-private (validate-description (desc (string-utf8 256)))
  (if (and (> (len desc) u0) (<= (len desc) u256))
      (ok true)
      (err ERR-INVALID-DESCRIPTION))
)

(define-private (validate-category (cat (string-utf8 50)))
  (if (or (is-eq cat "ethics") (is-eq cat "technical") (is-eq cat "management"))
      (ok true)
      (err ERR-INVALID-CATEGORY))
)

(define-private (validate-expiration (exp uint))
  (if (> exp block-height)
      (ok true)
      (err ERR-INVALID-EXPIRATION))
)

(define-private (validate-location (loc (string-utf8 100)))
  (if (<= (len loc) u100)
      (ok true)
      (err ERR-INVALID-LOCATION))
)

(define-private (validate-provider (prov principal))
  (if (is-issuer-approved prov)
      (ok true)
      (err ERR-INVALID-PROVIDER))
)

(define-private (validate-signature (sig (buff 65)))
  (if (is-eq (len sig) u65)
      (ok true)
      (err ERR-INVALID-SIGNATURE))
)

(define-public (set-authority-contract (contract-principal principal))
  (begin
    (asserts! (is-none (var-get authority-contract)) (err ERR-AUTHORITY-NOT-SET))
    (var-set authority-contract (some contract-principal))
    (ok true)
  )
)

(define-public (set-issuance-fee (new-fee uint))
  (begin
    (asserts! (is-some (var-get authority-contract)) (err ERR-AUTHORITY-NOT-SET))
    (asserts! (>= new-fee u0) (err ERR-INVALID-FEE))
    (var-set issuance-fee new-fee)
    (ok true)
  )
)

(define-public (set-max-credits-per-user (new-max uint))
  (begin
    (asserts! (is-some (var-get authority-contract)) (err ERR-AUTHORITY-NOT-SET))
    (asserts! (> new-max u0) (err ERR-INVALID-UPDATE))
    (var-set max-credits-per-user new-max)
    (ok true)
  )
)

(define-public (approve-issuer (issuer principal))
  (begin
    (asserts! (is-eq tx-sender (unwrap! (var-get authority-contract) (err ERR-AUTHORITY-NOT-SET))) (err ERR-NOT-AUTHORIZED))
    (map-set ApprovedIssuers issuer true)
    (ok true)
  )
)

(define-public (revoke-issuer (issuer principal))
  (begin
    (asserts! (is-eq tx-sender (unwrap! (var-get authority-contract) (err ERR-AUTHORITY-NOT-SET))) (err ERR-NOT-AUTHORIZED))
    (map-delete ApprovedIssuers issuer)
    (ok true)
  )
)

(define-public (issue-credit 
  (professional principal)
  (course-hash (buff 32))
  (credits uint)
  (description (string-utf8 256))
  (category (string-utf8 50))
  (expiration uint)
  (location (string-utf8 100))
  (signature (buff 65))
)
  (let (
    (token-id (+ (var-get last-token-id) u1))
    (authority (var-get authority-contract))
    (user-credits (default-to { total-credits: u0, token-ids: (list) } (map-get? CreditsByProfessional { professional: professional })))
  )
    (asserts! (is-issuer-approved tx-sender) (err ERR-ISSUER-NOT-VERIFIED))
    (try! (validate-professional professional))
    (try! (validate-course-hash course-hash))
    (try! (validate-credits credits))
    (try! (validate-description description))
    (try! (validate-category category))
    (try! (validate-expiration expiration))
    (try! (validate-location location))
    (try! (validate-signature signature))
    (asserts! (<= (+ (get total-credits user-credits) credits) (var-get max-credits-per-user)) (err ERR-MAX-CREDITS-EXCEEDED))
    (asserts! (is-some authority) (err ERR-AUTHORITY-NOT-SET))
    (try! (stx-transfer? (var-get issuance-fee) tx-sender (unwrap! authority (err ERR-AUTHORITY-NOT-SET))))
    (try! (nft-mint? cec-nft token-id professional))
    (map-set CreditDetails { token-id: token-id }
      { 
        professional: professional, 
        course-hash: course-hash, 
        credits: credits, 
        timestamp: block-height,
        description: description,
        category: category,
        expiration: expiration,
        status: true,
        location: location,
        provider: tx-sender
      }
    )
    (map-set Signatures { token-id: token-id } signature)
    (map-set CreditsByProfessional { professional: professional }
      { total-credits: (+ (get total-credits user-credits) credits),
        token-ids: (append (get token-ids user-credits) token-id) }
    )
    (var-set last-token-id token-id)
    (print { event: "credit-issued", token-id: token-id, professional: professional })
    (ok token-id)
  )
)

(define-public (update-credit-status (token-id uint) (new-status bool))
  (let ((details (map-get? CreditDetails { token-id: token-id })))
    (match details
      d
        (begin
          (asserts! (is-eq (get provider d) tx-sender) (err ERR-NOT-AUTHORIZED))
          (asserts! (not (is-eq (get status d) new-status)) (err ERR-INVALID-STATUS))
          (map-set CreditDetails { token-id: token-id }
            (merge d { status: new-status })
          )
          (print { event: "credit-status-updated", token-id: token-id, new-status: new-status })
          (ok true)
        )
      (err ERR-TOKEN-ALREADY-EXISTS)
    )
  )
)

(define-public (burn-credit (token-id uint))
  (let ((details (map-get? CreditDetails { token-id: token-id })))
    (match details
      d
        (begin
          (asserts! (is-eq (get professional d) tx-sender) (err ERR-NOT-AUTHORIZED))
          (try! (nft-burn? cec-nft token-id tx-sender))
          (map-delete CreditDetails { token-id: token-id })
          (map-delete Signatures { token-id: token-id })
          (let ((user-credits (unwrap! (map-get? CreditsByProfessional { professional: tx-sender }) (err ERR-USER-NOT-REGISTERED))))
            (map-set CreditsByProfessional { professional: tx-sender }
              { total-credits: (- (get total-credits user-credits) (get credits d)),
                token-ids: (filter (lambda (id) (not (is-eq id token-id))) (get token-ids user-credits)) }
            )
          )
          (print { event: "credit-burned", token-id: token-id })
          (ok true)
        )
      (err ERR-TOKEN-ALREADY-EXISTS)
    )
  )
)

(define-public (transfer-credit (token-id uint) (recipient principal))
  (let ((details (map-get? CreditDetails { token-id: token-id })))
    (match details
      d
        (begin
          (asserts! (is-eq (get professional d) tx-sender) (err ERR-NOT-AUTHORIZED))
          (try! (nft-transfer? cec-nft token-id tx-sender recipient))
          (map-set CreditDetails { token-id: token-id }
            (merge d { professional: recipient })
          )
          (let (
            (sender-credits (unwrap! (map-get? CreditsByProfessional { professional: tx-sender }) (err ERR-USER-NOT-REGISTERED)))
            (recip-credits (default-to { total-credits: u0, token-ids: (list) } (map-get? CreditsByProfessional { professional: recipient })))
          )
            (map-set CreditsByProfessional { professional: tx-sender }
              { total-credits: (- (get total-credits sender-credits) (get credits d)),
                token-ids: (filter (lambda (id) (not (is-eq id token-id))) (get token-ids sender-credits)) }
            )
            (map-set CreditsByProfessional { professional: recipient }
              { total-credits: (+ (get total-credits recip-credits) (get credits d)),
                token-ids: (append (get token-ids recip-credits) token-id) }
            )
          )
          (print { event: "credit-transferred", token-id: token-id, recipient: recipient })
          (ok true)
        )
      (err ERR-TOKEN-ALREADY-EXISTS)
    )
  )
)

(define-read-only (verify-signature (token-id uint) (sig (buff 65)))
  (is-eq (map-get? Signatures { token-id: token-id }) (some sig))
)

(define-read-only (get-total-credits (professional principal))
  (ok (get total-credits (default-to { total-credits: u0, token-ids: (list) } (map-get? CreditsByProfessional { professional: professional }))))
)