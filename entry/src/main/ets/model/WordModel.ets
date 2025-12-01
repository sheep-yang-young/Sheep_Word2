export interface Word {
  id?: number;
  spelling: string;
  phonetic?: string;
  meaning: string;
  example?: string;

  // SM-2 字段
  proficiency: number;
  repetition: number;
  interval: number;
  easeFactor: number;

  lastReviewTime: number;
  nextReviewTime: number;
}

// [修改] 增加 learnedToday 字段
export class DashboardStats {
  due: number = 0;           // 今日剩余待办
  learnedToday: number = 0;  // 今日已完成
  total: number = 0;         // 总词数
  mastered: number = 0;      // 已掌握(熟练度高)
}