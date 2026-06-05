import { common } from '@kit.AbilityKit';
import { promptAction, router } from '@kit.ArkUI';
import { ApiConfig } from '../service/DeepSeekApi';
import { AppTheme } from '../util/AppTheme';
import { SettingsStore } from '../util/SettingsStore';
import { ThemeStore } from '../util/ThemeStore';

@Entry
@Component
struct Settings {
  @State maxTokens: number = SettingsStore.DEFAULT_MAX_TOKENS;
  @State temperature: number = SettingsStore.DEFAULT_TEMPERATURE;
  @State maxTokensInput: string = `${SettingsStore.DEFAULT_MAX_TOKENS}`;
  @State isSaving: boolean = false;
  @StorageLink('isDarkMode') isDarkMode: boolean = false;

  aboutToAppear(): void {
    const ctx = getContext(this) as common.UIAbilityContext;
    ThemeStore.load(ctx).catch(() => {
    });
    this.maxTokens = ApiConfig.MAX_TOKENS;
    this.temperature = ApiConfig.TEMPERATURE;
    this.maxTokensInput = `${this.maxTokens}`;
  }

  async onDarkModeChange(isOn: boolean): Promise<void> {
    const ctx = getContext(this) as common.UIAbilityContext;
    await ThemeStore.setDarkMode(ctx, isOn);
  }

  private formatTemperature(value: number): string {
    return SettingsStore.clampTemperature(value).toFixed(1);
  }

  private onMaxTokensInputChange(value: string): void {
    this.maxTokensInput = value;
    const parsed = parseInt(value);
    if (!isNaN(parsed)) {
      this.maxTokens = SettingsStore.clampMaxTokens(parsed);
    }
  }

  private syncMaxTokensInput(): void {
    this.maxTokensInput = `${this.maxTokens}`;
  }

  private async saveSettings(): Promise<void> {
    if (this.isSaving) {
      return;
    }
    const parsed = parseInt(this.maxTokensInput);
    if (isNaN(parsed)) {
      promptAction.showToast({ message: '请输入有效的 Max Tokens 数值' });
      return;
    }

    this.isSaving = true;
    const safeMaxTokens = SettingsStore.clampMaxTokens(parsed);
    const safeTemperature = SettingsStore.clampTemperature(this.temperature);
    this.maxTokens = safeMaxTokens;
    this.temperature = safeTemperature;
    this.syncMaxTokensInput();

    try {
      const ctx = getContext(this) as common.UIAbilityContext;
      await SettingsStore.save(ctx, safeMaxTokens, safeTemperature);
      promptAction.showToast({ message: '设置已保存' });
      router.back();
    } catch (err) {
      promptAction.showToast({ message: '保存失败，请重试' });
    } finally {
      this.isSaving = false;
    }
  }

  @Builder
  SettingCard(title: string, desc: string) {
    Column() {
      Text(title)
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppTheme.titleText(this.isDarkMode))
      Text(desc)
        .fontSize(12)
        .fontColor(AppTheme.descText(this.isDarkMode))
        .margin({ top: 4 })
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
  }

  build() {
    Column() {
      Row() {
        Button({ type: ButtonType.Normal }) {
          Text('← 返回')
            .fontSize(15)
            .fontColor(Color.White)
        }
        .backgroundColor(Color.Transparent)
        .height(40)
        .onClick(() => {
          router.back();
        })

        Text('设置')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor(Color.White)
          .layoutWeight(1)
          .textAlign(TextAlign.Center)

        Blank()
          .width(56)
      }
      .width('100%')
      .height(56)
      .padding({ left: 8, right: 16 })
      .backgroundColor('#1A73E8')

      Scroll() {
        Column() {
          Row() {
            Column() {
              Text('夜间模式')
                .fontSize(16)
                .fontWeight(FontWeight.Medium)
                .fontColor(AppTheme.titleText(this.isDarkMode))
              Text('开启后使用深色界面，减轻夜间用眼疲劳')
                .fontSize(12)
                .fontColor(AppTheme.descText(this.isDarkMode))
                .margin({ top: 4 })
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)

            Toggle({ type: ToggleType.Switch, isOn: this.isDarkMode })
              .selectedColor('#90CAF9')
              .switchPointColor(Color.White)
              .onChange((isOn: boolean) => {
                this.onDarkModeChange(isOn);
              })
          }
          .width('100%')
          .padding(16)
          .backgroundColor(AppTheme.cardBackground(this.isDarkMode))
          .borderRadius(12)

          Column() {
            this.SettingCard(
              'Max Tokens',
              `范围 ${SettingsStore.MIN_MAX_TOKENS} - ${SettingsStore.MAX_MAX_TOKENS}，控制单次回复最大长度`
            )

            Row() {
              Text(`${this.maxTokens}`)
                .fontSize(22)
                .fontWeight(FontWeight.Bold)
                .fontColor('#1A73E8')
                .layoutWeight(1)
              Text('tokens')
                .fontSize(14)
                .fontColor(AppTheme.descText(this.isDarkMode))
            }
            .width('100%')
            .margin({ top: 12 })

            Slider({
              value: this.maxTokens,
              min: SettingsStore.MIN_MAX_TOKENS,
              max: SettingsStore.MAX_MAX_TOKENS,
              step: 1,
              style: SliderStyle.OutSet
            })
              .blockColor('#1A73E8')
              .trackColor(AppTheme.sliderTrack(this.isDarkMode))
              .selectedColor('#1A73E8')
              .margin({ top: 8 })
              .onChange((value: number) => {
                this.maxTokens = SettingsStore.clampMaxTokens(value);
                this.syncMaxTokensInput();
              })

            Row() {
              Text('精确输入')
                .fontSize(13)
                .fontColor(AppTheme.descText(this.isDarkMode))
                .width(72)
              TextInput({ text: this.maxTokensInput, placeholder: '1-2000' })
                .layoutWeight(1)
                .height(40)
                .type(InputType.Number)
                .borderRadius(8)
                .backgroundColor(AppTheme.inputFieldBackground(this.isDarkMode))
                .fontColor(AppTheme.titleText(this.isDarkMode))
                .padding({ left: 12, right: 12 })
                .onChange((value: string) => {
                  this.onMaxTokensInputChange(value);
                })
                .onSubmit(() => {
                  this.maxTokens = SettingsStore.clampMaxTokens(parseInt(this.maxTokensInput));
                  this.syncMaxTokensInput();
                })
            }
            .width('100%')
            .margin({ top: 12 })
          }
          .width('100%')
          .padding(16)
          .backgroundColor(AppTheme.cardBackground(this.isDarkMode))
          .borderRadius(12)
          .margin({ top: 12 })

          Column() {
            this.SettingCard(
              'Temperature',
              `范围 ${SettingsStore.MIN_TEMPERATURE} - ${SettingsStore.MAX_TEMPERATURE}，越高越有创意，越低越稳定`
            )

            Row() {
              Text(this.formatTemperature(this.temperature))
                .fontSize(22)
                .fontWeight(FontWeight.Bold)
                .fontColor('#1A73E8')
                .layoutWeight(1)
            }
            .width('100%')
            .margin({ top: 12 })

            Slider({
              value: this.temperature,
              min: SettingsStore.MIN_TEMPERATURE,
              max: SettingsStore.MAX_TEMPERATURE,
              step: 0.1,
              style: SliderStyle.OutSet
            })
              .blockColor('#1A73E8')
              .trackColor(AppTheme.sliderTrack(this.isDarkMode))
              .selectedColor('#1A73E8')
              .margin({ top: 8 })
              .onChange((value: number) => {
                this.temperature = SettingsStore.clampTemperature(value);
              })

            Row() {
              Text('0')
                .fontSize(12)
                .fontColor(AppTheme.hintText(this.isDarkMode))
              Blank()
                .layoutWeight(1)
              Text('2')
                .fontSize(12)
                .fontColor(AppTheme.hintText(this.isDarkMode))
            }
            .width('100%')
            .margin({ top: 4 })
          }
          .width('100%')
          .padding(16)
          .backgroundColor(AppTheme.cardBackground(this.isDarkMode))
          .borderRadius(12)
          .margin({ top: 12 })

          Text('当前 API 请求将使用以上参数')
            .fontSize(12)
            .fontColor(AppTheme.hintText(this.isDarkMode))
            .margin({ top: 16, bottom: 8 })

          Button(this.isSaving ? '保存中…' : '保存设置')
            .width('100%')
            .height(48)
            .fontSize(16)
            .fontColor(Color.White)
            .backgroundColor('#1A73E8')
            .borderRadius(24)
            .enabled(!this.isSaving)
            .onClick(() => {
              this.saveSettings();
            })

          Button('恢复默认')
            .width('100%')
            .height(44)
            .fontSize(14)
            .fontColor('#1A73E8')
            .backgroundColor('#E3F2FD')
            .borderRadius(22)
            .margin({ top: 12 })
            .enabled(!this.isSaving)
            .onClick(() => {
              this.maxTokens = SettingsStore.DEFAULT_MAX_TOKENS;
              this.temperature = SettingsStore.DEFAULT_TEMPERATURE;
              this.syncMaxTokensInput();
            })
        }
        .width('100%')
        .padding(16)
      }
      .layoutWeight(1)
      .width('100%')
      .backgroundColor(AppTheme.settingsPageBackground(this.isDarkMode))
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AppTheme.pageBackground(this.isDarkMode))
  }
}
