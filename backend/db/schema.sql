CREATE TABLE IF NOT EXISTS licenses (
  id             SERIAL PRIMARY KEY,
  license_key    VARCHAR(40) UNIQUE NOT NULL,
  role           VARCHAR(10) NOT NULL DEFAULT 'user',
  duration_hours INT,
  expires_at     TIMESTAMPTZ,
  hwid           VARCHAR(128),
  banned         BOOLEAN NOT NULL DEFAULT FALSE,
  note           VARCHAR(255),
  created_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  activated_at   TIMESTAMPTZ,
  last_used_at   TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_licenses_key ON licenses (license_key);
CREATE INDEX IF NOT EXISTS idx_licenses_hwid ON licenses (hwid);
