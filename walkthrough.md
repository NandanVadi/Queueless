# QueueLess walkthrough — Milestone 13

## Current architecture

QueueLess remains a layered Flutter application backed by Express, Prisma, and
PostgreSQL:

```text
Flutter screens → repositories → ApiService → Express → services → repositories → Prisma → PostgreSQL
                         ↓
                    SQLite cache
```

PostgreSQL is the source of truth for queue tokens and appointments. SQLite is
strictly a read cache for the last successfully synchronized server state; it
never creates, cancels, or otherwise invents server records while offline.

## Synchronization rules

1. Creates and cancellations are remote-first. The UI receives a successful
   result only after the API acknowledges it. The returned record is then
   cached locally.
2. Reads request the API first. SQLite is used only if that API request fails.
   A cache-write error is not treated as a network failure, so a successful API
   response cannot be replaced silently with stale data.
3. Every returned queue token and appointment is upserted by its server ID.
   Repeated responses therefore update one local row instead of creating
   duplicates.
4. Server responses include their parent service. The cache upserts that
   service in the same SQLite transaction before its queue token or
   appointment. A response without an included service is accepted only when
   its service is already cached; otherwise the cache write fails safely.
5. A successful `GET /queue/active` is an authoritative active snapshot.
   Locally active tokens missing from it are retained for history but marked
   inactive, preventing them from resurfacing in offline active-queue reads.
6. A successful `GET /appointments` is an authoritative complete snapshot.
   Cached appointments absent from it are removed, preventing orphaned stale
   records from being presented as server state.
7. Cancellation keeps history: its server-provided inactive/cancelled state is
   cached by upsert rather than deleting the record.

## Backend consistency contract

The queue create repository now includes the associated `service` in its
response, matching the existing queue read/cancel and appointment responses.
This gives Flutter the parent data needed for a foreign-key-safe cache write.
PostgreSQL continues to restrict service deletion when historical queue tokens
or appointments reference it.

## Verification performed

- Flutter synchronization tests cover authoritative upserts, stale active
  queue invalidation, stale appointment removal, offline cached reads, and
  cancellation acknowledgement.
- Existing Flutter UI, repository, SQLite, QR, and service tests remain green.
- Backend Jest API tests and Prisma schema validation are green.

No authentication, real-time transport, notifications, administration, or UI
feature scope was added in this milestone.

## Backend Test Database Isolation

**Development:**
`queueless`

**Testing:**
`queueless_test`

Backend Jest tests have been explicitly isolated to their own database (`queueless_test`).
Because test suites generally run destructive teardown scripts (`deleteMany()`, etc.) 
between test executions to ensure a clean state, executing them against the primary development
database results in unintentional destruction of application data. By dedicating an isolated 
test database specifically for testing workloads, the `queueless` development database is 
fully protected and safe from data loss.

## Milestone 22: Final Customer UX Polish & Release Readiness

**Status: COMPLETE**

**Goals achieved:**
- **Customer Home Experience**: Integrated a complete activity overview (Active Queue Token and Upcoming Appointment) directly on the HomeScreen so users can see their status immediately. Improved the greeting to be more personal.
- **Queue UX**: Replaced ambiguous "Inactive" labels with explicit "CANCELLED" or "COMPLETED" status on queue tokens. Verified proper UI states for all token lifecycle phases.
- **Appointment UX**: Confirmed graceful handling of duplicate submission prevention, cancellation confirmations, and API error fallback.
- **Profile UX**: Implemented secure Socket.io connection cleanup during logout, resolving potential memory leak and unwanted background polling on logout.
- **Error & Loading States**: Added and verified robust error handling across screens (`_ServiceErrorState`, empty states, pull-to-refresh).
- **Navigation Polish**: Verified Role-Based Access Control logic restricts normal users from accessing Admin/Operator tabs, defaulting unauthenticated users to the Splash/Login flow.
- **QR Features**: Validated MobileScanner's graceful degradation handles initialization errors on unsupported platforms cleanly, and validates QR data against local cache.
- **Testing Integrity**: Updated UI tests to assert against the explicit "CANCELLED" states and ensured complete test passage (104/104 Flutter tests, 68/68 Backend tests). Preserved the backend database isolation architecture using `queueless_test`.
