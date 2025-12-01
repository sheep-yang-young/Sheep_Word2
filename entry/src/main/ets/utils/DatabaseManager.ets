import { relationalStore, ValuesBucket } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { Word, DashboardStats } from '../model/WordModel';

const DB_NAME = 'Lumina_V2.db';

export class DatabaseManager {
  private static instance: DatabaseManager;
  private rdbStore: relationalStore.RdbStore | null = null;
  private context: common.Context | null = null;

  private constructor() {}

  public static getInstance(): DatabaseManager {
    if (!DatabaseManager.instance) {
      DatabaseManager.instance = new DatabaseManager();
    }
    return DatabaseManager.instance;
  }

  async init(context: common.Context): Promise<void> {
    this.context = context;
    if (this.rdbStore) return;
    try {
      this.rdbStore = await relationalStore.getRdbStore(context, {
        name: DB_NAME,
        securityLevel: relationalStore.SecurityLevel.S1
      });

      const store = this.rdbStore;
      if (store) {
        await store.executeSql(`
          CREATE TABLE IF NOT EXISTS words (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            spelling TEXT NOT NULL,
            phonetic TEXT,
            meaning TEXT,
            example TEXT,
            proficiency INTEGER DEFAULT 0,
            repetition INTEGER DEFAULT 0,
            interval INTEGER DEFAULT 0,
            easeFactor REAL DEFAULT 2.5,
            lastReviewTime INTEGER DEFAULT 0,
            nextReviewTime INTEGER DEFAULT 0
          )
        `);
      }
    } catch (err) {
      console.error(`[Lumina] DB Init failed: ${JSON.stringify(err)}`);
    }
  }

  // [新增] 删除单个单词
  async deleteWord(id: number): Promise<void> {
    const store = this.rdbStore;
    if (!store) return;
    try {
      const predicates = new relationalStore.RdbPredicates('words');
      predicates.equalTo('id', id);
      await store.delete(predicates);
      console.info(`[Lumina] Deleted word id: ${id}`);
    } catch (e) {
      console.error(`[Lumina] Delete failed: ${e}`);
    }
  }

  async getTodayReviewWords(limit: number = 20): Promise<Word[]> {
    if (!this.rdbStore) return [];
    try {
      const now = Date.now();
      const predicates = new relationalStore.RdbPredicates('words');
      predicates.lessThanOrEqualTo('nextReviewTime', now)
        .orderByAsc('nextReviewTime')
        .limitAs(limit);
      const resultSet = await this.rdbStore.query(predicates);
      const words: Word[] = [];
      while (resultSet.goToNextRow()) {
        words.push(this.mapRowToWord(resultSet));
      }
      resultSet.close();
      return words;
    } catch (err) { return []; }
  }

  async getDashboardStats(): Promise<DashboardStats> {
    let stats = new DashboardStats();
    if (!this.rdbStore) return stats;
    try {
      const now = Date.now();
      const todayStart = new Date();
      todayStart.setHours(0, 0, 0, 0);
      const todayStartTs = todayStart.getTime();

      const dueRes = await this.rdbStore.querySql('SELECT count(*) FROM words WHERE nextReviewTime <= ?', [now]);
      if (dueRes.goToFirstRow()) stats.due = dueRes.getLong(0);
      dueRes.close();

      const learnedRes = await this.rdbStore.querySql('SELECT count(*) FROM words WHERE lastReviewTime >= ?', [todayStartTs]);
      if (learnedRes.goToFirstRow()) stats.learnedToday = learnedRes.getLong(0);
      learnedRes.close();

      const totalRes = await this.rdbStore.querySql('SELECT count(*) FROM words');
      if (totalRes.goToFirstRow()) stats.total = totalRes.getLong(0);
      totalRes.close();

      const masterRes = await this.rdbStore.querySql('SELECT count(*) FROM words WHERE interval > 21');
      if (masterRes.goToFirstRow()) stats.mastered = masterRes.getLong(0);
      masterRes.close();

      return stats;
    } catch (e) { return stats; }
  }

  async getProficiencyDistribution(): Promise<number[]> {
    const store = this.rdbStore;
    if (!store) return [0,0,0,0,0];
    try {
      const resultSet = await store.querySql('SELECT proficiency FROM words');
      const stats = [0, 0, 0, 0, 0];
      while (resultSet.goToNextRow()) {
        const p = resultSet.getLong(0);
        if (p <= 20) stats[0]++;
        else if (p <= 40) stats[1]++;
        else if (p <= 60) stats[2]++;
        else if (p <= 80) stats[3]++;
        else stats[4]++;
      }
      resultSet.close();
      return stats;
    } catch (e) { return [0,0,0,0,0]; }
  }

  private mapRowToWord(resultSet: relationalStore.ResultSet): Word {
    return {
      id: resultSet.getLong(resultSet.getColumnIndex('id')),
      spelling: resultSet.getString(resultSet.getColumnIndex('spelling')),
      phonetic: resultSet.getString(resultSet.getColumnIndex('phonetic')),
      meaning: resultSet.getString(resultSet.getColumnIndex('meaning')),
      example: resultSet.getString(resultSet.getColumnIndex('example')),
      proficiency: resultSet.getLong(resultSet.getColumnIndex('proficiency')),
      repetition: resultSet.getLong(resultSet.getColumnIndex('repetition')),
      interval: resultSet.getLong(resultSet.getColumnIndex('interval')),
      easeFactor: resultSet.getDouble(resultSet.getColumnIndex('easeFactor')),
      lastReviewTime: resultSet.getLong(resultSet.getColumnIndex('lastReviewTime')),
      nextReviewTime: resultSet.getLong(resultSet.getColumnIndex('nextReviewTime'))
    };
  }

  async updateWordStats(id: number, interval: number, repetition: number, easeFactor: number): Promise<void> {
    const store = this.rdbStore;
    if (!store) return;
    const now = Date.now();
    const nextTime = now + (interval * 24 * 60 * 60 * 1000);
    const val: ValuesBucket = {
      interval: interval,
      repetition: repetition,
      easeFactor: easeFactor,
      lastReviewTime: now,
      nextReviewTime: nextTime,
      proficiency: Math.min(100, repetition * 10)
    };
    const pred = new relationalStore.RdbPredicates('words');
    pred.equalTo('id', id);
    await store.update(val, pred);
  }

  async batchInsertWords(words: Word[]): Promise<number> {
    const store = this.rdbStore;
    if (!store) return 0;
    let count = 0;
    try {
      const existingSpells = new Set<string>();
      const resultSet = await store.querySql('SELECT spelling FROM words');
      while (resultSet.goToNextRow()) {
        existingSpells.add(resultSet.getString(0));
      }
      resultSet.close();

      store.beginTransaction();
      for (const word of words) {
        if (!word.spelling || word.spelling.trim() === '') continue;
        if (existingSpells.has(word.spelling)) continue;

        const val: ValuesBucket = {
          spelling: word.spelling,
          phonetic: word.phonetic || '',
          meaning: word.meaning || '',
          example: word.example || '',
          proficiency: 0,
          repetition: 0,
          interval: 0,
          easeFactor: 2.5,
          lastReviewTime: 0,
          nextReviewTime: 0
        };
        await store.insert('words', val);
        count++;
        existingSpells.add(word.spelling);
      }
      store.commit();
      return count;
    } catch (e) {
      try { store.rollBack(); } catch (err) {}
      return 0;
    }
  }

  async cleanAllData(): Promise<void> {
    const store = this.rdbStore;
    if (!store) return;
    try {
      await store.executeSql('DELETE FROM words');
      await store.executeSql('DELETE FROM sqlite_sequence WHERE name = "words"');
    } catch(e){}
  }
}