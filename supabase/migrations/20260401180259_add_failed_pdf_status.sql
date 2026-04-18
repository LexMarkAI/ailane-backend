-- Migration: 20260401180259_add_failed_pdf_status
-- Applied: backfilled from supabase_migrations.schema_migrations 2026-04-17
-- Name: add_failed_pdf_status


-- Add 'failed' as a valid extraction status and mark the 20 known-bad records
UPDATE tribunal_decisions 
SET pdf_extraction_status = 'failed'
WHERE id IN (
  '3c52eede-8e85-4021-a753-f3337d8d3439',
  'cb6ae4d3-9181-4e0c-a57a-5ccd5e40df20',
  'e069392f-9e90-47b1-92d3-9b747fe7ed02',
  '6ce992e3-669f-40fd-854f-dc3379c0db98',
  '1d171058-33ef-405e-8f2c-debdc16aa160',
  '1f106343-edbb-4801-bdf0-b3da2d7f8ebd',
  'a23c7b7c-00cc-47c1-9bbc-7123cf097c6a',
  'ce4e6a12-c31e-4702-a673-e644b05ca117',
  '9a094a56-d5ac-4dfb-a6a9-4c3f23b7975f',
  'b87d03c3-d54e-4290-88c9-c082fb8b142a',
  '32071413-52bd-431f-913a-7c7fd71043d0',
  'fa26f000-eb56-4568-a95f-7a8fad6b879a',
  'a7cb0450-7ebe-4e5e-aee1-2b5c1b3ba68f',
  '3e9341e3-4bcb-4277-8a9c-caa2934d819d',
  '2883f439-2edf-407a-85cd-ee77d233ebe3',
  'c39acbf9-42d8-43d5-81ae-bb6fa5b0bcac',
  '6e1811a0-eeee-43d0-8b59-2309ae71dc7f',
  '6e8e45ca-ab59-48dc-800e-88df1904a8cc',
  'ff0bf218-69b3-444f-8368-008074184adc',
  '2c3723cc-a541-4f3f-acbd-ee1b282db816'
);

