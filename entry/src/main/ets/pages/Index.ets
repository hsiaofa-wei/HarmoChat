import { common } from '@kit.AbilityKit';
import { router } from '@kit.ArkUI';
import { Message, MessageRole, MessageStatus } from '../model/Message';
import { ChatService } from '../service/ChatService';
import { SpeechService } from '../service/SpeechService';
import { AppTheme } from '../util/AppTheme';
import { SettingsStore } from '../util/SettingsStore';
import { ThemeStore } from '../util/ThemeStore';

@Entry
@Component
struct Index {
  @State messages: Message[] = [];
  @State inputText: string = '';
  @State isSending: boolean = false;
  @State isListening: boolean = false;
  @State isSpeaking: boolean = false;
  @State speakingMessageId: string = '';
  @State enableThinking: boolean = false;
  /** 已手动展开思考过程的消息 id 列表（流式结束后默认收起） */
  @State expandedReasoningIds: string[] = [];
  /** 用于强制刷新列表项，确保折叠状态 UI 更新 */
  @State reasoningUiVersion: number = 0;
  @StorageLink('isDarkMode') isDarkMode: boolean = false;

  private chatService: ChatService = ChatService.getInstance();
  private speechService: SpeechService = SpeechService.getInstance();
  private scroller: Scroller = new Scroller();
  private longPressTimer: number = -1;
  private voicePressActive: boolean = false;
  aboutToAppear(): void {
    const ctx = getContext(this) as common.UIAbilityContext;
    SettingsStore.load(ctx).catch(() => {
    });
    ThemeStore.load(ctx).catch(() => {
    });
    if (!this.chatService.getCurrentSession()) {
      this.chatService.createNewSession();
    }
    this.enableThinking = this.chatService.isThinkingEnabled();
    this.loadMessages();
    this.setupSpeech();
  }

  setupSpeech(): void {
    this.speechService.setCallbacks({
      onRecognized: (text: string, _isFinal: boolean) => {
        this.inputText = text;
      },
      onListeningChange: (listening: boolean) => {
        this.isListening = listening;
      }
    });
    this.speechService.init().catch(() => {
    });
  }

  clearLongPressTimer(): void {
    if (this.longPressTimer >= 0) {
      clearTimeout(this.longPressTimer);
      this.longPressTimer = -1;
    }
  }

  async onInputTouch(event: TouchEvent): Promise<void> {
    if (this.isSending || this.isSpeaking) {
      return;
    }
    const ctx = getContext(this) as common.UIAbilityContext;
    if (event.type === TouchType.Down) {
      this.clearLongPressTimer();
      this.longPressTimer = setTimeout(async () => {
        this.longPressTimer = -1;
        this.voicePressActive = true;
        const started = await this.speechService.startListening(ctx);
        if (!started) {
          this.voicePressActive = false;
        }
      }, 400);
    } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
      this.clearLongPressTimer();
      if (this.voicePressActive || this.isListening) {
        this.voicePressActive = false;
        if (this.isListening) {
          this.speechService.stopListening();
        }
      }
    }
  }

  stopTts(): void {
    if (!this.isSpeaking) {
      return;
    }
    this.isSpeaking = false;
    this.speakingMessageId = '';
    this.reasoningUiVersion = this.reasoningUiVersion + 1;
    this.speechService.stopSpeak();
  }

  startSpeakMessage(message: Message): void {
    if (message.content.trim().length === 0 || this.isListening) {
      return;
    }
    if (this.isSpeaking && this.speakingMessageId === message.id) {
      return;
    }
    const speechText = SpeechService.sanitizeForSpeech(message.content);
    if (speechText.length === 0) {
      return;
    }
    if (this.isSpeaking) {
      this.speechService.stopSpeak();
    }
    this.isSpeaking = true;
    this.speakingMessageId = message.id;
    this.reasoningUiVersion = this.reasoningUiVersion + 1;
    this.speechService.speak(speechText, message.id);
  }

  stopSpeakMessage(message: Message): void {
    if (this.isSpeaking && this.speakingMessageId === message.id) {
      this.isSpeaking = false;
      this.speakingMessageId = '';
      this.reasoningUiVersion = this.reasoningUiVersion + 1;
      this.speechService.stopSpeak();
    }
  }

  openSettings(): void {
    router.pushUrl({ url: 'pages/Settings' });
  }

  async toggleDarkMode(): Promise<void> {
    const ctx = getContext(this) as common.UIAbilityContext;
    await ThemeStore.setDarkMode(ctx, !this.isDarkMode);
  }

  loadMessages(): void {
    this.messages = [...this.chatService.getCurrentMessages()];
    setTimeout(() => {
      this.scroller.scrollEdge(Edge.Bottom);
    }, 100);
  }

  build() {
    Column() {
      Row() {
        Text('HarmoChat')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor(Color.White)

        Button({ type: ButtonType.Normal }) {
          Text(this.isDarkMode ? '日间' : '夜间')
            .fontSize(13)
            .fontColor(Color.White)
        }
        .backgroundColor(Color.Transparent)
        .height(36)
        .margin({ left: 8 })
        .onClick(() => {
          this.toggleDarkMode();
        })

        Button({ type: ButtonType.Normal }) {
          Text('设置')
            .fontSize(13)
            .fontColor(Color.White)
        }
        .backgroundColor(Color.Transparent)
        .height(36)
        .margin({ left: 4 })
        .onClick(() => {
          this.openSettings();
        })

        Blank()
          .layoutWeight(1)

        Row() {
          Text('深度思考')
            .fontSize(13)
            .fontColor(Color.White)
            .margin({ right: 6 })
          Toggle({ type: ToggleType.Switch, isOn: this.enableThinking })
            .selectedColor('#90CAF9')
            .switchPointColor(Color.White)
            .onChange((isOn: boolean) => {
              this.enableThinking = isOn;
              this.chatService.setThinkingEnabled(isOn);
            })
        }
      }
      .width('100%')
      .height(56)
      .padding({ left: 16, right: 16 })
      .justifyContent(FlexAlign.SpaceBetween)
      .backgroundColor('#1A73E8')

      List({ scroller: this.scroller }) {
        ForEach(this.messages, (message: Message) => {
          ListItem() {
            this.MessageBubble(
              message,
              this.isReasoningExpanded(message.id, message.status === MessageStatus.SENDING),
              this.isDarkMode,
              this.isSpeaking && this.speakingMessageId === message.id
            )
          }
        }, (message: Message) =>
          `${message.id}_${message.status}_${message.content.length}_${message.reasoningContent.length}_` +
          `${this.reasoningUiVersion}_` +
          `${this.isReasoningExpanded(message.id, message.status === MessageStatus.SENDING)}_${this.isDarkMode}_` +
          `${this.isSpeaking}_${this.speakingMessageId}`)
      }
      .layoutWeight(1)
      .width('100%')
      .padding({ left: 12, right: 12, top: 8, bottom: 8 })
      .edgeEffect(EdgeEffect.Spring)

      Row() {
        Stack() {
          TextInput({
            text: this.inputText,
            placeholder: this.isListening ? '松开后结束…' : '输入消息，长按说话…'
          })
            .width('100%')
            .height(44)
            .borderRadius(22)
            .backgroundColor(AppTheme.inputBackground(this.isDarkMode))
            .fontColor(AppTheme.inputTextColor(this.isDarkMode))
            .placeholderColor(AppTheme.hintText(this.isDarkMode))
            .padding({ left: 16, right: 16 })
            .enabled(!this.isSending && !this.isListening)
            .onChange((value: string) => {
              this.inputText = value;
            })
            .onSubmit(() => {
              this.sendMessage();
            })
        }
        .layoutWeight(1)
        .height(44)
        .borderRadius(22)
        .border({
          width: this.isListening ? 2 : 0,
          color: '#FF4444'
        })
        .onTouch((event: TouchEvent) => {
          this.onInputTouch(event);
        })

        Button(this.isSending ? '…' : '发送')
          .type(ButtonType.Capsule)
          .height(44)
          .margin({ left: 8 })
          .enabled(!this.isSending && this.inputText.trim().length > 0)
          .onClick(() => {
            this.sendMessage();
          })
      }
      .width('100%')
      .padding(12)
      .backgroundColor(AppTheme.inputBarBackground(this.isDarkMode))
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AppTheme.pageBackground(this.isDarkMode))
  }

  isReasoningExpanded(messageId: string, isStreaming: boolean): boolean {
    if (isStreaming) {
      return true;
    }
    return this.expandedReasoningIds.indexOf(messageId) >= 0;
  }

  toggleReasoningExpand(messageId: string): void {
    const idx = this.expandedReasoningIds.indexOf(messageId);
    const next: string[] = [];
    if (idx >= 0) {
      for (let i = 0; i < this.expandedReasoningIds.length; i++) {
        if (i !== idx) {
          next.push(this.expandedReasoningIds[i]);
        }
      }
    } else {
      for (let i = 0; i < this.expandedReasoningIds.length; i++) {
        next.push(this.expandedReasoningIds[i]);
      }
      next.push(messageId);
    }
    this.expandedReasoningIds = next;
    this.reasoningUiVersion = this.reasoningUiVersion + 1;
  }

  @Builder
  ReasoningBlock(messageId: string, text: string, isStreaming: boolean, isExpanded: boolean, isDark: boolean) {
    Column() {
      Row() {
        Text('思考过程')
          .fontSize(12)
          .fontColor(AppTheme.reasoningLabel(isDark))
          .fontWeight(FontWeight.Medium)

        Blank()
          .layoutWeight(1)

        Button({ type: ButtonType.Normal }) {
          Text(isExpanded ? '收起 ▲' : '展开 ▼')
            .fontSize(12)
            .fontColor('#1A73E8')
        }
        .backgroundColor(Color.Transparent)
        .height(28)
        .padding({ left: 8, right: 0 })
        .enabled(!isStreaming)
        .onClick(() => {
          this.toggleReasoningExpand(messageId);
        })
      }
      .width('100%')
      .margin({ bottom: isExpanded ? 6 : 0 })

      if (isExpanded) {
        Scroll() {
          Text(isStreaming ? `${text}▋` : text)
            .fontSize(13)
            .fontColor(AppTheme.reasoningText(isDark))
            .lineHeight(20)
        }
        .width('100%')
        .constraintSize({ maxHeight: 160 })
        .scrollBar(BarState.Auto)
      }
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
    .padding(8)
    .margin({ bottom: 8 })
    .backgroundColor(AppTheme.reasoningBackground(isDark))
    .borderRadius(8)
  }

  @Builder
  MessageBubble(message: Message, isReasoningExpanded: boolean, isDark: boolean, isThisSpeaking: boolean) {
    Row() {
      if (message.role === MessageRole.USER) {
        Blank()
          .layoutWeight(1)

        Text(message.content)
          .fontSize(15)
          .fontColor(Color.White)
          .lineHeight(22)
          .padding(12)
          .constraintSize({ maxWidth: '78%' })
          .backgroundColor('#1A73E8')
          .borderRadius(16)
          .shadow({
            radius: 4,
            color: '#14000000',
            offsetX: 0,
            offsetY: 1
          })
      } else {
        Column() {
          if (message.status === MessageStatus.SENDING && message.reasoningContent.length === 0 &&
            message.content.length === 0) {
            Row() {
              LoadingProgress()
                .width(20)
                .height(20)
                .color('#1A73E8')
              Text('思考中…')
                .fontSize(14)
                .fontColor(AppTheme.secondaryText(isDark))
                .margin({ left: 8 })
            }
            .padding(4)
          } else {
            if (message.reasoningContent.length > 0) {
              this.ReasoningBlock(
                message.id,
                message.reasoningContent,
                message.status === MessageStatus.SENDING,
                isReasoningExpanded,
                isDark
              )
            } else if (message.status === MessageStatus.SENDING && message.content.length === 0) {
              Row() {
                LoadingProgress()
                  .width(18)
                  .height(18)
                  .color('#9E9E9E')
                Text('正在思考…')
                  .fontSize(13)
                  .fontColor(AppTheme.hintText(isDark))
                  .margin({ left: 8 })
              }
              .padding({ top: 4, bottom: 4 })
            }
            if (message.content.length > 0) {
              Text(message.status === MessageStatus.SENDING ? `${message.content}▋` : message.content)
                .fontSize(15)
                .fontColor(message.status === MessageStatus.ERROR ? '#D32F2F' : AppTheme.assistantText(isDark))
                .lineHeight(22)
                .margin({ top: message.reasoningContent.length > 0 ? 4 : 0 })

              if (message.status !== MessageStatus.SENDING && message.status !== MessageStatus.ERROR) {
                Row() {
                  Button({ type: ButtonType.Capsule }) {
                    Text('朗读')
                      .fontSize(12)
                      .fontColor(Color.White)
                  }
                  .height(28)
                  .padding({ left: 12, right: 12 })
                  .backgroundColor('#1A73E8')
                  .enabled(!this.isListening && !isThisSpeaking)
                  .onClick(() => {
                    this.startSpeakMessage(message);
                  })

                  Button({ type: ButtonType.Capsule }) {
                    Text('停止')
                      .fontSize(12)
                      .fontColor(Color.White)
                  }
                  .height(28)
                  .padding({ left: 12, right: 12 })
                  .margin({ left: 8 })
                  .backgroundColor('#D32F2F')
                  .enabled(isThisSpeaking)
                  .onClick(() => {
                    this.stopSpeakMessage(message);
                  })
                }
                .margin({ top: 8 })
              }
            }
          }
        }
        .alignItems(HorizontalAlign.Start)
        .alignSelf(ItemAlign.Start)
        .width('78%')
        .padding(12)
        .clip(true)
        .backgroundColor(AppTheme.assistantBubble(isDark))
        .borderRadius(16)
        .shadow({
          radius: 4,
          color: isDark ? '#00000000' : '#14000000',
          offsetX: 0,
          offsetY: 1
        })

        Blank()
          .layoutWeight(1)
      }
    }
    .width('100%')
    .margin({ top: 6, bottom: 6 })
    .alignItems(VerticalAlign.Top)
  }

  async sendMessage(): Promise<void> {
    if (this.inputText.trim() === '' || this.isSending) {
      return;
    }
    if (this.isListening) {
      this.speechService.stopListening();
    }
    this.clearLongPressTimer();

    const content = this.inputText.trim();
    this.inputText = '';
    this.isSending = true;
    this.chatService.setThinkingEnabled(this.enableThinking);
    this.messages = [...this.chatService.getCurrentMessages()];

    try {
      await this.chatService.sendMessage(content, () => {
        this.messages = [...this.chatService.getCurrentMessages()];
        setTimeout(() => {
          this.scroller.scrollEdge(Edge.Bottom);
        }, 50);
      });
    } catch (error) {
      this.messages = [...this.chatService.getCurrentMessages()];
    } finally {
      this.isSending = false;
      this.messages = [...this.chatService.getCurrentMessages()];
      setTimeout(() => {
        this.scroller.scrollEdge(Edge.Bottom);
      }, 100);
    }
  }
}
