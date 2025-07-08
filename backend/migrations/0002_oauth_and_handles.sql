-- Add OAuth and handle support to existing schema

-- Add OAuth columns to accounts table
ALTER TABLE accounts ADD COLUMN oauth_provider TEXT;
ALTER TABLE accounts ADD COLUMN oauth_id TEXT;
ALTER TABLE accounts ADD COLUMN handle TEXT UNIQUE;
ALTER TABLE accounts ADD COLUMN avatar_url TEXT;
ALTER TABLE accounts ADD COLUMN is_verified INTEGER DEFAULT 0;

-- Create OAuth tokens table for storing refresh tokens
CREATE TABLE oauth_tokens (
    id TEXT PRIMARY KEY,
    account_id TEXT NOT NULL,
    provider TEXT NOT NULL,
    access_token TEXT,
    refresh_token TEXT,
    expires_at INTEGER,
    scope TEXT,
    created_at INTEGER NOT NULL DEFAULT (unixepoch()),
    updated_at INTEGER NOT NULL DEFAULT (unixepoch()),
    FOREIGN KEY (account_id) REFERENCES accounts (id) ON DELETE CASCADE,
    UNIQUE(account_id, provider)
);

-- Create sessions table for managing login sessions
CREATE TABLE sessions (
    id TEXT PRIMARY KEY,
    account_id TEXT NOT NULL,
    session_token TEXT UNIQUE NOT NULL,
    expires_at INTEGER NOT NULL,
    created_at INTEGER NOT NULL DEFAULT (unixepoch()),
    last_used_at INTEGER DEFAULT (unixepoch()),
    user_agent TEXT,
    ip_address TEXT,
    FOREIGN KEY (account_id) REFERENCES accounts (id) ON DELETE CASCADE
);

-- Add indexes for OAuth and sessions
CREATE INDEX idx_accounts_oauth ON accounts (oauth_provider, oauth_id);
CREATE INDEX idx_accounts_handle ON accounts (handle);
CREATE INDEX idx_oauth_tokens_account ON oauth_tokens (account_id);
CREATE INDEX idx_sessions_token ON sessions (session_token);
CREATE INDEX idx_sessions_account ON sessions (account_id);
CREATE INDEX idx_sessions_expires ON sessions (expires_at);

-- Update existing accounts to have handles based on username
UPDATE accounts SET handle = username WHERE handle IS NULL;