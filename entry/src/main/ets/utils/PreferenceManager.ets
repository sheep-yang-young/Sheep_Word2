import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { promptAction } from '@kit.ArkUI';

const PREF_NAME = 'LuminaPrefs';
const KEY_DAILY_LIMIT = 'daily_limit';
const KEY_ACCENT_TYPE = 'accent_type';
const KEY_HAPTIC_ENABLED = 'haptic_enabled';
const KEY_REVIEW_MODE = 'review_mode';
const KEY_TTS_SPEED = 'tts_speed';
const KEY_CURRENT_BOOK = 'current_book';
const KEY_FIRST_LAUNCH = 'first_launch_v2';
const KEY_TIME_ATTACK_STATE = 'time_attack_state';
const KEY_CODE_MODE = 'is_code_mode';
const KEY_BOOK_CATEGORY_REGISTRY = 'book_category_registry';

// 定义编程相关的关键词
const CODE_KEYWORDS = ['code', 'program', 'java', 'python', 'cpp', 'c++', 'algorithm', '编程', '代码', '算法'];

export class PreferenceManager {
  private static instance: PreferenceManager;
  private pref: preferences.Preferences | null = null;

  private constructor() {}

  public static getInstance(): PreferenceManager {
    if (!PreferenceManager.instance) {
      PreferenceManager.instance = new PreferenceManager();
    }
    return PreferenceManager.instance;
  }

  async init(context: common.Context): Promise<void> {
    if (this.pref) return;
    try {
      this.pref = await preferences.getPreferences(context, PREF_NAME);
    } catch (e) {
      console.error('[Lumina] Pref init failed', e);
    }
  }

  async isFirstLaunch(): Promise<boolean> {
    if (!this.pref) return true;
    return (await this.pref.get(KEY_FIRST_LAUNCH, true)) as boolean;
  }

  async setFirstLaunch(isFirst: boolean): Promise<void> {
    if (!this.pref) return;
    await this.pref.put(KEY_FIRST_LAUNCH, isFirst);
    await this.pref.flush();
  }

  async getDailyLimit(): Promise<number> { if (!this.pref) return 20; return (await this.pref.get(KEY_DAILY_LIMIT, 20)) as number; }
  async setDailyLimit(limit: number): Promise<void> { if (!this.pref) return; await this.pref.put(KEY_DAILY_LIMIT, limit); await this.pref.flush(); }

  async getAccentType(): Promise<number> { if (!this.pref) return 2; return (await this.pref.get(KEY_ACCENT_TYPE, 2)) as number; }
  async setAccentType(type: number): Promise<void> { if (!this.pref) return; await this.pref.put(KEY_ACCENT_TYPE, type); await this.pref.flush(); }

  async isHapticEnabled(): Promise<boolean> { if (!this.pref) return true; return (await this.pref.get(KEY_HAPTIC_ENABLED, true)) as boolean; }
  async setHapticEnabled(enabled: boolean): Promise<void> { if (!this.pref) return; await this.pref.put(KEY_HAPTIC_ENABLED, enabled); await this.pref.flush(); }

  async getReviewMode(): Promise<number> { if (!this.pref) return 0; return (await this.pref.get(KEY_REVIEW_MODE, 0)) as number; }
  async setReviewMode(mode: number): Promise<void> { if (!this.pref) return; await this.pref.put(KEY_REVIEW_MODE, mode); await this.pref.flush(); }

  async getTtsSpeed(): Promise<number> { if (!this.pref) return 1.0; return (await this.pref.get(KEY_TTS_SPEED, 1.0)) as number; }
  async setTtsSpeed(speed: number): Promise<void> { if (!this.pref) return; await this.pref.put(KEY_TTS_SPEED, speed); await this.pref.flush(); }

  async getCurrentBook(): Promise<string> { if (!this.pref) return "Default Library"; return (await this.pref.get(KEY_CURRENT_BOOK, "Default Library")) as string; }

  // [修改] 设置当前词书，并触发自动模式检测
  async setCurrentBook(name: string): Promise<boolean> {
    if (!this.pref) return false;
    await this.pref.put(KEY_CURRENT_BOOK, name);
    await this.pref.flush();
    // 自动检测是否开启编程模式
    const result = await this.checkAndSetCodeMode(name);
    return result.isCodeMode;
  }

  async getTimeAttackState<T>(): Promise<T | null> {
    if (!this.pref) return null;
    const raw = (await this.pref.get(KEY_TIME_ATTACK_STATE, "")) as string;
    if (!raw) return null;
    try { return JSON.parse(raw) as T; } catch (e) { return null; }
  }

  async setTimeAttackState(value: object): Promise<void> {
    if (!this.pref) return;
    try {
      await this.pref.put(KEY_TIME_ATTACK_STATE, JSON.stringify(value));
      await this.pref.flush();
    } catch (e) { console.error('[Lumina] Failed to persist time attack state', e); }
  }

  async clearTimeAttackState(): Promise<void> { if (!this.pref) return; await this.pref.delete(KEY_TIME_ATTACK_STATE); await this.pref.flush(); }

  // [新增] 编程模式相关
  async isProgrammingMode(): Promise<boolean> {
    if (!this.pref) return false;
    return await this.pref.get(KEY_CODE_MODE, false) as boolean;
  }

  async setProgrammingMode(isEnabled: boolean): Promise<void> {
    if (!this.pref) return;
    await this.pref.put(KEY_CODE_MODE, isEnabled);
    await this.pref.flush();
  }

  async registerBookCategory(bookName: string, category: string): Promise<void> {
    if (!this.pref) return;
    const registry = await this.getCategoryRegistry();
    registry[bookName] = category;
    await this.pref.put(KEY_BOOK_CATEGORY_REGISTRY, JSON.stringify(registry));
    await this.pref.flush();
  }

  async getBookCategory(bookName: string): Promise<string | null> {
    if (!this.pref) return null;
    const registry = await this.getCategoryRegistry();
    return registry[bookName] ?? null;
  }

  private async getCategoryRegistry(): Promise<Record<string, string>> {
    if (!this.pref) return {};
    try {
      const raw = (await this.pref.get(KEY_BOOK_CATEGORY_REGISTRY, '{}')) as string;
      return JSON.parse(raw) as Record<string, string>;
    } catch (e) {
      console.error('[Lumina] Failed to parse category registry', e);
      return {};
    }
  }

  // [新增] 自动检测逻辑
  private async checkAndSetCodeMode(bookName: string): Promise<CodeModeResult> {
    const storedCategory = await this.getBookCategory(bookName);
    const lowerName = bookName.toLowerCase();
    const isCodeRelated = storedCategory
      ? storedCategory.toLowerCase() === 'code'
      : CODE_KEYWORDS.some(keyword => lowerName.includes(keyword));
    const currentMode = await this.isProgrammingMode();

    if (isCodeRelated && !currentMode) {
      await this.setProgrammingMode(true);
      promptAction.showToast({ message: '已切换至编程模式' });
      console.info(`[AutoMode] Enable Code Mode for: ${bookName}`);
      return { isCodeMode: true, changed: true } as CodeModeResult;
    }

    if (!isCodeRelated && currentMode) {
      await this.setProgrammingMode(false);
      promptAction.showToast({ message: '已切换至通用模式' });
      console.info(`[AutoMode] Disable Code Mode for: ${bookName}`);
      return { isCodeMode: false, changed: true } as CodeModeResult;
    }

    return { isCodeMode: currentMode, changed: false } as CodeModeResult;
  }
}

interface CodeModeResult {
  isCodeMode: boolean;
  changed: boolean;
}
