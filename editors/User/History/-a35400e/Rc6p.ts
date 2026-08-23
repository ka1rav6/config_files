import type { VisitRecord, ResearchSession, UserSettings } from "../types";

const DB_NAME = "wayfinder";
const DB_VERSION = 1;

const STORES = {
  visits: "visits",
  sessions: "sessions",
  settings: "settings",
} as const;

let dbPromise: Promise<IDBDatabase> | null = null;

function openDb(): Promise<IDBDatabase> {
  if (dbPromise) return dbPromise;

  dbPromise = new Promise((resolve, reject) => {
    const req = indexedDB.open(DB_NAME, DB_VERSION);

    req.onupgradeneeded = () => {
      const db = req.result;

      if (!db.objectStoreNames.contains(STORES.visits)) {
        const visits = db.createObjectStore(STORES.visits, { keyPath: "id" });
        visits.createIndex("byDomain", "domain");
        visits.createIndex("byVisitTime", "visitTime");
          visits.createIndex("byCategory", "category");
          visits.createIndex("bySessionId", "sessionId");
      }

      if (!db.objectStoreNames.contains(STORES.sessions)) {
        const sessions = db.createObjectStore(STORES.sessions, { keyPath: "id" });
        sessions.createIndex("bySaved", "saved");
      }

      if (!db.objectStoreNames.contains(STORES.settings)) {
        db.createObjectStore(STORES.settings, { keyPath: "key" });
      }
    };

    req.onsuccess = () => resolve(req.result);
    req.onerror = () => reject(req.error);
  });

  return dbPromise;
}

async function withStore<T>(
  storeName: string,
  mode: IDBTransactionMode,
  fn: (store: IDBObjectStore) => Promise<T> | T
): Promise<T> {
  const db = await openDb();
  return new Promise<T>((resolve, reject) => {
    const tx = db.transaction(storeName, mode);
    const store = tx.objectStore(storeName);
    Promise.resolve(fn(store)).then(resolve, reject);
    tx.onerror = () => reject(tx.error);
  });
}

// ---- Visits ----

export async function saveVisit(visit: VisitRecord): Promise<void> {
  await withStore(STORES.visits, "readwrite", (store) => {
    store.put(visit);
  });
}

export async function getAllVisits(): Promise<VisitRecord[]> {
  return withStore(STORES.visits, "readonly", (store) => {
    return new Promise((resolve, reject) => {
      const req = store.getAll();
      req.onsuccess = () => resolve(req.result as VisitRecord[]);
      req.onerror = () => reject(req.error);
    });
  });
}

export async function deleteVisitsOlderThan(epochMs: number): Promise<number> {
  return withStore(STORES.visits, "readwrite", (store) => {
    return new Promise((resolve, reject) => {
      const index = store.index("byVisitTime");
      const range = IDBKeyRange.upperBound(epochMs);
      let deleted = 0;
      const cursorReq = index.openCursor(range);
      cursorReq.onsuccess = () => {
        const cursor = cursorReq.result;
        if (cursor) {
          cursor.delete();
          deleted++;
          cursor.continue();
        } else {
          resolve(deleted);
        }
      };
      cursorReq.onerror = () => reject(cursorReq.error);
    });
  });
}

// ---- Sessions ----

export async function saveSession(session: ResearchSession): Promise<void> {
  await withStore(STORES.sessions, "readwrite", (store) => {
    store.put(session);
  });
}

export async function getAllSessions(): Promise<ResearchSession[]> {
  return withStore(STORES.sessions, "readonly", (store) => {
    return new Promise((resolve, reject) => {
      const req = store.getAll();
      req.onsuccess = () => resolve(req.result as ResearchSession[]);
      req.onerror = () => reject(req.error);
    });
  });
}

// ---- Settings ----

const DEFAULT_SETTINGS: UserSettings = {
  tier: "free",
  theme: "midnight",
  suggestionsEnabled: true,
  historyRetentionDays: 90,
};

export async function getSettings(): Promise<UserSettings> {
  return withStore(STORES.settings, "readonly", (store) => {
    return new Promise((resolve, reject) => {
      const req = store.get("settings");
      req.onsuccess = () => resolve(req.result?.value ?? DEFAULT_SETTINGS);
      req.onerror = () => reject(req.error);
    });
  });
}

export async function saveSettings(settings: UserSettings): Promise<void> {
  await withStore(STORES.settings, "readwrite", (store) => {
    store.put({ key: "settings", value: settings });
  });
}
