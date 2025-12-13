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
        try { await store.executeSql('ALTER TABLE words ADD COLUMN book_id TEXT'); } catch (e) {}
        try { await store.executeSql('ALTER TABLE words ADD COLUMN note TEXT'); } catch (e) {}
        try { await store.executeSql('ALTER TABLE words ADD COLUMN roots TEXT'); } catch (e) {}
        try { await store.executeSql('ALTER TABLE words ADD COLUMN affixes TEXT'); } catch (e) {}
        try { await store.executeSql('ALTER TABLE words ADD COLUMN collocations TEXT'); } catch (e) {}
        try { await store.executeSql('ALTER TABLE words ADD COLUMN synonyms TEXT'); } catch (e) {}
        try { await store.executeSql('ALTER TABLE words ADD COLUMN antonyms TEXT'); } catch (e) {}
        try { await store.executeSql('ALTER TABLE words ADD COLUMN derivatives TEXT'); } catch (e) {}
        try { await store.executeSql('ALTER TABLE words ADD COLUMN senses TEXT'); } catch (e) {}
        try { await store.executeSql('ALTER TABLE words ADD COLUMN knowledgeScore INTEGER DEFAULT 0'); } catch (e) {}
        try { await store.executeSql('UPDATE words SET book_id = "Default Library" WHERE book_id IS NULL OR book_id = ""'); } catch (e) {}
        await store.executeSql(`CREATE TABLE IF NOT EXISTS activity_log (dateStr TEXT PRIMARY KEY, count INTEGER DEFAULT 0)`);
      }
    } catch (err) {
      console.error(`[Lumina] DB Init failed: ${JSON.stringify(err)}`);
    }
  }

  // --- 核心：统计逻辑 ---
  async getDashboardStats(bookId: string): Promise<DashboardStats> {
    let stats = new DashboardStats();
    const store = this.rdbStore;
    if (!store) return stats;

    try {
      const todayStart = new Date(); todayStart.setHours(0,0,0,0);
      const endOfToday = new Date(); endOfToday.setHours(23, 59, 59, 999);

      // 1. Total: 当前书总词数
      const totalRes = await store.querySql('SELECT count(*) FROM words WHERE book_id = ?', [bookId]);
      if (totalRes.goToFirstRow()) stats.total = totalRes.getLong(0);
      totalRes.close();

      // 2. Learned Today: 今天学了多少个 (用于进度条)
      const learnedRes = await store.querySql('SELECT count(*) FROM words WHERE book_id = ? AND lastReviewTime >= ?', [bookId, todayStart.getTime()]);
      if (learnedRes.goToFirstRow()) stats.learnedToday = learnedRes.getLong(0);
      learnedRes.close();

      // 3. Mastered: 熟练度高的
      const masterRes = await store.querySql('SELECT count(*) FROM words WHERE book_id = ? AND (interval > 21 OR proficiency = 100)', [bookId]);
      if (masterRes.goToFirstRow()) stats.mastered = masterRes.getLong(0);
      masterRes.close();

      // 4. Due (今日实际待办): 这里我们存的是“积压的复习 + 还没学的新词”
      // 为了简单，这里存“总积压复习数”
      const dueRes = await store.querySql('SELECT count(*) FROM words WHERE book_id = ? AND nextReviewTime <= ?', [bookId, endOfToday.getTime()]);
      if (dueRes.goToFirstRow()) stats.due = dueRes.getLong(0);
      dueRes.close();

      // 连续打卡
      stats.streak = await this.calculateStreak();

      return stats;
    } catch (e) { return stats; }
  }

  // --- 智能获取今日单词 (复习优先 + 每日新词限额) ---
  async getTodayReviewWords(bookId: string, dailyLimit: number = 20): Promise<Word[]> {
    const store = this.rdbStore;
    if (!store) return [];
    try {
      const todayStart = new Date(); todayStart.setHours(0,0,0,0);
      const endOfToday = new Date(); endOfToday.setHours(23, 59, 59, 999);

      // 1. 查今天已学的新词数
      const learnedNewRes = await store.querySql(
        'SELECT count(*) FROM words WHERE book_id = ? AND lastReviewTime >= ? AND repetition = 1',
        [bookId, todayStart.getTime()]
      );
      let learnedNewCount = 0;
      if (learnedNewRes.goToFirstRow()) learnedNewCount = learnedNewRes.getLong(0);
      learnedNewRes.close();

      // 2. 计算剩余新词配额
      let newQuota = dailyLimit - learnedNewCount;
      if (newQuota < 0) newQuota = 0;

      // 3. 组合查询: (旧词复习) + (新词 LIMIT quota)
      const sql = `
        SELECT * FROM words
        WHERE book_id = ?
        AND (
          (lastReviewTime > 0 AND nextReviewTime <= ?)
          OR
          (lastReviewTime = 0 AND id IN (SELECT id FROM words WHERE book_id = ? AND lastReviewTime = 0 LIMIT ?))
        )
        ORDER BY CASE WHEN lastReviewTime > 0 THEN 0 ELSE 1 END ASC, nextReviewTime ASC
      `;

      const resultSet = await store.querySql(sql, [bookId, endOfToday.getTime(), bookId, newQuota]);
      const words: Word[] = [];
      while (resultSet.goToNextRow()) {
        words.push(this.mapRowToWord(resultSet));
      }
      resultSet.close();
      return words;
    } catch (err) { return []; }
  }

  // ... (其他标准方法保持不变)
  async checkBookExists(bookId: string): Promise<boolean> { const s=this.rdbStore; if(!s)return false; try{const r=await s.querySql('SELECT count(*) FROM words WHERE book_id = ?',[bookId]); let c=0; if(r.goToFirstRow())c=r.getLong(0); r.close(); return c>0;}catch(e){return false;} }
  async findAnyValidBook(): Promise<string> { const s=this.rdbStore; if(!s)return"Default Library"; try{const q='SELECT book_id,COUNT(*) as c FROM words GROUP BY book_id ORDER BY c DESC LIMIT 1'; const r=await s.querySql(q); let b="Default Library"; if(r.goToFirstRow())b=r.getString(0); r.close(); return b;}catch(e){return"Default Library";} }
  async getSpellingReviewWords(bookId: string, limit: number = 20): Promise<Word[]> { const s=this.rdbStore; if(!s)return[]; try{const q=`SELECT * FROM words WHERE book_id=? AND lastReviewTime>0 ORDER BY proficiency ASC LIMIT ?`; const r=await s.querySql(q,[bookId,limit]); const w:Word[]=[]; while(r.goToNextRow())w.push(this.mapRowToWord(r)); r.close(); return w;}catch(e){return[];} }
  async getRandomWords(bookId: string, limit: number = 20): Promise<Word[]> { const s=this.rdbStore; if(!s)return[]; try{const r=await s.querySql(`SELECT * FROM words WHERE book_id = ? ORDER BY RANDOM() LIMIT ?`,[bookId,limit]); const w:Word[]=[]; while(r.goToNextRow())w.push(this.mapRowToWord(r)); r.close(); return w;}catch(e){return[];} }
  async searchWords(bookId: string, k: string, m: number = 0): Promise<Word[]> { const s=this.rdbStore; if(!s)return[]; try{const p=new relationalStore.RdbPredicates('words'); p.equalTo('book_id',bookId); if(k&&k.trim()!=='')p.and().beginWrap().like('spelling',`%${k}%`).or().like('meaning',`%${k}%`).endWrap(); switch(m){case 1:p.orderByAsc('proficiency');break;case 2:p.orderByDesc('proficiency');break;case 3:p.orderByDesc('id');break;default:p.orderByAsc('spelling');break;} p.limitAs(100); const r=await s.query(p); const w:Word[]=[]; while(r.goToNextRow())w.push(this.mapRowToWord(r)); r.close(); return w;}catch(e){return[];} }
  async updateWordStats(id: number, interval: number, repetition: number, easeFactor: number): Promise<void> { const s=this.rdbStore; if(!s)return; const n=Date.now(); const next=n+(interval*24*60*60*1000); let np=Math.min(100,Math.round((interval/21)*100)); if(interval<=1)np=10; const v:ValuesBucket={interval,repetition,easeFactor,lastReviewTime:n,nextReviewTime:next,proficiency:np}; const p=new relationalStore.RdbPredicates('words'); p.equalTo('id',id); await s.update(v,p); }
  async updateWordInfo(w: Word): Promise<void> { const s=this.rdbStore; if(!s||!w.id)return; const v:ValuesBucket={spelling:w.spelling,phonetic:w.phonetic??'',meaning:w.meaning,example:w.example??'',note:w.note??'',roots:this.serializeArray(w.roots),affixes:this.serializeArray(w.affixes),collocations:this.serializeArray(w.collocations),synonyms:this.serializeArray(w.synonyms),antonyms:this.serializeArray(w.antonyms),derivatives:this.serializeArray(w.derivatives),senses:this.serializeArray(w.senses),knowledgeScore:w.knowledgeScore??0}; const p=new relationalStore.RdbPredicates('words'); p.equalTo('id',w.id); await s.update(v,p); }
  async updateWordNote(id: number, note: string): Promise<void> { const s=this.rdbStore; if(!s)return; const v:ValuesBucket={note}; const p=new relationalStore.RdbPredicates('words'); p.equalTo('id',id); await s.update(v,p); }
  async deleteWord(id: number): Promise<void> { const s=this.rdbStore; if(!s)return; const p=new relationalStore.RdbPredicates('words'); p.equalTo('id',id); await s.delete(p); }
  async batchInsertWords(bookId: string, words: Word[]): Promise<number> { const s=this.rdbStore; if(!s)return 0; let c=0; try{const set=new Set<string>(); const r=await s.querySql('SELECT spelling FROM words WHERE book_id = ?',[bookId]); while(r.goToNextRow())set.add(r.getString(0)); r.close(); s.beginTransaction(); for(const w of words){if(!w.spelling||set.has(w.spelling))continue; const v:ValuesBucket={book_id:bookId,spelling:w.spelling,phonetic:w.phonetic||'',meaning:w.meaning||'',example:w.example||'',note:w.note||'',roots:this.serializeArray(w.roots),affixes:this.serializeArray(w.affixes),collocations:this.serializeArray(w.collocations),synonyms:this.serializeArray(w.synonyms),antonyms:this.serializeArray(w.antonyms),derivatives:this.serializeArray(w.derivatives),senses:this.serializeArray(w.senses),knowledgeScore:w.knowledgeScore??0,proficiency:w.proficiency??0,repetition:w.repetition??0,interval:w.interval??0,easeFactor:w.easeFactor??2.5,lastReviewTime:w.lastReviewTime??0,nextReviewTime:w.nextReviewTime??0}; await s.insert('words',v); c++; set.add(w.spelling);} s.commit(); return c;}catch(e){try{s.rollBack()}catch(er){} return 0;} }
  async calculateStreak(): Promise<number> { const s=this.rdbStore; if(!s)return 0; try{const r=await s.querySql('SELECT dateStr FROM activity_log ORDER BY dateStr DESC'); const d:string[]=[]; while(r.goToNextRow())d.push(r.getString(0)); r.close(); if(d.length===0)return 0; let k=0; const t=new Date(); let h=d.includes(`${t.getFullYear()}-${(t.getMonth()+1).toString().padStart(2,'0')}-${t.getDate().toString().padStart(2,'0')}`); let c=h?new Date():(()=>{const x=new Date();x.setDate(x.getDate()-1);return x;})(); while(true){const str=`${c.getFullYear()}-${(c.getMonth()+1).toString().padStart(2,'0')}-${c.getDate().toString().padStart(2,'0')}`; if(d.includes(str)){k++;c.setDate(c.getDate()-1);}else{break;}} return k;}catch(e){return 0;} }
  async logActivity(): Promise<void> { const s=this.rdbStore; if(!s)return; const d=`${new Date().getFullYear()}-${(new Date().getMonth()+1).toString().padStart(2,'0')}-${new Date().getDate().toString().padStart(2,'0')}`; try{const r=await s.querySql('SELECT count FROM activity_log WHERE dateStr=?',[d]); let c=0; let ex=false; if(r.goToFirstRow()){c=r.getLong(0);ex=true;} r.close(); const v:ValuesBucket={dateStr:d,count:c+1}; if(ex){const p=new relationalStore.RdbPredicates('activity_log'); p.equalTo('dateStr',d); await s.update(v,p);}else{await s.insert('activity_log',v);}}catch(e){} }
  async getActivityStats(days: number=28): Promise<Map<string,number>> { const s=this.rdbStore; const m=new Map<string,number>(); if(!s)return m; try{const r=await s.querySql(`SELECT * FROM activity_log ORDER BY dateStr DESC LIMIT ?`,[days]); while(r.goToNextRow())m.set(r.getString(0),r.getLong(1)); r.close();}catch(e){} return m; }
  async getProficiencyDistribution(bookId: string): Promise<number[]> { const s=this.rdbStore; if(!s)return[0,0,0,0,0]; try{const q=`SELECT SUM(CASE WHEN proficiency<=20 THEN 1 ELSE 0 END),SUM(CASE WHEN proficiency>20 AND proficiency<=40 THEN 1 ELSE 0 END),SUM(CASE WHEN proficiency>40 AND proficiency<=60 THEN 1 ELSE 0 END),SUM(CASE WHEN proficiency>60 AND proficiency<=80 THEN 1 ELSE 0 END),SUM(CASE WHEN proficiency>80 THEN 1 ELSE 0 END) FROM words WHERE book_id=?`; const r=await s.querySql(q,[bookId]); const a=[0,0,0,0,0]; if(r.goToFirstRow()){a[0]=r.getLong(0)||0;a[1]=r.getLong(1)||0;a[2]=r.getLong(2)||0;a[3]=r.getLong(3)||0;a[4]=r.getLong(4)||0;} r.close(); return a;}catch(e){return[0,0,0,0,0];} }
  async cleanAllData(): Promise<void> { const s=this.rdbStore; if(!s)return; try{await s.executeSql('DELETE FROM words'); await s.executeSql('DELETE FROM sqlite_sequence WHERE name="words"'); await s.executeSql('DELETE FROM activity_log');}catch(e){} }
  async resetLearningProgress(bookId: string): Promise<void> { const s=this.rdbStore; if(!s)return; const v:ValuesBucket={proficiency:0,repetition:0,interval:0,easeFactor:2.5,lastReviewTime:0,nextReviewTime:0}; const p=new relationalStore.RdbPredicates('words'); p.equalTo('book_id',bookId); await s.update(v,p); }
  async recordKnowledgePractice(id: number, correct: boolean): Promise<void> { const s=this.rdbStore; if(!s)return; try{const res=await s.querySql('SELECT knowledgeScore, proficiency FROM words WHERE id=?',[id]); let score=0; let prof=0; if(res.goToFirstRow()){score=res.getLong(0)||0; prof=res.getLong(1)||0;} res.close(); const now=Date.now(); const delta=correct?5: -2; const newScore=Math.max(0, score + delta); const newProf=Math.min(100, Math.max(0, prof + (correct?3:0))); const v:ValuesBucket={knowledgeScore:newScore, proficiency:newProf, lastReviewTime:now, nextReviewTime:now + 24*60*60*1000}; const p=new relationalStore.RdbPredicates('words'); p.equalTo('id',id); await s.update(v,p); await this.logActivity(); }catch(e){} }
  private serializeArray(arr?: string[]): string { if (!arr || arr.length === 0) return '[]'; try { return JSON.stringify(arr); } catch (e) { return '[]'; } }
  private parseArray(raw: string | null): string[] { if (!raw) return []; try { const parsed: unknown = JSON.parse(raw); if (!Array.isArray(parsed)) { return []; } return parsed.map((item) => String(item)); } catch (e) { return []; } }
  private mapRowToWord(r: relationalStore.ResultSet): Word { const g=(c:string)=>{const i=r.getColumnIndex(c);return i>=0?r.getString(i):''}; const l=(c:string)=>{const i=r.getColumnIndex(c);return i>=0?r.getLong(i):0;}; const d=(c:string)=>{const i=r.getColumnIndex(c);return i>=0?r.getDouble(i):0;}; return { id:l('id'), bookId:g('book_id'), spelling:g('spelling'), phonetic:g('phonetic'), meaning:g('meaning'), example:g('example'), note:g('note'), roots:this.parseArray(g('roots')), affixes:this.parseArray(g('affixes')), collocations:this.parseArray(g('collocations')), synonyms:this.parseArray(g('synonyms')), antonyms:this.parseArray(g('antonyms')), derivatives:this.parseArray(g('derivatives')), senses:this.parseArray(g('senses')), knowledgeScore:l('knowledgeScore'), proficiency:l('proficiency'), repetition:l('repetition'), interval:l('interval'), easeFactor:d('easeFactor'), lastReviewTime:l('lastReviewTime'), nextReviewTime:l('nextReviewTime') }; }
}