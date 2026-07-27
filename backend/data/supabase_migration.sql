-- DawaaCheck Supabase Database Migration
-- Run this in Supabase SQL Editor

-- Users table
CREATE TABLE IF NOT EXISTS users (
    id TEXT PRIMARY KEY, -- Firebase UID
    email TEXT,
    display_name TEXT,
    photo_url TEXT,
    device_token TEXT,
    is_anonymous BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Scan Results table
CREATE TABLE IF NOT EXISTS scan_results (
    id TEXT PRIMARY KEY, -- sc_timestamp format
    user_id TEXT REFERENCES users(id),
    scan_timestamp TIMESTAMPTZ DEFAULT NOW(),
    medicine_name TEXT NOT NULL,
    manufacturer TEXT,
    registration_number TEXT,
    barcode TEXT,
    batch_number TEXT,
    expiry_date TEXT,
    overall_verdict TEXT NOT NULL CHECK (overall_verdict IN ('VERIFIED', 'UNVERIFIED', 'DANGER')),
    confidence_score FLOAT DEFAULT 0,
    agent_results JSONB DEFAULT '[]'::JSONB,
    scan_latitude FLOAT,
    scan_longitude FLOAT,
    recall_alert_sent BOOLEAN DEFAULT FALSE
);

-- DRAP Medicines table
CREATE TABLE IF NOT EXISTS drap_medicines (
    id SERIAL PRIMARY KEY,
    registration_number TEXT UNIQUE NOT NULL,
    brand_name TEXT NOT NULL,
    generic_name TEXT,
    manufacturer TEXT NOT NULL,
    active_ingredients JSONB DEFAULT '[]'::JSONB,
    dosage_form TEXT,
    strength TEXT,
    pack_size TEXT,
    mrp FLOAT,
    registration_date TEXT,
    expiry_date TEXT,
    status TEXT DEFAULT 'Active'
);

-- DRAP Recalls table
CREATE TABLE IF NOT EXISTS drap_recalls (
    id TEXT PRIMARY KEY,
    recall_class TEXT NOT NULL CHECK (recall_class IN ('CLASS_I', 'CLASS_II')),
    medicine_name TEXT NOT NULL,
    registration_number TEXT,
    batch_numbers TEXT[] DEFAULT '{}',
    recall_reason TEXT NOT NULL,
    recall_date DATE NOT NULL,
    drap_notice_number TEXT,
    is_active BOOLEAN DEFAULT TRUE
);

-- ADR Reports table
CREATE TABLE IF NOT EXISTS adr_reports (
    id SERIAL PRIMARY KEY,
    user_id TEXT REFERENCES users(id),
    scan_id TEXT REFERENCES scan_results(id),
    medicine_name TEXT NOT NULL,
    batch_number TEXT,
    reaction_description TEXT NOT NULL,
    severity TEXT NOT NULL CHECK (severity IN ('MILD', 'MODERATE', 'SEVERE', 'LIFE_THREATENING')),
    reaction_date DATE NOT NULL,
    patient_age_group TEXT NOT NULL,
    meddra_term TEXT,
    is_flagged BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Safety Heatmap table (anonymized aggregated data)
CREATE TABLE IF NOT EXISTS safety_heatmap (
    id SERIAL PRIMARY KEY,
    latitude FLOAT NOT NULL, -- rounded to 3 decimal places
    longitude FLOAT NOT NULL,
    verdict_type TEXT NOT NULL CHECK (verdict_type IN ('VERIFIED', 'UNVERIFIED', 'DANGER')),
    scan_count INTEGER DEFAULT 1,
    UNIQUE(latitude, longitude, verdict_type)
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_scan_results_user_id ON scan_results(user_id);
CREATE INDEX IF NOT EXISTS idx_scan_results_verdict ON scan_results(overall_verdict);
CREATE INDEX IF NOT EXISTS idx_scan_results_timestamp ON scan_results(scan_timestamp DESC);
CREATE INDEX IF NOT EXISTS idx_drap_medicines_brand ON drap_medicines(brand_name);
CREATE INDEX IF NOT EXISTS idx_drap_medicines_generic ON drap_medicines(generic_name);
CREATE INDEX IF NOT EXISTS idx_drap_recalls_active ON drap_recalls(is_active);
CREATE INDEX IF NOT EXISTS idx_adr_reports_medicine ON adr_reports(medicine_name);

-- Row Level Security
ALTER TABLE scan_results ENABLE ROW LEVEL SECURITY;
ALTER TABLE adr_reports ENABLE ROW LEVEL SECURITY;

-- RLS Policies: users can only see their own data
CREATE POLICY "Users can view own scans" ON scan_results
    FOR SELECT USING (user_id = current_setting('request.jwt.claims')::json->>'sub');

CREATE POLICY "Users can insert own scans" ON scan_results
    FOR INSERT WITH CHECK (user_id = current_setting('request.jwt.claims')::json->>'sub');

CREATE POLICY "Users can delete own scans" ON scan_results
    FOR DELETE USING (user_id = current_setting('request.jwt.claims')::json->>'sub');

CREATE POLICY "Users can view own ADR reports" ON adr_reports
    FOR SELECT USING (user_id = current_setting('request.jwt.claims')::json->>'sub');

CREATE POLICY "Users can insert own ADR reports" ON adr_reports
    FOR INSERT WITH CHECK (user_id = current_setting('request.jwt.claims')::json->>'sub');

-- Public read for recalls and medicines (no auth required)
ALTER TABLE drap_recalls ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Public read recalls" ON drap_recalls FOR SELECT USING (true);

ALTER TABLE drap_medicines ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Public read medicines" ON drap_medicines FOR SELECT USING (true);
