-- 同步会话表 - 记录每次同步会话的基本信息
CREATE TABLE IF NOT EXISTS SyncSessions (
    id TEXT PRIMARY KEY,
    deviceId TEXT NOT NULL,
    userName TEXT,
    startTimestamp TEXT NOT NULL,
    endTimestamp TEXT,
    status TEXT NOT NULL, -- 'in_progress', 'completed', 'failed', 'cancelled'
    deviceInfo TEXT
);

-- 同步操作表 - 记录同步过程中的各种操作
CREATE TABLE IF NOT EXISTS SyncOperations (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    syncId TEXT NOT NULL,
    operation TEXT NOT NULL, -- 'database', 'file', etc.
    status TEXT NOT NULL, -- 'started', 'in_progress', 'completed', 'failed'
    details TEXT, -- JSON格式的详细信息
    timestamp TEXT NOT NULL,
    FOREIGN KEY (syncId) REFERENCES SyncSessions(id)
);

-- 同步日志表 - 记录所有同步相关的日志
CREATE TABLE IF NOT EXISTS SyncLogs (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    timestamp TEXT NOT NULL,
    operation TEXT NOT NULL,
    status TEXT NOT NULL,
    details TEXT -- JSON格式的详细信息
);

-- 修改Photos表以支持同步
ALTER TABLE Photos ADD COLUMN syncId TEXT;
ALTER TABLE Photos ADD COLUMN syncTimestamp TEXT;
ALTER TABLE Photos ADD COLUMN modifiedTimestamp TEXT;
ALTER TABLE Photos ADD COLUMN deviceId TEXT;