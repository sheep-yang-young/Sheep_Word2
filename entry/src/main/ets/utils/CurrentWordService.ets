import { Word } from '../model/WordModel';
import hilog from '@ohos.hilog';

const DOMAIN: number = 0xA0A03D;
const TAG: string = 'CurrentWordService';

/**
 * Concrete snapshot implementation to satisfy ArkTS requirements that object
 * literals map to a declared class or interface without relying on restricted
 * standard library helpers.
 */
class WordSnapshot implements Word {
  id?: number;
  bookId: string = '';
  spelling: string = '';
  phonetic?: string;
  meaning: string = '';
  example?: string;
  note?: string;
  roots?: string[];
  affixes?: string[];
  collocations?: string[];
  synonyms?: string[];
  antonyms?: string[];
  derivatives?: string[];
  senses?: string[];
  knowledgeScore?: number;
  proficiency: number = 0;
  repetition: number = 0;
  interval: number = 0;
  easeFactor: number = 0;
  lastReviewTime: number = 0;
  nextReviewTime: number = 0;
  proficiencySpelling?: number;
  repetitionSpelling?: number;
  intervalSpelling?: number;
  easeFactorSpelling?: number;
  lastReviewTimeSpelling?: number;
  nextReviewTimeSpelling?: number;
}

/**
 * Lightweight shared store for the word currently being studied in the UI.
 *
 * The data is mirrored into AppStorage so non-component code (e.g., floating ball manager)
 * can still retrieve the latest value even after navigation.
 */
export class CurrentWordService {
  private static inst: CurrentWordService = new CurrentWordService();
  private currentWord: Word | null = null;

  static getInstance(): CurrentWordService {
    return CurrentWordService.inst;
  }

  setCurrentWord(word: Word | null): void {
    if (word) {
      const cloned: Word = this.cloneWord(word);
      this.currentWord = cloned;
      AppStorage.setOrCreate('CurrentStudyWord', cloned);
      hilog.debug(DOMAIN, TAG, 'Set current word to %{public}s', word.spelling);
    } else {
      this.currentWord = null;
      AppStorage.setOrCreate('CurrentStudyWord', null);
      hilog.debug(DOMAIN, TAG, 'Cleared current word');
    }
  }

  getCurrentWord(): Word | null {
    if (this.currentWord) {
      return this.currentWord;
    }
    const stored = AppStorage.get<Word>('CurrentStudyWord');
    if (stored) {
      this.currentWord = stored;
      return stored;
    }
    hilog.debug(DOMAIN, TAG, 'No current word available');
    return null;
  }

  /**
   * ArkTS limits standard library usage and dynamic object composition. Build
   * a shallow clone manually so the returned literal exactly matches the Word
   * interface while avoiding Object.assign/spread.
   */
  private cloneWord(source: Word): Word {
    const cloned: Word = {
      bookId: source.bookId,
      spelling: source.spelling,
      meaning: source.meaning,
      proficiency: source.proficiency,
      repetition: source.repetition,
      interval: source.interval,
      easeFactor: source.easeFactor,
      lastReviewTime: source.lastReviewTime,
      nextReviewTime: source.nextReviewTime
    };

    if (source.id !== undefined) { cloned.id = source.id; }
    if (source.phonetic !== undefined) { cloned.phonetic = source.phonetic; }
    if (source.example !== undefined) { cloned.example = source.example; }
    if (source.note !== undefined) { cloned.note = source.note; }
    if (source.roots !== undefined) { cloned.roots = source.roots; }
    if (source.affixes !== undefined) { cloned.affixes = source.affixes; }
    if (source.collocations !== undefined) { cloned.collocations = source.collocations; }
    if (source.synonyms !== undefined) { cloned.synonyms = source.synonyms; }
    if (source.antonyms !== undefined) { cloned.antonyms = source.antonyms; }
    if (source.derivatives !== undefined) { cloned.derivatives = source.derivatives; }
    if (source.senses !== undefined) { cloned.senses = source.senses; }
    if (source.knowledgeScore !== undefined) { cloned.knowledgeScore = source.knowledgeScore; }
    if (source.proficiencySpelling !== undefined) { cloned.proficiencySpelling = source.proficiencySpelling; }
    if (source.repetitionSpelling !== undefined) { cloned.repetitionSpelling = source.repetitionSpelling; }
    if (source.intervalSpelling !== undefined) { cloned.intervalSpelling = source.intervalSpelling; }
    if (source.easeFactorSpelling !== undefined) { cloned.easeFactorSpelling = source.easeFactorSpelling; }
    if (source.lastReviewTimeSpelling !== undefined) { cloned.lastReviewTimeSpelling = source.lastReviewTimeSpelling; }
    if (source.nextReviewTimeSpelling !== undefined) { cloned.nextReviewTimeSpelling = source.nextReviewTimeSpelling; }

    return cloned;
  }
}
