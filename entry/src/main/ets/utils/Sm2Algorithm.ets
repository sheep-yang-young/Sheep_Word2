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
      return { repetition: 0, interval: 1, easeFactor: Math.max(1.3, easeFactor - 0.2) };
    }

    const q = grade === ReviewGrade.HARD ? 3 : (grade === ReviewGrade.GOOD ? 4 : 5);
    easeFactor = easeFactor + (0.1 - (5 - q) * (0.08 + (5 - q) * 0.02));
    if (easeFactor < 1.3) easeFactor = 1.3;

    repetition += 1;
    if (repetition === 1) interval = 1;
    else if (repetition === 2) interval = 6;
    else interval = Math.ceil(interval * easeFactor);

    return { interval, repetition, easeFactor };
  }
}