CREATE TABLE IF NOT EXISTS users (
    uuid            UUID PRIMARY KEY,
    name            VARCHAR(100) NOT NULL,
    username        VARCHAR(50) NOT NULL UNIQUE,
    email           VARCHAR(255) NOT NULL UNIQUE,
    phone_number    VARCHAR(20) NOT NULL UNIQUE,
    hashed_password TEXT NOT NULL,
    scam_detection  BOOLEAN NOT NULL DEFAULT FALSE,
    created_at      TIMESTAMP DEFAULT NOW(),
    updated_at      TIMESTAMP DEFAULT NOW()
);
-- 2. Create the function to automatically lowercase the username
-- This function will be called by the trigger before insert/update
CREATE OR REPLACE FUNCTION set_username_lowercase()
RETURNS TRIGGER AS $$
BEGIN
    NEW.username = LOWER(NEW.username); -- Convert to lowercase
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 3. Create the trigger that uses the above function
-- This trigger fires BEFORE ANY INSERT OR UPDATE operation
CREATE TRIGGER enforce_lowercase_username
BEFORE INSERT OR UPDATE ON users
FOR EACH ROW
EXECUTE FUNCTION set_username_lowercase();

-- 4. Adjust the CHECK constraint
-- Drop the old constraint if it exists, then add the new one.
-- The 'username = lower(username)' part is removed from CHECK,
-- as the trigger now handles the lowercasing. The CHECK
-- constraint only needs to validate the allowed characters.
ALTER TABLE users
DROP CONSTRAINT IF EXISTS chk_username_format; -- Drop if it was defined previously

ALTER TABLE users
ADD CONSTRAINT chk_username_format
CHECK (username ~ '^[a-z0-9._]+$');

CREATE OR REPLACE FUNCTION trim_name_field()
RETURNS TRIGGER AS $$
BEGIN
    NEW.name = TRIM(NEW.name);  -- Remove leading/trailing whitespace
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trim_name_before_write
BEFORE INSERT OR UPDATE ON users
FOR EACH ROW
EXECUTE FUNCTION trim_name_field();

-- Insert dummy users
INSERT INTO users (uuid, name, username, email, phone_number, hashed_password, scam_detection)
VALUES
  ('11111111-1111-1111-1111-111111111111', 'Alice Cheng', 'alice', 'user1@example.com', '0911000001', '$2b$12$WDpsRtYLL8H9kFhMuGKPYefAJLuFX2a1g2zwSz1cFQKj1DZjank4K', TRUE), -- passAlice1
  ('22222222-2222-2222-2222-222222222222', 'Bob Smith', 'bob', 'user2@example.com', '0911000002', '$2b$12$lIrcY2ZqtaA8236n/tWemeAufOZe9wuitYEF8Xa70UMqgUl/d/4S', TRUE), -- passBob1

  ('4ac10511-9f94-4bda-be08-cadc46018b8d', 'Test', 'test', 'test@example.com', '0911000003', '$2b$12$t74LBr5mlJfvptNrju4m1eNGfLMIMxl9rZlaRp/5LUXkUH/pIUo9S', FALSE) -- test
ON CONFLICT (username) DO NOTHING;  -- prevent duplicate entries 
