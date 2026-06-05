import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { ApiConfig } from '../service/DeepSeekApi';

export class SettingsStore {
  private static readonly PREF_NAME: string = 'harmochat_settings';
  private static readonly KEY_MAX_TOKENS: string = 'max_tokens';
  private static readonly KEY_TEMPERATURE: string = 'temperature';

  static readonly MIN_MAX_TOKENS: number = 1;
  static readonly MAX_MAX_TOKENS: number = 2000;
  static readonly MIN_TEMPERATURE: number = 0;
  static readonly MAX_TEMPERATURE: number = 2;
  static readonly DEFAULT_MAX_TOKENS: number = 2000;
  static readonly DEFAULT_TEMPERATURE: number = 0.7;

  static clampMaxTokens(value: number): number {
    const rounded = Math.round(value);
    if (rounded < SettingsStore.MIN_MAX_TOKENS) {
      return SettingsStore.MIN_MAX_TOKENS;
    }
    if (rounded > SettingsStore.MAX_MAX_TOKENS) {
      return SettingsStore.MAX_MAX_TOKENS;
    }
    return rounded;
  }

  static clampTemperature(value: number): number {
    if (value < SettingsStore.MIN_TEMPERATURE) {
      return SettingsStore.MIN_TEMPERATURE;
    }
    if (value > SettingsStore.MAX_TEMPERATURE) {
      return SettingsStore.MAX_TEMPERATURE;
    }
    return Math.round(value * 10) / 10;
  }

  static applyToApiConfig(maxTokens: number, temperature: number): void {
    ApiConfig.MAX_TOKENS = SettingsStore.clampMaxTokens(maxTokens);
    ApiConfig.TEMPERATURE = SettingsStore.clampTemperature(temperature);
  }

  private static readNumber(value: preferences.ValueType, defaultValue: number): number {
    if (typeof value === 'number') {
      return value;
    }
    if (typeof value === 'string') {
      const parsed = parseInt(value);
      if (!isNaN(parsed)) {
        return parsed;
      }
    }
    return defaultValue;
  }

  static async load(context: common.UIAbilityContext): Promise<void> {
    try {
      const pref = await preferences.getPreferences(context, SettingsStore.PREF_NAME);
      const maxTokensRaw =
        await pref.get(SettingsStore.KEY_MAX_TOKENS, SettingsStore.DEFAULT_MAX_TOKENS);
      const temperatureRaw =
        await pref.get(SettingsStore.KEY_TEMPERATURE, SettingsStore.DEFAULT_TEMPERATURE);
      const maxTokens = SettingsStore.clampMaxTokens(
        SettingsStore.readNumber(maxTokensRaw, SettingsStore.DEFAULT_MAX_TOKENS)
      );
      const temperature = SettingsStore.clampTemperature(
        SettingsStore.readNumber(temperatureRaw, SettingsStore.DEFAULT_TEMPERATURE)
      );
      SettingsStore.applyToApiConfig(maxTokens, temperature);
    } catch (err) {
      SettingsStore.applyToApiConfig(
        SettingsStore.DEFAULT_MAX_TOKENS,
        SettingsStore.DEFAULT_TEMPERATURE
      );
    }
  }

  static async save(
    context: common.UIAbilityContext,
    maxTokens: number,
    temperature: number
  ): Promise<void> {
    const safeMaxTokens = SettingsStore.clampMaxTokens(maxTokens);
    const safeTemperature = SettingsStore.clampTemperature(temperature);
    SettingsStore.applyToApiConfig(safeMaxTokens, safeTemperature);

    const pref = await preferences.getPreferences(context, SettingsStore.PREF_NAME);
    await pref.put(SettingsStore.KEY_MAX_TOKENS, safeMaxTokens);
    await pref.put(SettingsStore.KEY_TEMPERATURE, safeTemperature);
    await pref.flush();
  }
}
