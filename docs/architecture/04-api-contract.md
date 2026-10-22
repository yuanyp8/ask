# Initial REST API Contract

## 1. Conventions

- Base path: /api/v1
- JSON request and response bodies.
- UUIDs for resource IDs.
- Timestamps use RFC 3339 / ISO 8601 with timezone.
- List endpoints support limit and cursor pagination; do not rely on offset pagination for rapidly changing task lists.
- Mutating endpoints should accept an Idempotency-Key where retry could create duplicate work.
- Long-running analysis creation returns HTTP 202 Accepted and a run resource.
- API handlers enforce project membership and work/project linkage; UUID unpredictability is not authorization.

## 2. Error envelope

Return a stable envelope with a machine-readable code, human-readable message, optional field errors, and request ID.

    {
      "error": {
        "code": "SOURCE_VERSION_MISMATCH",
        "message": "The split version does not belong to the selected source version.",
        "details": {},
        "request_id": "..."
      }
    }

Do not return raw provider exceptions or stack traces to clients.

## 3. Project and work

- POST /projects — create a project.
- GET /projects — list accessible projects.
- GET /projects/{project_id} — project details.
- POST /projects/{project_id}/works — link or create a work in a project.
- GET /projects/{project_id}/works — list works.
- GET /works/{work_id} — work details.
- PATCH /works/{work_id} — update title and metadata with optimistic version checking.

## 4. Source ingestion and splitting

- POST /works/{work_id}/sources — create an upload/import record.
- POST /sources/{source_id}/parse — enqueue parsing and normalization.
- GET /sources/{source_id} — source status and metadata.
- GET /sources/{source_id}/versions — list immutable source versions.
- GET /source-versions/{source_version_id}/split-versions — list segmentations.
- POST /source-versions/{source_version_id}/split-versions — create a draft split version.
- GET /split-versions/{split_version_id}/chapters — list chapter metadata and pagination.
- GET /chapters/{chapter_id} — chapter content and offsets.
- PATCH /split-versions/{split_version_id}/chapters/{chapter_id} — edit title or boundary in a draft split only.
- POST /split-versions/{split_version_id}/confirm — confirm the segmentation and make it eligible for analysis.

Boundary edits must produce a new draft split version or an explicit new revision; never mutate a split version already referenced by an analysis run.

## 5. Analysis runs

- POST /works/{work_id}/analysis-runs — create a run.
- GET /analysis-runs/{run_id} — status, progress, input versions, and errors.
- GET /analysis-runs/{run_id}/steps — stage/step status.
- POST /analysis-runs/{run_id}/cancel — request cooperative cancellation.
- POST /analysis-runs/{run_id}/retry — retry failed/retryable steps under policy.

Example create request:

    {
      "task_type": "book_reverse_analysis",
      "source_version_id": "UUID",
      "split_version_id": "UUID",
      "scope": {
        "chapter_ids": [],
        "outputs": ["chapter_outline", "entities", "events", "plotlines"]
      },
      "options": {
        "language": "zh-CN",
        "include_evidence": true
      }
    }

Example accepted response:

    {
      "data": {
        "id": "UUID",
        "status": "queued",
        "progress": {
          "completed_steps": 0,
          "total_steps": 0,
          "stage": "validate_inputs"
        }
      }
    }

## 6. Artifacts and story structure

- GET /works/{work_id}/artifacts — filter by type, scope, status, and source version.
- GET /artifacts/{artifact_id} — full artifact payload and provenance.
- POST /artifacts/{artifact_id}/review — accept, reject, or request edits.
- GET /works/{work_id}/entities — list/search entities.
- GET /entities/{entity_id} — entity profile, aliases, relations, events, and evidence.
- PATCH /entities/{entity_id} — edit canonical name or description using optimistic concurrency.
- POST /entities/{entity_id}/merge — merge into another entity with an audit record.
- GET /works/{work_id}/events — ordered event list and filters.
- GET /works/{work_id}/plotlines — list plotlines.
- GET /plotlines/{plotline_id} — plotline detail and ordered nodes.
- GET /works/{work_id}/outline-sets — list outline versions.
- GET /outline-sets/{outline_set_id}/tree — retrieve outline nodes as a tree.
- PATCH /outline-nodes/{node_id} — edit node content/position with revision checking.
- GET /claims/{claim_id}/evidence — return verified evidence anchors and chapter references.

## 7. Concurrency and revision checks

Editable resources should expose a revision number or ETag. Updates include the expected revision; stale updates return HTTP 409 with the current revision reference. This prevents the UI from silently overwriting newer edits.

## 8. API boundaries

- The API coordinates domain operations; it does not contain model prompts inline.
- Model calls run in workers, not in ordinary request handlers.
- Source parsing is called through a preprocessor interface.
- Retrieval is an internal capability at first; do not expose vector database implementation details in public API contracts.
- API DTOs are versioned separately from internal database models.
