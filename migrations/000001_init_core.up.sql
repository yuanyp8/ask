-- ASK core schema, migration 000001
-- Requires PostgreSQL 14+.
-- Keep source versions and confirmed split versions immutable at the application layer.


CREATE TABLE app_users (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    external_subject text UNIQUE,
    display_name text NOT NULL,
    email text,
    created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE projects (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    name text NOT NULL,
    description text NOT NULL DEFAULT '',
    project_type text NOT NULL DEFAULT 'mixed'
        CHECK (project_type IN ('research', 'writing', 'mixed')),
    status text NOT NULL DEFAULT 'active'
        CHECK (status IN ('active', 'archived')),
    owner_id uuid NOT NULL REFERENCES app_users(id) ON DELETE RESTRICT,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE project_members (
    project_id uuid NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
    user_id uuid NOT NULL REFERENCES app_users(id) ON DELETE CASCADE,
    role text NOT NULL CHECK (role IN ('owner', 'editor', 'viewer')),
    joined_at timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (project_id, user_id)
);

CREATE TABLE works (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    title text NOT NULL,
    work_type text NOT NULL CHECK (work_type IN ('published', 'original')),
    language_code text NOT NULL DEFAULT 'zh-CN',
    genre text,
    metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE project_works (
    project_id uuid NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
    work_id uuid NOT NULL REFERENCES works(id) ON DELETE RESTRICT,
    role text NOT NULL DEFAULT 'primary'
        CHECK (role IN ('primary', 'reference', 'inspiration')),
    added_at timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (project_id, work_id)
);

CREATE TABLE source_documents (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    work_id uuid NOT NULL REFERENCES works(id) ON DELETE RESTRICT,
    original_filename text NOT NULL,
    media_type text NOT NULL,
    storage_key text NOT NULL UNIQUE,
    sha256 char(64) NOT NULL,
    byte_size bigint NOT NULL CHECK (byte_size >= 0),
    status text NOT NULL DEFAULT 'uploaded'
        CHECK (status IN ('uploaded', 'parsing', 'ready', 'failed', 'archived')),
    created_by uuid REFERENCES app_users(id) ON DELETE SET NULL,
    created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_source_documents_work_created
    ON source_documents(work_id, created_at DESC);
CREATE INDEX idx_source_documents_checksum
    ON source_documents(work_id, sha256);

CREATE TABLE source_versions (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    source_document_id uuid NOT NULL REFERENCES source_documents(id) ON DELETE RESTRICT,
    version_no integer NOT NULL CHECK (version_no > 0),
    normalized_text_key text,
    content_sha256 char(64) NOT NULL,
    parser_name text NOT NULL,
    parser_version text NOT NULL,
    normalization_profile jsonb NOT NULL DEFAULT '{}'::jsonb,
    created_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE (source_document_id, version_no)
);

CREATE INDEX idx_source_versions_document
    ON source_versions(source_document_id, version_no DESC);

CREATE TABLE split_versions (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    source_version_id uuid NOT NULL REFERENCES source_versions(id) ON DELETE RESTRICT,
    version_no integer NOT NULL CHECK (version_no > 0),
    split_config jsonb NOT NULL DEFAULT '{}'::jsonb,
    status text NOT NULL DEFAULT 'draft'
        CHECK (status IN ('draft', 'confirmed', 'superseded')),
    created_by uuid REFERENCES app_users(id) ON DELETE SET NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    confirmed_at timestamptz,
    UNIQUE (source_version_id, version_no),
    UNIQUE (id, source_version_id),
    CHECK (status <> 'confirmed' OR confirmed_at IS NOT NULL)
);

CREATE INDEX idx_split_versions_source
    ON split_versions(source_version_id, version_no DESC);

CREATE TABLE source_chapters (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    split_version_id uuid NOT NULL REFERENCES split_versions(id) ON DELETE RESTRICT,
    chapter_no integer NOT NULL CHECK (chapter_no > 0),
    title text NOT NULL,
    chapter_type text NOT NULL DEFAULT 'normal'
        CHECK (chapter_type IN ('normal', 'prologue', 'epilogue', 'interlude', 'appendix', 'unknown')),
    content_text text NOT NULL,
    start_offset bigint,
    end_offset bigint,
    content_sha256 char(64) NOT NULL,
    char_count integer NOT NULL CHECK (char_count >= 0),
    created_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE (split_version_id, chapter_no),
    CHECK (char_count = char_length(content_text)),
    CHECK (
        (start_offset IS NULL AND end_offset IS NULL)
        OR (start_offset >= 0 AND end_offset >= start_offset)
    )
);

CREATE INDEX idx_source_chapters_split_order
    ON source_chapters(split_version_id, chapter_no);
CREATE INDEX idx_source_chapters_content_hash
    ON source_chapters(content_sha256);

COMMENT ON COLUMN source_chapters.start_offset IS
    'Optional zero-based offset in the canonical normalized full source text.';
COMMENT ON COLUMN source_chapters.end_offset IS
    'Optional exclusive offset in the canonical normalized full source text.';
COMMENT ON COLUMN source_chapters.content_text IS
    'Canonical normalized chapter text. Evidence offsets are measured in Unicode code points over this exact text.';

CREATE TABLE analysis_runs (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    project_id uuid NOT NULL,
    work_id uuid NOT NULL,
    source_version_id uuid REFERENCES source_versions(id) ON DELETE RESTRICT,
    split_version_id uuid REFERENCES split_versions(id) ON DELETE RESTRICT,
    task_type text NOT NULL
        CHECK (task_type IN (
            'chapter_analysis',
            'book_reverse_analysis',
            'entity_resolution',
            'plotline_synthesis',
            'outline_generation',
            'consistency_check',
            'custom'
        )),
    status text NOT NULL DEFAULT 'queued'
        CHECK (status IN ('queued', 'running', 'completed_with_warnings', 'succeeded', 'failed', 'cancelled')),
    idempotency_key text,
    input_manifest jsonb NOT NULL DEFAULT '{}'::jsonb,
    progress jsonb NOT NULL DEFAULT '{}'::jsonb,
    model_id text,
    prompt_version text,
    error_code text,
    error_message text,
    requested_by uuid REFERENCES app_users(id) ON DELETE SET NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    started_at timestamptz,
    finished_at timestamptz,
    FOREIGN KEY (project_id, work_id)
        REFERENCES project_works(project_id, work_id) ON DELETE RESTRICT,
    FOREIGN KEY (split_version_id, source_version_id)
        REFERENCES split_versions(id, source_version_id) ON DELETE RESTRICT,
    CHECK (split_version_id IS NULL OR source_version_id IS NOT NULL),
    CHECK (finished_at IS NULL OR started_at IS NULL OR finished_at >= started_at)
);

CREATE UNIQUE INDEX uq_analysis_runs_idempotency
    ON analysis_runs(project_id, idempotency_key)
    WHERE idempotency_key IS NOT NULL;
CREATE INDEX idx_analysis_runs_project_status
    ON analysis_runs(project_id, status, created_at DESC);
CREATE INDEX idx_analysis_runs_work_created
    ON analysis_runs(work_id, created_at DESC);
CREATE INDEX idx_analysis_runs_source_split
    ON analysis_runs(source_version_id, split_version_id);

CREATE TABLE artifacts (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    work_id uuid NOT NULL REFERENCES works(id) ON DELETE RESTRICT,
    artifact_key text NOT NULL,
    artifact_type text NOT NULL,
    revision integer NOT NULL CHECK (revision > 0),
    scope_type text NOT NULL DEFAULT 'work'
        CHECK (scope_type IN ('work', 'chapter', 'entity', 'plotline', 'outline_set')),
    scope_id uuid,
    source_version_id uuid REFERENCES source_versions(id) ON DELETE RESTRICT,
    split_version_id uuid REFERENCES split_versions(id) ON DELETE RESTRICT,
    payload_schema_version integer NOT NULL DEFAULT 1 CHECK (payload_schema_version > 0),
    payload jsonb NOT NULL DEFAULT '{}'::jsonb,
    rendered_markdown text,
    status text NOT NULL DEFAULT 'draft'
        CHECK (status IN ('draft', 'in_review', 'accepted', 'rejected', 'superseded', 'stale')),
    run_id uuid REFERENCES analysis_runs(id) ON DELETE SET NULL,
    supersedes_artifact_id uuid REFERENCES artifacts(id) ON DELETE SET NULL,
    created_by uuid REFERENCES app_users(id) ON DELETE SET NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE (work_id, artifact_key, revision),
    FOREIGN KEY (split_version_id, source_version_id)
        REFERENCES split_versions(id, source_version_id) ON DELETE RESTRICT,
    CHECK (
        (scope_type = 'work' AND scope_id IS NULL)
        OR (scope_type <> 'work' AND scope_id IS NOT NULL)
    ),
    CHECK (split_version_id IS NULL OR source_version_id IS NOT NULL)
);

CREATE INDEX idx_artifacts_work_key_revision
    ON artifacts(work_id, artifact_key, revision DESC);
CREATE INDEX idx_artifacts_work_type_created
    ON artifacts(work_id, artifact_type, created_at DESC);
CREATE INDEX idx_artifacts_run
    ON artifacts(run_id);

CREATE TABLE analysis_run_steps (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    run_id uuid NOT NULL REFERENCES analysis_runs(id) ON DELETE CASCADE,
    step_key text NOT NULL,
    sequence_no integer NOT NULL CHECK (sequence_no > 0),
    status text NOT NULL DEFAULT 'pending'
        CHECK (status IN ('pending', 'running', 'succeeded', 'retryable_failed', 'terminal_failed', 'skipped')),
    attempt_count integer NOT NULL DEFAULT 0 CHECK (attempt_count >= 0),
    input_json jsonb NOT NULL DEFAULT '{}'::jsonb,
    output_json jsonb NOT NULL DEFAULT '{}'::jsonb,
    output_artifact_id uuid REFERENCES artifacts(id) ON DELETE SET NULL,
    error_code text,
    error_message text,
    started_at timestamptz,
    finished_at timestamptz,
    created_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE (run_id, step_key),
    UNIQUE (run_id, sequence_no),
    CHECK (finished_at IS NULL OR started_at IS NULL OR finished_at >= started_at)
);

CREATE INDEX idx_analysis_run_steps_status
    ON analysis_run_steps(run_id, status, sequence_no);

CREATE TABLE story_entities (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    work_id uuid NOT NULL REFERENCES works(id) ON DELETE RESTRICT,
    entity_type text NOT NULL
        CHECK (entity_type IN ('character', 'location', 'organization', 'object', 'concept', 'other')),
    canonical_name text NOT NULL,
    normalized_name text NOT NULL,
    description text NOT NULL DEFAULT '',
    attributes jsonb NOT NULL DEFAULT '{}'::jsonb,
    first_seen_chapter_id uuid REFERENCES source_chapters(id) ON DELETE SET NULL,
    status text NOT NULL DEFAULT 'active'
        CHECK (status IN ('active', 'merged', 'archived')),
    merged_into_entity_id uuid,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    FOREIGN KEY (merged_into_entity_id, work_id)
        REFERENCES story_entities(id, work_id) ON DELETE RESTRICT,
    CHECK (merged_into_entity_id IS NULL OR merged_into_entity_id <> id),
    CHECK (
        (status = 'merged' AND merged_into_entity_id IS NOT NULL)
        OR (status <> 'merged' AND merged_into_entity_id IS NULL)
    ),
    UNIQUE (id, work_id)
);

CREATE INDEX idx_story_entities_work_type_name
    ON story_entities(work_id, entity_type, normalized_name);
CREATE INDEX idx_story_entities_work_status
    ON story_entities(work_id, status);

CREATE TABLE entity_aliases (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    entity_id uuid NOT NULL REFERENCES story_entities(id) ON DELETE CASCADE,
    alias text NOT NULL,
    normalized_alias text NOT NULL,
    alias_type text NOT NULL DEFAULT 'alternate_name'
        CHECK (alias_type IN ('alternate_name', 'title', 'nickname', 'transliteration', 'unknown')),
    created_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE (entity_id, normalized_alias)
);

CREATE INDEX idx_entity_aliases_normalized
    ON entity_aliases(normalized_alias);

CREATE TABLE story_relations (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    work_id uuid NOT NULL REFERENCES works(id) ON DELETE RESTRICT,
    source_entity_id uuid NOT NULL,
    target_entity_id uuid NOT NULL,
    relation_type text NOT NULL,
    description text NOT NULL DEFAULT '',
    confidence numeric(4,3) CHECK (confidence IS NULL OR confidence BETWEEN 0 AND 1),
    attributes jsonb NOT NULL DEFAULT '{}'::jsonb,
    status text NOT NULL DEFAULT 'candidate'
        CHECK (status IN ('candidate', 'accepted', 'rejected', 'archived')),
    created_at timestamptz NOT NULL DEFAULT now(),
    FOREIGN KEY (source_entity_id, work_id)
        REFERENCES story_entities(id, work_id) ON DELETE RESTRICT,
    FOREIGN KEY (target_entity_id, work_id)
        REFERENCES story_entities(id, work_id) ON DELETE RESTRICT,
    CHECK (source_entity_id <> target_entity_id)
);

CREATE INDEX idx_story_relations_source
    ON story_relations(work_id, source_entity_id, relation_type);
CREATE INDEX idx_story_relations_target
    ON story_relations(work_id, target_entity_id, relation_type);

CREATE TABLE story_events (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    work_id uuid NOT NULL REFERENCES works(id) ON DELETE RESTRICT,
    event_key text NOT NULL,
    chapter_id uuid REFERENCES source_chapters(id) ON DELETE SET NULL,
    event_type text NOT NULL DEFAULT 'other',
    summary text NOT NULL,
    narrative_order bigint NOT NULL,
    story_time_label text,
    attributes jsonb NOT NULL DEFAULT '{}'::jsonb,
    status text NOT NULL DEFAULT 'candidate'
        CHECK (status IN ('candidate', 'accepted', 'rejected', 'archived')),
    created_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE (work_id, event_key),
    UNIQUE (id, work_id)
);

CREATE INDEX idx_story_events_work_order
    ON story_events(work_id, narrative_order);
CREATE INDEX idx_story_events_chapter
    ON story_events(chapter_id);

CREATE TABLE event_relations (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    work_id uuid NOT NULL REFERENCES works(id) ON DELETE RESTRICT,
    source_event_id uuid NOT NULL,
    target_event_id uuid NOT NULL,
    relation_type text NOT NULL
        CHECK (relation_type IN ('causes', 'enables', 'precedes', 'foreshadows', 'reveals', 'contradicts', 'parallels', 'other')),
    confidence numeric(4,3) CHECK (confidence IS NULL OR confidence BETWEEN 0 AND 1),
    attributes jsonb NOT NULL DEFAULT '{}'::jsonb,
    status text NOT NULL DEFAULT 'candidate'
        CHECK (status IN ('candidate', 'accepted', 'rejected', 'archived')),
    created_at timestamptz NOT NULL DEFAULT now(),
    FOREIGN KEY (source_event_id, work_id)
        REFERENCES story_events(id, work_id) ON DELETE RESTRICT,
    FOREIGN KEY (target_event_id, work_id)
        REFERENCES story_events(id, work_id) ON DELETE RESTRICT,
    CHECK (source_event_id <> target_event_id),
    UNIQUE (work_id, source_event_id, target_event_id, relation_type)
);

CREATE INDEX idx_event_relations_source
    ON event_relations(work_id, source_event_id);
CREATE INDEX idx_event_relations_target
    ON event_relations(work_id, target_event_id);

CREATE TABLE analysis_claims (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    artifact_id uuid NOT NULL REFERENCES artifacts(id) ON DELETE RESTRICT,
    entity_id uuid REFERENCES story_entities(id) ON DELETE RESTRICT,
    event_id uuid REFERENCES story_events(id) ON DELETE RESTRICT,
    claim_type text NOT NULL,
    claim_text text NOT NULL,
    epistemic_status text NOT NULL
        CHECK (epistemic_status IN ('explicit', 'inferred', 'speculative')),
    confidence numeric(4,3) CHECK (confidence IS NULL OR confidence BETWEEN 0 AND 1),
    review_status text NOT NULL DEFAULT 'unreviewed'
        CHECK (review_status IN ('unreviewed', 'accepted', 'rejected', 'edited')),
    attributes jsonb NOT NULL DEFAULT '{}'::jsonb,
    reviewed_by uuid REFERENCES app_users(id) ON DELETE SET NULL,
    reviewed_at timestamptz,
    created_at timestamptz NOT NULL DEFAULT now(),
    CHECK (entity_id IS NULL OR event_id IS NULL)
);

CREATE INDEX idx_analysis_claims_artifact
    ON analysis_claims(artifact_id, review_status);
CREATE INDEX idx_analysis_claims_entity
    ON analysis_claims(entity_id)
    WHERE entity_id IS NOT NULL;
CREATE INDEX idx_analysis_claims_event
    ON analysis_claims(event_id)
    WHERE event_id IS NOT NULL;

CREATE TABLE evidence_anchors (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    claim_id uuid NOT NULL REFERENCES analysis_claims(id) ON DELETE CASCADE,
    chapter_id uuid NOT NULL REFERENCES source_chapters(id) ON DELETE RESTRICT,
    anchor_kind text NOT NULL DEFAULT 'quote'
        CHECK (anchor_kind IN ('quote', 'span', 'chapter_context')),
    start_char integer NOT NULL CHECK (start_char >= 0),
    end_char integer NOT NULL CHECK (end_char > start_char),
    quote_text text NOT NULL,
    quote_sha256 char(64) NOT NULL,
    evidence_role text NOT NULL DEFAULT 'supports'
        CHECK (evidence_role IN ('supports', 'challenges', 'context')),
    created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_evidence_anchors_claim
    ON evidence_anchors(claim_id);
CREATE INDEX idx_evidence_anchors_chapter_span
    ON evidence_anchors(chapter_id, start_char, end_char);

CREATE TABLE story_relation_evidence (
    relation_id uuid NOT NULL REFERENCES story_relations(id) ON DELETE CASCADE,
    evidence_anchor_id uuid NOT NULL REFERENCES evidence_anchors(id) ON DELETE CASCADE,
    PRIMARY KEY (relation_id, evidence_anchor_id)
);

CREATE TABLE event_relation_evidence (
    event_relation_id uuid NOT NULL REFERENCES event_relations(id) ON DELETE CASCADE,
    evidence_anchor_id uuid NOT NULL REFERENCES evidence_anchors(id) ON DELETE CASCADE,
    PRIMARY KEY (event_relation_id, evidence_anchor_id)
);

CREATE TABLE plotlines (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    work_id uuid NOT NULL REFERENCES works(id) ON DELETE RESTRICT,
    line_key text NOT NULL,
    title text NOT NULL,
    line_type text NOT NULL
        CHECK (line_type IN ('main', 'subplot', 'character_arc', 'mystery', 'romance', 'theme', 'other')),
    description text NOT NULL DEFAULT '',
    goal text,
    resolution text,
    confidence numeric(4,3) CHECK (confidence IS NULL OR confidence BETWEEN 0 AND 1),
    status text NOT NULL DEFAULT 'candidate'
        CHECK (status IN ('candidate', 'active', 'closed', 'rejected', 'archived')),
    attributes jsonb NOT NULL DEFAULT '{}'::jsonb,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE (work_id, line_key)
);

CREATE INDEX idx_plotlines_work_type_status
    ON plotlines(work_id, line_type, status);

CREATE TABLE plotline_nodes (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    plotline_id uuid NOT NULL REFERENCES plotlines(id) ON DELETE CASCADE,
    position integer NOT NULL CHECK (position > 0),
    node_type text NOT NULL
        CHECK (node_type IN ('setup', 'development', 'turning_point', 'convergence', 'payoff', 'closure', 'other')),
    event_id uuid REFERENCES story_events(id) ON DELETE RESTRICT,
    chapter_id uuid REFERENCES source_chapters(id) ON DELETE RESTRICT,
    summary text NOT NULL DEFAULT '',
    narrative_function text NOT NULL DEFAULT '',
    attributes jsonb NOT NULL DEFAULT '{}'::jsonb,
    created_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE (plotline_id, position),
    CHECK (event_id IS NOT NULL OR chapter_id IS NOT NULL)
);

CREATE INDEX idx_plotline_nodes_event
    ON plotline_nodes(event_id)
    WHERE event_id IS NOT NULL;
CREATE INDEX idx_plotline_nodes_chapter
    ON plotline_nodes(chapter_id)
    WHERE chapter_id IS NOT NULL;

CREATE TABLE outline_sets (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    work_id uuid NOT NULL REFERENCES works(id) ON DELETE RESTRICT,
    title text NOT NULL,
    outline_mode text NOT NULL
        CHECK (outline_mode IN ('reverse_analysis', 'planned_outline')),
    version_no integer NOT NULL CHECK (version_no > 0),
    source_version_id uuid REFERENCES source_versions(id) ON DELETE RESTRICT,
    split_version_id uuid REFERENCES split_versions(id) ON DELETE RESTRICT,
    status text NOT NULL DEFAULT 'draft'
        CHECK (status IN ('draft', 'in_review', 'accepted', 'superseded', 'stale')),
    created_by uuid REFERENCES app_users(id) ON DELETE SET NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE (work_id, outline_mode, version_no),
    FOREIGN KEY (split_version_id, source_version_id)
        REFERENCES split_versions(id, source_version_id) ON DELETE RESTRICT,
    CHECK (split_version_id IS NULL OR source_version_id IS NOT NULL),
    CHECK (
        outline_mode <> 'reverse_analysis'
        OR (source_version_id IS NOT NULL AND split_version_id IS NOT NULL)
    )
);

CREATE INDEX idx_outline_sets_work_mode_version
    ON outline_sets(work_id, outline_mode, version_no DESC);

CREATE TABLE outline_nodes (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    outline_set_id uuid NOT NULL REFERENCES outline_sets(id) ON DELETE CASCADE,
    parent_id uuid,
    node_type text NOT NULL
        CHECK (node_type IN ('book', 'volume', 'act', 'story_arc', 'chapter', 'scene', 'beat')),
    title text NOT NULL,
    summary text NOT NULL DEFAULT '',
    position integer NOT NULL CHECK (position > 0),
    source_chapter_id uuid REFERENCES source_chapters(id) ON DELETE RESTRICT,
    linked_event_id uuid REFERENCES story_events(id) ON DELETE RESTRICT,
    attributes jsonb NOT NULL DEFAULT '{}'::jsonb,
    created_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE (id, outline_set_id),
    FOREIGN KEY (parent_id, outline_set_id)
        REFERENCES outline_nodes(id, outline_set_id) ON DELETE CASCADE
);

CREATE UNIQUE INDEX uq_outline_nodes_child_position
    ON outline_nodes(outline_set_id, parent_id, position)
    WHERE parent_id IS NOT NULL;
CREATE UNIQUE INDEX uq_outline_nodes_root_position
    ON outline_nodes(outline_set_id, position)
    WHERE parent_id IS NULL;
CREATE INDEX idx_outline_nodes_parent
    ON outline_nodes(outline_set_id, parent_id, position);

