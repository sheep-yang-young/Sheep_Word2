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
        const columns = ['book_id', 'note', 'roots', 'affixes', 'collocations', 'synonyms', 'antonyms', 'derivatives', 'senses', 'knowledgeScore'];
        for (const col of columns) {
          try { await store.executeSql(`ALTER TABLE words ADD COLUMN ${col} TEXT`); } catch (e) {}
        }
        try { await store.executeSql('UPDATE words SET book_id = "Default Library" WHERE book_id IS NULL OR book_id = ""'); } catch (e) {}
        await store.executeSql(`CREATE TABLE IF NOT EXISTS activity_log (
          dateStr TEXT NOT NULL,
          book_id TEXT NOT NULL DEFAULT 'Default Library',
          count INTEGER DEFAULT 0,
          PRIMARY KEY(dateStr, book_id)
        )`);
        await this.ensureActivityLogScoped(store);
      }
    } catch (err) {
      console.error(`[Lumina] DB Init failed: ${JSON.stringify(err)}`);
    }
  }

  // --- 统计逻辑 ---
  async getDashboardStats(bookId: string): Promise<DashboardStats> {
    let stats = new DashboardStats();
    const store = this.rdbStore;
    if (!store) return stats;

    try {
      const todayStart = new Date(); todayStart.setHours(0,0,0,0);
      const endOfToday = new Date(); endOfToday.setHours(23, 59, 59, 999);

      const totalRes = await store.querySql('SELECT count(*) FROM words WHERE book_id = ?', [bookId]);
      if (totalRes.goToFirstRow()) stats.total = totalRes.getLong(0);
      totalRes.close();

      const learnedRes = await store.querySql('SELECT count(*) FROM words WHERE book_id = ? AND lastReviewTime >= ?', [bookId, todayStart.getTime()]);
      if (learnedRes.goToFirstRow()) stats.learnedToday = learnedRes.getLong(0);
      learnedRes.close();

      const masterRes = await store.querySql('SELECT count(*) FROM words WHERE book_id = ? AND (proficiency >= 100 OR interval > 21)', [bookId]);
      if (masterRes.goToFirstRow()) stats.mastered = masterRes.getLong(0);
      masterRes.close();

      const dueRes = await store.querySql(
        'SELECT count(*) FROM words WHERE book_id = ? AND lastReviewTime > 0 AND nextReviewTime <= ?',
        [bookId, endOfToday.getTime()]
      );
      if (dueRes.goToFirstRow()) stats.due = dueRes.getLong(0);
      dueRes.close();

      stats.streak = await this.calculateStreak(bookId);
      return stats;
    } catch (e) { return stats; }
  }

  // --- 万能取词 ---
  async getRandomWords(bookId: string, limit: number = 20): Promise<Word[]> {
    const s=this.rdbStore;
    if(!s)return[];
    try {
      let r = await s.querySql(`SELECT * FROM words WHERE book_id = ? ORDER BY RANDOM() LIMIT ?`, [bookId, limit]);
      let w: Word[] = [];
      while(r.goToNextRow()) w.push(this.mapRowToWord(r));
      r.close();

      if (w.length === 0) {
        const validBook = await this.findAnyValidBook();
        if (validBook !== "Default Library" && validBook !== bookId) {
          r = await s.querySql(`SELECT * FROM words WHERE book_id = ? ORDER BY RANDOM() LIMIT ?`, [validBook, limit]);
          while(r.goToNextRow()) w.push(this.mapRowToWord(r));
          r.close();
        }
      }
      if (w.length === 0) {
        r = await s.querySql(`SELECT * FROM words ORDER BY RANDOM() LIMIT ?`, [limit]);
        while(r.goToNextRow()) w.push(this.mapRowToWord(r));
        r.close();
      }
      return w;
    } catch(e) { return []; }
  }

  // --- 辅助查询 ---
  async findAnyValidBook(): Promise<string> {
    const s=this.rdbStore;
    if(!s)return"Default Library";
    try{
      const q='SELECT book_id FROM words GROUP BY book_id HAVING count(*) > 0 LIMIT 1';
      const r=await s.querySql(q);
      let b="Default Library";
      if(r.goToFirstRow()) b = r.getString(0);
      r.close();
      return b || "Default Library";
    } catch(e){ return"Default Library"; }
  }

  async checkBookExists(bookId: string): Promise<boolean> { const s=this.rdbStore; if(!s)return false; try{const r=await s.querySql('SELECT count(*) FROM words WHERE book_id = ?',[bookId]); let c=0; if(r.goToFirstRow())c=r.getLong(0); r.close(); return c>0;}catch(e){return false;} }
  async getTodayReviewWords(bookId: string, dailyLimit: number = 20): Promise<Word[]> { const s=this.rdbStore; if(!s) return []; try { const endOfToday = new Date(); endOfToday.setHours(23, 59, 59, 999); const sql = `SELECT * FROM words WHERE book_id = ? AND ((lastReviewTime > 0 AND nextReviewTime <= ?) OR (lastReviewTime = 0 AND id IN (SELECT id FROM words WHERE book_id = ? AND lastReviewTime = 0 LIMIT ?))) ORDER BY CASE WHEN lastReviewTime > 0 THEN 0 ELSE 1 END ASC, nextReviewTime ASC`; const r = await s.querySql(sql, [bookId, endOfToday.getTime(), bookId, dailyLimit]); const w: Word[] = []; while (r.goToNextRow()) { w.push(this.mapRowToWord(r)); } r.close(); return w; } catch (err) { return []; } }
  async getSpellingReviewWords(bookId: string, limit: number = 20): Promise<Word[]> { const s=this.rdbStore; if(!s)return[]; try{const q=`SELECT * FROM words WHERE book_id=? AND lastReviewTime>0 ORDER BY proficiency ASC LIMIT ?`; const r=await s.querySql(q,[bookId,limit]); const w:Word[]=[]; while(r.goToNextRow())w.push(this.mapRowToWord(r)); r.close(); return w;}catch(e){return[];} }
  async searchWords(bookId: string, k: string, m: number = 0): Promise<Word[]> { const s=this.rdbStore; if(!s)return[]; try{const p=new relationalStore.RdbPredicates('words'); p.equalTo('book_id',bookId); if(k&&k.trim()!=='')p.and().beginWrap().like('spelling',`%${k}%`).or().like('meaning',`%${k}%`).endWrap(); switch(m){case 1:p.orderByAsc('proficiency');break;case 2:p.orderByDesc('proficiency');break;case 3:p.orderByDesc('id');break;default:p.orderByAsc('spelling');break;} p.limitAs(100); const r=await s.query(p); const w:Word[]=[]; while(r.goToNextRow())w.push(this.mapRowToWord(r)); r.close(); return w;}catch(e){return[];} }

  // [核心修复] 更新熟练度逻辑：间隔达到 7 天即视为 100% 掌握，反馈更灵敏
  async updateWordStats(id: number, interval: number, repetition: number, easeFactor: number): Promise<void> {
    const s=this.rdbStore; if(!s)return;
    const n=Date.now();
    const next=n+(interval*24*60*60*1000);

    // 原公式 interval/21 太慢，改为 interval/7。
    // 这意味着：Easy (约4天) -> 57% 熟练度；Hard (约1天) -> 14%。第二次 Easy -> 100%。
    let np=Math.min(100, Math.round((interval / 7) * 100));

    // 只要开始学了，至少给 5 分
    if(repetition>0 && np<5) np=5;

    const v:ValuesBucket={interval,repetition,easeFactor,lastReviewTime:n,nextReviewTime:next,proficiency:np};
    const p=new relationalStore.RdbPredicates('words');
    p.equalTo('id',id);
    await s.update(v,p);
  }

  async updateWordInfo(w: Word): Promise<void> { const s=this.rdbStore; if(!s||!w.id)return; const v:ValuesBucket={spelling:w.spelling,phonetic:w.phonetic??'',meaning:w.meaning,example:w.example??'',note:w.note??'',roots:this.serializeArray(w.roots),affixes:this.serializeArray(w.affixes),collocations:this.serializeArray(w.collocations),synonyms:this.serializeArray(w.synonyms),antonyms:this.serializeArray(w.antonyms),derivatives:this.serializeArray(w.derivatives),senses:this.serializeArray(w.senses),knowledgeScore:w.knowledgeScore??0}; const p=new relationalStore.RdbPredicates('words'); p.equalTo('id',w.id); await s.update(v,p); }
  async updateWordNote(id: number, note: string): Promise<void> { const s=this.rdbStore; if(!s)return; const v:ValuesBucket={note}; const p=new relationalStore.RdbPredicates('words'); p.equalTo('id',id); await s.update(v,p); }
  async deleteWord(id: number): Promise<void> { const s=this.rdbStore; if(!s)return; const p=new relationalStore.RdbPredicates('words'); p.equalTo('id',id); await s.delete(p); }
  async batchInsertWords(bookId: string, words: Word[]): Promise<number> { const s=this.rdbStore; if(!s)return 0; let c=0; try{const set=new Set<string>(); try{const r=await s.querySql('SELECT spelling FROM words WHERE book_id = ?',[bookId]); while(r.goToNextRow())set.add(r.getString(0)); r.close();}catch(e){} s.beginTransaction(); for(const w of words){if(!w.spelling||set.has(w.spelling))continue; const v:ValuesBucket={book_id:bookId,spelling:w.spelling,phonetic:w.phonetic||'',meaning:w.meaning||'',example:w.example||'',note:w.note||'',roots:this.serializeArray(w.roots),affixes:this.serializeArray(w.affixes),collocations:this.serializeArray(w.collocations),synonyms:this.serializeArray(w.synonyms),antonyms:this.serializeArray(w.antonyms),derivatives:this.serializeArray(w.derivatives),senses:this.serializeArray(w.senses),knowledgeScore:w.knowledgeScore??0,proficiency:w.proficiency??0,repetition:w.repetition??0,interval:w.interval??0,easeFactor:w.easeFactor??2.5,lastReviewTime:w.lastReviewTime??0,nextReviewTime:w.nextReviewTime??0}; await s.insert('words',v); c++; set.add(w.spelling);} s.commit(); return c;}catch(e){try{s.rollBack()}catch(er){} return 0;} }
  async cleanAllData(): Promise<void> { const s=this.rdbStore; if(!s)return; try{await s.executeSql('DELETE FROM words'); await s.executeSql('DELETE FROM sqlite_sequence WHERE name="words"'); await s.executeSql('DELETE FROM activity_log');}catch(e){} }
  async resetLearningProgress(bookId: string): Promise<void> { const s=this.rdbStore; if(!s)return; const v:ValuesBucket={proficiency:0,repetition:0,interval:0,easeFactor:2.5,lastReviewTime:0,nextReviewTime:0}; const p=new relationalStore.RdbPredicates('words'); p.equalTo('book_id',bookId); await s.update(v,p); }
  async recordKnowledgePractice(id: number, correct: boolean): Promise<void> { const s=this.rdbStore; if(!s)return; try{const res=await s.querySql('SELECT knowledgeScore, proficiency, book_id FROM words WHERE id=?',[id]); let score=0; let prof=0; let book='Default Library'; if(res.goToFirstRow()){score=res.getLong(0)||0; prof=res.getLong(1)||0; book=res.getString(2)||'Default Library';} res.close(); const now=Date.now(); const delta=correct?5: -2; const newScore=Math.max(0, score + delta); const newProf=Math.min(100, Math.max(0, prof + (correct?3:0))); const v:ValuesBucket={knowledgeScore:newScore, proficiency:newProf, lastReviewTime:now, nextReviewTime:now + 24*60*60*1000}; const p=new relationalStore.RdbPredicates('words'); p.equalTo('id',id); await s.update(v,p); await this.logActivity(book); }catch(e){} }
  async calculateStreak(bookId: string): Promise<number> { const s=this.rdbStore; if(!s)return 0; try{const r=await s.querySql('SELECT dateStr FROM activity_log WHERE book_id = ? ORDER BY dateStr DESC',[bookId]); const d:string[]=[]; while(r.goToNextRow())d.push(r.getString(0)); r.close(); if(d.length===0)return 0; let k=0; const t=new Date(); let h=d.includes(`${t.getFullYear()}-${(t.getMonth()+1).toString().padStart(2,'0')}-${t.getDate().toString().padStart(2,'0')}`); let c=h?new Date():(()=>{const x=new Date();x.setDate(x.getDate()-1);return x;})(); while(true){const str=`${c.getFullYear()}-${(c.getMonth()+1).toString().padStart(2,'0')}-${c.getDate().toString().padStart(2,'0')}`; if(d.includes(str)){k++;c.setDate(c.getDate()-1);}else{break;}} return k;}catch(e){return 0;} }
  async logActivity(bookId: string): Promise<void> { const s=this.rdbStore; if(!s)return; const d=`${new Date().getFullYear()}-${(new Date().getMonth()+1).toString().padStart(2,'0')}-${new Date().getDate().toString().padStart(2,'0')}`; try{const r=await s.querySql('SELECT count FROM activity_log WHERE dateStr=? AND book_id=?',[d,bookId]); let c=0; let ex=false; if(r.goToFirstRow()){c=r.getLong(0);ex=true;} r.close(); const v:ValuesBucket={dateStr:d,book_id:bookId,count:c+1}; if(ex){const p=new relationalStore.RdbPredicates('activity_log'); p.equalTo('dateStr',d); p.and(); p.equalTo('book_id',bookId); await s.update(v,p);}else{await s.insert('activity_log',v);}}catch(e){} }
  async getActivityStats(bookId: string, days: number=28): Promise<Map<string,number>> { const s=this.rdbStore; const m=new Map<string,number>(); if(!s)return m; try{const r=await s.querySql(`SELECT dateStr, count FROM activity_log WHERE book_id = ? ORDER BY dateStr DESC LIMIT ?`,[bookId,days]); while(r.goToNextRow())m.set(r.getString(0),r.getLong(1)); r.close();}catch(e){} return m; }
  private async ensureActivityLogScoped(store: relationalStore.RdbStore): Promise<void> { try{const info=await store.querySql("PRAGMA table_info(activity_log)"); let hasBook=false; const nameIdx=info.getColumnIndex('name'); while(info.goToNextRow()){if(info.getString(nameIdx)==='book_id'){hasBook=true;break;}} info.close(); if(hasBook)return; await store.executeSql(`CREATE TABLE IF NOT EXISTS activity_log_new (dateStr TEXT NOT NULL, book_id TEXT NOT NULL DEFAULT 'Default Library', count INTEGER DEFAULT 0, PRIMARY KEY(dateStr, book_id))`); try{await store.executeSql(`INSERT OR IGNORE INTO activity_log_new (dateStr, book_id, count) SELECT dateStr, 'Default Library', count FROM activity_log`);}catch(e){} await store.executeSql('DROP TABLE IF EXISTS activity_log'); await store.executeSql('ALTER TABLE activity_log_new RENAME TO activity_log');}catch(e){} }
  async getProficiencyDistribution(bookId: string): Promise<number[]> { const s=this.rdbStore; if(!s)return[0,0,0,0,0]; try{const q=`SELECT SUM(CASE WHEN proficiency<=20 THEN 1 ELSE 0 END),SUM(CASE WHEN proficiency>20 AND proficiency<=40 THEN 1 ELSE 0 END),SUM(CASE WHEN proficiency>40 AND proficiency<=60 THEN 1 ELSE 0 END),SUM(CASE WHEN proficiency>60 AND proficiency<=80 THEN 1 ELSE 0 END),SUM(CASE WHEN proficiency>80 THEN 1 ELSE 0 END) FROM words WHERE book_id=?`; const r=await s.querySql(q,[bookId]); const a=[0,0,0,0,0]; if(r.goToFirstRow()){a[0]=r.getLong(0)||0;a[1]=r.getLong(1)||0;a[2]=r.getLong(2)||0;a[3]=r.getLong(3)||0;a[4]=r.getLong(4)||0;} r.close(); return a;}catch(e){return[0,0,0,0,0];} }
  private serializeArray(arr?: string[]): string { if (!arr || arr.length === 0) return '[]'; try { return JSON.stringify(arr); } catch (e) { return '[]'; } }
  private parseArray(raw: string | null): string[] { if (!raw) return []; try { const parsed: object = JSON.parse(raw) as object; if (!Array.isArray(parsed)) return []; return (parsed as object[]).map((item) => String(item)); } catch (e) { return []; } }
  private mapRowToWord(r: relationalStore.ResultSet): Word { const g=(c:string)=>{const i=r.getColumnIndex(c);return i>=0?r.getString(i):''}; const l=(c:string)=>{const i=r.getColumnIndex(c);return i>=0?r.getLong(i):0;}; const d=(c:string)=>{const i=r.getColumnIndex(c);return i>=0?r.getDouble(i):0;}; return { id:l('id'), bookId:g('book_id'), spelling:g('spelling'), phonetic:g('phonetic'), meaning:g('meaning'), example:g('example'), note:g('note'), roots:this.parseArray(g('roots')), affixes:this.parseArray(g('affixes')), collocations:this.parseArray(g('collocations')), synonyms:this.parseArray(g('synonyms')), antonyms:this.parseArray(g('antonyms')), derivatives:this.parseArray(g('derivatives')), senses:this.parseArray(g('senses')), knowledgeScore:l('knowledgeScore'), proficiency:l('proficiency'), repetition:l('repetition'), interval:l('interval'), easeFactor:d('easeFactor'), lastReviewTime:l('lastReviewTime'), nextReviewTime:l('nextReviewTime') }; }
}