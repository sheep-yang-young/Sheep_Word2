import { Word } from '../model/WordModel';
import hilog from '@ohos.hilog';

const DOMAIN: number = 0xA0A03D;
const TAG: string = 'CurrentWordService';

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
      // Shallow copy to avoid external mutations from breaking our cache
      const cloned: Word = Object.assign({}, word);
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
}
