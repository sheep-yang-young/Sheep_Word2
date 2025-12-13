import { DatabaseManager } from './DatabaseManager';
import { Sm2Algorithm, ReviewGrade } from './Sm2Algorithm';
import { Word } from '../model/WordModel';

export async function fetchReviewWords(bookId: string, limit: number): Promise<Word[]> {
  return DatabaseManager.getInstance().getTodayReviewWords(bookId, limit);
}

export async function commitReviewResult(word: Word, grade: ReviewGrade): Promise<void> {
  const result = Sm2Algorithm.calculate(word, grade);
  if (word.id !== undefined) {
    await DatabaseManager.getInstance().updateWordStats(word.id, result.interval, result.repetition, result.easeFactor);
    await DatabaseManager.getInstance().logActivity();
  }
}
