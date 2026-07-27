-- ============================================================================
-- DawaaCheck Production Database Migration V2
-- Run this in Supabase SQL Editor AFTER the original migration
-- Adds all drug data tables for production-level app
-- ============================================================================

-- ============================================================================
-- 1. MEDICINES (Unified — merges DRAP branded + generic info)
-- ============================================================================

-- Add missing columns to existing drap_medicines table
ALTER TABLE drap_medicines ADD COLUMN IF NOT EXISTS category TEXT;
ALTER TABLE drap_medicines ADD COLUMN IF NOT EXISTS barcode TEXT;
ALTER TABLE drap_medicines ADD COLUMN IF NOT EXISTS image_url TEXT;
ALTER TABLE drap_medicines ADD COLUMN IF NOT EXISTS is_otc BOOLEAN DEFAULT FALSE;
ALTER TABLE drap_medicines ADD COLUMN IF NOT EXISTS common_use TEXT;

-- Full-text search vector on drap_medicines
ALTER TABLE drap_medicines ADD COLUMN IF NOT EXISTS search_vector tsvector;

CREATE OR REPLACE FUNCTION update_medicine_search_vector()
RETURNS trigger AS $$
BEGIN
  NEW.search_vector := to_tsvector('english',
    coalesce(NEW.brand_name, '') || ' ' ||
    coalesce(NEW.generic_name, '') || ' ' ||
    coalesce(NEW.manufacturer, '') || ' ' ||
    coalesce(NEW.category, '')
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_medicine_search ON drap_medicines;
CREATE TRIGGER trg_medicine_search
  BEFORE INSERT OR UPDATE ON drap_medicines
  FOR EACH ROW EXECUTE FUNCTION update_medicine_search_vector();

CREATE INDEX IF NOT EXISTS idx_medicines_search ON drap_medicines USING gin(search_vector);
CREATE INDEX IF NOT EXISTS idx_medicines_category ON drap_medicines(category);
CREATE INDEX IF NOT EXISTS idx_medicines_otc ON drap_medicines(is_otc);

-- ============================================================================
-- 2. GENERIC DRUGS (922 generics with clinical data)
-- ============================================================================

CREATE TABLE IF NOT EXISTS generic_drugs (
    id SERIAL PRIMARY KEY,
    generic_name TEXT UNIQUE NOT NULL,
    therapeutic_class TEXT,
    mechanism_of_action TEXT,
    dosage_guidance TEXT,
    pregnancy_category TEXT,
    pregnancy_notes TEXT,
    pregnancy_score INTEGER,
    lactation_safe BOOLEAN,
    lactation_notes TEXT,
    fertility_notes TEXT,
    is_controlled BOOLEAN DEFAULT FALSE,
    addiction_notes TEXT,
    contraindications JSONB DEFAULT '[]'::JSONB,
    drug_interactions_list JSONB DEFAULT '[]'::JSONB,
    special_populations JSONB DEFAULT '{}'::JSONB,
    forms JSONB DEFAULT '[]'::JSONB,
    source_version TEXT,
    last_updated TEXT
);

CREATE INDEX IF NOT EXISTS idx_generic_name ON generic_drugs(generic_name);
CREATE INDEX IF NOT EXISTS idx_generic_class ON generic_drugs(therapeutic_class);

ALTER TABLE generic_drugs ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Public read generic drugs" ON generic_drugs FOR SELECT USING (true);

-- ============================================================================
-- 3. DRUG INTERACTIONS
-- ============================================================================

CREATE TABLE IF NOT EXISTS drug_interactions (
    id SERIAL PRIMARY KEY,
    drug_a TEXT NOT NULL,
    drug_b TEXT NOT NULL,
    severity TEXT NOT NULL CHECK (severity IN ('CONTRAINDICATED', 'MAJOR', 'MODERATE', 'MINOR')),
    description TEXT NOT NULL,
    recommendation TEXT,
    UNIQUE(drug_a, drug_b)
);

CREATE INDEX IF NOT EXISTS idx_interactions_drug_a ON drug_interactions(drug_a);
CREATE INDEX IF NOT EXISTS idx_interactions_drug_b ON drug_interactions(drug_b);
CREATE INDEX IF NOT EXISTS idx_interactions_severity ON drug_interactions(severity);

ALTER TABLE drug_interactions ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Public read interactions" ON drug_interactions FOR SELECT USING (true);

-- ============================================================================
-- 4. DRUG SIDE EFFECTS
-- ============================================================================

CREATE TABLE IF NOT EXISTS drug_side_effects (
    id SERIAL PRIMARY KEY,
    drug_name TEXT UNIQUE NOT NULL,
    common_effects JSONB DEFAULT '[]'::JSONB,
    serious_effects JSONB DEFAULT '[]'::JSONB,
    black_box_warning TEXT,
    max_dose TEXT,
    overdose_antidote TEXT,
    contraindicated JSONB DEFAULT '[]'::JSONB,
    avoid_with JSONB DEFAULT '[]'::JSONB
);

CREATE INDEX IF NOT EXISTS idx_side_effects_drug ON drug_side_effects(drug_name);

ALTER TABLE drug_side_effects ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Public read side effects" ON drug_side_effects FOR SELECT USING (true);

-- ============================================================================
-- 5. WHO AWARE ANTIBIOTICS
-- ============================================================================

CREATE TABLE IF NOT EXISTS who_aware_antibiotics (
    id SERIAL PRIMARY KEY,
    name TEXT NOT NULL,
    category TEXT NOT NULL CHECK (category IN ('access', 'watch', 'reserve')),
    antibiotic_class TEXT,
    key_access BOOLEAN DEFAULT FALSE,
    oral_available BOOLEAN DEFAULT FALSE
);

CREATE INDEX IF NOT EXISTS idx_aware_name ON who_aware_antibiotics(name);
CREATE INDEX IF NOT EXISTS idx_aware_category ON who_aware_antibiotics(category);

ALTER TABLE who_aware_antibiotics ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Public read WHO AWaRe" ON who_aware_antibiotics FOR SELECT USING (true);

-- ============================================================================
-- 6. PEDIATRIC SAFETY
-- ============================================================================

CREATE TABLE IF NOT EXISTS pediatric_safety (
    id SERIAL PRIMARY KEY,
    drug_name TEXT NOT NULL,
    safety_type TEXT NOT NULL CHECK (safety_type IN ('contraindicated', 'dose_adjustment', 'monitoring_required')),
    reason TEXT,
    age_limit TEXT,
    alternative TEXT,
    dose_info TEXT,
    monitoring_parameters TEXT
);

CREATE INDEX IF NOT EXISTS idx_pediatric_drug ON pediatric_safety(drug_name);
CREATE INDEX IF NOT EXISTS idx_pediatric_type ON pediatric_safety(safety_type);

ALTER TABLE pediatric_safety ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Public read pediatric safety" ON pediatric_safety FOR SELECT USING (true);

-- ============================================================================
-- 7. PRICE DATABASE WITH GENERIC ALTERNATIVES
-- ============================================================================

CREATE TABLE IF NOT EXISTS medicine_prices (
    id SERIAL PRIMARY KEY,
    brand_name TEXT NOT NULL,
    generic_name TEXT,
    manufacturer TEXT,
    dosage_form TEXT,
    strength TEXT,
    pack_size TEXT,
    mrp FLOAT,
    generic_alternatives JSONB DEFAULT '[]'::JSONB
);

CREATE INDEX IF NOT EXISTS idx_prices_brand ON medicine_prices(brand_name);
CREATE INDEX IF NOT EXISTS idx_prices_generic ON medicine_prices(generic_name);

ALTER TABLE medicine_prices ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Public read prices" ON medicine_prices FOR SELECT USING (true);

-- ============================================================================
-- 8. MEDICINE IMAGES
-- ============================================================================

CREATE TABLE IF NOT EXISTS medicine_images (
    id SERIAL PRIMARY KEY,
    drug_name TEXT NOT NULL,
    image_url TEXT NOT NULL,
    image_type TEXT DEFAULT 'molecular', -- 'molecular', 'package', 'pill', 'label'
    source TEXT,
    license TEXT,
    width INTEGER,
    height INTEGER
);

CREATE INDEX IF NOT EXISTS idx_images_drug ON medicine_images(drug_name);

ALTER TABLE medicine_images ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Public read images" ON medicine_images FOR SELECT USING (true);

-- ============================================================================
-- 9. DRUG CONDITIONS (treatment guidelines)
-- ============================================================================

CREATE TABLE IF NOT EXISTS drug_conditions (
    id SERIAL PRIMARY KEY,
    condition_name TEXT UNIQUE NOT NULL,
    first_line JSONB DEFAULT '[]'::JSONB,
    second_line JSONB DEFAULT '[]'::JSONB,
    third_line JSONB DEFAULT '[]'::JSONB,
    lifestyle TEXT,
    monitoring TEXT
);

CREATE INDEX IF NOT EXISTS idx_conditions_name ON drug_conditions(condition_name);

ALTER TABLE drug_conditions ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Public read conditions" ON drug_conditions FOR SELECT USING (true);

-- ============================================================================
-- 10. MANUFACTURERS
-- ============================================================================

CREATE TABLE IF NOT EXISTS manufacturers (
    id SERIAL PRIMARY KEY,
    name TEXT UNIQUE NOT NULL,
    city TEXT,
    company_type TEXT, -- 'Local', 'MNC'
    drap_license TEXT,
    major_brands JSONB DEFAULT '[]'::JSONB,
    established INTEGER
);

ALTER TABLE manufacturers ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Public read manufacturers" ON manufacturers FOR SELECT USING (true);

-- ============================================================================
-- 11. OPENFDA DRUG LABELS (international reference)
-- ============================================================================

CREATE TABLE IF NOT EXISTS openfda_drugs (
    id SERIAL PRIMARY KEY,
    generic_name TEXT NOT NULL,
    brand_names JSONB DEFAULT '[]'::JSONB,
    manufacturer TEXT,
    route JSONB DEFAULT '[]'::JSONB,
    substance_name JSONB DEFAULT '[]'::JSONB,
    product_type JSONB DEFAULT '[]'::JSONB,
    dosage_form TEXT,
    indications TEXT,
    warnings TEXT,
    contraindications TEXT,
    drug_interactions TEXT,
    pregnancy TEXT,
    pediatric_use TEXT,
    adverse_reactions TEXT
);

CREATE INDEX IF NOT EXISTS idx_openfda_generic ON openfda_drugs(generic_name);

ALTER TABLE openfda_drugs ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Public read openfda" ON openfda_drugs FOR SELECT USING (true);

-- ============================================================================
-- 12. OPENFDA ADVERSE EVENTS
-- ============================================================================

CREATE TABLE IF NOT EXISTS openfda_adverse_events (
    id SERIAL PRIMARY KEY,
    drug_name TEXT NOT NULL,
    top_reactions JSONB DEFAULT '[]'::JSONB
);

CREATE INDEX IF NOT EXISTS idx_adverse_drug ON openfda_adverse_events(drug_name);

ALTER TABLE openfda_adverse_events ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Public read adverse events" ON openfda_adverse_events FOR SELECT USING (true);

-- ============================================================================
-- 13. OPENFDA RECALLS (international)
-- ============================================================================

CREATE TABLE IF NOT EXISTS openfda_recalls (
    id SERIAL PRIMARY KEY,
    search_term TEXT,
    recall_number TEXT,
    event_id TEXT,
    status TEXT,
    classification TEXT, -- 'Class I', 'Class II', 'Class III'
    product_description TEXT,
    reason_for_recall TEXT,
    recalling_firm TEXT,
    city TEXT,
    state TEXT,
    country TEXT,
    recall_initiation_date TEXT,
    report_date TEXT,
    voluntary_mandated TEXT
);

CREATE INDEX IF NOT EXISTS idx_fda_recalls_term ON openfda_recalls(search_term);

ALTER TABLE openfda_recalls ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Public read FDA recalls" ON openfda_recalls FOR SELECT USING (true);

-- ============================================================================
-- 14. Update DRAP RECALLS table to add missing columns
-- ============================================================================

ALTER TABLE drap_recalls ADD COLUMN IF NOT EXISTS manufacturer TEXT;
ALTER TABLE drap_recalls ADD COLUMN IF NOT EXISTS affected_regions JSONB DEFAULT '[]'::JSONB;

-- Drop the old CHECK constraint and re-add with CLASS_III
DO $$ BEGIN
  ALTER TABLE drap_recalls DROP CONSTRAINT IF EXISTS drap_recalls_recall_class_check;
  ALTER TABLE drap_recalls ADD CONSTRAINT drap_recalls_recall_class_check
    CHECK (recall_class IN ('CLASS_I', 'CLASS_II', 'CLASS_III'));
EXCEPTION WHEN OTHERS THEN NULL;
END $$;

-- ============================================================================
-- 15. Update ADR REPORTS table for production
-- ============================================================================

ALTER TABLE adr_reports ADD COLUMN IF NOT EXISTS generic_name TEXT;
ALTER TABLE adr_reports ADD COLUMN IF NOT EXISTS manufacturer TEXT;
ALTER TABLE adr_reports ADD COLUMN IF NOT EXISTS onset_date TEXT;
ALTER TABLE adr_reports ADD COLUMN IF NOT EXISTS patient_age FLOAT;
ALTER TABLE adr_reports ADD COLUMN IF NOT EXISTS patient_weight FLOAT;
ALTER TABLE adr_reports ADD COLUMN IF NOT EXISTS patient_gender TEXT;
ALTER TABLE adr_reports ADD COLUMN IF NOT EXISTS outcome TEXT;
ALTER TABLE adr_reports ADD COLUMN IF NOT EXISTS latitude FLOAT;
ALTER TABLE adr_reports ADD COLUMN IF NOT EXISTS longitude FLOAT;
ALTER TABLE adr_reports ADD COLUMN IF NOT EXISTS status TEXT DEFAULT 'submitted';
ALTER TABLE adr_reports ADD COLUMN IF NOT EXISTS submitted_at TIMESTAMPTZ DEFAULT NOW();

-- Drop old constraints that might conflict
DO $$ BEGIN
  ALTER TABLE adr_reports DROP CONSTRAINT IF EXISTS adr_reports_severity_check;
  ALTER TABLE adr_reports ADD CONSTRAINT adr_reports_severity_check
    CHECK (severity IN ('MILD', 'MODERATE', 'SEVERE', 'LIFE_THREATENING', 'mild', 'moderate', 'severe', 'life_threatening'));
EXCEPTION WHEN OTHERS THEN NULL;
END $$;

-- Make scan_id and reaction_date nullable for flexibility
ALTER TABLE adr_reports ALTER COLUMN scan_id DROP NOT NULL;
ALTER TABLE adr_reports ALTER COLUMN reaction_date DROP NOT NULL;
ALTER TABLE adr_reports ALTER COLUMN patient_age_group DROP NOT NULL;

-- ============================================================================
-- 16. RXNORM CLASSIFICATIONS (drug coding)
-- ============================================================================

CREATE TABLE IF NOT EXISTS rxnorm_classifications (
    id SERIAL PRIMARY KEY,
    drug_name TEXT NOT NULL,
    rxcui TEXT,
    classes JSONB DEFAULT '[]'::JSONB,
    properties JSONB DEFAULT '{}'::JSONB
);

CREATE INDEX IF NOT EXISTS idx_rxnorm_drug ON rxnorm_classifications(drug_name);

ALTER TABLE rxnorm_classifications ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Public read rxnorm" ON rxnorm_classifications FOR SELECT USING (true);

-- ============================================================================
-- 17. Service role policies for backend inserts
-- ============================================================================

-- Service role key bypasses RLS automatically, no extra policies needed.

-- ============================================================================
-- 18. Useful views for the app
-- ============================================================================

-- Combined medicine view (brand + generic info in one query)
CREATE OR REPLACE VIEW medicine_full_details AS
SELECT
    m.id,
    m.registration_number,
    m.brand_name,
    m.generic_name,
    m.manufacturer,
    m.active_ingredients,
    m.dosage_form,
    m.strength,
    m.pack_size,
    m.mrp,
    m.category,
    m.is_otc,
    m.image_url,
    m.status,
    g.therapeutic_class,
    g.mechanism_of_action,
    g.pregnancy_category,
    g.pregnancy_notes,
    g.is_controlled,
    g.contraindications AS generic_contraindications,
    g.forms AS available_forms,
    s.common_effects,
    s.serious_effects,
    s.black_box_warning,
    s.max_dose
FROM drap_medicines m
LEFT JOIN generic_drugs g ON lower(m.generic_name) = lower(g.generic_name)
LEFT JOIN drug_side_effects s ON lower(m.generic_name) = lower(s.drug_name)
WHERE m.status = 'Active';

-- Recall alerts view (combined DRAP + FDA)
CREATE OR REPLACE VIEW all_recalls AS
SELECT
    'DRAP' AS source,
    id::TEXT AS recall_id,
    recall_class AS classification,
    medicine_name,
    recall_reason AS reason,
    recall_date::TEXT AS recall_date,
    manufacturer,
    is_active
FROM drap_recalls
UNION ALL
SELECT
    'FDA' AS source,
    id::TEXT AS recall_id,
    classification,
    product_description AS medicine_name,
    reason_for_recall AS reason,
    recall_initiation_date AS recall_date,
    recalling_firm AS manufacturer,
    TRUE AS is_active
FROM openfda_recalls;

-- ============================================================================
-- Done! Run the upload_to_supabase.py script next to populate data.
-- ============================================================================
