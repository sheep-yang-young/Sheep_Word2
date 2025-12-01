import { DatabaseManager } from '../utils/DatabaseManager';
import { Word } from '../model/WordModel';
import { Sm2Algorithm, ReviewGrade } from '../utils/Sm2Algorithm';
import { CleanCard } from '../components/CustomComponents';
import { media } from '@kit.MediaKit';
import { common } from '@kit.AbilityKit';
import { promptAction } from '@kit.ArkUI';
import { PreferenceManager } from '../utils/PreferenceManager';
import { vibrator } from '@kit.SensorServiceKit'; // [新增] 振动模块

@Component
export struct ReviewPage {
  @Consume('pageStack') pageStack: NavPathStack;
  @Consume refreshFlag: number;

  @State words: Word[] = [];
  @State currentIndex: number = 0;
  @State isAnswerShown: boolean = false;
  @State isFinished: boolean = false;
  @State isLoading: boolean = true;

  private avPlayer: media.AVPlayer | null = null;

  // [新增] 本地状态缓存
  private accentType: number = 2; // 默认美音
  private isHapticOn: boolean = true;

  async aboutToAppear(): Promise<void> {
    await this.initAudioPlayer();

    // 加载用户偏好
    const prefs = PreferenceManager.getInstance();
    const limit = await prefs.getDailyLimit();
    this.accentType = await prefs.getAccentType();
    this.isHapticOn = await prefs.isHapticEnabled();

    this.words = await DatabaseManager.getInstance().getTodayReviewWords(limit);
    this.isLoading = false;

    if (this.words.length === 0) {
      this.isFinished = true;
    } else {
      this.playWord(this.words[0].spelling);
    }
  }

  aboutToDisappear(): void {
    if (this.avPlayer) {
      this.avPlayer.release();
    }
  }

  async initAudioPlayer(): Promise<void> {
    try {
      this.avPlayer = await media.createAVPlayer();
    } catch (e) {
      console.error('[Lumina] Create AVPlayer failed:', e);
    }
  }

  async playWord(text: string): Promise<void> {
    if (!this.avPlayer) return;
    try {
      await this.avPlayer.reset();
      // [修改] 根据 accentType (1=UK, 2=US) 动态调整 URL
      // 有道 API: type=1(英), type=2(美)
      this.avPlayer.url = `https://dict.youdao.com/dictvoice?audio=${text}&type=${this.accentType}`;

      this.avPlayer.on('stateChange', async (state: string) => {
        if (state === 'initialized') {
          await this.avPlayer?.prepare();
        } else if (state === 'prepared') {
          await this.avPlayer?.play();
        }
      });
    } catch (e) {
      console.error('[Lumina] Play failed:', e);
    }
  }

  // [新增] 触发振动反馈
  triggerHaptic(grade: ReviewGrade): void {
    if (!this.isHapticOn) return;

    try {
      // 根据 grade 提供不同的振动时长
      let duration = 30;
      if (grade === ReviewGrade.AGAIN) duration = 100; // 忘记了，长震动提醒
      else if (grade === ReviewGrade.EASY) duration = 20; // 简单，轻微震动

      vibrator.startVibration({
        type: 'time',
        duration: duration,
      }, {
        id: 0,
        usage: 'touch'
      });
    } catch (e) {
      // 忽略不支持振动的设备报错
    }
  }

  async deleteCurrentWord(): Promise<void> {
    const word = this.words[this.currentIndex];
    if (word && word.id !== undefined) {
      await DatabaseManager.getInstance().deleteWord(word.id);
      try { promptAction.showToast({ message: 'Deleted' }); } catch (e) {}
      this.words.splice(this.currentIndex, 1);
      if (this.currentIndex >= this.words.length) {
        this.isFinished = true;
      } else {
        this.playWord(this.words[this.currentIndex].spelling);
      }
    }
  }

  goBack(): void {
    this.refreshFlag++;
    this.pageStack.pop();
  }

  async submitReview(grade: ReviewGrade): Promise<void> {
    // [新增] 触发振动
    this.triggerHaptic(grade);

    const currentWord = this.words[this.currentIndex];
    const result = Sm2Algorithm.calculate(currentWord, grade);

    if (currentWord.id !== undefined) {
      await DatabaseManager.getInstance().updateWordStats(
        currentWord.id,
        result.interval,
        result.repetition,
        result.easeFactor
      );
      // 记录活跃
      await DatabaseManager.getInstance().logActivity();
    }

    if (this.currentIndex < this.words.length - 1) {
      this.currentIndex++;
      this.isAnswerShown = false;
      this.playWord(this.words[this.currentIndex].spelling);
    } else {
      this.isFinished = true;
      this.refreshFlag++;
    }
  }

  build() {
    NavDestination() {
      Column() {
        if (this.isLoading) {
          LoadingProgress().width(50).height(50).color('#0A59F7')
        } else if (this.isFinished) {
          Column({ space: 20 }) {
            Image($r('sys.media.ohos_ic_public_ok')).width(80).height(80).fillColor('#10B981')
            Text('Session Complete!').fontSize(24).fontWeight(FontWeight.Bold)
            Text('You have finished your daily goals.').fontSize(16).fontColor('#999')
            Button('Back to Home').backgroundColor('#F0F2F5').fontColor('#333')
              .onClick(() => { this.goBack() })
          }
          .width('100%').height('100%').justifyContent(FlexAlign.Center)
        } else if (this.words.length > 0) {
          // Top Bar
          Row() {
            Image($r('sys.media.ohos_ic_public_arrow_left')).width(24).height(24).fillColor('#333').onClick(() => { this.goBack() })
            Blank()
            Text(`${this.currentIndex + 1} / ${this.words.length}`).fontColor('#999').fontSize(16).fontWeight(FontWeight.Medium)
            Blank()
            Image($r('sys.media.ohos_ic_public_remove')).width(20).height(20).fillColor('#CCC')
              .onClick(() => {
                promptAction.showDialog({ title: 'Delete Word?', message: 'Permanently remove?', buttons: [{ text: 'Cancel', color: '#666' }, { text: 'Delete', color: '#FF4D4F' }] }).then(res => { if (res.index === 1) this.deleteCurrentWord(); })
              })
          }
          .width('100%').padding({ left: 20, right: 20, bottom: 10 })

          Progress({ value: this.currentIndex + 1, total: this.words.length, type: ProgressType.Linear }).color('#0A59F7').width('100%').height(4)

          Column() {
            CleanCard() {
              Column() {
                Row({ space: 8 }) {
                  Text(this.words[this.currentIndex].spelling).fontSize(36).fontWeight(FontWeight.Bold).fontColor('#1A1A1A')
                  Button({ type: ButtonType.Circle }) { Image($r('sys.media.ohos_ic_public_sound')).width(20).height(20).fillColor('#0A59F7') }
                  .width(36).height(36).backgroundColor('rgba(10, 89, 247, 0.1)')
                  .onClick(() => { this.playWord(this.words[this.currentIndex].spelling) })
                }
                .margin({ top: 40 }).alignItems(VerticalAlign.Center)

                if (this.words[this.currentIndex].phonetic) Text(this.words[this.currentIndex].phonetic).fontSize(18).fontColor('#888').margin({ top: 10 })

                if (this.isAnswerShown) {
                  Divider().color('#EEE').width('40%').margin({ top: 40, bottom: 40 })
                  Text(this.words[this.currentIndex].meaning).fontSize(22).fontColor('#333').fontWeight(FontWeight.Medium).textAlign(TextAlign.Center)
                  if (this.words[this.currentIndex].example) Text(this.words[this.currentIndex].example).fontSize(16).fontColor('#666').fontStyle(FontStyle.Italic).textAlign(TextAlign.Center).margin({ top: 20 }).padding({ left: 20, right: 20 })
                } else {
                  Column() { Text('Tap to Show Answer').fontSize(16).fontColor('#BBB') }
                  .height(200).justifyContent(FlexAlign.Center).width('100%')
                  .onClick(() => {
                    this.getUIContext().animateTo({ duration: 300 }, () => {
                      this.isAnswerShown = true;
                      this.playWord(this.words[this.currentIndex].spelling);
                    })
                  })
                }
              }
              .width('100%').height('65%')
            }
          }
          .padding({ left: 20, right: 20, top: 30 }).layoutWeight(1)

          if (this.isAnswerShown) {
            Row({ space: 12 }) {
              this.ReviewButton('Again', '#FF4D4F', () => { this.submitReview(ReviewGrade.AGAIN) })
              this.ReviewButton('Hard', '#FAAD14', () => { this.submitReview(ReviewGrade.HARD) })
              this.ReviewButton('Good', '#0A59F7', () => { this.submitReview(ReviewGrade.GOOD) })
              this.ReviewButton('Easy', '#10B981', () => { this.submitReview(ReviewGrade.EASY) })
            }
            .padding({ bottom: 30, left: 16, right: 16 })
          } else {
            Button('Show Answer').width('90%').height(56).backgroundColor('#0A59F7').fontSize(18)
              .onClick(() => {
                this.getUIContext().animateTo({ duration: 300 }, () => {
                  this.isAnswerShown = true;
                  this.playWord(this.words[this.currentIndex].spelling);
                })
              })
              .margin({ bottom: 40 })
          }
        }
      }
      .width('100%').height('100%').backgroundColor('#F5F7FA').padding({ top: 48 })
    }
    .hideTitleBar(true)
  }

  @Builder ReviewButton(label: string, color: string, action: () => void) {
    Button(label).layoutWeight(1).height(50).backgroundColor(Color.White).fontColor(color).border({ width: 1, color: color }).fontSize(14).fontWeight(FontWeight.Medium).onClick(action)
  }
}