import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import promptAction from '@ohos.promptAction';

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
const KEY_FLOATING_BALL = 'floating_ball_enabled';

const CODE_KEYWORDS = ['code', 'program', 'java', 'python', 'cpp', 'c++', 'algorithm', '编程', '代码', '算法'];

class CodeModeResult {
  isCodeMode: boolean = false;
  changed: boolean = false;
}

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

  // [修复] 参数改为 common.Context，这样 UIAbility 和 FormExtension 都能用
  async init(context: common.Context): Promise<void> {
    if (this.pref) return;
    try {
      this.pref = await preferences.getPreferences(context, PREF_NAME);
    } catch (e) {
      console.error('[Lumina] Pref init failed', JSON.stringify(e));
    }
  }

  // === 基础配置 ===
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

  // === 悬浮球配置 ===
  async isFloatingBallEnabled(): Promise<boolean> {
    if (!this.pref) return false;
    return await this.pref.get(KEY_FLOATING_BALL, false) as boolean;
  }

  async setFloatingBallEnabled(enabled: boolean): Promise<void> {
    if (!this.pref) return;
    await this.pref.put(KEY_FLOATING_BALL, enabled);
    await this.pref.flush();
  }

  // === 词书管理 ===
  async getCurrentBook(): Promise<string> { if (!this.pref) return "Default Library"; return (await this.pref.get(KEY_CURRENT_BOOK, "Default Library")) as string; }

  async setCurrentBook(name: string): Promise<boolean> {
    if (!this.pref) return false;
    await this.pref.put(KEY_CURRENT_BOOK, name);
    await this.pref.flush();
    const result = await this.checkAndSetCodeMode(name);
    return result.isCodeMode;
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
      return {};
    }
  }

  // === 编程模式 ===
  async isProgrammingMode(): Promise<boolean> {
    if (!this.pref) return false;
    return await this.pref.get(KEY_CODE_MODE, false) as boolean;
  }

  async setProgrammingMode(isEnabled: boolean): Promise<void> {
    if (!this.pref) return;
    await this.pref.put(KEY_CODE_MODE, isEnabled);
    await this.pref.flush();
  }

  private async checkAndSetCodeMode(bookName: string): Promise<CodeModeResult> {
    const storedCategory = await this.getBookCategory(bookName);
    const lowerName = bookName.toLowerCase();
    const isCodeRelated = storedCategory
      ? storedCategory.toLowerCase() === 'code'
      : CODE_KEYWORDS.some(keyword => lowerName.includes(keyword));
    const currentMode = await this.isProgrammingMode();

    if (isCodeRelated && !currentMode) {
      await this.setProgrammingMode(true);
      try { promptAction.showToast({ message: '已切换至编程模式' }); } catch(e) {}
      const res = new CodeModeResult();
      res.isCodeMode = true;
      res.changed = true;
      return res;
    }

    if (!isCodeRelated && currentMode) {
      await this.setProgrammingMode(false);
      try { promptAction.showToast({ message: '已切换至通用模式' }); } catch(e) {}
      const res = new CodeModeResult();
      res.isCodeMode = false;
      res.changed = true;
      return res;
    }

    const res = new CodeModeResult();
    res.isCodeMode = currentMode;
    res.changed = false;
    return res;
  }

  // === 60秒挑战状态 ===
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
    } catch (e) { }
  }

  async clearTimeAttackState(): Promise<void> {
    if (!this.pref) return;
    await this.pref.delete(KEY_TIME_ATTACK_STATE);
    await this.pref.flush();
  }
}