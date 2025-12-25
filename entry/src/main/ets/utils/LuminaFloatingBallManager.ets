import hilog from '@ohos.hilog';
import { common } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import floatingBall from '@ohos.window.floatingBall';
import { CurrentWordService } from './CurrentWordService';
import { DatabaseManager } from './DatabaseManager';
import { PreferenceManager } from './PreferenceManager';
import { promptAction } from '@kit.ArkUI';
import { Word } from '../model/WordModel';

const DOMAIN: number = 0xA0A03D;
const TAG: string = 'LuminaBall';

export class LuminaFloatingBallManager {
  private static inst: LuminaFloatingBallManager = new LuminaFloatingBallManager();

  private ctx: common.UIAbilityContext | null = null;
  private controller: floatingBall.FloatingBallController | null = null;
  private started: boolean = false;

  static getInstance(): LuminaFloatingBallManager {
    return LuminaFloatingBallManager.inst;
  }

  init(context: common.UIAbilityContext): void {
    this.ctx = context;
  }

  /**
   * 启动悬浮球
   */
  async start(): Promise<void> {
    if (!this.ctx) {
      hilog.warn(DOMAIN, TAG, 'Floating ball start skipped: context not initialized');
      return;
    }
    if (this.started) {
      hilog.info(DOMAIN, TAG, 'Already started');
      return;
    }

    try {
      hilog.info(DOMAIN, TAG, 'Attempting to create floating ball...');

      this.controller = await floatingBall.create({ context: this.ctx });

      if (!this.controller) {
        hilog.error(DOMAIN, TAG, 'Controller creation failed (null)');
        return;
      }

      hilog.info(DOMAIN, TAG, 'FloatingBallController created');

      // 设置点击监听
      this.controller.on('click', () => {
        hilog.info(DOMAIN, TAG, 'onClick event received from floating ball');
        this.onBallClick();
      });

      // 设置状态监听
      this.controller.on('stateChange', (st: floatingBall.FloatingBallState) => {
        hilog.info(DOMAIN, TAG, 'stateChange=%{public}s', JSON.stringify(st));
      });

      // 设置属性
      const params: floatingBall.FloatingBallParams = {
        template: floatingBall.FloatingBallTemplate.NORMAL,
        title: '收藏单词',
        content: '保存当前学习'
      };

      await this.controller.startFloatingBall(params);
      this.started = true;
      hilog.info(DOMAIN, TAG, 'startFloatingBall OK with params=%{public}s', JSON.stringify(params));
    } catch (err) {
      const error = err as BusinessError;
      hilog.error(DOMAIN, TAG, 'startFloatingBall FAILED: %{public}s', JSON.stringify(error));
    }
  }

  /**
   * 停止悬浮球
   */
  async stop(): Promise<void> {
    try {
      if (this.controller) {
        await this.controller.stopFloatingBall();
        this.controller.off('click');
        this.controller.off('stateChange');
        // 销毁引用
        this.controller = null;
      }
      this.started = false;
      hilog.info(DOMAIN, TAG, 'stopFloatingBall OK');
    } catch (err) {
      const error = err as BusinessError;
      hilog.warn(DOMAIN, TAG, 'stopFloatingBall err=%{public}s', JSON.stringify(error));
    } finally {
      this.started = false;
    }
  }

  private async onBallClick(): Promise<void> {
    hilog.info(DOMAIN, TAG, 'onBallClick invoked');

    if (!this.ctx) {
      hilog.error(DOMAIN, TAG, 'onBallClick aborted: context missing');
      return;
    }

    if (!CurrentWordService.getInstance().isInReviewSession()) {
      hilog.warn(DOMAIN, TAG, 'onBallClick aborted: not in review session');
      try { promptAction.showToast({ message: '你没有在背单词' }); } catch (e) {}
      return;
    }

    const currentWord = CurrentWordService.getInstance().getCurrentWord();
    if (!currentWord || !currentWord.spelling) {
      hilog.warn(DOMAIN, TAG, 'onBallClick aborted: no current word');
      try { promptAction.showToast({ message: '暂无正在学习的单词' }); } catch (e) {}
      return;
    }

    const targetBook = await PreferenceManager.getInstance().getCurrentBook();
    const normalizedWord = await this.buildPersistableWord(currentWord, targetBook);
    try {
      const insertedId = await DatabaseManager.getInstance().addWord(normalizedWord);
      if (insertedId > 0) {
        hilog.info(DOMAIN, TAG, 'Word added via floating ball: %{public}s', normalizedWord.spelling);
        try { promptAction.showToast({ message: `已添加：${normalizedWord.spelling}` }); } catch (e) {}
      } else {
        hilog.info(DOMAIN, TAG, 'Word already exists or failed to insert: %{public}s', normalizedWord.spelling);
        try { promptAction.showToast({ message: '当前词书已包含该单词' }); } catch (e) {}
      }
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'onBallClick insert failed %{public}s', JSON.stringify(err));
      try { promptAction.showToast({ message: '保存单词时出错' }); } catch (e) {}
    }
  }

  private async buildPersistableWord(word: Word, targetBook: string): Promise<Word> {
    let bookId = targetBook;
    if (!bookId || bookId.trim().length === 0) {
      bookId = word.bookId;
    }

    if (!bookId || bookId.trim().length === 0) {
      try {
        bookId = await PreferenceManager.getInstance().getCurrentBook();
      } catch (e) {
        hilog.warn(DOMAIN, TAG, 'Fallback book id fetch failed %{public}s', JSON.stringify(e));
      }
    }

    const normalized: Word = {
      bookId: bookId || 'Default Library',
      spelling: word.spelling || '',
      meaning: word.meaning || '',
      phonetic: word.phonetic || '',
      example: word.example || '',
      note: word.note || '',
      roots: word.roots || [],
      affixes: word.affixes || [],
      collocations: word.collocations || [],
      synonyms: word.synonyms || [],
      antonyms: word.antonyms || [],
      derivatives: word.derivatives || [],
      senses: word.senses || [],
      knowledgeScore: word.knowledgeScore ?? 0,
      proficiency: word.proficiency ?? 0,
      repetition: word.repetition ?? 0,
      interval: word.interval ?? 0,
      easeFactor: word.easeFactor ?? 2.5,
      lastReviewTime: word.lastReviewTime ?? 0,
      nextReviewTime: word.nextReviewTime ?? 0,
      proficiencySpelling: word.proficiencySpelling ?? 0,
      repetitionSpelling: word.repetitionSpelling ?? 0,
      intervalSpelling: word.intervalSpelling ?? 0,
      easeFactorSpelling: word.easeFactorSpelling ?? 2.5,
      lastReviewTimeSpelling: word.lastReviewTimeSpelling ?? 0,
      nextReviewTimeSpelling: word.nextReviewTimeSpelling ?? 0
    };

    if (word.id !== undefined) {
      normalized.id = word.id;
    }
    return normalized;
  }
}