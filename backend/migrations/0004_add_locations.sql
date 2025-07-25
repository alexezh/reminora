-- Add locations field to photos table for storing LocationInfo array as JSON

-- Add locations column to photos table
ALTER TABLE photos ADD COLUMN locations TEXT;

-- Add index for locations data (for potential future JSON queries)
-- Note: D1 SQLite supports basic JSON operations but indexing may be limited
-- CREATE INDEX idx_photos_locations ON photos (json_extract(locations, '$'));