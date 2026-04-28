-- Phase 1 of AILANE-CC-BRIEF-IS-SOLE-TRADER-001
-- Adds B-tree index on is_sole_trader to support §43.4 view-creation pattern filtering.

CREATE INDEX idx_em_is_sole_trader ON public.employer_master(is_sole_trader);

