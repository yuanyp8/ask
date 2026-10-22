-- ASK core schema rollback, migration 000001
-- Drops only objects introduced by 000001. Back up data before rollback.


DROP TABLE IF EXISTS outline_nodes;
DROP TABLE IF EXISTS outline_sets;
DROP TABLE IF EXISTS plotline_nodes;
DROP TABLE IF EXISTS plotlines;
DROP TABLE IF EXISTS event_relation_evidence;
DROP TABLE IF EXISTS story_relation_evidence;
DROP TABLE IF EXISTS evidence_anchors;
DROP TABLE IF EXISTS analysis_claims;
DROP TABLE IF EXISTS event_relations;
DROP TABLE IF EXISTS story_events;
DROP TABLE IF EXISTS story_relations;
DROP TABLE IF EXISTS entity_aliases;
DROP TABLE IF EXISTS story_entities;
DROP TABLE IF EXISTS analysis_run_steps;
DROP TABLE IF EXISTS artifacts;
DROP TABLE IF EXISTS analysis_runs;
DROP TABLE IF EXISTS source_chapters;
DROP TABLE IF EXISTS split_versions;
DROP TABLE IF EXISTS source_versions;
DROP TABLE IF EXISTS source_documents;
DROP TABLE IF EXISTS project_works;
DROP TABLE IF EXISTS works;
DROP TABLE IF EXISTS project_members;
DROP TABLE IF EXISTS projects;
DROP TABLE IF EXISTS app_users;

