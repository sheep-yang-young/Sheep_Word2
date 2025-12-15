export interface Word {
  id?: number;
  bookId: string;
  spelling: string;
  phonetic?: string;
  meaning: string;
  example?: string;
  note?: string;

  // 拓展词汇知识
  roots?: string[];
  affixes?: string[];
  collocations?: string[];
  synonyms?: string[];
  antonyms?: string[];
  derivatives?: string[];
  senses?: string[];

  // 练习反馈
  knowledgeScore?: number;

  // --- 认知模式 (Card Mode) 记忆算法字段 ---
  proficiency: number;
  repetition: number;
  interval: number;
  easeFactor: number;
  lastReviewTime: number;
  nextReviewTime: number;

  // --- [新增] 拼写模式 (Spelling Mode) 独立记忆算法字段 ---
  proficiencySpelling?: number;
  repetitionSpelling?: number;
  intervalSpelling?: number;
  easeFactorSpelling?: number;
  lastReviewTimeSpelling?: number;
  nextReviewTimeSpelling?: number;
}

export class DashboardStats {
  due: number = 0;           // 今日待办总数
  dueReviews: number = 0;    // 仅待复习
  newToday: number = 0;      // 今日新词
  learnedToday: number = 0;  // 今日已学
  total: number = 0;         // 总数
  mastered: number = 0;      // 已掌握
  streak: number = 0;        // 连续打卡
}