-- Create accounts table
CREATE TABLE accounts (
    id TEXT PRIMARY KEY,
    username TEXT UNIQUE NOT NULL,
    email TEXT UNIQUE NOT NULL,
    display_name TEXT,
    bio TEXT,
    created_at INTEGER NOT NULL DEFAULT (unixepoch()),
    updated_at INTEGER NOT NULL DEFAULT (unixepoch())
);

-- Create photos table for storing photo metadata and JSON data
CREATE TABLE photos (
    id TEXT PRIMARY KEY,
    account_id TEXT NOT NULL,
    photo_data TEXT NOT NULL, -- JSON blob containing photo info
    latitude REAL,
    longitude REAL,
    location_name TEXT,
    caption TEXT,
    created_at INTEGER NOT NULL DEFAULT (unixepoch()),
    updated_at INTEGER NOT NULL DEFAULT (unixepoch()),
    FOREIGN KEY (account_id) REFERENCES accounts (id) ON DELETE CASCADE
);

-- Create follows table for social connections
CREATE TABLE follows (
    id TEXT PRIMARY KEY,
    follower_id TEXT NOT NULL,
    following_id TEXT NOT NULL,
    created_at INTEGER NOT NULL DEFAULT (unixepoch()),
    FOREIGN KEY (follower_id) REFERENCES accounts (id) ON DELETE CASCADE,
    FOREIGN KEY (following_id) REFERENCES accounts (id) ON DELETE CASCADE,
    UNIQUE(follower_id, following_id)
);

-- Create photo_timeline table for efficient querying
CREATE TABLE photo_timeline (
    id TEXT PRIMARY KEY,
    photo_id TEXT NOT NULL,
    account_id TEXT NOT NULL, -- account who posted the photo
    visible_to_account_id TEXT NOT NULL, -- account who can see this photo (follower)
    created_at INTEGER NOT NULL DEFAULT (unixepoch()),
    FOREIGN KEY (photo_id) REFERENCES photos (id) ON DELETE CASCADE,
    FOREIGN KEY (account_id) REFERENCES accounts (id) ON DELETE CASCADE,
    FOREIGN KEY (visible_to_account_id) REFERENCES accounts (id) ON DELETE CASCADE
);

-- Indexes for performance
CREATE INDEX idx_photos_account_id ON photos (account_id);
CREATE INDEX idx_photos_created_at ON photos (created_at);
CREATE INDEX idx_photos_location ON photos (latitude, longitude);
CREATE INDEX idx_follows_follower ON follows (follower_id);
CREATE INDEX idx_follows_following ON follows (following_id);
CREATE INDEX idx_timeline_visible_to ON photo_timeline (visible_to_account_id, created_at);
CREATE INDEX idx_timeline_account ON photo_timeline (account_id, created_at);