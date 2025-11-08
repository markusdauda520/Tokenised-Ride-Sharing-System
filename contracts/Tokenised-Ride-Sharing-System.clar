(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_ALREADY_EXISTS (err u101))
(define-constant ERR_NOT_FOUND (err u102))
(define-constant ERR_INVALID_STATUS (err u103))
(define-constant ERR_INSUFFICIENT_BALANCE (err u104))
(define-constant ERR_INVALID_AMOUNT (err u105))
(define-constant ERR_ALREADY_CANCELLED (err u106))
(define-constant CANCELLATION_PENALTY_PERCENT u20)

(define-fungible-token ride-token)

(define-map drivers
    { driver: principal }
    {
        name: (string-ascii 50),
        vehicle: (string-ascii 100),
        rating: uint,
        total-rides: uint,
        is-active: bool,
        earnings: uint,
    }
)

(define-map riders
    { rider: principal }
    {
        name: (string-ascii 50),
        rating: uint,
        total-rides: uint,
        token-balance: uint,
        cancelled-rides: uint,
    }
)

(define-map rides
    { ride-id: uint }
    {
        rider: principal,
        driver: (optional principal),
        pickup: (string-ascii 100),
        destination: (string-ascii 100),
        fare: uint,
        status: (string-ascii 20),
        created-at: uint,
        completed-at: (optional uint),
        cancelled-at: (optional uint),
        penalty-paid: uint,
    }
)

(define-data-var next-ride-id uint u1)
(define-data-var total-supply uint u1000000)

(define-public (mint-tokens
        (recipient principal)
        (amount uint)
    )
    (begin
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
        (ft-mint? ride-token amount recipient)
    )
)

(define-public (transfer-tokens
        (amount uint)
        (sender principal)
        (recipient principal)
    )
    (begin
        (asserts! (is-eq tx-sender sender) ERR_UNAUTHORIZED)
        (ft-transfer? ride-token amount sender recipient)
    )
)

(define-public (register-driver
        (name (string-ascii 50))
        (vehicle (string-ascii 100))
    )
    (let ((driver-exists (map-get? drivers { driver: tx-sender })))
        (asserts! (is-none driver-exists) ERR_ALREADY_EXISTS)
        (map-set drivers { driver: tx-sender } {
            name: name,
            vehicle: vehicle,
            rating: u5,
            total-rides: u0,
            is-active: true,
            earnings: u0,
        })
        (ok true)
    )
)

(define-public (register-rider (name (string-ascii 50)))
    (let ((rider-exists (map-get? riders { rider: tx-sender })))
        (asserts! (is-none rider-exists) ERR_ALREADY_EXISTS)
        (map-set riders { rider: tx-sender } {
            name: name,
            rating: u5,
            total-rides: u0,
            token-balance: u0,
            cancelled-rides: u0,
        })
        (ok true)
    )
)

(define-public (toggle-driver-status)
    (let ((driver-data (unwrap! (map-get? drivers { driver: tx-sender }) ERR_NOT_FOUND)))
        (map-set drivers { driver: tx-sender }
            (merge driver-data { is-active: (not (get is-active driver-data)) })
        )
        (ok true)
    )
)

(define-public (request-ride
        (pickup (string-ascii 100))
        (destination (string-ascii 100))
        (fare uint)
    )
    (let (
            (ride-id (var-get next-ride-id))
            (rider-data (unwrap! (map-get? riders { rider: tx-sender }) ERR_NOT_FOUND))
            (rider-balance (ft-get-balance ride-token tx-sender))
        )
        (asserts! (>= rider-balance fare) ERR_INSUFFICIENT_BALANCE)
        (asserts! (> fare u0) ERR_INVALID_AMOUNT)
        (map-set rides { ride-id: ride-id } {
            rider: tx-sender,
            driver: none,
            pickup: pickup,
            destination: destination,
            fare: fare,
            status: "requested",
            created-at: stacks-block-height,
            completed-at: none,
            cancelled-at: none,
            penalty-paid: u0,
        })
        (var-set next-ride-id (+ ride-id u1))
        (ok ride-id)
    )
)

(define-public (accept-ride (ride-id uint))
    (let (
            (ride-data (unwrap! (map-get? rides { ride-id: ride-id }) ERR_NOT_FOUND))
            (driver-data (unwrap! (map-get? drivers { driver: tx-sender }) ERR_NOT_FOUND))
        )
        (asserts! (get is-active driver-data) ERR_INVALID_STATUS)
        (asserts! (is-eq (get status ride-data) "requested") ERR_INVALID_STATUS)
        (map-set rides { ride-id: ride-id }
            (merge ride-data {
                driver: (some tx-sender),
                status: "accepted",
            })
        )
        (ok true)
    )
)

(define-public (start-ride (ride-id uint))
    (let ((ride-data (unwrap! (map-get? rides { ride-id: ride-id }) ERR_NOT_FOUND)))
        (asserts! (is-eq (some tx-sender) (get driver ride-data))
            ERR_UNAUTHORIZED
        )
        (asserts! (is-eq (get status ride-data) "accepted") ERR_INVALID_STATUS)
        (map-set rides { ride-id: ride-id }
            (merge ride-data { status: "in-progress" })
        )
        (ok true)
    )
)

(define-public (complete-ride (ride-id uint))
    (let (
            (ride-data (unwrap! (map-get? rides { ride-id: ride-id }) ERR_NOT_FOUND))
            (driver (unwrap! (get driver ride-data) ERR_NOT_FOUND))
            (rider (get rider ride-data))
            (fare (get fare ride-data))
        )
        (asserts! (is-eq tx-sender driver) ERR_UNAUTHORIZED)
        (asserts! (is-eq (get status ride-data) "in-progress") ERR_INVALID_STATUS)
        (try! (ft-transfer? ride-token fare rider driver))
        (map-set rides { ride-id: ride-id }
            (merge ride-data {
                status: "completed",
                completed-at: (some stacks-block-height),
            })
        )
        (update-driver-stats driver fare)
        (update-rider-stats rider)
        (ok true)
    )
)

(define-public (cancel-ride (ride-id uint))
    (let (
            (ride-data (unwrap! (map-get? rides { ride-id: ride-id }) ERR_NOT_FOUND))
            (rider (get rider ride-data))
            (driver-opt (get driver ride-data))
            (fare (get fare ride-data))
            (status (get status ride-data))
            (rider-data (unwrap! (map-get? riders { rider: rider }) ERR_NOT_FOUND))
        )
        (asserts! (is-eq tx-sender rider) ERR_UNAUTHORIZED)
        (asserts! (or (is-eq status "requested") (is-eq status "accepted"))
            ERR_INVALID_STATUS
        )
        (if (is-eq status "accepted")
            (let (
                    (driver (unwrap! driver-opt ERR_NOT_FOUND))
                    (penalty (/ (* fare CANCELLATION_PENALTY_PERCENT) u100))
                    (rider-balance (ft-get-balance ride-token rider))
                )
                (asserts! (>= rider-balance penalty) ERR_INSUFFICIENT_BALANCE)
                (try! (ft-transfer? ride-token penalty rider driver))
                (map-set rides { ride-id: ride-id }
                    (merge ride-data {
                        status: "cancelled",
                        cancelled-at: (some stacks-block-height),
                        penalty-paid: penalty,
                    })
                )
                (map-set riders { rider: rider }
                    (merge rider-data { cancelled-rides: (+ (get cancelled-rides rider-data) u1) })
                )
                (ok penalty)
            )
            (begin
                (map-set rides { ride-id: ride-id }
                    (merge ride-data {
                        status: "cancelled",
                        cancelled-at: (some stacks-block-height),
                        penalty-paid: u0,
                    })
                )
                (map-set riders { rider: rider }
                    (merge rider-data { cancelled-rides: (+ (get cancelled-rides rider-data) u1) })
                )
                (ok u0)
            )
        )
    )
)

(define-private (update-driver-stats
        (driver principal)
        (fare uint)
    )
    (let ((driver-data (unwrap-panic (map-get? drivers { driver: driver }))))
        (map-set drivers { driver: driver }
            (merge driver-data {
                total-rides: (+ (get total-rides driver-data) u1),
                earnings: (+ (get earnings driver-data) fare),
            })
        )
    )
)

(define-private (update-rider-stats (rider principal))
    (let ((rider-data (unwrap-panic (map-get? riders { rider: rider }))))
        (map-set riders { rider: rider }
            (merge rider-data { total-rides: (+ (get total-rides rider-data) u1) })
        )
    )
)

(define-public (rate-driver
        (ride-id uint)
        (rating uint)
    )
    (let (
            (ride-data (unwrap! (map-get? rides { ride-id: ride-id }) ERR_NOT_FOUND))
            (driver (unwrap! (get driver ride-data) ERR_NOT_FOUND))
        )
        (asserts! (is-eq tx-sender (get rider ride-data)) ERR_UNAUTHORIZED)
        (asserts! (is-eq (get status ride-data) "completed") ERR_INVALID_STATUS)
        (asserts! (and (>= rating u1) (<= rating u5)) ERR_INVALID_AMOUNT)
        (update-driver-rating driver rating)
        (ok true)
    )
)

(define-public (rate-rider
        (ride-id uint)
        (rating uint)
    )
    (let (
            (ride-data (unwrap! (map-get? rides { ride-id: ride-id }) ERR_NOT_FOUND))
            (rider (get rider ride-data))
        )
        (asserts! (is-eq (some tx-sender) (get driver ride-data))
            ERR_UNAUTHORIZED
        )
        (asserts! (is-eq (get status ride-data) "completed") ERR_INVALID_STATUS)
        (asserts! (and (>= rating u1) (<= rating u5)) ERR_INVALID_AMOUNT)
        (update-rider-rating rider rating)
        (ok true)
    )
)

(define-private (update-driver-rating
        (driver principal)
        (new-rating uint)
    )
    (let ((driver-data (unwrap-panic (map-get? drivers { driver: driver }))))
        (let (
                (current-rating (get rating driver-data))
                (total-rides (get total-rides driver-data))
                (updated-rating (if (> total-rides u1)
                    (/ (+ (* current-rating (- total-rides u1)) new-rating)
                        total-rides
                    )
                    new-rating
                ))
            )
            (map-set drivers { driver: driver }
                (merge driver-data { rating: updated-rating })
            )
        )
    )
)

(define-private (update-rider-rating
        (rider principal)
        (new-rating uint)
    )
    (let ((rider-data (unwrap-panic (map-get? riders { rider: rider }))))
        (let (
                (current-rating (get rating rider-data))
                (total-rides (get total-rides rider-data))
                (updated-rating (if (> total-rides u1)
                    (/ (+ (* current-rating (- total-rides u1)) new-rating)
                        total-rides
                    )
                    new-rating
                ))
            )
            (map-set riders { rider: rider }
                (merge rider-data { rating: updated-rating })
            )
        )
    )
)

(define-read-only (get-driver (driver principal))
    (map-get? drivers { driver: driver })
)

(define-read-only (get-rider (rider principal))
    (map-get? riders { rider: rider })
)

(define-read-only (get-ride (ride-id uint))
    (map-get? rides { ride-id: ride-id })
)

(define-read-only (get-token-balance (user principal))
    (ft-get-balance ride-token user)
)

(define-read-only (get-next-ride-id)
    (var-get next-ride-id)
)

(define-read-only (get-rider-cancellation-stats (rider principal))
    (let ((rider-data (map-get? riders { rider: rider })))
        (match rider-data
            data (ok {
                total-rides: (get total-rides data),
                cancelled-rides: (get cancelled-rides data),
                cancellation-rate: (if (> (get total-rides data) u0)
                    (/ (* (get cancelled-rides data) u100) (get total-rides data))
                    u0
                ),
            })
            ERR_NOT_FOUND
        )
    )
)
