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
        // 确保日志表存在
        await store.executeSql(`CREATE TABLE IF NOT EXISTS activity_log (dateStr TEXT PRIMARY KEY, count INTEGER DEFAULT 0)`);
      }
    } catch (err) {
      console.error(`[Lumina] DB Init failed: ${JSON.stringify(err)}`);
    }
  }

  // [修复] 补全这个缺失的方法
  async resetLearningProgress(): Promise<void> {
    const store = this.rdbStore;
    if (!store) return;
    try {
      // 重置所有记忆参数
      const val: ValuesBucket = {
        proficiency: 0,
        repetition: 0,
        interval: 0,
        easeFactor: 2.5,
        lastReviewTime: 0,
        nextReviewTime: 0
      };
      // 不加条件的 predicates 代表更新所有行
      const pred = new relationalStore.RdbPredicates('words');
      await store.update(val, pred);
      console.info('[Lumina] Learning progress reset successfully');
    } catch (e) {
      console.error('[Lumina] Reset failed:', e);
    }
  }

  async searchWords(keyword: string, sortMode: number = 0): Promise<Word[]> {
    const store = this.rdbStore;
    if (!store) return [];
    try {
      const predicates = new relationalStore.RdbPredicates('words');
      if (keyword && keyword.trim() !== '') {
        predicates.like('spelling', `%${keyword}%`)
          .or()
          .like('meaning', `%${keyword}%`);
      }

      switch (sortMode) {
        case 1: predicates.orderByAsc('proficiency'); break;
        case 2: predicates.orderByDesc('proficiency'); break;
        case 3: predicates.orderByDesc('id'); break;
        case 0: default: predicates.orderByAsc('spelling'); break;
      }

      const resultSet = await store.query(predicates);
      const words: Word[] = [];
      while (resultSet.goToNextRow()) {
        words.push(this.mapRowToWord(resultSet));
      }
      resultSet.close();
      return words;
    } catch (e) {
      return [];
    }
  }

  // ... (保留其他所有方法，确保不报错)
  async getDashboardStats(): Promise<DashboardStats> {
    let stats = new DashboardStats();
    const store = this.rdbStore;
    if (!store) return stats;
    try {
      const now = Date.now();
      const todayStart = new Date(); todayStart.setHours(0,0,0,0);

      try {
        const totalRes = await store.querySql('SELECT count(*) FROM words');
        if (totalRes.goToFirstRow()) stats.total = totalRes.getLong(0);
        totalRes.close();
      } catch(e){}

      try {
        const dueRes = await store.querySql('SELECT count(*) FROM words WHERE nextReviewTime <= ?', [now]);
        if (dueRes.goToFirstRow()) stats.due = dueRes.getLong(0);
        dueRes.close();
      } catch(e){}

      try {
        const learnedRes = await store.querySql('SELECT count(*) FROM words WHERE lastReviewTime >= ?', [todayStart.getTime()]);
        if (learnedRes.goToFirstRow()) stats.learnedToday = learnedRes.getLong(0);
        learnedRes.close();
      } catch(e){}

      try {
        const masterRes = await store.querySql('SELECT count(*) FROM words WHERE interval > 21');
        if (masterRes.goToFirstRow()) stats.mastered = masterRes.getLong(0);
        masterRes.close();
      } catch(e){}

      return stats;
    } catch (e) { return stats; }
  }

  async updateWordInfo(word: Word): Promise<void> {
    const store = this.rdbStore;
    if (!store || word.id === undefined) return;
    const val: ValuesBucket = { spelling: word.spelling, phonetic: word.phonetic ?? '', meaning: word.meaning, example: word.example ?? '' };
    const pred = new relationalStore.RdbPredicates('words'); pred.equalTo('id', word.id);
    await store.update(val, pred);
  }

  async getTodayReviewWords(limit: number = 20): Promise<Word[]> {
    if (!this.rdbStore) return [];
    try {
      const now = Date.now();
      const predicates = new relationalStore.RdbPredicates('words');
      predicates.lessThanOrEqualTo('nextReviewTime', now).orderByAsc('nextReviewTime').limitAs(limit);
      const resultSet = await this.rdbStore.query(predicates);
      const words: Word[] = [];
      while (resultSet.goToNextRow()) words.push(this.mapRowToWord(resultSet));
      resultSet.close();
      return words;
    } catch (err) { return []; }
  }

  async getProficiencyDistribution(): Promise<number[]> {
    const store = this.rdbStore; if (!store) return [0,0,0,0,0];
    try {
      const resultSet = await store.querySql('SELECT proficiency FROM words');
      const stats = [0,0,0,0,0];
      while (resultSet.goToNextRow()) {
        const p = resultSet.getLong(0);
        if (p<=20) stats[0]++; else if (p<=40) stats[1]++; else if (p<=60) stats[2]++; else if (p<=80) stats[3]++; else stats[4]++;
      }
      resultSet.close(); return stats;
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
    const store = this.rdbStore; if (!store) return;
    const now = Date.now(); const nextTime = now + (interval * 24 * 60 * 60 * 1000);
    const val: ValuesBucket = { interval, repetition, easeFactor, lastReviewTime: now, nextReviewTime: nextTime, proficiency: Math.min(100, repetition * 10) };
    const pred = new relationalStore.RdbPredicates('words'); pred.equalTo('id', id);
    await store.update(val, pred);
  }

  async batchInsertWords(words: Word[]): Promise<number> {
    const store = this.rdbStore; if (!store) return 0;
    let count = 0;
    try {
      const existingSpells = new Set<string>();
      const resultSet = await store.querySql('SELECT spelling FROM words');
      while (resultSet.goToNextRow()) existingSpells.add(resultSet.getString(0)); resultSet.close();
      store.beginTransaction();
      for (const word of words) {
        if (!word.spelling || word.spelling.trim() === '') continue;
        if (existingSpells.has(word.spelling)) continue;
        const val: ValuesBucket = { spelling: word.spelling, phonetic: word.phonetic||'', meaning: word.meaning||'', example: word.example||'', proficiency: 0, repetition: 0, interval: 0, easeFactor: 2.5, lastReviewTime: 0, nextReviewTime: 0 };
        await store.insert('words', val); count++; existingSpells.add(word.spelling);
      }
      store.commit(); return count;
    } catch (e) { try{store.rollBack()}catch(err){} return 0; }
  }

  async deleteWord(id: number): Promise<void> {
    const store = this.rdbStore; if (!store) return;
    try { const pred = new relationalStore.RdbPredicates('words'); pred.equalTo('id', id); await store.delete(pred); } catch (e) {}
  }

  async cleanAllData(): Promise<void> {
    const store = this.rdbStore; if (!store) return;
    try {
      await store.executeSql('DELETE FROM words');
      await store.executeSql('DELETE FROM sqlite_sequence WHERE name = "words"');
      await store.executeSql('DELETE FROM activity_log');
    } catch(e){}
  }

  async logActivity(): Promise<void> {
    const store = this.rdbStore; if (!store) return;
    const now = new Date();
    const dateStr = `${now.getFullYear()}-${(now.getMonth()+1).toString().padStart(2, '0')}-${now.getDate().toString().padStart(2, '0')}`;
    try {
      const result = await store.querySql('SELECT count FROM activity_log WHERE dateStr = ?', [dateStr]);
      let currentCount = 0;
      let exists = false;
      if (result.goToFirstRow()) { currentCount = result.getLong(0); exists = true; }
      result.close();
      const val: ValuesBucket = { dateStr: dateStr, count: currentCount + 1 };
      if (exists) {
        const pred = new relationalStore.RdbPredicates('activity_log');
        pred.equalTo('dateStr', dateStr);
        await store.update(val, pred);
      } else {
        await store.insert('activity_log', val);
      }
    } catch (e) {}
  }

  async getActivityStats(days: number = 28): Promise<Map<string, number>> {
    const store = this.rdbStore;
    const map = new Map<string, number>();
    if (!store) return map;
    try {
      const resultSet = await store.querySql(`SELECT * FROM activity_log ORDER BY dateStr DESC LIMIT ?`, [days]);
      while (resultSet.goToNextRow()) {
        map.set(resultSet.getString(0), resultSet.getLong(1));
      }
      resultSet.close();
    } catch (e) {}
    return map;
  }
}