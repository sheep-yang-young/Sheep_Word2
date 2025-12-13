import { DatabaseManager } from '../utils/DatabaseManager';
import { Word } from '../model/WordModel';
import { media } from '@kit.MediaKit';
import { common } from '@kit.AbilityKit';
import { PreferenceManager } from '../utils/PreferenceManager';

@Component
export struct ZenPage {
  @Consume('pageStack') pageStack: NavPathStack;

  @State words: Word[] = [];
  @State currentIndex: number = 0;
  @State isBreathing: boolean = false;
  @State showSpelling: boolean = false;
  @State showMeaning: boolean = false;

  private timer: number = -1;
  private avPlayer: media.AVPlayer | null = null;
  private accentType: number = 2;
  private currentBookId: string = "Default Library";

  async aboutToAppear(): Promise<void> {
    this.accentType = await PreferenceManager.getInstance().getAccentType();
    this.currentBookId = await PreferenceManager.getInstance().getCurrentBook();

    await this.initAudioPlayer();
    this.words = await DatabaseManager.getInstance().getRandomWords(this.currentBookId, 30);

    if (this.words.length > 0) {
      this.startZenLoop();
    }
  }

  aboutToDisappear(): void {
    if (this.timer !== -1) clearTimeout(this.timer);
    if (this.avPlayer) this.avPlayer.release();
  }

  async initAudioPlayer(): Promise<void> {
    try { this.avPlayer = await media.createAVPlayer(); } catch (e) {}
  }

  async playWord(text: string): Promise<void> {
    if (!this.avPlayer) return;
    try {
      await this.avPlayer.reset();
      this.avPlayer.url = `https://dict.youdao.com/dictvoice?audio=${text}&type=${this.accentType}`;
      this.avPlayer.on('stateChange', async (state: string) => {
        if (state === 'initialized') await this.avPlayer?.prepare();
        else if (state === 'prepared') await this.avPlayer?.play();
      });
    } catch (e) {}
  }

  startZenLoop(): void {
    this.showSpelling = false;
    this.showMeaning = false;
    this.isBreathing = false;

    this.timer = setTimeout(() => {
      this.isBreathing = true;
      this.showSpelling = true;
      this.playWord(this.words[this.currentIndex].spelling);

      this.timer = setTimeout(() => {
        this.isBreathing = false;
        this.showMeaning = true;

        this.timer = setTimeout(() => {
          this.nextWord();
        }, 4000);
      }, 4000);
    }, 500);
  }

  nextWord(): void {
    if (this.currentIndex < this.words.length - 1) {
      this.currentIndex++;
      this.startZenLoop();
    } else {
      this.currentIndex = 0;
      this.startZenLoop();
    }
  }

  build() {
    NavDestination() {
      Stack({ alignContent: Alignment.Center }) {
        // 1. 背景
        Rect()
          .width('100%').height('100%')
          .linearGradient({ angle: 180, colors: [['#0F2027', 0.0], ['#203A43', 0.5], ['#2C5364', 1.0]] })

        if (this.words.length > 0) {
          // 2. 呼吸光球 (背景层，在文字底下)
          Circle({ width: 220, height: 220 })
            .fill('rgba(255, 255, 255, 0.05)')
            .scale({ x: this.isBreathing ? 1.5 : 1.0, y: this.isBreathing ? 1.5 : 1.0 })
            .animation({ duration: 4000, curve: Curve.EaseInOut })
            .blur(30)

          Circle({ width: 160, height: 160 })
            .fill('rgba(255, 255, 255, 0.1)')
            .scale({ x: this.isBreathing ? 1.3 : 1.0, y: this.isBreathing ? 1.3 : 1.0 })
            .animation({ duration: 4000, curve: Curve.EaseInOut })
            .blur(15)

          // 3. 文字层 (最上层)
          Column({ space: 24 }) {
            Text(this.words[this.currentIndex].spelling)
              .fontSize(48)
              .fontWeight(FontWeight.Bolder)
              .fontColor(Color.White)
              .opacity(this.showSpelling ? 1 : 0)
              .animation({ duration: 1000 })
              .textAlign(TextAlign.Center)

            if (this.words[this.currentIndex].phonetic) {
              Text(this.words[this.currentIndex].phonetic)
                .fontSize(18)
                .fontColor('rgba(255,255,255,0.6)')
                .opacity(this.showSpelling ? 1 : 0)
                .animation({ duration: 1000 })
            }

            Text(this.words[this.currentIndex].meaning)
              .fontSize(20)
              .fontColor('rgba(255,255,255,0.9)')
              .textAlign(TextAlign.Center)
              .padding({ left: 40, right: 40 })
              .opacity(this.showMeaning ? 1 : 0)
              .animation({ duration: 1000 })
              .margin({ top: 20 })
          }
          .justifyContent(FlexAlign.Center) // 确保文字垂直居中
          .width('100%')
          .height('100%')
          // 关键：让点击事件穿透文字层，不影响底部按钮
          .hitTestBehavior(HitTestMode.Transparent)
        } else {
          Text('No words available.\nPlease import words first.')
            .fontColor(Color.White)
            .textAlign(TextAlign.Center)
            .opacity(0.6)
        }

        // 4. 退出按钮 (固定在底部)
        Column() {
          Button('退出禅定模式')
            .backgroundColor('rgba(255,255,255,0.15)')
            .fontColor('rgba(255,255,255,0.8)')
            .fontSize(14)
            .height(44)
            .padding({ left: 32, right: 32 })
            .borderRadius(22)
            .border({ width: 1, color: 'rgba(255,255,255,0.2)' })
            .onClick(() => { this.pageStack.pop() })
            .margin({ bottom: 80 })
        }
        .width('100%').height('100%')
        .justifyContent(FlexAlign.End)
        .hitTestBehavior(HitTestMode.Transparent)
      }
      .width('100%').height('100%')
    }
    .hideTitleBar(true)
  }
}