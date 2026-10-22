# ASK — AI Novel Research & Writing Platform

面向小说拆解、AI 导读与长篇创作的结构化工作台。

## Product direction

ASK does not treat a novel as a single prompt or a long chat. It turns source text and author-confirmed plans into versioned, queryable story assets:

- Source documents, immutable text versions, chapters and evidence anchors
- Chapter outlines, book/volume outlines and story arcs
- Characters, organizations, places, events and relations
- Main plots, subplots, foreshadowing and timelines
- Reading guides, notes and comprehension exercises
- Original-fiction canon, outlines, manuscript versions and consistency checks

## First vertical slice

`Import → Parse chapters → Analyze chapter beats → Extract entities/events → Build plotlines → Link conclusions to source evidence → Review/edit`

The first release prioritizes the reverse-analysis path. Reading and original-fiction writing will reuse the same source, structure, evidence and task infrastructure.

## Engineering principles

1. Persist AI results as typed, versioned domain data—not chat-only output.
2. Bind every analysis run to an exact source/split version and record model/prompt provenance.
3. Keep source evidence locatable and verifiable; distinguish explicit facts from inference.
4. Use PostgreSQL for transactional data and relationships; use JSONB only for evolving payloads, not as a substitute for core relational structure.
5. Start with a modular Go backend and asynchronous workers; split deployables only when operational needs justify it.
6. Make long-running work resumable, idempotent, observable and incrementally recomputable.
7. Treat reverse-analysis outlines and planned creative outlines as distinct semantic modes.

## Status

The repository starts as a greenfield project. Architecture and data-model decisions are being recorded before application scaffolding.

See [docs/index.md](docs/index.md) for the complete product and technical design set, and `migrations/` for the PostgreSQL schema draft.


## Architecture documents

- [Product scope and MVP](docs/architecture/00-product-scope.md)
- [Core domain model](docs/architecture/01-domain-model.md)
- [PostgreSQL data model](docs/architecture/02-data-model.md)
- [Asynchronous analysis pipeline](docs/architecture/03-analysis-pipeline.md)
- [REST API contract](docs/architecture/04-api-contract.md)
- [Implementation roadmap](docs/architecture/05-implementation-roadmap.md)

## Database migrations

- [Initial schema](migrations/000001_init_core.up.sql)
- [Initial schema rollback](migrations/000001_init_core.down.sql)

The migration is a design baseline and has not yet been validated against a running PostgreSQL instance. Treat it as reviewable implementation input, not a production-ready schema.


## Design phase

The repository is currently in requirements analysis and detailed design. No application scaffolding has started. All design docs and SQL are drafts until reviewed and validated.

Start here:
- [Design document index](docs/index.md)
- [Platform capabilities](docs/requirements/01-platform-capabilities.md)
- [Functional decomposition](docs/requirements/03-functional-decomposition.md)
- [Field review](docs/architecture/07-field-review.md)
- [Data dictionary](docs/architecture/15-data-dictionary.md)
