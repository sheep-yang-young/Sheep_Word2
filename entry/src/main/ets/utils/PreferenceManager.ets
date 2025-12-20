import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';

const PREF_NAME = 'LuminaPrefs';
const KEY_DAILY_LIMIT = 'daily_limit';
const KEY_ACCENT_TYPE = 'accent_type';
const KEY_HAPTIC_ENABLED = 'haptic_enabled';
const KEY_REVIEW_MODE = 'review_mode';
const KEY_TTS_SPEED = 'tts_speed';
const KEY_CURRENT_BOOK = 'current_book';
const KEY_FIRST_LAUNCH = 'first_launch_v2'; // 升级key以确保老用户也能看到新引导
const KEY_TIME_ATTACK_STATE = 'time_attack_state';
const KEY_CODE_MODE = 'is_code_mode';

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

  // [新增] 是否首次启动
  async isFirstLaunch(): Promise<boolean> {
    if (!this.pref) return true;
    return (await this.pref.get(KEY_FIRST_LAUNCH, true)) as boolean;
  }

  // [新增] 设置非首次启动
  async setFirstLaunch(isFirst: boolean): Promise<void> {
    if (!this.pref) return;
    await this.pref.put(KEY_FIRST_LAUNCH, isFirst);
    await this.pref.flush();
  }

  // ... (保持其他所有 getter/setter 不变，直接复制即可)
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
  async setCurrentBook(name: string): Promise<void> { if (!this.pref) return; await this.pref.put(KEY_CURRENT_BOOK, name); await this.pref.flush(); }

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
  async isProgrammingMode(): Promise<boolean> {
    // 必须判空，并调用 this.pref.get
    if (!this.pref) return false;
    return await this.pref.get('is_code_mode', false) as boolean;
  }

  // [修复] 设置编程模式状态
  async setProgrammingMode(isEnabled: boolean): Promise<void> {
    if (!this.pref) return;
    // 必须调用 this.pref.put
    await this.pref.put('is_code_mode', isEnabled);
    await this.pref.flush(); // 别忘了刷盘保存
  }
}