-- Add comments table for user interactions

-- Create comments table
CREATE TABLE comments (
    id TEXT PRIMARY KEY,
    from_user_id TEXT NOT NULL,
    to_user_id TEXT,
    target_photo_id TEXT,
    comment_text TEXT NOT NULL,
    type TEXT NOT NULL DEFAULT 'comment', -- 'comment', 'reaction', 'like'
    is_reaction INTEGER DEFAULT 0,
    created_at INTEGER NOT NULL DEFAULT (unixepoch()),
    updated_at INTEGER NOT NULL DEFAULT (unixepoch()),
    FOREIGN KEY (from_user_id) REFERENCES accounts (id) ON DELETE CASCADE,
    FOREIGN KEY (to_user_id) REFERENCES accounts (id) ON DELETE CASCADE,
    FOREIGN KEY (target_photo_id) REFERENCES photos (id) ON DELETE CASCADE
);

-- Add indexes for comments
CREATE INDEX idx_comments_from_user ON comments (from_user_id, created_at);
CREATE INDEX idx_comments_to_user ON comments (to_user_id, created_at);
CREATE INDEX idx_comments_photo ON comments (target_photo_id, created_at);
CREATE INDEX idx_comments_type ON comments (type, created_at);

-- Add notification/interaction tracking
CREATE TABLE comment_threads (
    id TEXT PRIMARY KEY,
    target_photo_id TEXT,
    target_user_id TEXT,
    participants TEXT, -- JSON array of user IDs
    last_activity_at INTEGER NOT NULL DEFAULT (unixepoch()),
    comment_count INTEGER DEFAULT 0,
    created_at INTEGER NOT NULL DEFAULT (unixepoch()),
    FOREIGN KEY (target_photo_id) REFERENCES photos (id) ON DELETE CASCADE,
    FOREIGN KEY (target_user_id) REFERENCES accounts (id) ON DELETE CASCADE
);

CREATE INDEX idx_comment_threads_photo ON comment_threads (target_photo_id);
CREATE INDEX idx_comment_threads_user ON comment_threads (target_user_id, last_activity_at);