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

See `docs/architecture/` for the design documents and `migrations/` for the initial PostgreSQL schema.
