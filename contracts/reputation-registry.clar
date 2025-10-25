(define-constant role-driver u1)
(define-constant role-rider u2)
(define-constant err-unauthorized u100)
(define-constant err-bad-role u101)
(define-constant err-bad-rating u102)
(define-constant err-duplicate u103)

(define-map issuers {who: principal} {allowed: bool})
(define-map rating-stats {s: principal, role: uint} {count: uint, sum: uint})
(define-map rated-keys {r: uint, s: principal} {flag: bool})

(define-private (is-owner (p principal))
    (is-eq p (contract-owner)))

(define-private (is-issuer (p principal))
    (match (map-get? issuers {who: p})
        i (get allowed i)
        false))

(define-public (set-issuer (who principal) (allowed bool))
    (if (is-owner tx-sender)
        (begin
            (map-set issuers {who: who} {allowed: allowed})
            (ok true))
        (err err-unauthorized)))

(define-public (issue-rating (ride-id uint) (subject principal) (role uint) (rating uint))
    (if (and (not (is-issuer tx-sender)) (not (is-owner tx-sender)))
        (err err-unauthorized)
        (let (
                (dup (map-get? rated-keys {r: ride-id, s: subject}))
                (valid-role (or (is-eq role role-driver) (is-eq role role-rider)))
                (valid-rating (and (>= rating u1) (<= rating u5)))
             )
            (if (not valid-role)
                (err err-bad-role)
                (if (not valid-rating)
                    (err err-bad-rating)
                    (if (is-some dup)
                        (err err-duplicate)
                        (let (
                               (key {s: subject, role: role})
                               (stat (map-get? rating-stats key))
                             )
                            (begin
                                (map-set rated-keys {r: ride-id, s: subject} {flag: true})
                                (match stat
                                    st (map-set rating-stats key {count: (+ (get count st) u1), sum: (+ (get sum st) rating)})
                                    (map-set rating-stats key {count: u1, sum: rating}))
                                (ok true)))))))))

(define-read-only (get-stats (subject principal) (role uint))
    (let ((key {s: subject, role: role}))
        (match (map-get? rating-stats key)
            st {count: (get count st), sum: (get sum st), avg: (if (> (get count st) u0) (/ (get sum st) (get count st)) u0)}
            {count: u0, sum: u0, avg: u0})))

(define-read-only (is-rated (ride-id uint) (subject principal))
    (match (map-get? rated-keys {r: ride-id, s: subject})
        f (get flag f)
        false))

(define-read-only (is-issuer-allowed (who principal))
    (match (map-get? issuers {who: who})
        i (get allowed i)
        false))