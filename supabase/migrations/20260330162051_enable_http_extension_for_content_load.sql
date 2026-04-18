-- Migration: 20260330162051_enable_http_extension_for_content_load
-- Applied: backfilled from supabase_migrations.schema_migrations 2026-04-17
-- Name: enable_http_extension_for_content_load


-- Enable http extension for one-time content loading
CREATE EXTENSION IF NOT EXISTS http WITH SCHEMA extensions;

