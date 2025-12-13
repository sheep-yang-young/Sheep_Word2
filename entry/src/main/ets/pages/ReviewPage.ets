import { DatabaseManager } from '../utils/DatabaseManager';
import { Word } from '../model/WordModel';
import { Sm2Algorithm, ReviewGrade } from '../utils/Sm2Algorithm';
import { CleanCard } from '../components/CustomComponents';
import { media } from '@kit.MediaKit';
import { common } from '@kit.AbilityKit';
import { promptAction } from '@kit.ArkUI';
import { PreferenceManager } from '../utils/PreferenceManager';
import { vibrator } from '@kit.SensorServiceKit';

@Component
export struct ReviewPage {
  @Consume('pageStack') pageStack: NavPathStack;
  @Consume refreshFlag: number;

  @State words: Word[] = [];
  @State currentIndex: number = 0;
  @State isAnswerShown: boolean = false;
  @State isFinished: boolean = false;
  @State isLoading: boolean = true;

  @State currentNote: string = '';

  @State reviewMode: number = 0;
  @State userInput: string = '';
  @State isSpellingCorrect: boolean | null = null;
  @State hintText: string = '';

  // [动效] 卡片旋转角度
  @State cardAngle: number = 0;

  private avPlayer: media.AVPlayer | null = null;
  private accentType: number = 2;
  private isHapticOn: boolean = true;
  private ttsSpeed: number = 1.0;
  private currentBookId: string = "Default Library";

  noteController: CustomDialogController = new CustomDialogController({
    builder: NoteDialog({
      text: this.currentNote,
      onConfirm: (val: string) => { this.saveNote(val) }
    }),
    alignment: DialogAlignment.Bottom,
    autoCancel: true,
    customStyle: true
  });

  async aboutToAppear(): Promise<void> {
    await this.initAudioPlayer();
    const prefs = PreferenceManager.getInstance();
    const limit = await prefs.getDailyLimit();
    this.accentType = await prefs.getAccentType();
    this.isHapticOn = await prefs.isHapticEnabled();
    this.reviewMode = await prefs.getReviewMode();
    this.ttsSpeed = await prefs.getTtsSpeed();
    this.currentBookId = await prefs.getCurrentBook();

    this.words = await DatabaseManager.getInstance().getTodayReviewWords(this.currentBookId, limit);
    this.isLoading = false;

    if (this.words.length === 0) {
      this.isFinished = true;
    } else {
      this.loadCurrentWord();
    }
  }

  loadCurrentWord(): void {
    if (this.currentIndex < this.words.length) {
      // 重置翻转状态
      animateTo({ duration: 0 }, () => { this.cardAngle = 0; });

      const word = this.words[this.currentIndex];
      this.currentNote = word.note || '';
      this.userInput = '';
      this.isSpellingCorrect = null;
      this.generateHint(word.spelling);

      if (this.reviewMode === 0) this.playWord(word.spelling);
    }
  }

  generateHint(word: string): void {
    if (!word) { this.hintText = ''; return; }
    const cleanWord = word.trim();
    const len = cleanWord.length;
    if (len <= 2) { this.hintText = '_ '.repeat(len); return; }
    const revealCount = Math.ceil(len / 3);
    const indices = new Set<number>();
    while(indices.size < revealCount) indices.add(Math.floor(Math.random() * len));
    let hint = '';
    for (let i = 0; i < len; i++) { if (indices.has(i)) hint += cleanWord[i] + ' '; else hint += '_ '; }
    this.hintText = hint.trim();
  }

  aboutToDisappear(): void { if (this.avPlayer) this.avPlayer.release(); this.refreshFlag++; }
  async initAudioPlayer(): Promise<void> { try { this.avPlayer = await media.createAVPlayer(); } catch (e) {} }

  async playWord(text: string): Promise<void> {
    if (!this.avPlayer) return;
    try {
      await this.avPlayer.reset();
      this.avPlayer.url = `https://dict.youdao.com/dictvoice?audio=${text}&type=${this.accentType}`;
      this.avPlayer.on('stateChange', async (state: string) => {
        if (state === 'initialized') await this.avPlayer?.prepare();
        else if (state === 'prepared') { await this.avPlayer?.setSpeed(this.ttsSpeed); await this.avPlayer?.play(); }
      });
    } catch (e) {}
  }

  triggerHaptic(grade: ReviewGrade): void { if (!this.isHapticOn) return; try { let duration = 30; if (grade === ReviewGrade.AGAIN) duration = 80; vibrator.startVibration({ type: 'time', duration: duration }, { id: 0, usage: 'touch' }); } catch (e) {} }

  checkSpelling(): void {
    const correct = this.words[this.currentIndex].spelling.trim().toLowerCase();
    const input = this.userInput.trim().toLowerCase();
    if (input === correct) {
      this.isSpellingCorrect = true;
      this.triggerHaptic(ReviewGrade.EASY);
      this.showAnswerWithFlip(); // 拼写正确也翻转
      this.playWord(this.words[this.currentIndex].spelling);
    } else {
      this.isSpellingCorrect = false;
      this.triggerHaptic(ReviewGrade.AGAIN);
    }
  }

  async saveNote(val: string): Promise<void> { const word = this.words[this.currentIndex]; this.currentNote = val; word.note = val; if (word.id !== undefined) await DatabaseManager.getInstance().updateWordNote(word.id, val); }
  async deleteCurrentWord(): Promise<void> { const word = this.words[this.currentIndex]; if (word && word.id !== undefined) { await DatabaseManager.getInstance().deleteWord(word.id); try { promptAction.showToast({ message: 'Deleted' }); } catch (e) {} this.words.splice(this.currentIndex, 1); if (this.currentIndex >= this.words.length) this.isFinished = true; else this.loadCurrentWord(); } }
  goBack(): void { this.refreshFlag++; this.pageStack.pop(); }

  async submitReview(grade: ReviewGrade): Promise<void> {
    this.triggerHaptic(grade);
    const currentWord = this.words[this.currentIndex];
    const result = Sm2Algorithm.calculate(currentWord, grade);
    if (currentWord.id !== undefined) { await DatabaseManager.getInstance().updateWordStats(currentWord.id, result.interval, result.repetition, result.easeFactor); await DatabaseManager.getInstance().logActivity(); }

    this.refreshFlag++;

    if (this.currentIndex < this.words.length - 1) {
      this.currentIndex++;
      this.isAnswerShown = false;
      this.loadCurrentWord();
    } else {
      this.isFinished = true;
    }
  }

  // 翻转显示答案
  showAnswerWithFlip() {
    this.isAnswerShown = true;
    animateTo({ duration: 600, curve: Curve.EaseInOut }, () => {
      this.cardAngle = 180;
    });
  }

  build() {
    NavDestination() {
      Column() {
        if (this.isLoading) { LoadingProgress().width(50).height(50).color('#0A59F7') }
        else if (this.isFinished) {
          Column({ space: 20 }) { Image($r('sys.media.ohos_ic_public_ok')).width(80).height(80).fillColor('#10B981'); Text('Session Complete!').fontSize(24).fontWeight(FontWeight.Bold); Text(this.reviewMode === 1 ? 'Spelling practice done.' : 'Daily goals finished.').fontSize(16).fontColor('#999'); Button('Back to Home').backgroundColor('#F0F2F5').fontColor('#333').onClick(() => { this.goBack() }) }.width('100%').height('100%').justifyContent(FlexAlign.Center)
        } else if (this.words.length > 0) {
          Row() { Image($r('sys.media.ohos_ic_public_arrow_left')).width(24).height(24).fillColor('#333').onClick(() => { this.goBack() }); Blank(); Text(`${this.currentIndex + 1} / ${this.words.length}`).fontColor('#999').fontSize(16).fontWeight(FontWeight.Medium); Blank(); Row({ space: 16 }) { Image($r('sys.media.ohos_ic_public_edit')).width(22).height(22).fillColor(this.currentNote ? '#0A59F7' : '#CCC').onClick(() => { this.noteController.open(); }); Image($r('sys.media.ohos_ic_public_remove')).width(22).height(22).fillColor('#CCC').onClick(() => { promptAction.showDialog({ title: 'Delete?', message: 'Permanently remove?', buttons: [{ text: 'Cancel', color: '#666' }, { text: 'Delete', color: '#FF4D4F' }] }).then(res => { if (res.index === 1) this.deleteCurrentWord(); }) }) } }.width('100%').padding({ left: 20, right: 20, bottom: 10 })
          Progress({ value: this.currentIndex + 1, total: this.words.length, type: ProgressType.Linear }).color('#0A59F7').width('100%').height(4)

          Column() {
            CleanCard() {
              Stack() {
                // --- 正面 ---
                if (this.cardAngle < 90) {
                  Column() {
                    if (this.reviewMode === 1) {
                      Column({ space: 16 }) { Text(this.hintText).fontSize(32).fontWeight(FontWeight.Bold).fontColor('#0A59F7').letterSpacing(2).margin({ top: 30 }); TextInput({ placeholder: 'Type the word...', text: this.userInput }).height(56).fontSize(20).fontWeight(FontWeight.Bold).textAlign(TextAlign.Center).fontColor(this.isSpellingCorrect === false ? '#FF4D4F' : '#1A1A1A').onChange((val) => { this.userInput = val; this.isSpellingCorrect = null; }).onSubmit(() => { this.checkSpelling() }); Button('Check').backgroundColor('#F0F2F5').fontColor('#333').height(40).onClick(() => { this.checkSpelling() }) }
                    } else {
                      Row({ space: 8 }) { Text(this.words[this.currentIndex].spelling).fontSize(36).fontWeight(FontWeight.Bold).fontColor('#1A1A1A'); Button({ type: ButtonType.Circle }) { Image($r('sys.media.ohos_ic_public_sound')).width(20).height(20).fillColor('#0A59F7') }.width(36).height(36).backgroundColor('rgba(10, 89, 247, 0.1)').onClick(() => { this.playWord(this.words[this.currentIndex].spelling) }) }.margin({ top: 40 }).alignItems(VerticalAlign.Center)
                    }
                    if (this.words[this.currentIndex].phonetic) Text(this.words[this.currentIndex].phonetic).fontSize(18).fontColor('#888').margin({ top: 10 })
                    if (this.reviewMode === 0) Column() { Text('Tap to Show Answer').fontSize(16).fontColor('#BBB') }.height(200).justifyContent(FlexAlign.Center).width('100%').onClick(() => { this.showAnswerWithFlip(); this.playWord(this.words[this.currentIndex].spelling); })
                  }.width('100%').height('65%')
                }
                // --- 背面 ---
                else {
                  Column() {
                    Row({ space: 8 }) { Text(this.words[this.currentIndex].spelling).fontSize(32).fontWeight(FontWeight.Bold).fontColor('#1A1A1A'); Button({ type: ButtonType.Circle }) { Image($r('sys.media.ohos_ic_public_sound')).width(20).height(20).fillColor('#0A59F7') }.width(32).height(32).backgroundColor('rgba(10, 89, 247, 0.1)').onClick(() => { this.playWord(this.words[this.currentIndex].spelling) }) }.margin({ top: 20 })
                    Divider().color('#EEE').width('40%').margin({ top: 20, bottom: 20 })
                    Scroll() { Column({ space: 10 }) { Text(this.words[this.currentIndex].meaning).fontSize(22).fontColor('#333').fontWeight(FontWeight.Medium).textAlign(TextAlign.Center); if (this.words[this.currentIndex].example) Text(this.words[this.currentIndex].example).fontSize(16).fontColor('#666').fontStyle(FontStyle.Italic).textAlign(TextAlign.Center).margin({ top: 10 }); if (this.currentNote) Column() { Text('NOTE').fontSize(10).fontColor('#0A59F7').fontWeight(FontWeight.Bold); Text(this.currentNote).fontSize(14).fontColor('#666').margin({ top: 4 }) }.width('100%').padding(12).backgroundColor('#F0F9FF').borderRadius(8).alignItems(HorizontalAlign.Start).margin({ top: 20 }).onClick(() => { this.noteController.open() }) }.padding({ left: 20, right: 20 }) }.layoutWeight(1).scrollBar(BarState.Auto)
                  }
                  .width('100%').height('65%')
                  // [核心修复] 正确的旋转参数：绕Y轴旋转180度
                  .rotate({ x: 0, y: 1, z: 0, angle: 180 })
                }
              }
              // 容器整体旋转动画
              .rotate({ x: 0, y: 1, z: 0, angle: this.cardAngle })
            }
          }.padding({ left: 20, right: 20, top: 30 }).layoutWeight(1)

          if (this.isAnswerShown) { Row({ space: 12 }) { this.ReviewButton('Again', '#FF4D4F', () => { this.submitReview(ReviewGrade.AGAIN) }); this.ReviewButton('Hard', '#FAAD14', () => { this.submitReview(ReviewGrade.HARD) }); this.ReviewButton('Good', '#0A59F7', () => { this.submitReview(ReviewGrade.GOOD) }); this.ReviewButton('Easy', '#10B981', () => { this.submitReview(ReviewGrade.EASY) }) }.padding({ bottom: 30, left: 16, right: 16 }) }
          else { if (this.reviewMode === 0) Button('Show Answer').width('90%').height(56).backgroundColor('#0A59F7').fontSize(18).onClick(() => { this.showAnswerWithFlip(); this.playWord(this.words[this.currentIndex].spelling); }).margin({ bottom: 40 }); else Button('I don\'t know').width('90%').height(56).backgroundColor(Color.Transparent).fontColor('#999').fontSize(14).onClick(() => { this.showAnswerWithFlip(); this.playWord(this.words[this.currentIndex].spelling); }).margin({ bottom: 40 }) }
        }
      }.width('100%').height('100%').backgroundColor('#F5F7FA').padding({ top: 48 })
    }.hideTitleBar(true)
  }
  @Builder ReviewButton(l: string, c: string, a: () => void) { Button(l).layoutWeight(1).height(50).backgroundColor(Color.White).fontColor(c).border({ width: 1, color: c }).fontSize(14).fontWeight(FontWeight.Medium).onClick(a) }
}
@CustomDialog struct NoteDialog { controller: CustomDialogController; @State text: string = ''; onConfirm: (val: string) => void = () => {}; build() { Column({ space: 16 }) { Text('Edit Note').fontSize(18).fontWeight(FontWeight.Bold).width('100%'); TextArea({ text: this.text, placeholder: 'Write your thoughts...' }).height(120).backgroundColor('#F9F9F9').onChange((val) => { this.text = val }); Row({ space: 12 }) { Button('Cancel').layoutWeight(1).backgroundColor('#F5F7FA').fontColor('#666').onClick(() => this.controller.close()); Button('Save').layoutWeight(1).backgroundColor('#0A59F7').fontColor(Color.White).onClick(() => { this.onConfirm(this.text); this.controller.close(); }) } }.padding(20).backgroundColor(Color.White).borderRadius({ topLeft: 24, topRight: 24 }).width('100%') } }