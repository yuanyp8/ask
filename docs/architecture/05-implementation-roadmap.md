# Implementation Roadmap

## 1. Initial technology direction

- Backend: Go modular monolith, following the existing aisphere-go/KRATOS conventions for config, logging, metrics, tracing, graceful shutdown and common infrastructure where the dependency is suitable.
- Worker: same Go codebase, separately runnable process for asynchronous jobs.
- Frontend: Next.js / TypeScript.
- Transactional database: PostgreSQL is the source of truth for business records, run/step state and outbox.
- Runtime services: Redis for queue wake-up, locks, cache and resumable streaming state; Redis is not the sole store of durable job history.
- File/object storage: use the existing metastoragex/objectstorex abstraction over MinIO/S3; business packages do not import storage vendor SDKs directly.
- Identity and authorization: Casdoor OIDC + existing Kernel IAM/Authorizer + SpiceDB relationship authorization.
- Audit: auditx is the authoritative audit service; ASK writes transactional outbox events and publishes them reliably.
- Model gateway: new-api OpenAI-compatible API for chat, embedding and reranking; model routes and credentials remain external configuration.
- Retrieval: structured PostgreSQL queries first, then PostgreSQL full-text search and pgvector; add reranking via new-api based on evaluation.
- Preprocessing: service interface for parsing, normalization and splitting, with an independent process where deployment/runtime needs justify it.

These are shared platform integrations, not services to reimplement inside ASK. Module boundaries do not require one deployment per module.

## 2. Suggested repository layout

    .
    ├── apps/
    │   └── web/                  # Next.js UI
    ├── cmd/
    │   ├── api/                  # HTTP API entry point
    │   └── worker/               # async worker entry point
    ├── internal/
    │   ├── project/
    │   ├── work/
    │   ├── source/
    │   ├── analysis/
    │   ├── artifact/
    │   ├── storymodel/
    │   ├── evidence/
    │   ├── outline/
    │   ├── reading/              # later phase
    │   ├── writing/              # later phase
    │   ├── modelgateway/          # new-api adapter
    │   ├── retrieval/             # PostgreSQL FTS/pgvector adapters
    │   ├── outbox/                # durable side-effect delivery
    │   ├── authorization/         # Authorizer contract/adapter
    │   ├── storage/               # metastoragex/objectstorex adapter
    │   └── platform/
    ├── migrations/
    ├── docs/
    │   └── architecture/
    ├── deployments/
    ├── scripts/
    └── testdata/

Keep internal packages organized by business capability. Avoid a global util package that becomes a dependency sink. Domain types should not import HTTP, SQL-driver, or model-provider packages.

## 3. Dependency direction

- HTTP handlers depend on application services.
- Application services depend on domain contracts and repository interfaces.
- Repository implementations depend on PostgreSQL.
- Analysis orchestration depends on modelgateway, source repository, artifact repository, and task execution contracts.
- Modelgateway does not depend on story domain types beyond normalized request/response contracts.
- Worker and API reuse application services but have separate process entry points.
- The web client consumes API DTOs; it should not mirror database tables directly.

## 4. Milestones

### M0 — Architecture and data foundation

- Review product scope and domain model.
- Add PostgreSQL migration and migration test.
- Reuse shared platform config, structured logging, health/readiness, request IDs, authz/audit/storage/model adapters and graceful shutdown; add the transactional outbox publisher.
- Define repository and service interfaces.
- Add CI for formatting, linting, unit tests, migration checks, and frontend type checks.

Exit criteria: service starts reproducibly, migrations run from an empty database, and core tables can be created and rolled back.

### M1 — Import and chapter segmentation

- Project/work CRUD.
- TXT upload/import and checksum detection.
- Parser/normalizer adapter.
- Draft split version, chapter preview, manual boundary/title edits, confirmation.
- Chapter content API and reader UI.

Exit criteria: a novel can be imported, inspected, corrected, and confirmed without AI analysis.

### M2 — Chapter analysis

- Analysis run API, idempotency and worker checkpointing.
- Structured chapter extraction and schema validation.
- Artifact storage and evidence anchor verification.
- Progress UI and failure/retry display.

Exit criteria: selected chapters can be analyzed repeatedly without duplicate records, and source citations open at the correct text.

### M3 — Cross-chapter story model

- Entity and alias extraction.
- Human-assisted entity merge/split.
- Event consolidation and event relations.
- Main/subplot candidates and ordered plotline nodes.
- Hierarchical outline generation.

Exit criteria: a user can navigate from an outline node or plotline to the chapters and evidence that support it.

### M4 — Reading and writing foundations

- Reading position, notes, guided questions, and review exercises.
- Canon and planned outline.
- Manuscript chapter versions and consistency checks.
- Incremental invalidation and regeneration UI.

Exit criteria: reading and writing reuse the story/source infrastructure without confusing planned content with source facts.

## 5. Engineering quality gates

- Unit tests for version validation, offset verification, idempotency, and entity merge logic.
- Integration tests against a real PostgreSQL instance for migrations and foreign-key invariants.
- Golden test corpus with known chapter boundaries and selected evidence spans.
- Contract tests for parser and model gateway adapters.
- Failure-injection tests for worker restart, retry, duplicate delivery, and cancellation.
- Privacy-safe logs; do not log complete manuscript text by default.
- Migration rollback verified before a migration is considered complete.

## 6. Immediate next implementation task

Implement M0 only after reviewing the migration in this repository. The first code PR should include configuration, DB connection, migration runner, health endpoints, CI, and repository interfaces. Do not scaffold all product screens before the import and analysis contracts are proven.
