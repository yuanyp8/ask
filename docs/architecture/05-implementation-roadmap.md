# Implementation Roadmap

## 1. Initial technology direction

- Backend: Go modular monolith with explicit domain/application/repository boundaries.
- Worker: same Go codebase, separately runnable process for asynchronous jobs.
- Frontend: Next.js / TypeScript workspace for project home, chapter review, outline tree, entity browser, and analysis progress.
- Transactional database: PostgreSQL.
- File/object storage: S3-compatible interface; MinIO is suitable for self-hosted deployment.
- Queue: start with PostgreSQL-backed jobs or an existing reliable queue adapter; avoid adding Redis/MQ solely for architecture aesthetics. Choose based on expected concurrency and deployment constraints.
- Retrieval: keyword search first; add embeddings and reranking behind a retrieval interface once evidence retrieval is evaluated.
- Preprocessing: define a service interface for parsing, normalization, and splitting. It can run as a separate service when independent deployment or language/runtime requirements justify it.

The technology list is a starting decision, not a reason to create a microservice for every domain.

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
    │   ├── modelgateway/
    │   ├── retrieval/
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
- Add config, structured logging, health/readiness, request IDs, and graceful shutdown.
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
