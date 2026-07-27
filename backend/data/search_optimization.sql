-- ============================================================================
-- DawaaCheck Search Optimization Migration
-- Run this in the Supabase SQL Editor (https://supabase.com/dashboard)
-- Safe to run multiple times (all statements use IF NOT EXISTS)
-- Expected result: medicine search drops from ~1800ms to <200ms
-- ============================================================================

-- ─── Step 1: Enable trigram extension for fast LIKE/ILIKE searches ───
CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- ─── Step 2: drap_medicines indexes (main search table, 329 rows) ───

-- Trigram indexes for the ilike fallback path in /medicines/search
-- These turn sequential scans into index scans for LIKE '%paracetamol%' queries
CREATE INDEX IF NOT EXISTS idx_drap_medicines_brand_trgm
  ON drap_medicines USING GIN (brand_name gin_trgm_ops);

CREATE INDEX IF NOT EXISTS idx_drap_medicines_generic_trgm
  ON drap_medicines USING GIN (generic_name gin_trgm_ops);

CREATE INDEX IF NOT EXISTS idx_drap_medicines_manufacturer_trgm
  ON drap_medicines USING GIN (manufacturer gin_trgm_ops);

-- GIN index on the full-text search vector (may already exist from v2 migration)
CREATE INDEX IF NOT EXISTS idx_drap_medicines_search_vector
  ON drap_medicines USING GIN (search_vector);

-- Functional index for case-insensitive joins in medicine_full_details view
CREATE INDEX IF NOT EXISTS idx_drap_medicines_lower_generic
  ON drap_medicines (lower(generic_name));

-- ─── Step 3: generic_drugs indexes (922 rows) ───

CREATE INDEX IF NOT EXISTS idx_generic_drugs_generic_trgm
  ON generic_drugs USING GIN (generic_name gin_trgm_ops);

CREATE INDEX IF NOT EXISTS idx_generic_drugs_lower_generic
  ON generic_drugs (lower(generic_name));

-- ─── Step 4: medicine_prices indexes (135 rows) ───

CREATE INDEX IF NOT EXISTS idx_medicine_prices_brand_trgm
  ON medicine_prices USING GIN (brand_name gin_trgm_ops);

CREATE INDEX IF NOT EXISTS idx_medicine_prices_generic_trgm
  ON medicine_prices USING GIN (generic_name gin_trgm_ops);

-- ─── Step 5: openfda_drugs indexes (920 rows) ───

CREATE INDEX IF NOT EXISTS idx_openfda_drugs_generic_trgm
  ON openfda_drugs USING GIN (generic_name gin_trgm_ops);

-- JSONB index for brand_names array lookups
CREATE INDEX IF NOT EXISTS idx_openfda_drugs_brand_names
  ON openfda_drugs USING GIN (brand_names);

-- ─── Step 6: drug_interactions indexes (50 rows) ───

CREATE INDEX IF NOT EXISTS idx_drug_interactions_drug_a_trgm
  ON drug_interactions USING GIN (drug_a gin_trgm_ops);

CREATE INDEX IF NOT EXISTS idx_drug_interactions_drug_b_trgm
  ON drug_interactions USING GIN (drug_b gin_trgm_ops);

-- ─── Step 7: drug_side_effects indexes (149 rows) ───

CREATE INDEX IF NOT EXISTS idx_drug_side_effects_drug_trgm
  ON drug_side_effects USING GIN (drug_name gin_trgm_ops);

CREATE INDEX IF NOT EXISTS idx_drug_side_effects_lower_drug
  ON drug_side_effects (lower(drug_name));

-- ─── Step 8: who_aware_antibiotics indexes (60 rows) ───

CREATE INDEX IF NOT EXISTS idx_who_aware_name_trgm
  ON who_aware_antibiotics USING GIN (name gin_trgm_ops);

-- ─── Step 9: pediatric_safety indexes (35 rows) ───

CREATE INDEX IF NOT EXISTS idx_pediatric_safety_drug_trgm
  ON pediatric_safety USING GIN (drug_name gin_trgm_ops);

-- ─── Step 10: recall tables indexes ───

CREATE INDEX IF NOT EXISTS idx_drap_recalls_medicine_trgm
  ON drap_recalls USING GIN (medicine_name gin_trgm_ops);

CREATE INDEX IF NOT EXISTS idx_openfda_recalls_product_trgm
  ON openfda_recalls USING GIN (product_description gin_trgm_ops);

-- ─── Step 11: adverse events indexes ───

CREATE INDEX IF NOT EXISTS idx_openfda_adverse_drug_trgm
  ON openfda_adverse_events USING GIN (drug_name gin_trgm_ops);

-- ─── Step 12: Refresh query planner statistics on all tables ───

ANALYZE drap_medicines;
ANALYZE generic_drugs;
ANALYZE medicine_prices;
ANALYZE openfda_drugs;
ANALYZE drug_interactions;
ANALYZE drug_side_effects;
ANALYZE who_aware_antibiotics;
ANALYZE pediatric_safety;
ANALYZE drap_recalls;
ANALYZE openfda_recalls;
ANALYZE openfda_adverse_events;
ANALYZE scan_results;
ANALYZE users;
ANALYZE adr_reports;

-- ============================================================================
-- Done! Expected improvements:
-- - /medicines/search: 1800ms → <200ms (trigram indexes on brand/generic/manufacturer)
-- - Agent 3 (recall lookups): 30-50% faster
-- - Agent 5 (price lookups): 30-50% faster
-- - Agent 10 (interaction checks): faster bidirectional drug_a/drug_b queries
-- ============================================================================
