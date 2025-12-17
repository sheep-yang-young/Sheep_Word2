import { relationalStore, ValuesBucket } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { Word, DashboardStats } from '../model/WordModel';

interface ColumnDefinition {
  name: string;
  type: string;
}

interface ActivityRecord {
  dateStr: string;
  count: number;
}

const DB_NAME = 'Lumina_V2.db';

export class DatabaseManager {
  private static instance: DatabaseManager;
  private rdbStore: relationalStore.RdbStore | null = null;
  private context: common.Context | null = null;

  private constructor() {}

  private async setupSchema(store: relationalStore.RdbStore): Promise<void> {
    await store.executeSql(`
      CREATE TABLE IF NOT EXISTS words (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        book_id TEXT,
        spelling TEXT NOT NULL,
        phonetic TEXT,
        meaning TEXT,
        example TEXT,
        note TEXT,
        roots TEXT,
        affixes TEXT,
        collocations TEXT,
        synonyms TEXT,
        antonyms TEXT,
        derivatives TEXT,
        senses TEXT,
        knowledgeScore INTEGER DEFAULT 0,
        proficiency INTEGER DEFAULT 0,
        repetition INTEGER DEFAULT 0,
        interval INTEGER DEFAULT 0,
        easeFactor REAL DEFAULT 2.5,
        lastReviewTime INTEGER DEFAULT 0,
        nextReviewTime INTEGER DEFAULT 0
      )
    `);

    // 1. 基础扩展字段
    const optionalColumns: ColumnDefinition[] = [
      { name: 'book_id', type: 'TEXT' },
      { name: 'note', type: 'TEXT' },
      { name: 'roots', type: 'TEXT' },
      { name: 'affixes', type: 'TEXT' },
      { name: 'collocations', type: 'TEXT' },
      { name: 'synonyms', type: 'TEXT' },
      { name: 'antonyms', type: 'TEXT' },
      { name: 'derivatives', type: 'TEXT' },
      { name: 'senses', type: 'TEXT' },
      { name: 'knowledgeScore', type: 'INTEGER' }
    ];

    // 2. 拼写模式专用字段
    const spellingColumns: ColumnDefinition[] = [
      { name: 'proficiencySpelling', type: 'INTEGER DEFAULT 0' },
      { name: 'repetitionSpelling', type: 'INTEGER DEFAULT 0' },
      { name: 'intervalSpelling', type: 'INTEGER DEFAULT 0' },
      { name: 'easeFactorSpelling', type: 'REAL DEFAULT 2.5' },
      { name: 'lastReviewTimeSpelling', type: 'INTEGER DEFAULT 0' },
      { name: 'nextReviewTimeSpelling', type: 'INTEGER DEFAULT 0' }
    ];

    const allColumns = [...optionalColumns, ...spellingColumns];

    for (const col of allColumns) {
      try {
        await store.executeSql(`ALTER TABLE words ADD COLUMN ${col.name} ${col.type}`);
      } catch (e) {}
    }

    try { await store.executeSql('UPDATE words SET book_id = "Default Library" WHERE book_id IS NULL OR book_id = ""'); } catch (e) {}
    await store.executeSql(`CREATE TABLE IF NOT EXISTS activity_log (dateStr TEXT PRIMARY KEY, count INTEGER DEFAULT 0)`);
  }

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
        await this.setupSchema(store);
      }
    } catch (err) {
      console.error(`[Lumina] DB Init failed: ${JSON.stringify(err)}`);
    }
  }

  // --- [新增] 单个单词插入 (用于自定义导入) ---
  async addWord(word: Word): Promise<number> {
    const s = this.rdbStore;
    if (!s) return 0;
    try {
      // 查重：同一本词书下不允许重复单词
      const p = new relationalStore.RdbPredicates('words');
      p.equalTo('book_id', word.bookId).and().equalTo('spelling', word.spelling);
      const r = await s.query(p);
      if (r.rowCount > 0) {
        r.close();
        return 0; // 已存在，跳过
      }
      r.close();

      const v: ValuesBucket = {
        book_id: word.bookId,
        spelling: word.spelling,
        phonetic: word.phonetic || '',
        meaning: word.meaning || '',
        example: word.example || '',
        note: word.note || '',
        roots: this.serializeArray(word.roots),
        affixes: this.serializeArray(word.affixes),
        collocations: this.serializeArray(word.collocations),
        synonyms: this.serializeArray(word.synonyms),
        antonyms: this.serializeArray(word.antonyms),
        derivatives: this.serializeArray(word.derivatives),
        senses: this.serializeArray(word.senses),
        knowledgeScore: word.knowledgeScore ?? 0,
        proficiency: 0, repetition: 0, interval: 0, easeFactor: 2.5, lastReviewTime: 0, nextReviewTime: 0,
        proficiencySpelling: 0, repetitionSpelling: 0, intervalSpelling: 0, easeFactorSpelling: 2.5, lastReviewTimeSpelling: 0, nextReviewTimeSpelling: 0
      };
      return await s.insert('words', v);
    } catch (e) {
      return 0;
    }
  }

  // --- 核心：万能随机取词 ---
  async getRandomWords(bookId: string, limit: number = 20): Promise<Word[]> {
    const s = this.rdbStore;
    if (!s) return [];
    try {
      // 1. 尝试查询当前书
      let r = await s.querySql(`SELECT * FROM words WHERE book_id = ? ORDER BY RANDOM() LIMIT ?`, [bookId, limit]);
      let w: Word[] = [];
      while (r.goToNextRow()) w.push(this.mapRowToWord(r));
      r.close();

      // 2. 如果没数据，尝试查找任意一本有数据的书
      if (w.length === 0) {
        const validBook = await this.findAnyValidBook();
        if (validBook !== "Default Library" && validBook !== bookId) {
          r = await s.querySql(`SELECT * FROM words WHERE book_id = ? ORDER BY RANDOM() LIMIT ?`, [validBook, limit]);
          while (r.goToNextRow()) w.push(this.mapRowToWord(r));
          r.close();
        }
      }

      // 3. 全库随机搜索
      if (w.length === 0) {
        r = await s.querySql(`SELECT * FROM words ORDER BY RANDOM() LIMIT ?`, [limit]);
        while (r.goToNextRow()) w.push(this.mapRowToWord(r));
        r.close();
      }

      return w;
    } catch (e) { return []; }
  }

  // --- 搜索功能 ---
  async searchWords(bookId: string, k: string, m: number = 0): Promise<Word[]> {
    const s=this.rdbStore;
    if(!s)return[];
    try{
      const p=new relationalStore.RdbPredicates('words');
      p.equalTo('book_id',bookId);
      if(k&&k.trim()!=='') p.and().beginWrap().like('spelling',`%${k}%`).or().like('meaning',`%${k}%`).endWrap();
      switch(m){
        case 1:p.orderByAsc('proficiency');break;
        case 2:p.orderByDesc('proficiency');break;
        case 3:p.orderByDesc('id');break;
        default:p.orderByAsc('spelling');break;
      }
      p.limitAs(100);
      const r=await s.query(p);
      const w:Word[]=[];
      while(r.goToNextRow())w.push(this.mapRowToWord(r));
      r.close();
      return w;
    }catch(e){return[];}
  }

  // --- 统计面板 ---
  async getDashboardStats(bookId: string, dailyLimit: number = 20, mode: number = 0): Promise<DashboardStats> {
    let stats = new DashboardStats();
    const store = this.rdbStore;
    if (!store) return stats;

    try {
      const todayStart = new Date(); todayStart.setHours(0,0,0,0);
      const endOfToday = new Date(); endOfToday.setHours(23, 59, 59, 999);

      // Total
      const totalRes = await store.querySql('SELECT count(*) FROM words WHERE book_id = ?', [bookId]);
      if (totalRes.goToFirstRow()) stats.total = totalRes.getLong(0);
      totalRes.close();

      if (mode === 0) {
        // === 认知模式 ===
        const learnedRes = await store.querySql('SELECT count(*) FROM words WHERE book_id = ? AND lastReviewTime >= ?', [bookId, todayStart.getTime()]);
        if (learnedRes.goToFirstRow()) stats.learnedToday = learnedRes.getLong(0);
        learnedRes.close();

        const masterRes = await store.querySql('SELECT count(*) FROM words WHERE book_id = ? AND (proficiency >= 80 OR interval > 21)', [bookId]);
        if (masterRes.goToFirstRow()) stats.mastered = masterRes.getLong(0);
        masterRes.close();

        const dueRes = await store.querySql('SELECT count(*) FROM words WHERE book_id = ? AND lastReviewTime > 0 AND nextReviewTime <= ?', [bookId, endOfToday.getTime()]);
        if (dueRes.goToFirstRow()) stats.dueReviews = dueRes.getLong(0);
        dueRes.close();

        const remainingQuota = Math.max(0, dailyLimit - stats.learnedToday);
        const newRes = await store.querySql('SELECT count(*) FROM (SELECT id FROM words WHERE book_id = ? AND lastReviewTime = 0 LIMIT ?)', [bookId, remainingQuota]);
        if (newRes.goToFirstRow()) stats.newToday = newRes.getLong(0);
        newRes.close();

      } else {
        // === 拼写模式 ===
        const learnedRes = await store.querySql('SELECT count(*) FROM words WHERE book_id = ? AND lastReviewTimeSpelling >= ?', [bookId, todayStart.getTime()]);
        if (learnedRes.goToFirstRow()) stats.learnedToday = learnedRes.getLong(0);
        learnedRes.close();

        const masterRes = await store.querySql('SELECT count(*) FROM words WHERE book_id = ? AND proficiencySpelling >= 80', [bookId]);
        if (masterRes.goToFirstRow()) stats.mastered = masterRes.getLong(0);
        masterRes.close();

        const dueRes = await store.querySql('SELECT count(*) FROM words WHERE book_id = ? AND lastReviewTimeSpelling > 0 AND nextReviewTimeSpelling <= ?', [bookId, endOfToday.getTime()]);
        if (dueRes.goToFirstRow()) stats.dueReviews = dueRes.getLong(0);
        dueRes.close();

        const remainingQuota = Math.max(0, dailyLimit - stats.learnedToday);
        const newRes = await store.querySql('SELECT count(*) FROM (SELECT id FROM words WHERE book_id = ? AND lastReviewTime > 0 AND lastReviewTimeSpelling = 0 LIMIT ?)', [bookId, remainingQuota]);
        if (newRes.goToFirstRow()) stats.newToday = newRes.getLong(0);
        newRes.close();
      }

      stats.due = stats.dueReviews + stats.newToday;
      stats.streak = await this.calculateStreak();
      return stats;
    } catch (e) { return stats; }
  }

  async getTodayWordList(bookId: string, dailyLimit: number, mode: number): Promise<Word[]> {
    if (mode === 1) return this.getTodaySpellingWords(bookId, dailyLimit);
    else return this.getTodayCardWords(bookId, dailyLimit);
  }

  private async getTodayCardWords(bookId: string, dailyLimit: number): Promise<Word[]> {
    const s = this.rdbStore; if (!s) return [];
    try {
      const todayStart = new Date(); todayStart.setHours(0,0,0,0);
      const endOfToday = new Date(); endOfToday.setHours(23, 59, 59, 999);
      let learnedToday = 0;
      const lRes = await s.querySql('SELECT count(*) FROM words WHERE book_id = ? AND lastReviewTime >= ?', [bookId, todayStart.getTime()]);
      if (lRes.goToFirstRow()) learnedToday = lRes.getLong(0);
      lRes.close();
      const quota = Math.max(0, dailyLimit - learnedToday);
      const sql = `SELECT * FROM words WHERE book_id = ? AND ((lastReviewTime > 0 AND nextReviewTime <= ?) OR (lastReviewTime = 0 AND id IN (SELECT id FROM words WHERE book_id = ? AND lastReviewTime = 0 LIMIT ?))) ORDER BY CASE WHEN lastReviewTime > 0 THEN 0 ELSE 1 END ASC, nextReviewTime ASC`;
      const r = await s.querySql(sql, [bookId, endOfToday.getTime(), bookId, quota]);
      const w: Word[] = [];
      while (r.goToNextRow()) w.push(this.mapRowToWord(r));
      r.close();
      return w;
    } catch (e) { return []; }
  }

  private async getTodaySpellingWords(bookId: string, dailyLimit: number): Promise<Word[]> {
    const s = this.rdbStore; if (!s) return [];
    try {
      const todayStart = new Date(); todayStart.setHours(0,0,0,0);
      const endOfToday = new Date(); endOfToday.setHours(23, 59, 59, 999);
      let learnedToday = 0;
      const lRes = await s.querySql('SELECT count(*) FROM words WHERE book_id = ? AND lastReviewTimeSpelling >= ?', [bookId, todayStart.getTime()]);
      if (lRes.goToFirstRow()) learnedToday = lRes.getLong(0);
      lRes.close();
      const quota = Math.max(0, dailyLimit - learnedToday);
      const sql = `SELECT * FROM words WHERE book_id = ? AND ((lastReviewTimeSpelling > 0 AND nextReviewTimeSpelling <= ?) OR (lastReviewTimeSpelling = 0 AND lastReviewTime > 0 AND id IN (SELECT id FROM words WHERE book_id = ? AND lastReviewTime > 0 AND lastReviewTimeSpelling = 0 LIMIT ?))) ORDER BY CASE WHEN lastReviewTimeSpelling > 0 THEN 0 ELSE 1 END ASC, nextReviewTimeSpelling ASC`;
      const r = await s.querySql(sql, [bookId, endOfToday.getTime(), bookId, quota]);
      const w: Word[] = [];
      while (r.goToNextRow()) w.push(this.mapRowToWord(r));
      r.close();
      return w;
    } catch (e) { return []; }
  }

  async updateWordStats(id: number, interval: number, repetition: number, easeFactor: number, mode: number = 0): Promise<void> {
    const s = this.rdbStore; if (!s) return;
    const now = Date.now();
    const next = now + (interval * 24 * 60 * 60 * 1000);
    let np = Math.min(100, Math.round((interval / 21) * 100));
    if (repetition > 0 && np < 10) np = 10;
    const p = new relationalStore.RdbPredicates('words');
    p.equalTo('id', id);
    let v: ValuesBucket;
    if (mode === 0) v = { interval, repetition, easeFactor, lastReviewTime: now, nextReviewTime: next, proficiency: np };
    else v = { intervalSpelling: interval, repetitionSpelling: repetition, easeFactorSpelling: easeFactor, lastReviewTimeSpelling: now, nextReviewTimeSpelling: next, proficiencySpelling: np };
    await s.update(v, p);
  }

  async findAnyValidBook(): Promise<string> { const s=this.rdbStore; if(!s)return"Default Library"; try{ const q='SELECT book_id FROM words GROUP BY book_id HAVING count(*) > 0 LIMIT 1'; const r=await s.querySql(q); let b="Default Library"; if(r.goToFirstRow()) b = r.getString(0); r.close(); return b || "Default Library"; } catch(e){ return"Default Library"; } }
  async checkBookExists(bookId: string): Promise<boolean> { const s=this.rdbStore; if(!s)return false; try{const r=await s.querySql('SELECT count(*) FROM words WHERE book_id = ?',[bookId]); let c=0; if(r.goToFirstRow())c=r.getLong(0); r.close(); return c>0;}catch(e){return false;} }
  async updateWordInfo(w: Word): Promise<void> { const s=this.rdbStore; if(!s||!w.id)return; const v:ValuesBucket={spelling:w.spelling,phonetic:w.phonetic??'',meaning:w.meaning,example:w.example??'',note:w.note??'',roots:this.serializeArray(w.roots),affixes:this.serializeArray(w.affixes),collocations:this.serializeArray(w.collocations),synonyms:this.serializeArray(w.synonyms),antonyms:this.serializeArray(w.antonyms),derivatives:this.serializeArray(w.derivatives),senses:this.serializeArray(w.senses),knowledgeScore:w.knowledgeScore??0}; const p=new relationalStore.RdbPredicates('words'); p.equalTo('id',w.id); await s.update(v,p); }
  async updateWordNote(id: number, note: string): Promise<void> { const s=this.rdbStore; if(!s)return; const v:ValuesBucket={note}; const p=new relationalStore.RdbPredicates('words'); p.equalTo('id',id); await s.update(v,p); }
  async deleteWord(id: number): Promise<void> { const s=this.rdbStore; if(!s)return; const p=new relationalStore.RdbPredicates('words'); p.equalTo('id',id); await s.delete(p); }

  async batchInsertWords(bookId: string, words: Word[]): Promise<number> {
    const s = this.rdbStore; if (!s) return 0;
    let c = 0;
    try {
      const set = new Set<string>();
      try { const r = await s.querySql('SELECT spelling FROM words WHERE book_id = ?', [bookId]); while (r.goToNextRow()) set.add(r.getString(0)); r.close(); } catch (e) {}
      s.beginTransaction();
      for (const w of words) {
        if (!w.spelling || set.has(w.spelling)) continue;
        const v: ValuesBucket = {
          book_id: bookId,
          spelling: w.spelling,
          phonetic: w.phonetic || '',
          meaning: w.meaning || '',
          example: w.example || '',
          note: w.note || '',
          roots: this.serializeArray(w.roots),
          affixes: this.serializeArray(w.affixes),
          collocations: this.serializeArray(w.collocations),
          synonyms: this.serializeArray(w.synonyms),
          antonyms: this.serializeArray(w.antonyms),
          derivatives: this.serializeArray(w.derivatives),
          senses: this.serializeArray(w.senses),
          knowledgeScore: w.knowledgeScore ?? 0,
          proficiency: w.proficiency ?? 0, repetition: w.repetition ?? 0, interval: w.interval ?? 0, easeFactor: w.easeFactor ?? 2.5, lastReviewTime: w.lastReviewTime ?? 0, nextReviewTime: w.nextReviewTime ?? 0,
          proficiencySpelling: 0, repetitionSpelling: 0, intervalSpelling: 0, easeFactorSpelling: 2.5, lastReviewTimeSpelling: 0, nextReviewTimeSpelling: 0
        };
        await s.insert('words', v);
        c++;
        set.add(w.spelling);
      }
      s.commit();
      return c;
    } catch (e) { try { s.rollBack() } catch (er) {} return 0; }
  }

  async cleanAllData(): Promise<void> { const s=this.rdbStore; if(!s)return; try{await s.executeSql('DELETE FROM words'); await s.executeSql('DELETE FROM sqlite_sequence WHERE name="words"'); await s.executeSql('DELETE FROM activity_log');}catch(e){} }
  async resetLearningProgress(bookId: string): Promise<void> { const s = this.rdbStore; if (!s) return; const v: ValuesBucket = { proficiency: 0, repetition: 0, interval: 0, easeFactor: 2.5, lastReviewTime: 0, nextReviewTime: 0, proficiencySpelling: 0, repetitionSpelling: 0, intervalSpelling: 0, easeFactorSpelling: 2.5, lastReviewTimeSpelling: 0, nextReviewTimeSpelling: 0 }; const p = new relationalStore.RdbPredicates('words'); p.equalTo('book_id', bookId); await s.update(v, p); }

  async rebuildDatabase(): Promise<boolean> {
    const store = this.rdbStore; if (!store) return false;
    let wordsBackup: Word[] = [];
    const activityBackup: ActivityRecord[] = [];
    try {
      const wordsRes = await store.querySql('SELECT * FROM words');
      while (wordsRes.goToNextRow()) wordsBackup.push(this.mapRowToWord(wordsRes));
      wordsRes.close();
      try { const actRes = await store.querySql('SELECT dateStr, count FROM activity_log'); while (actRes.goToNextRow()) activityBackup.push({ dateStr: actRes.getString(0), count: actRes.getLong(1) }); actRes.close(); } catch (e) {}
      await store.executeSql('DROP TABLE IF EXISTS words'); await store.executeSql('DROP TABLE IF EXISTS activity_log'); try { await store.executeSql('DELETE FROM sqlite_sequence WHERE name="words"'); } catch (e) {}
      await this.setupSchema(store);
      store.beginTransaction();
      for (const w of wordsBackup) {
        const values: ValuesBucket = {
          book_id: w.bookId, spelling: w.spelling, phonetic: w.phonetic ?? '', meaning: w.meaning ?? '', example: w.example ?? '', note: w.note ?? '',
          roots: this.serializeArray(w.roots), affixes: this.serializeArray(w.affixes), collocations: this.serializeArray(w.collocations), synonyms: this.serializeArray(w.synonyms), antonyms: this.serializeArray(w.antonyms), derivatives: this.serializeArray(w.derivatives), senses: this.serializeArray(w.senses), knowledgeScore: w.knowledgeScore ?? 0,
          proficiency: w.proficiency ?? 0, repetition: w.repetition ?? 0, interval: w.interval ?? 0, easeFactor: w.easeFactor ?? 2.5, lastReviewTime: w.lastReviewTime ?? 0, nextReviewTime: w.nextReviewTime ?? 0,
          proficiencySpelling: w.proficiencySpelling ?? 0, repetitionSpelling: w.repetitionSpelling ?? 0, intervalSpelling: w.intervalSpelling ?? 0, easeFactorSpelling: w.easeFactorSpelling ?? 2.5, lastReviewTimeSpelling: w.lastReviewTimeSpelling ?? 0, nextReviewTimeSpelling: w.nextReviewTimeSpelling ?? 0
        };
        await store.insert('words', values);
      }
      for (const a of activityBackup) { const values: ValuesBucket = { dateStr: a.dateStr, count: a.count }; await store.insert('activity_log', values); }
      store.commit();
      return true;
    } catch (e) { try { store.rollBack(); } catch (er) {} return false; }
  }

  async calculateStreak(): Promise<number> { const s=this.rdbStore; if(!s)return 0; try{const r=await s.querySql('SELECT dateStr FROM activity_log ORDER BY dateStr DESC'); const d:string[]=[]; while(r.goToNextRow())d.push(r.getString(0)); r.close(); if(d.length===0)return 0; let k=0; const t=new Date(); let h=d.includes(`${t.getFullYear()}-${(t.getMonth()+1).toString().padStart(2,'0')}-${t.getDate().toString().padStart(2,'0')}`); let c=h?new Date():(()=>{const x=new Date();x.setDate(x.getDate()-1);return x;})(); while(true){const str=`${c.getFullYear()}-${(c.getMonth()+1).toString().padStart(2,'0')}-${c.getDate().toString().padStart(2,'0')}`; if(d.includes(str)){k++;c.setDate(c.getDate()-1);}else{break;}} return k;}catch(e){return 0;} }
  async logActivity(): Promise<void> { const s=this.rdbStore; if(!s)return; const d=`${new Date().getFullYear()}-${(new Date().getMonth()+1).toString().padStart(2,'0')}-${new Date().getDate().toString().padStart(2,'0')}`; try{const r=await s.querySql('SELECT count FROM activity_log WHERE dateStr=?',[d]); let c=0; let ex=false; if(r.goToFirstRow()){c=r.getLong(0);ex=true;} r.close(); const v:ValuesBucket={dateStr:d,count:c+1}; if(ex){const p=new relationalStore.RdbPredicates('activity_log'); p.equalTo('dateStr',d); await s.update(v,p);}else{await s.insert('activity_log',v);}}catch(e){} }
  async getActivityStats(days: number=28): Promise<Map<string,number>> { const s=this.rdbStore; const m=new Map<string,number>(); if(!s)return m; try{const r=await s.querySql(`SELECT * FROM activity_log ORDER BY dateStr DESC LIMIT ?`,[days]); while(r.goToNextRow())m.set(r.getString(0),r.getLong(1)); r.close();}catch(e){} return m; }
  async getProficiencyDistribution(bookId: string): Promise<number[]> { const s=this.rdbStore; if(!s)return[0,0,0,0,0]; try{const q=`SELECT SUM(CASE WHEN proficiency<=20 THEN 1 ELSE 0 END),SUM(CASE WHEN proficiency>20 AND proficiency<=40 THEN 1 ELSE 0 END),SUM(CASE WHEN proficiency>40 AND proficiency<=60 THEN 1 ELSE 0 END),SUM(CASE WHEN proficiency>60 AND proficiency<=80 THEN 1 ELSE 0 END),SUM(CASE WHEN proficiency>80 THEN 1 ELSE 0 END) FROM words WHERE book_id=?`; const r=await s.querySql(q,[bookId]); const a=[0,0,0,0,0]; if(r.goToFirstRow()){a[0]=r.getLong(0)||0;a[1]=r.getLong(1)||0;a[2]=r.getLong(2)||0;a[3]=r.getLong(3)||0;a[4]=r.getLong(4)||0;} r.close(); return a;}catch(e){return[0,0,0,0,0];} }
  async recordKnowledgePractice(id: number, correct: boolean): Promise<void> { const s=this.rdbStore; if(!s)return; try{const res=await s.querySql('SELECT knowledgeScore, proficiency FROM words WHERE id=?',[id]); let score=0; let prof=0; if(res.goToFirstRow()){score=res.getLong(0)||0; prof=res.getLong(1)||0;} res.close(); const now=Date.now(); const delta=correct?5: -2; const newScore=Math.max(0, score + delta); const newProf=Math.min(100, Math.max(0, prof + (correct?3:0))); const v:ValuesBucket={knowledgeScore:newScore, proficiency:newProf, lastReviewTime:now, nextReviewTime:now + 24*60*60*1000}; const p=new relationalStore.RdbPredicates('words'); p.equalTo('id',id); await s.update(v,p); await this.logActivity(); }catch(e){} }
  async getSpellingReviewWords(bookId: string, limit: number = 20): Promise<Word[]> { const s=this.rdbStore; if(!s)return[]; try{const q=`SELECT * FROM words WHERE book_id=? AND lastReviewTime>0 ORDER BY proficiency ASC LIMIT ?`; const r=await s.querySql(q,[bookId,limit]); const w:Word[]=[]; while(r.goToNextRow())w.push(this.mapRowToWord(r)); r.close(); return w;}catch(e){return[];} }

  private serializeArray(arr?: string[]): string { if (!arr || arr.length === 0) return '[]'; try { return JSON.stringify(arr); } catch (e) { return '[]'; } }
  private parseArray(raw: string | null): string[] { if (!raw) return []; try { const parsed: Object = JSON.parse(raw); if (Array.isArray(parsed)) { return (parsed as Object[]).map((item: Object) => String(item)); } return []; } catch (e) { return []; } }

  private mapRowToWord(r: relationalStore.ResultSet): Word {
    const g=(c:string)=>{const i=r.getColumnIndex(c);return i>=0?r.getString(i):''};
    const l=(c:string)=>{const i=r.getColumnIndex(c);return i>=0?r.getLong(i):0;};
    const d=(c:string)=>{const i=r.getColumnIndex(c);return i>=0?r.getDouble(i):0;};

    return {
      id: l('id'), bookId: g('book_id'), spelling: g('spelling'), phonetic: g('phonetic'), meaning: g('meaning'), example: g('example'), note: g('note'),
      roots: this.parseArray(g('roots')), affixes: this.parseArray(g('affixes')), collocations: this.parseArray(g('collocations')), synonyms: this.parseArray(g('synonyms')), antonyms: this.parseArray(g('antonyms')), derivatives: this.parseArray(g('derivatives')), senses: this.parseArray(g('senses')), knowledgeScore: l('knowledgeScore'),
      proficiency: l('proficiency'), repetition: l('repetition'), interval: l('interval'), easeFactor: d('easeFactor'), lastReviewTime: l('lastReviewTime'), nextReviewTime: l('nextReviewTime'),
      proficiencySpelling: l('proficiencySpelling'), repetitionSpelling: l('repetitionSpelling'), intervalSpelling: l('intervalSpelling'), easeFactorSpelling: d('easeFactorSpelling') || 2.5, lastReviewTimeSpelling: l('lastReviewTimeSpelling'), nextReviewTimeSpelling: l('nextReviewTimeSpelling')
    };
  }
}