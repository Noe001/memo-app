-- Create optimized database schema for Supabase
-- This migration creates UUID-based tables with RLS preparation and performance optimization

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Enable full-text search extension
CREATE EXTENSION IF NOT EXISTS "pg_trgm";

-- Create profiles table for Supabase Auth integration
CREATE TABLE IF NOT EXISTS profiles (
    id UUID PRIMARY KEY REFERENCES auth.users ON DELETE CASCADE,
    name VARCHAR(50) NOT NULL,
    email VARCHAR(255) NOT NULL UNIQUE,
    theme VARCHAR(20) DEFAULT 'light' CHECK (theme IN ('light', 'dark', 'high-contrast')),
    keyboard_shortcuts_enabled BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create optimized memos table with UUID
CREATE TABLE IF NOT EXISTS memos (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    title VARCHAR(255),
    description TEXT,
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    visibility INTEGER DEFAULT 0 CHECK (visibility IN (0, 1, 2)), -- 0=private, 1=public, 2=shared
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    
    -- Constraint to ensure at least title or description is present
    CONSTRAINT title_or_description_check CHECK (
        title IS NOT NULL AND trim(title) != '' OR 
        description IS NOT NULL AND trim(description) != ''
    )
);

-- Create optimized tags table with UUID
CREATE TABLE IF NOT EXISTS tags (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(100) NOT NULL UNIQUE,
    color VARCHAR(7) DEFAULT '#007bff' CHECK (color ~ '^#[0-9a-fA-F]{6}$'),
    description TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create memo_tags junction table with UUID
CREATE TABLE IF NOT EXISTS memo_tags (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    memo_id UUID NOT NULL REFERENCES memos(id) ON DELETE CASCADE,
    tag_id UUID NOT NULL REFERENCES tags(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    
    -- Ensure unique memo-tag combinations
    UNIQUE(memo_id, tag_id)
);

-- Create sessions table for legacy authentication (optional)
CREATE TABLE IF NOT EXISTS sessions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    token VARCHAR(255) NOT NULL UNIQUE,
    user_agent TEXT,
    ip_address INET,
    expires_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create performance indexes
-- Profiles table indexes
CREATE INDEX IF NOT EXISTS idx_profiles_email ON profiles(email);
CREATE INDEX IF NOT EXISTS idx_profiles_updated_at ON profiles(updated_at);

-- Memos table indexes
CREATE INDEX IF NOT EXISTS idx_memos_user_id_updated_at ON memos(user_id, updated_at DESC);
CREATE INDEX IF NOT EXISTS idx_memos_user_id_visibility ON memos(user_id, visibility);
CREATE INDEX IF NOT EXISTS idx_memos_visibility ON memos(visibility);
CREATE INDEX IF NOT EXISTS idx_memos_created_at ON memos(created_at DESC);

-- Full-text search indexes for memos
CREATE INDEX IF NOT EXISTS idx_memos_title_gin ON memos USING gin(to_tsvector('simple', COALESCE(title, '')));
CREATE INDEX IF NOT EXISTS idx_memos_description_gin ON memos USING gin(to_tsvector('simple', COALESCE(description, '')));

-- Trigram indexes for fuzzy search
CREATE INDEX IF NOT EXISTS idx_memos_title_trgm ON memos USING gin(title gin_trgm_ops);
CREATE INDEX IF NOT EXISTS idx_memos_description_trgm ON memos USING gin(description gin_trgm_ops);

-- Tags table indexes
CREATE INDEX IF NOT EXISTS idx_tags_name ON tags(name);
CREATE INDEX IF NOT EXISTS idx_tags_name_trgm ON tags USING gin(name gin_trgm_ops);

-- Memo_tags table indexes
CREATE INDEX IF NOT EXISTS idx_memo_tags_memo_id ON memo_tags(memo_id);
CREATE INDEX IF NOT EXISTS idx_memo_tags_tag_id ON memo_tags(tag_id);

-- Sessions table indexes
CREATE INDEX IF NOT EXISTS idx_sessions_user_id ON sessions(user_id);
CREATE INDEX IF NOT EXISTS idx_sessions_token ON sessions(token);
CREATE INDEX IF NOT EXISTS idx_sessions_expires_at ON sessions(expires_at);
CREATE INDEX IF NOT EXISTS idx_sessions_user_id_expires_at ON sessions(user_id, expires_at);

-- Create updated_at trigger function
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply updated_at triggers - Drop existing triggers first
DROP TRIGGER IF EXISTS update_profiles_updated_at ON profiles;
DROP TRIGGER IF EXISTS update_memos_updated_at ON memos;
DROP TRIGGER IF EXISTS update_tags_updated_at ON tags;
DROP TRIGGER IF EXISTS update_memo_tags_updated_at ON memo_tags;
DROP TRIGGER IF EXISTS update_sessions_updated_at ON sessions;

CREATE TRIGGER update_profiles_updated_at
    BEFORE UPDATE ON profiles
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_memos_updated_at
    BEFORE UPDATE ON memos
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_tags_updated_at
    BEFORE UPDATE ON tags
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_memo_tags_updated_at
    BEFORE UPDATE ON memo_tags
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_sessions_updated_at
    BEFORE UPDATE ON sessions
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Create helper functions for tag search
CREATE OR REPLACE FUNCTION get_memos_with_tags(tag_names text[])
RETURNS TABLE(memo_id UUID) AS $$
BEGIN
    RETURN QUERY
    SELECT m.id
    FROM memos m
    JOIN memo_tags mt ON m.id = mt.memo_id
    JOIN tags t ON mt.tag_id = t.id
    WHERE t.name = ANY(tag_names)
    GROUP BY m.id
    HAVING COUNT(DISTINCT t.name) = array_length(tag_names, 1);
END;
$$ LANGUAGE plpgsql;

-- Create full-text search function
CREATE OR REPLACE FUNCTION search_memos(search_query text, user_uuid UUID)
RETURNS TABLE(
    memo_id UUID,
    title VARCHAR(255),
    description TEXT,
    rank REAL
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        m.id,
        m.title,
        m.description,
        ts_rank(
            to_tsvector('simple', COALESCE(m.title, '') || ' ' || COALESCE(m.description, '')),
            plainto_tsquery('simple', search_query)
        ) as rank
    FROM memos m
    WHERE m.user_id = user_uuid
    AND (
        to_tsvector('simple', COALESCE(m.title, '') || ' ' || COALESCE(m.description, ''))
        @@ plainto_tsquery('simple', search_query)
    )
    ORDER BY rank DESC, m.updated_at DESC;
END;
$$ LANGUAGE plpgsql;

-- Add comments for documentation
COMMENT ON TABLE profiles IS 'User profiles integrated with Supabase Auth';
COMMENT ON TABLE memos IS 'User memos with full-text search optimization';
COMMENT ON TABLE tags IS 'Tags for categorizing memos';
COMMENT ON TABLE memo_tags IS 'Junction table for memo-tag relationships';
COMMENT ON TABLE sessions IS 'Session management for legacy authentication';

COMMENT ON FUNCTION get_memos_with_tags IS 'Helper function to find memos containing all specified tags';
COMMENT ON FUNCTION search_memos IS 'Full-text search function for memos with simple language support';
COMMENT ON FUNCTION update_updated_at_column IS 'Trigger function to automatically update updated_at timestamps'; 
