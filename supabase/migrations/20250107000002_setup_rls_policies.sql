-- Setup Row Level Security (RLS) policies for all tables
-- This ensures users can only access their own data with proper security

-- Enable RLS on all tables
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE memos ENABLE ROW LEVEL SECURITY;
ALTER TABLE tags ENABLE ROW LEVEL SECURITY;
ALTER TABLE memo_tags ENABLE ROW LEVEL SECURITY;
ALTER TABLE sessions ENABLE ROW LEVEL SECURITY;

-- ===========================================
-- PROFILES TABLE RLS POLICIES
-- ===========================================

-- Users can view their own profile
CREATE POLICY "Users can view their own profile"
ON profiles FOR SELECT
TO authenticated
USING (auth.uid() = id);

-- Users can update their own profile
CREATE POLICY "Users can update their own profile"
ON profiles FOR UPDATE
TO authenticated
USING (auth.uid() = id)
WITH CHECK (auth.uid() = id);

-- Users can insert their own profile (for new account creation)
CREATE POLICY "Users can insert their own profile"
ON profiles FOR INSERT
TO authenticated
WITH CHECK (auth.uid() = id);

-- Users can delete their own profile
CREATE POLICY "Users can delete their own profile"
ON profiles FOR DELETE
TO authenticated
USING (auth.uid() = id);

-- ===========================================
-- MEMOS TABLE RLS POLICIES
-- ===========================================

-- Users can view their own memos
CREATE POLICY "Users can view their own memos"
ON memos FOR SELECT
TO authenticated
USING (user_id = auth.uid());

-- Users can view public memos from all users
CREATE POLICY "Users can view public memos"
ON memos FOR SELECT
TO authenticated
USING (visibility = 1); -- 1 = public

-- Users can insert their own memos
CREATE POLICY "Users can insert their own memos"
ON memos FOR INSERT
TO authenticated
WITH CHECK (user_id = auth.uid());

-- Users can update their own memos
CREATE POLICY "Users can update their own memos"
ON memos FOR UPDATE
TO authenticated
USING (user_id = auth.uid())
WITH CHECK (user_id = auth.uid());

-- Users can delete their own memos
CREATE POLICY "Users can delete their own memos"
ON memos FOR DELETE
TO authenticated
USING (user_id = auth.uid());

-- ===========================================
-- TAGS TABLE RLS POLICIES
-- ===========================================

-- For tags, we'll use a shared approach where users can view all tags
-- but can only manage tags that are used by their memos

-- Users can view all tags (for autocomplete and selection)
CREATE POLICY "Users can view all tags"
ON tags FOR SELECT
TO authenticated
USING (true);

-- Users can insert new tags
CREATE POLICY "Users can insert new tags"
ON tags FOR INSERT
TO authenticated
WITH CHECK (true);

-- Users can update tags that are used by their memos
CREATE POLICY "Users can update tags used by their memos"
ON tags FOR UPDATE
TO authenticated
USING (
    id IN (
        SELECT DISTINCT mt.tag_id 
        FROM memo_tags mt 
        JOIN memos m ON mt.memo_id = m.id 
        WHERE m.user_id = auth.uid()
    )
);

-- Users can delete tags that are only used by their memos
CREATE POLICY "Users can delete tags used only by their memos"
ON tags FOR DELETE
TO authenticated
USING (
    id IN (
        SELECT tag_id 
        FROM memo_tags mt 
        JOIN memos m ON mt.memo_id = m.id 
        WHERE m.user_id = auth.uid()
    )
    AND id NOT IN (
        SELECT tag_id 
        FROM memo_tags mt 
        JOIN memos m ON mt.memo_id = m.id 
        WHERE m.user_id != auth.uid()
    )
);

-- ===========================================
-- MEMO_TAGS TABLE RLS POLICIES
-- ===========================================

-- Users can view memo_tags for their own memos
CREATE POLICY "Users can view memo_tags for their own memos"
ON memo_tags FOR SELECT
TO authenticated
USING (
    memo_id IN (
        SELECT id FROM memos WHERE user_id = auth.uid()
    )
);

-- Users can view memo_tags for public memos
CREATE POLICY "Users can view memo_tags for public memos"
ON memo_tags FOR SELECT
TO authenticated
USING (
    memo_id IN (
        SELECT id FROM memos WHERE visibility = 1
    )
);

-- Users can insert memo_tags for their own memos
CREATE POLICY "Users can insert memo_tags for their own memos"
ON memo_tags FOR INSERT
TO authenticated
WITH CHECK (
    memo_id IN (
        SELECT id FROM memos WHERE user_id = auth.uid()
    )
);

-- Users can update memo_tags for their own memos
CREATE POLICY "Users can update memo_tags for their own memos"
ON memo_tags FOR UPDATE
TO authenticated
USING (
    memo_id IN (
        SELECT id FROM memos WHERE user_id = auth.uid()
    )
)
WITH CHECK (
    memo_id IN (
        SELECT id FROM memos WHERE user_id = auth.uid()
    )
);

-- Users can delete memo_tags for their own memos
CREATE POLICY "Users can delete memo_tags for their own memos"
ON memo_tags FOR DELETE
TO authenticated
USING (
    memo_id IN (
        SELECT id FROM memos WHERE user_id = auth.uid()
    )
);

-- ===========================================
-- SESSIONS TABLE RLS POLICIES
-- ===========================================

-- Users can view their own sessions
CREATE POLICY "Users can view their own sessions"
ON sessions FOR SELECT
TO authenticated
USING (user_id = auth.uid());

-- Users can insert their own sessions
CREATE POLICY "Users can insert their own sessions"
ON sessions FOR INSERT
TO authenticated
WITH CHECK (user_id = auth.uid());

-- Users can update their own sessions
CREATE POLICY "Users can update their own sessions"
ON sessions FOR UPDATE
TO authenticated
USING (user_id = auth.uid())
WITH CHECK (user_id = auth.uid());

-- Users can delete their own sessions
CREATE POLICY "Users can delete their own sessions"
ON sessions FOR DELETE
TO authenticated
USING (user_id = auth.uid());

-- ===========================================
-- ADDITIONAL SECURITY FUNCTIONS
-- ===========================================

-- Function to check if user can access memo (for complex visibility logic)
CREATE OR REPLACE FUNCTION can_user_access_memo(memo_uuid UUID, user_uuid UUID)
RETURNS BOOLEAN AS $$
DECLARE
    memo_visibility INTEGER;
    memo_owner UUID;
BEGIN
    SELECT visibility, user_id INTO memo_visibility, memo_owner
    FROM memos WHERE id = memo_uuid;
    
    -- Owner can always access
    IF memo_owner = user_uuid THEN
        RETURN TRUE;
    END IF;
    
    -- Public memos can be accessed by anyone
    IF memo_visibility = 1 THEN
        RETURN TRUE;
    END IF;
    
    -- Shared memos logic (future implementation)
    -- IF memo_visibility = 2 THEN
    --     RETURN check_shared_access(memo_uuid, user_uuid);
    -- END IF;
    
    RETURN FALSE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get user's memo count (for analytics)
CREATE OR REPLACE FUNCTION get_user_memo_count(user_uuid UUID)
RETURNS INTEGER AS $$
BEGIN
    RETURN (
        SELECT COUNT(*) 
        FROM memos 
        WHERE user_id = user_uuid
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get user's tag count (for analytics)
CREATE OR REPLACE FUNCTION get_user_tag_count(user_uuid UUID)
RETURNS INTEGER AS $$
BEGIN
    RETURN (
        SELECT COUNT(DISTINCT mt.tag_id) 
        FROM memo_tags mt 
        JOIN memos m ON mt.memo_id = m.id 
        WHERE m.user_id = user_uuid
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to cleanup expired sessions
CREATE OR REPLACE FUNCTION cleanup_expired_sessions()
RETURNS INTEGER AS $$
DECLARE
    deleted_count INTEGER;
BEGIN
    DELETE FROM sessions 
    WHERE expires_at < NOW();
    
    GET DIAGNOSTICS deleted_count = ROW_COUNT;
    RETURN deleted_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ===========================================
-- GRANT PERMISSIONS
-- ===========================================

-- Grant necessary permissions to authenticated users
GRANT SELECT, INSERT, UPDATE, DELETE ON profiles TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON memos TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON tags TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON memo_tags TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON sessions TO authenticated;

-- Grant execute permissions on functions
GRANT EXECUTE ON FUNCTION can_user_access_memo TO authenticated;
GRANT EXECUTE ON FUNCTION get_user_memo_count TO authenticated;
GRANT EXECUTE ON FUNCTION get_user_tag_count TO authenticated;
GRANT EXECUTE ON FUNCTION get_memos_with_tags TO authenticated;
GRANT EXECUTE ON FUNCTION search_memos TO authenticated;

-- Grant execute permission on cleanup function to service role only
GRANT EXECUTE ON FUNCTION cleanup_expired_sessions TO service_role;

-- ===========================================
-- COMMENTS FOR DOCUMENTATION
-- ===========================================

COMMENT ON POLICY "Users can view their own profile" ON profiles IS 'Allows users to view their own profile data';
COMMENT ON POLICY "Users can view their own memos" ON memos IS 'Allows users to view their own memos';
COMMENT ON POLICY "Users can view public memos" ON memos IS 'Allows users to view public memos from all users';
COMMENT ON POLICY "Users can view all tags" ON tags IS 'Allows users to view all tags for autocomplete and selection';

COMMENT ON FUNCTION can_user_access_memo IS 'Security function to check if user can access a specific memo';
COMMENT ON FUNCTION get_user_memo_count IS 'Analytics function to get memo count for a user';
COMMENT ON FUNCTION get_user_tag_count IS 'Analytics function to get tag count for a user';
COMMENT ON FUNCTION cleanup_expired_sessions IS 'Maintenance function to cleanup expired sessions'; 
