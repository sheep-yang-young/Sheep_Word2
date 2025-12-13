import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';

const PREF_NAME = 'LuminaPrefs';
const KEY_DAILY_LIMIT = 'daily_limit';
const KEY_ACCENT_TYPE = 'accent_type';
const KEY_HAPTIC_ENABLED = 'haptic_enabled';
const KEY_REVIEW_MODE = 'review_mode';
const KEY_TTS_SPEED = 'tts_speed';
const KEY_CURRENT_BOOK = 'current_book';
const KEY_CUSTOM_BOOKS = 'custom_books';
const KEY_FIRST_LAUNCH = 'first_launch_v2'; // 升级key以确保老用户也能看到新引导
const KEY_REMINDER_ENABLED = 'reminder_enabled';
const KEY_REMINDER_TIME = 'reminder_time';

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

  async getCustomBooks(): Promise<string[]> {
    if (!this.pref) return [];
    const raw = await this.pref.get(KEY_CUSTOM_BOOKS, '[]');
    try { return JSON.parse(raw as string) as string[]; } catch (e) { return []; }
  }

  async addCustomBook(name: string): Promise<void> {
    if (!this.pref) return;
    const list = await this.getCustomBooks();
    if (!list.includes(name)) {
      list.push(name);
      await this.pref.put(KEY_CUSTOM_BOOKS, JSON.stringify(list));
      await this.pref.flush();
    }
  }

  async getReminderEnabled(): Promise<boolean> { if (!this.pref) return false; return (await this.pref.get(KEY_REMINDER_ENABLED, false)) as boolean; }
  async setReminderEnabled(value: boolean): Promise<void> { if (!this.pref) return; await this.pref.put(KEY_REMINDER_ENABLED, value); await this.pref.flush(); }
  async getReminderTime(): Promise<string> { if (!this.pref) return '08:00'; return (await this.pref.get(KEY_REMINDER_TIME, '08:00')) as string; }
  async setReminderTime(value: string): Promise<void> { if (!this.pref) return; await this.pref.put(KEY_REMINDER_TIME, value); await this.pref.flush(); }
}