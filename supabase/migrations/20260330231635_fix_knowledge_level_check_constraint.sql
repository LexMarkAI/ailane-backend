-- Migration: 20260330231635_fix_knowledge_level_check_constraint
-- Applied: backfilled from supabase_migrations.schema_migrations 2026-04-17
-- Name: fix_knowledge_level_check_constraint


-- Fix: add 'adaptive' to the allowed values for detected_knowledge_level
ALTER TABLE kl_eileen_conversations 
DROP CONSTRAINT kl_eileen_conversations_detected_knowledge_level_check;

ALTER TABLE kl_eileen_conversations 
ADD CONSTRAINT kl_eileen_conversations_detected_knowledge_level_check 
CHECK (detected_knowledge_level = ANY (ARRAY['beginner', 'intermediate', 'advanced', 'adaptive']));

