import { Word } from '../model/WordModel';

export enum ReviewGrade {
  AGAIN = 0,
  HARD = 1,
  GOOD = 2,
  EASY = 3
}

export interface Sm2Result {
  interval: number;
  repetition: number;
  easeFactor: number;
}

export class Sm2Algorithm {
  static calculate(word: Word, grade: ReviewGrade): Sm2Result {
    let interval = word.interval;
    let repetition = word.repetition;
    let easeFactor = word.easeFactor;

    if (grade === ReviewGrade.AGAIN) {
      // 忘记了，重置进度
      return { repetition: 0, interval: 1, easeFactor: Math.max(1.3, easeFactor - 0.2) };
    }

    // 动态调整难度因子
    const q = grade === ReviewGrade.HARD ? 3 : (grade === ReviewGrade.GOOD ? 4 : 5);
    easeFactor = easeFactor + (0.1 - (5 - q) * (0.08 + (5 - q) * 0.02));
    if (easeFactor < 1.3) easeFactor = 1.3;

    repetition += 1;

    // --- [核心修改点] ---
    if (repetition === 1) {
      // 是新词第一次背诵
      if (grade === ReviewGrade.EASY) {
        // 【修改策略】：如果第一次就觉得简单，说明可能是熟词。
        // 直接设置间隔为 22 天（在 DatabaseManager 中计算熟练度时，22/21 > 100%，直接算掌握）
        // 如果你觉得 22 天太激进，可以改成 7 天（熟练度约 33%）
        interval = 22;
      } else {
        // 普通或困难，按标准算法，明天复习
        interval = 1;
      }
    } else if (repetition === 2) {
      // 第二次复习
      if (grade === ReviewGrade.EASY) {
        interval = 15; // 如果连续觉得简单，步子跨大一点
      } else {
        interval = 6; // 标准 SM2 步长
      }
    } else {
      // 后续复习：间隔 = 上次间隔 * 难度因子
      interval = Math.ceil(interval * easeFactor);
    }

    // 额外的修正：如果选了 Easy，我们可以给予一点额外的间隔奖励
    if (grade === ReviewGrade.EASY && repetition > 2) {
      interval = Math.ceil(interval * 1.3);
    }

    return { interval, repetition, easeFactor };
  }
}