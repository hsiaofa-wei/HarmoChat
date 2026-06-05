import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';

export const THEME_STORAGE_KEY: string = 'isDarkMode';

export class ThemeStore {
  private static readonly PREF_NAME: string = 'harmochat_settings';
  private static readonly KEY_DARK_MODE: string = 'dark_mode';

  static async load(context: common.UIAbilityContext): Promise<void> {
    try {
      const pref = await preferences.getPreferences(context, ThemeStore.PREF_NAME);
      const raw = await pref.get(ThemeStore.KEY_DARK_MODE, false);
      const isDark = ThemeStore.readBool(raw, false);
      AppStorage.setOrCreate(THEME_STORAGE_KEY, isDark);
    } catch (err) {
      AppStorage.setOrCreate(THEME_STORAGE_KEY, false);
    }
  }

  static async setDarkMode(context: common.UIAbilityContext, isDark: boolean): Promise<void> {
    AppStorage.set(THEME_STORAGE_KEY, isDark);
    try {
      const pref = await preferences.getPreferences(context, ThemeStore.PREF_NAME);
      await pref.put(ThemeStore.KEY_DARK_MODE, isDark);
      await pref.flush();
    } catch (err) {
      // 内存状态已更新，持久化失败时下次启动恢复默认
    }
  }

  private static readBool(value: preferences.ValueType, defaultValue: boolean): boolean {
    if (typeof value === 'boolean') {
      return value;
    }
    return defaultValue;
  }
}
