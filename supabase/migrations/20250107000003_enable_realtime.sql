-- Enable realtime features for memo application tables
-- This migration enables Supabase Realtime subscriptions for real-time collaboration

-- Enable realtime for all relevant tables
ALTER PUBLICATION supabase_realtime ADD TABLE memos;
ALTER PUBLICATION supabase_realtime ADD TABLE tags;
ALTER PUBLICATION supabase_realtime ADD TABLE memo_tags;
ALTER PUBLICATION supabase_realtime ADD TABLE profiles;

-- Create realtime change tracking functions
CREATE OR REPLACE FUNCTION broadcast_memo_changes()
RETURNS TRIGGER AS $$
BEGIN
    -- Broadcast memo changes with user context
    IF TG_OP = 'INSERT' THEN
        PERFORM pg_notify('memo_changes', json_build_object(
            'operation', 'INSERT',
            'table', 'memos',
            'new', row_to_json(NEW),
            'user_id', NEW.user_id,
            'timestamp', extract(epoch from now())
        )::text);
        RETURN NEW;
    END IF;
    
    IF TG_OP = 'UPDATE' THEN
        PERFORM pg_notify('memo_changes', json_build_object(
            'operation', 'UPDATE',
            'table', 'memos',
            'old', row_to_json(OLD),
            'new', row_to_json(NEW),
            'user_id', NEW.user_id,
            'timestamp', extract(epoch from now())
        )::text);
        RETURN NEW;
    END IF;
    
    IF TG_OP = 'DELETE' THEN
        PERFORM pg_notify('memo_changes', json_build_object(
            'operation', 'DELETE',
            'table', 'memos',
            'old', row_to_json(OLD),
            'user_id', OLD.user_id,
            'timestamp', extract(epoch from now())
        )::text);
        RETURN OLD;
    END IF;
    
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- Create realtime tag changes function
CREATE OR REPLACE FUNCTION broadcast_tag_changes()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        PERFORM pg_notify('tag_changes', json_build_object(
            'operation', 'INSERT',
            'table', 'tags',
            'new', row_to_json(NEW),
            'timestamp', extract(epoch from now())
        )::text);
        RETURN NEW;
    END IF;
    
    IF TG_OP = 'UPDATE' THEN
        PERFORM pg_notify('tag_changes', json_build_object(
            'operation', 'UPDATE',
            'table', 'tags',
            'old', row_to_json(OLD),
            'new', row_to_json(NEW),
            'timestamp', extract(epoch from now())
        )::text);
        RETURN NEW;
    END IF;
    
    IF TG_OP = 'DELETE' THEN
        PERFORM pg_notify('tag_changes', json_build_object(
            'operation', 'DELETE',
            'table', 'tags',
            'old', row_to_json(OLD),
            'timestamp', extract(epoch from now())
        )::text);
        RETURN OLD;
    END IF;
    
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- Create memo-tag association change function
CREATE OR REPLACE FUNCTION broadcast_memo_tag_changes()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        PERFORM pg_notify('memo_tag_changes', json_build_object(
            'operation', 'INSERT',
            'table', 'memo_tags',
            'new', row_to_json(NEW),
            'timestamp', extract(epoch from now())
        )::text);
        RETURN NEW;
    END IF;
    
    IF TG_OP = 'DELETE' THEN
        PERFORM pg_notify('memo_tag_changes', json_build_object(
            'operation', 'DELETE',
            'table', 'memo_tags',
            'old', row_to_json(OLD),
            'timestamp', extract(epoch from now())
        )::text);
        RETURN OLD;
    END IF;
    
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- Create conflict resolution function
CREATE OR REPLACE FUNCTION resolve_memo_conflict(
    memo_uuid UUID,
    client_version TIMESTAMPTZ,
    new_title VARCHAR(255),
    new_description TEXT,
    user_uuid UUID
)
RETURNS TABLE(
    success BOOLEAN,
    current_version TIMESTAMPTZ,
    conflict_detected BOOLEAN,
    resolved_title VARCHAR(255),
    resolved_description TEXT
) AS $$
DECLARE
    current_memo RECORD;
    version_conflict BOOLEAN := FALSE;
BEGIN
    -- Get current memo state
    SELECT * INTO current_memo FROM memos WHERE id = memo_uuid;
    
    -- Check if memo exists and user has permission
    IF NOT FOUND OR current_memo.user_id != user_uuid THEN
        RETURN QUERY SELECT FALSE, NOW(), FALSE, ''::VARCHAR(255), ''::TEXT;
        RETURN;
    END IF;
    
    -- Check for version conflict
    IF current_memo.updated_at > client_version THEN
        version_conflict := TRUE;
        -- Simple conflict resolution: merge changes with server version taking precedence
        -- You can implement more sophisticated conflict resolution here
        RETURN QUERY SELECT 
            TRUE, 
            current_memo.updated_at, 
            TRUE, 
            current_memo.title, 
            current_memo.description;
    ELSE
        -- No conflict, update normally
        UPDATE memos 
        SET title = new_title, description = new_description, updated_at = NOW()
        WHERE id = memo_uuid;
        
        RETURN QUERY SELECT 
            TRUE, 
            NOW(), 
            FALSE, 
            new_title, 
            new_description;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- Create realtime presence tracking
CREATE TABLE IF NOT EXISTS realtime_presence (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    memo_id UUID REFERENCES memos(id) ON DELETE CASCADE,
    presence_type VARCHAR(50) NOT NULL CHECK (presence_type IN ('editing', 'viewing', 'idle')),
    last_seen TIMESTAMPTZ DEFAULT NOW(),
    session_id TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    
    UNIQUE(user_id, memo_id, session_id)
);

-- Create presence tracking triggers
CREATE TRIGGER update_realtime_presence_updated_at
    BEFORE UPDATE ON realtime_presence
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Create indexes for presence tracking
CREATE INDEX IF NOT EXISTS idx_realtime_presence_memo_id ON realtime_presence(memo_id);
CREATE INDEX IF NOT EXISTS idx_realtime_presence_user_id ON realtime_presence(user_id);
CREATE INDEX IF NOT EXISTS idx_realtime_presence_last_seen ON realtime_presence(last_seen);
CREATE INDEX IF NOT EXISTS idx_realtime_presence_session_id ON realtime_presence(session_id);

-- Create triggers for realtime broadcasting
CREATE TRIGGER memo_changes_trigger
    AFTER INSERT OR UPDATE OR DELETE ON memos
    FOR EACH ROW
    EXECUTE FUNCTION broadcast_memo_changes();

CREATE TRIGGER tag_changes_trigger
    AFTER INSERT OR UPDATE OR DELETE ON tags
    FOR EACH ROW
    EXECUTE FUNCTION broadcast_tag_changes();

CREATE TRIGGER memo_tag_changes_trigger
    AFTER INSERT OR DELETE ON memo_tags
    FOR EACH ROW
    EXECUTE FUNCTION broadcast_memo_tag_changes();

-- Create presence management functions
CREATE OR REPLACE FUNCTION update_user_presence(
    user_uuid UUID,
    memo_uuid UUID,
    presence_state VARCHAR(50),
    session_uuid TEXT
)
RETURNS BOOLEAN AS $$
BEGIN
    INSERT INTO realtime_presence (user_id, memo_id, presence_type, session_id, last_seen)
    VALUES (user_uuid, memo_uuid, presence_state, session_uuid, NOW())
    ON CONFLICT (user_id, memo_id, session_id)
    DO UPDATE SET 
        presence_type = EXCLUDED.presence_type,
        last_seen = NOW(),
        updated_at = NOW();
    
    RETURN TRUE;
EXCEPTION
    WHEN OTHERS THEN
        RETURN FALSE;
END;
$$ LANGUAGE plpgsql;

-- Create function to clean up stale presence records
CREATE OR REPLACE FUNCTION cleanup_stale_presence()
RETURNS INTEGER AS $$
DECLARE
    deleted_count INTEGER;
BEGIN
    -- Delete presence records older than 5 minutes
    DELETE FROM realtime_presence 
    WHERE last_seen < NOW() - INTERVAL '5 minutes';
    
    GET DIAGNOSTICS deleted_count = ROW_COUNT;
    RETURN deleted_count;
END;
$$ LANGUAGE plpgsql;

-- Create function to get active editors for a memo
CREATE OR REPLACE FUNCTION get_active_editors(memo_uuid UUID)
RETURNS TABLE(
    user_id UUID,
    user_name VARCHAR(50),
    user_email VARCHAR(255),
    presence_type VARCHAR(50),
    last_seen TIMESTAMPTZ
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        p.id,
        p.name,
        p.email,
        rp.presence_type,
        rp.last_seen
    FROM realtime_presence rp
    JOIN profiles p ON rp.user_id = p.id
    WHERE rp.memo_id = memo_uuid
    AND rp.last_seen > NOW() - INTERVAL '2 minutes'
    ORDER BY rp.last_seen DESC;
END;
$$ LANGUAGE plpgsql;

-- Add comments for documentation
COMMENT ON FUNCTION broadcast_memo_changes IS 'Broadcasts memo changes via pg_notify for realtime subscriptions';
COMMENT ON FUNCTION broadcast_tag_changes IS 'Broadcasts tag changes via pg_notify for realtime subscriptions';
COMMENT ON FUNCTION broadcast_memo_tag_changes IS 'Broadcasts memo-tag association changes via pg_notify for realtime subscriptions';
COMMENT ON FUNCTION resolve_memo_conflict IS 'Resolves conflicts when multiple users edit the same memo';
COMMENT ON FUNCTION update_user_presence IS 'Updates or creates user presence record for realtime collaboration';
COMMENT ON FUNCTION cleanup_stale_presence IS 'Removes stale presence records for cleanup';
COMMENT ON FUNCTION get_active_editors IS 'Returns list of users currently editing a memo';
COMMENT ON TABLE realtime_presence IS 'Tracks user presence for realtime collaboration features'; 
