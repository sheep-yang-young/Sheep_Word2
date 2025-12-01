import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';

const PREF_NAME = 'LuminaPrefs';
const KEY_DAILY_LIMIT = 'daily_limit';
const KEY_ACCENT_TYPE = 'accent_type'; // 1=UK, 2=US
const KEY_HAPTIC_ENABLED = 'haptic_enabled'; // boolean

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

  // --- 每日目标 ---
  async getDailyLimit(): Promise<number> {
    if (!this.pref) return 20;
    return (await this.pref.get(KEY_DAILY_LIMIT, 20)) as number;
  }

  async setDailyLimit(limit: number): Promise<void> {
    if (!this.pref) return;
    await this.pref.put(KEY_DAILY_LIMIT, limit);
    await this.pref.flush();
  }

  // --- 口音设置 (1:英音, 2:美音) ---
  async getAccentType(): Promise<number> {
    if (!this.pref) return 2; // 默认美音
    return (await this.pref.get(KEY_ACCENT_TYPE, 2)) as number;
  }

  async setAccentType(type: number): Promise<void> {
    if (!this.pref) return;
    await this.pref.put(KEY_ACCENT_TYPE, type);
    await this.pref.flush();
  }

  // --- 振动反馈 ---
  async isHapticEnabled(): Promise<boolean> {
    if (!this.pref) return true; // 默认开启
    return (await this.pref.get(KEY_HAPTIC_ENABLED, true)) as boolean;
  }

  async setHapticEnabled(enabled: boolean): Promise<void> {
    if (!this.pref) return;
    await this.pref.put(KEY_HAPTIC_ENABLED, enabled);
    await this.pref.flush();
  }
}