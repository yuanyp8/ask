# Asynchronous Analysis Pipeline

## 1. Execution model

Book analysis is a durable workflow, not a long HTTP request. The API creates an analysis run and returns immediately. A worker claims the run, executes idempotent steps, persists checkpoints, and publishes progress. The UI polls initially; Server-Sent Events can be added later without changing task semantics.

Recommended run statuses:
- queued
- running
- completed_with_warnings
- succeeded
- failed
- cancelled

Recommended step statuses:
- pending
- running
- succeeded
- retryable_failed
- terminal_failed
- skipped

Terminal run states are succeeded, completed_with_warnings, failed, and cancelled.

## 2. Pipeline stages

### Stage 0 — Validate inputs

Validate that the work belongs to the project, the source version belongs to the selected document, and the split version belongs to that source version. Capture an immutable input manifest. Reject stale or mismatched identifiers before consuming model tokens.

### Stage 1 — Chapter-level extraction

For each chapter, extract a schema-validated record containing:
- concise chapter summary;
- ordered event candidates;
- character/entity mentions and aliases;
- goals, actions, conflicts, and turning points;
- information revealed or withheld;
- foreshadowing candidates;
- chapter function and ending hook;
- claims and evidence spans.

Every extracted span must be mapped back to canonical chapter text. If the model returns an invalid quote or invalid offsets, the validator should attempt a bounded repair or mark the claim as lacking verified evidence.

### Stage 2 — Entity resolution

Normalize names, compare aliases and nearby context, and match mentions to existing work-scoped entities. Ambiguous matches remain candidates for review. Do not automatically merge solely because two names are similar.

### Stage 3 — Event consolidation

Deduplicate overlapping event candidates across retries and aggregation. Use stable extraction keys derived from run scope, chapter, and local event identity. Keep narrative order separate from in-world time labels.

### Stage 4 — Cross-chapter synthesis

Using chapter artifacts and selected evidence, infer:
- character arcs and relationships;
- main and secondary plotlines;
- book/volume/story-arc outline;
- foreshadowing and payoff candidates;
- timeline inconsistencies and unresolved threads;
- themes and narrative techniques.

Book-level synthesis must not be performed by blindly concatenating every chapter into one prompt. It should use hierarchical summaries and targeted retrieval, while retaining links to chapter-level artifacts.

### Stage 5 — Validation

Run deterministic checks:
- all referenced chapter/entity/event IDs exist;
- all evidence anchors target the selected split version;
- offsets are in range and quote hashes match;
- artifact payload matches its registered schema version;
- plotline and outline nodes have valid ordering;
- entity/relation references are within the same work;
- no duplicate records are created by retry.

Run model-assisted checks separately and label them as probabilistic, not deterministic.

### Stage 6 — Persist and review

Persist artifacts, claims, evidence, entities, events, relations, and plotlines in transactions sized to a chapter or bounded batch. Expose a review queue for uncertain entity merges, unsupported claims, and conflicting interpretations.

## 3. Idempotency and recovery

- Every API-created run accepts an idempotency key.
- A unique constraint prevents duplicate run creation for the same project/key.
- Every worker step has a stable step key and checkpoint.
- Use upserts with deterministic external keys for extraction results where possible.
- A retry must not duplicate chapters, entities, events, claims, or artifacts.
- Retries should be bounded and use exponential backoff for transient model/network errors.
- Validation errors and malformed model output should be surfaced as structured errors; do not retry indefinitely.
- Cancellation is cooperative: stop before the next expensive step, mark the run cancelled, and preserve completed checkpoints.
- A worker lease or heartbeat is needed so abandoned running steps can be reclaimed after a process crash.

## 4. Incremental recomputation

A changed chapter should invalidate only:
1. its chapter-level extraction artifact;
2. entity/event resolution dependent on the changed chapter;
3. summaries and plotline/outline nodes whose dependency sets include changed facts;
4. book-level synthesis artifacts that depend on those changed nodes.

Prior artifacts remain immutable history and are marked stale for the new input version. Initial implementation may conservatively rerun a whole synthesis stage while retaining chapter-level checkpoints; dependency-aware partial synthesis can be improved after correctness is established.

## 5. Model gateway contract

The analysis domain calls a provider-neutral interface. It should support:
- structured JSON output with schema validation;
- timeout and cancellation;
- retry classification;
- token and latency accounting;
- model ID and prompt/template version capture;
- configurable concurrency and rate limits;
- redacted logs that do not leak full manuscript text by default.

Do not bind persisted artifacts to one provider's response format. Store normalized domain payloads plus minimal provider metadata.

## 6. Human review

Review is not a binary confidence threshold. Users can:
- accept a claim;
- reject it;
- edit the wording;
- change explicit/inferred/speculative classification;
- merge or split entities;
- correct a plotline assignment;
- request re-analysis of a selected chapter.

The review action and actor must be recorded. A user-edited claim should retain its original generated text or revision linkage.

## 7. Observability

Track run duration, step duration, retry count, model latency, input/output token usage when available, validation failure count, evidence verification rate, and cancellation reason. Logs should include run ID, step key, work ID, and source/split version IDs.
