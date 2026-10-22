# Product Scope and MVP

## 1. Product definition

ASK is a structured workspace for reverse-engineering existing novels and designing coherent original long-form fiction. Its core asset is a versioned narrative model—not a chat transcript. Reading tutoring and manuscript drafting build on this foundation.

The first release validates two connected paths: evidence-backed reverse analysis of an existing novel, and structured forward design of an original novel. Full manuscript generation and advanced reading-tutor features follow later. Both paths reuse the same entity, event, plotline, outline, version and task foundations, while keeping source facts separate from planned fiction.

## 2. Primary users and jobs

- **Reader / researcher:** understand a novel's structure, characters, themes, plotlines, foreshadowing, and narrative techniques with traceable source evidence.
- **Writer:** create and maintain a coherent story bible, outline, plotlines, chapter beats, and manuscript.
- **Editor / reviewer:** inspect AI conclusions, correct entity resolution, approve or reject claims, and track the impact of changes.

## 3. MVP vertical slice

1. Create a project and add a work.
2. Upload a text source and record its checksum and storage location.
3. Parse and normalize the source into an immutable source version.
4. Split the normalized text into chapters. Show a preview and allow boundary/title correction.
5. Confirm a split version. A correction creates a new split version; it must not silently mutate the old version.
6. Start an asynchronous analysis run bound to the exact source and split versions.
7. Analyze each chapter into events, chapter beats, characters, conflicts, information changes, and chapter function.
8. Consolidate entities across chapters and create candidate relations and plotlines.
9. Store claims and link them to verifiable source anchors.
10. Show results in an editable UI. User edits and review decisions must persist independently from the original AI output.
11. Create an original work without an uploaded source; define a creative brief, premise, characters, causal event spine, plotlines and a planned outline.
12. Run basic design diagnostics for missing causal dependencies, character-motivation conflicts, timeline conflicts and unresolved threads; diagnostics are suggestions, not automatic rewrites.

## 4. MVP acceptance criteria

- Re-uploading the same file can be detected by SHA-256 and handled idempotently.
- The user can inspect chapter boundaries before analysis.
- Every analysis run exposes status, progress, stage, timestamps, and actionable error information.
- A run can resume or retry failed work without duplicating already persisted entities/events.
- Every generated artifact identifies its source version, split version, model, prompt version, and producing run where applicable.
- A key conclusion can be opened at the relevant chapter and quoted text.
- AI-generated facts are distinguishable from explicit source statements and human-confirmed facts.
- Users can edit, accept, or reject results without losing the original generated revision.
- A new source or split version does not make an old analysis appear current.
- The system can rerun one chapter and its dependent aggregation rather than requiring a full-book rerun.

## 5. Initial scope

### Included

- TXT ingestion first; EPUB and DOCX adapters can follow behind the same import interface.
- Source normalization, chapter splitting, split preview and confirmation.
- Chapter-level analysis and book-level synthesis.
- Character/entity extraction, event extraction, candidate relations, plotline candidates and outline artifacts.
- Evidence anchors, human review, version provenance and async job status.
- Original novel design workbench: creative brief, multiple story concepts, character/relationship model, planned events, plotlines and a hierarchical outline.
- Basic design diagnostics and change-impact warnings.
- Basic project/work management and a functional analysis/design UI.

### Deferred

- OCR-heavy PDF ingestion.
- Public publishing, collaboration comments, billing and marketplace features.
- Dedicated graph database.
- Autonomous full-novel generation, chapter-by-chapter manuscript production and multi-agent free-form writing.
- Advanced semantic comparison across a large library.
- Fine-grained collaborative editing and real-time multi-user cursors.

## 6. Product rules

1. The original uploaded bytes are immutable.
2. Normalized source versions are immutable.
3. Chapter splitting is versioned separately from normalized source content.
4. Reverse-analysis output and planned creative structure are different semantic modes.
5. The model may propose facts; the user or a validator decides whether to accept them.
6. Evidence must point to exact source text. Unsupported interpretation must be labelled as inference or speculation.
7. Long-running work is asynchronous and resumable.
8. The UI must expose source evidence beside conclusions, not hide provenance in a debug screen.

## 7. Success measures for the first milestone

- Import-to-chapter-preview success rate.
- Chapter boundary correction rate.
- Percentage of material claims with valid evidence anchors.
- Entity merge/split correction rate.
- Analysis retry success rate.
- Time to inspect and correct a full-book outline.
- Number of stale artifacts correctly identified after source/split changes.
