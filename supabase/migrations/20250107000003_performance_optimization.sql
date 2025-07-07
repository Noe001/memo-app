-- Performance optimization for Supabase database
-- This migration adds additional indexes, monitoring, and performance enhancements

-- ===========================================
-- ADDITIONAL PERFORMANCE INDEXES
-- ===========================================

-- Composite index for memo search with user filtering
CREATE INDEX IF NOT EXISTS idx_memos_user_visibility_updated 
ON memos(user_id, visibility, updated_at DESC)
WHERE visibility IN (0, 1);

-- Partial index for public memos only
CREATE INDEX IF NOT EXISTS idx_memos_public_updated 
ON memos(updated_at DESC, user_id)
WHERE visibility = 1;

-- Composite index for tag popularity analysis
CREATE INDEX IF NOT EXISTS idx_memo_tags_tag_created 
ON memo_tags(tag_id, created_at DESC);

-- Index for session cleanup
CREATE INDEX IF NOT EXISTS idx_sessions_expires_cleanup 
ON sessions(expires_at)
WHERE expires_at < NOW() + INTERVAL '7 days';

-- Profile email search optimization
CREATE INDEX IF NOT EXISTS idx_profiles_email_trgm 
ON profiles USING gin(email gin_trgm_ops);

-- ===========================================
-- MATERIALIZED VIEWS FOR ANALYTICS
-- ===========================================

-- Memo statistics per user
CREATE MATERIALIZED VIEW IF NOT EXISTS user_memo_stats AS
SELECT 
    p.id as user_id,
    p.name as user_name,
    p.email as user_email,
    COUNT(m.id) as total_memos,
    COUNT(CASE WHEN m.visibility = 0 THEN 1 END) as private_memos,
    COUNT(CASE WHEN m.visibility = 1 THEN 1 END) as public_memos,
    COUNT(CASE WHEN m.visibility = 2 THEN 1 END) as shared_memos,
    COUNT(DISTINCT mt.tag_id) as unique_tags_used,
    MAX(m.updated_at) as last_memo_updated,
    MIN(m.created_at) as first_memo_created
FROM profiles p
LEFT JOIN memos m ON p.id = m.user_id
LEFT JOIN memo_tags mt ON m.id = mt.memo_id
GROUP BY p.id, p.name, p.email;

-- Tag popularity statistics
CREATE MATERIALIZED VIEW IF NOT EXISTS tag_popularity_stats AS
SELECT 
    t.id as tag_id,
    t.name as tag_name,
    t.color as tag_color,
    COUNT(mt.memo_id) as usage_count,
    COUNT(DISTINCT m.user_id) as unique_users,
    COUNT(CASE WHEN m.visibility = 1 THEN 1 END) as public_usage,
    MAX(mt.created_at) as last_used,
    MIN(mt.created_at) as first_used
FROM tags t
LEFT JOIN memo_tags mt ON t.id = mt.tag_id
LEFT JOIN memos m ON mt.memo_id = m.id
GROUP BY t.id, t.name, t.color;

-- Create indexes on materialized views
CREATE INDEX IF NOT EXISTS idx_user_memo_stats_user_id ON user_memo_stats(user_id);
CREATE INDEX IF NOT EXISTS idx_user_memo_stats_total_memos ON user_memo_stats(total_memos DESC);
CREATE INDEX IF NOT EXISTS idx_tag_popularity_usage ON tag_popularity_stats(usage_count DESC);
CREATE INDEX IF NOT EXISTS idx_tag_popularity_users ON tag_popularity_stats(unique_users DESC);

-- ===========================================
-- PERFORMANCE MONITORING FUNCTIONS
-- ===========================================

-- Function to refresh materialized views
CREATE OR REPLACE FUNCTION refresh_analytics_views()
RETURNS VOID AS $$
BEGIN
    REFRESH MATERIALIZED VIEW user_memo_stats;
    REFRESH MATERIALIZED VIEW tag_popularity_stats;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get database performance stats
CREATE OR REPLACE FUNCTION get_database_stats()
RETURNS TABLE(
    table_name TEXT,
    row_count BIGINT,
    table_size TEXT,
    index_size TEXT,
    total_size TEXT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        schemaname||'.'||tablename as table_name,
        n_tup_ins + n_tup_upd + n_tup_del as row_count,
        pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) as table_size,
        pg_size_pretty(pg_indexes_size(schemaname||'.'||tablename)) as index_size,
        pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename) + pg_indexes_size(schemaname||'.'||tablename)) as total_size
    FROM pg_stat_user_tables 
    WHERE schemaname = 'public'
    ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to analyze query performance
CREATE OR REPLACE FUNCTION analyze_slow_queries()
RETURNS TABLE(
    query_text TEXT,
    calls BIGINT,
    total_time DOUBLE PRECISION,
    mean_time DOUBLE PRECISION,
    stddev_time DOUBLE PRECISION
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        substr(query, 1, 100) as query_text,
        calls,
        total_exec_time as total_time,
        mean_exec_time as mean_time,
        stddev_exec_time as stddev_time
    FROM pg_stat_statements 
    WHERE query NOT LIKE '%pg_stat_statements%'
    ORDER BY total_exec_time DESC
    LIMIT 10;
EXCEPTION
    WHEN undefined_table THEN
        RAISE NOTICE 'pg_stat_statements extension not available';
        RETURN;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ===========================================
-- MAINTENANCE FUNCTIONS
-- ===========================================

-- Function to cleanup old sessions
CREATE OR REPLACE FUNCTION cleanup_old_sessions()
RETURNS INTEGER AS $$
DECLARE
    deleted_count INTEGER;
BEGIN
    DELETE FROM sessions 
    WHERE expires_at < NOW() - INTERVAL '7 days';
    
    GET DIAGNOSTICS deleted_count = ROW_COUNT;
    
    -- Log the cleanup
    INSERT INTO maintenance_log (action, details, created_at)
    VALUES ('session_cleanup', 'Deleted ' || deleted_count || ' expired sessions', NOW());
    
    RETURN deleted_count;
EXCEPTION
    WHEN undefined_table THEN
        -- If maintenance_log doesn't exist, just return count
        RETURN deleted_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to update table statistics
CREATE OR REPLACE FUNCTION update_table_statistics()
RETURNS VOID AS $$
BEGIN
    -- Update statistics for all tables
    ANALYZE profiles;
    ANALYZE memos;
    ANALYZE tags;
    ANALYZE memo_tags;
    ANALYZE sessions;
    
    -- Refresh materialized views
    PERFORM refresh_analytics_views();
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ===========================================
-- MONITORING TABLE (OPTIONAL)
-- ===========================================

-- Create maintenance log table for tracking operations
CREATE TABLE IF NOT EXISTS maintenance_log (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    action VARCHAR(50) NOT NULL,
    details TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create index for maintenance log
CREATE INDEX IF NOT EXISTS idx_maintenance_log_created_at ON maintenance_log(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_maintenance_log_action ON maintenance_log(action);

-- ===========================================
-- SCHEDULED MAINTENANCE (CRON JOBS)
-- ===========================================

-- Note: In Supabase, you would set up these as scheduled functions
-- or use external cron jobs to call these functions

-- Example scheduled maintenance script (to be run daily):
-- SELECT cleanup_old_sessions();
-- SELECT update_table_statistics();

-- ===========================================
-- QUERY OPTIMIZATION VIEWS
-- ===========================================

-- View for popular memo content analysis
CREATE OR REPLACE VIEW popular_memo_content AS
SELECT 
    m.id,
    m.title,
    m.description,
    m.visibility,
    m.created_at,
    m.updated_at,
    p.name as author_name,
    array_agg(t.name) as tag_names,
    COUNT(mt.tag_id) as tag_count
FROM memos m
JOIN profiles p ON m.user_id = p.id
LEFT JOIN memo_tags mt ON m.id = mt.memo_id
LEFT JOIN tags t ON mt.tag_id = t.id
WHERE m.visibility = 1  -- Only public memos
GROUP BY m.id, m.title, m.description, m.visibility, m.created_at, m.updated_at, p.name
ORDER BY m.updated_at DESC;

-- View for user activity summary
CREATE OR REPLACE VIEW user_activity_summary AS
SELECT 
    p.id as user_id,
    p.name,
    p.email,
    p.theme,
    ums.total_memos,
    ums.private_memos,
    ums.public_memos,
    ums.unique_tags_used,
    ums.last_memo_updated,
    CASE 
        WHEN ums.last_memo_updated > NOW() - INTERVAL '1 day' THEN 'Active'
        WHEN ums.last_memo_updated > NOW() - INTERVAL '7 days' THEN 'Recent'
        WHEN ums.last_memo_updated > NOW() - INTERVAL '30 days' THEN 'Inactive'
        ELSE 'Dormant'
    END as activity_status
FROM profiles p
LEFT JOIN user_memo_stats ums ON p.id = ums.user_id;

-- ===========================================
-- PERFORMANCE TESTING FUNCTIONS
-- ===========================================

-- Function to test search performance
CREATE OR REPLACE FUNCTION test_search_performance(search_term TEXT)
RETURNS TABLE(
    method TEXT,
    result_count BIGINT,
    execution_time INTERVAL
) AS $$
DECLARE
    start_time TIMESTAMP;
    end_time TIMESTAMP;
    count_result BIGINT;
BEGIN
    -- Test 1: Full-text search
    start_time := clock_timestamp();
    SELECT COUNT(*) INTO count_result
    FROM memos 
    WHERE to_tsvector('japanese', COALESCE(title, '') || ' ' || COALESCE(description, ''))
    @@ plainto_tsquery('japanese', search_term);
    end_time := clock_timestamp();
    
    RETURN QUERY SELECT 'Full-text search'::TEXT, count_result, (end_time - start_time);
    
    -- Test 2: Trigram search
    start_time := clock_timestamp();
    SELECT COUNT(*) INTO count_result
    FROM memos 
    WHERE title % search_term OR description % search_term;
    end_time := clock_timestamp();
    
    RETURN QUERY SELECT 'Trigram search'::TEXT, count_result, (end_time - start_time);
    
    -- Test 3: LIKE search
    start_time := clock_timestamp();
    SELECT COUNT(*) INTO count_result
    FROM memos 
    WHERE LOWER(title) LIKE '%' || LOWER(search_term) || '%' 
    OR LOWER(description) LIKE '%' || LOWER(search_term) || '%';
    end_time := clock_timestamp();
    
    RETURN QUERY SELECT 'LIKE search'::TEXT, count_result, (end_time - start_time);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ===========================================
-- GRANTS AND PERMISSIONS
-- ===========================================

-- Grant permissions for analytics functions
GRANT EXECUTE ON FUNCTION refresh_analytics_views TO service_role;
GRANT EXECUTE ON FUNCTION get_database_stats TO service_role;
GRANT EXECUTE ON FUNCTION analyze_slow_queries TO service_role;
GRANT EXECUTE ON FUNCTION cleanup_old_sessions TO service_role;
GRANT EXECUTE ON FUNCTION update_table_statistics TO service_role;
GRANT EXECUTE ON FUNCTION test_search_performance TO service_role;

-- Grant SELECT permissions on materialized views
GRANT SELECT ON user_memo_stats TO authenticated;
GRANT SELECT ON tag_popularity_stats TO authenticated;

-- Grant SELECT permissions on performance views
GRANT SELECT ON popular_memo_content TO authenticated;
GRANT SELECT ON user_activity_summary TO authenticated;

-- ===========================================
-- COMMENTS FOR DOCUMENTATION
-- ===========================================

COMMENT ON MATERIALIZED VIEW user_memo_stats IS 'Aggregated statistics for user memo activity';
COMMENT ON MATERIALIZED VIEW tag_popularity_stats IS 'Statistics for tag usage and popularity';
COMMENT ON FUNCTION refresh_analytics_views IS 'Refresh all materialized views for analytics';
COMMENT ON FUNCTION get_database_stats IS 'Get database size and performance statistics';
COMMENT ON FUNCTION cleanup_old_sessions IS 'Remove expired sessions older than 7 days';
COMMENT ON FUNCTION update_table_statistics IS 'Update table statistics and refresh analytics';
COMMENT ON FUNCTION test_search_performance IS 'Test and compare different search methods performance'; 
