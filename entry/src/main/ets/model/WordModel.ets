export interface Word {
  id?: number;
  bookId: string; // 核心字段：所属词书
  spelling: string;
  phonetic?: string;
  meaning: string;
  example?: string;
  note?: string;

  // SM-2 记忆算法字段
  proficiency: number;
  repetition: number;
  interval: number;
  easeFactor: number;

  lastReviewTime: number;
  nextReviewTime: number;
}

export class DashboardStats {
  due: number = 0;           // 今日待办
  learnedToday: number = 0;  // 今日已学
  total: number = 0;         // 总数
  mastered: number = 0;      // 已掌握
  streak: number = 0;        // 连续打卡
}