import { DatabaseManager } from '../utils/DatabaseManager';
import { Word } from '../model/WordModel';
import { Sm2Algorithm, ReviewGrade } from '../utils/Sm2Algorithm';
import { CleanCard } from '../components/CustomComponents';
import { common } from '@kit.AbilityKit';
import { promptAction } from '@kit.ArkUI';
import { PreferenceManager } from '../utils/PreferenceManager';
import { vibrator } from '@kit.SensorServiceKit';
// [修改] 移除 textToSpeech，换回稳定的 MediaKit
import { media } from '@kit.MediaKit';
import { BusinessError } from '@kit.BasicServicesKit';

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

  @State scenarioOptions: string[] = [];
  @State scenarioQuestion: string = '';
  @State scenarioCorrectOption: string = '';
  @State scenarioFeedback: string = '';
  @State scenarioAnswered: boolean = false;

  @State cardAngle: number = 0;

  @State isCodeMode: boolean = false;
  @State isSpeaking: boolean = false;

  // [修改] 使用 AVPlayer 替代 TTS
  private avPlayer: media.AVPlayer | undefined = undefined;
  private isHapticOn: boolean = true;
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
    const prefs = PreferenceManager.getInstance();
    const limit = await prefs.getDailyLimit();
    this.isHapticOn = await prefs.isHapticEnabled();
    this.reviewMode = await prefs.getReviewMode();
    this.currentBookId = await prefs.getCurrentBook();

    this.isCodeMode = await prefs.isProgrammingMode();

    this.words = await DatabaseManager.getInstance().getTodayWordList(this.currentBookId, limit, this.reviewMode);
    this.isLoading = false;

    if (this.words.length === 0) {
      this.isFinished = true;
    } else {
      this.loadCurrentWord();
    }
  }

  // [修改] 销毁播放器资源
  aboutToDisappear(): void {
    if (this.avPlayer) {
      this.avPlayer.release();
      this.avPlayer = undefined;
    }
    this.refreshFlag++;
  }

  // [核心修改] AVPlayer 播放逻辑 (标准状态机)
  async playWord(word: string): Promise<void> {
    if (!word || this.isSpeaking) return;

    // 编程模式下，默认不自动朗读，除非手动点击
    // 这里由调用方控制逻辑，playWord 只负责播放

    this.isSpeaking = true;
    try {
      // 1. 初始化播放器
      if (!this.avPlayer) {
        this.avPlayer = await media.createAVPlayer();
        this.setAVPlayerCallback();
      }

      // 2. 重置状态
      if (this.avPlayer.state !== 'idle') {
        await this.avPlayer.reset();
      }

      // 3. 设置 URL (有道美音)
      this.avPlayer.url = `https://dict.youdao.com/dictvoice?audio=${word}&type=2`;
    } catch (e) {
      console.error(`Audio Play Failed: ${JSON.stringify(e)}`);
      this.isSpeaking = false;
    }
  }

  // [核心修改] 状态监听
  setAVPlayerCallback() {
    if (!this.avPlayer) return;
    this.avPlayer.on('stateChange', (state: media.AVPlayerState) => {
      switch (state) {
        case 'initialized':
          this.avPlayer?.prepare();
          break;
        case 'prepared':
          this.avPlayer?.play();
          break;
        case 'completed':
          this.isSpeaking = false; // 播放结束，解除锁定
          break;
        case 'error':
          this.isSpeaking = false;
          this.avPlayer?.reset();
          break;
      }
    });
    this.avPlayer.on('error', (err: BusinessError) => {
      console.error(`AVPlayer error: ${JSON.stringify(err)}`);
      this.isSpeaking = false;
    });
  }

  loadCurrentWord(): void {
    if (this.currentIndex < this.words.length) {
      animateTo({ duration: 0 }, () => { this.cardAngle = 0; });

      const word = this.words[this.currentIndex];
      this.currentNote = word.note || '';
      this.userInput = '';
      this.isSpellingCorrect = null;
      this.generateHint(word.spelling);
      this.prepareScenario(word);

      // 非编程模式且非拼写模式，自动发音
      if (this.reviewMode === 0 && !this.isCodeMode) {
        //稍微延迟一点点避免切换动画卡顿
        setTimeout(() => {
          this.playWord(word.spelling);
        }, 300);
      }
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

  prepareScenario(word: Word): void {
    this.scenarioOptions = [];
    this.scenarioQuestion = '';
    this.scenarioCorrectOption = '';
    this.scenarioFeedback = '';
    this.scenarioAnswered = false;

    if (word.senses && word.senses.length > 1) {
      const uniqueSenses = Array.from(new Set(word.senses.filter((item) => !!item)));
      if (uniqueSenses.length > 1) {
        const context = (word.collocations && word.collocations.length > 0) ? word.collocations[0] : (word.example || '选择最贴合的场景含义');
        this.scenarioQuestion = `在“${context}”的语境下，${word.spelling} 更接近哪一种含义？`;
        this.scenarioCorrectOption = uniqueSenses[0];
        this.scenarioOptions = this.shuffleArray(uniqueSenses);
      }
    }
  }

  shuffleArray(list: string[]): string[] {
    const arr = list.slice();
    for (let i = arr.length - 1; i > 0; i--) {
      const j = Math.floor(Math.random() * (i + 1));
      const tmp = arr[i];
      arr[i] = arr[j];
      arr[j] = tmp;
    }
    return arr;
  }

  async selectScenarioOption(option: string): Promise<void> {
    if (!this.scenarioOptions.length || this.scenarioAnswered) return;
    this.scenarioAnswered = true;
    const isCorrect = option === this.scenarioCorrectOption;
    this.scenarioFeedback = isCorrect ? '命中正确场景！' : `正确答案：${this.scenarioCorrectOption}`;
    const currentWord = this.words[this.currentIndex];
    if (currentWord && currentWord.id !== undefined) {
      await DatabaseManager.getInstance().recordKnowledgePractice(currentWord.id, isCorrect);
    }
  }

  triggerHaptic(grade: ReviewGrade): void { if (!this.isHapticOn) return; try { let duration = 30; if (grade === ReviewGrade.AGAIN) duration = 80; vibrator.startVibration({ type: 'time', duration: duration }, { id: 0, usage: 'touch' }); } catch (e) {} }

  checkSpelling(): void {
    const correct = this.words[this.currentIndex].spelling.trim().toLowerCase();
    const input = this.userInput.trim().toLowerCase();
    if (input === correct) {
      this.isSpellingCorrect = true;
      this.triggerHaptic(ReviewGrade.EASY);
      this.showAnswerWithFlip();
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

    let calcWord: Word = {
      id: currentWord.id,
      bookId: currentWord.bookId,
      spelling: currentWord.spelling,
      phonetic: currentWord.phonetic,
      meaning: currentWord.meaning,
      example: currentWord.example,
      note: currentWord.note,
      roots: currentWord.roots,
      affixes: currentWord.affixes,
      collocations: currentWord.collocations,
      synonyms: currentWord.synonyms,
      antonyms: currentWord.antonyms,
      derivatives: currentWord.derivatives,
      senses: currentWord.senses,
      knowledgeScore: currentWord.knowledgeScore,
      proficiency: currentWord.proficiency,
      repetition: currentWord.repetition,
      interval: currentWord.interval,
      easeFactor: currentWord.easeFactor,
      lastReviewTime: currentWord.lastReviewTime,
      nextReviewTime: currentWord.nextReviewTime,
      proficiencySpelling: currentWord.proficiencySpelling,
      repetitionSpelling: currentWord.repetitionSpelling,
      intervalSpelling: currentWord.intervalSpelling,
      easeFactorSpelling: currentWord.easeFactorSpelling,
      lastReviewTimeSpelling: currentWord.lastReviewTimeSpelling,
      nextReviewTimeSpelling: currentWord.nextReviewTimeSpelling
    };

    if (this.reviewMode === 1) {
      calcWord.interval = currentWord.intervalSpelling || 0;
      calcWord.repetition = currentWord.repetitionSpelling || 0;
      calcWord.easeFactor = currentWord.easeFactorSpelling || 2.5;
    }

    const result = Sm2Algorithm.calculate(calcWord, grade);

    if (currentWord.id !== undefined) {
      await DatabaseManager.getInstance().updateWordStats(
        currentWord.id,
        result.interval,
        result.repetition,
        result.easeFactor,
        this.reviewMode
      );
      await DatabaseManager.getInstance().logActivity();
    }

    this.refreshFlag++;

    if (this.currentIndex < this.words.length - 1) {
      this.currentIndex++;
      this.isAnswerShown = false;
      this.loadCurrentWord();
    } else {
      this.isFinished = true;
    }
  }

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
          Column({ space: 20 }) { Image($r('sys.media.ohos_ic_public_ok')).width(80).height(80).fillColor('#10B981'); Text('今日任务完成ヾ(≧▽≦*)o!').fontSize(24).fontWeight(FontWeight.Bold); Text(this.reviewMode === 1 ? 'Spelling practice done.' : 'Daily goals finished.').fontSize(16).fontColor('#999'); Button('返回主页').backgroundColor('#F0F2F5').fontColor('#333').onClick(() => { this.goBack() }) }.width('100%').height('100%').justifyContent(FlexAlign.Center)
        } else if (this.words.length > 0) {
          Row() { Image($r('sys.media.ohos_ic_public_arrow_left')).width(24).height(24).fillColor('#333').onClick(() => { this.goBack() }); Blank(); Text(`${this.currentIndex + 1} / ${this.words.length}`).fontColor('#999').fontSize(16).fontWeight(FontWeight.Medium); Blank(); Row({ space: 16 }) { Image($r('sys.media.ohos_ic_public_edit')).width(22).height(22).fillColor(this.currentNote ? '#0A59F7' : '#CCC').onClick(() => { this.noteController.open(); }); Image($r('sys.media.ohos_ic_public_remove')).width(22).height(22).fillColor('#CCC').onClick(() => { promptAction.showDialog({ title: 'Delete?', message: 'Permanently remove?', buttons: [{ text: 'Cancel', color: '#666' }, { text: 'Delete', color: '#FF4D4F' }] }).then(res => { if (res.index === 1) this.deleteCurrentWord(); }) }) } }.width('100%').padding({ left: 20, right: 20, bottom: 10 })
          Progress({ value: this.currentIndex + 1, total: this.words.length, type: ProgressType.Linear }).color('#0A59F7').width('100%').height(4)

          Column() {
            CleanCard() {
              Stack() {
                // === 卡片正面 (Front) ===
                if (this.cardAngle < 90) {
                  Column() {
                    if (this.isCodeMode) {
                      // --- 极客编程模式 (Front) ---
                      Column() {
                        Text(this.words[this.currentIndex].spelling)
                          .fontFamily('Monospace') // 代码字体
                          .fontSize(20)
                          .fontWeight(FontWeight.Regular)
                          .fontColor('#D4D4D4') // VSCode 浅灰
                          .width('100%')
                      }
                      .width('90%')
                      .padding(20)
                      .backgroundColor('#1E1E1E') // VSCode 深灰背景
                      .borderRadius(6)
                      .margin({ top: 60 })
                      .alignItems(HorizontalAlign.Start)
                      .shadow({ radius: 0 }) // 扁平化设计

                      Text('Use Case / API Signature')
                        .fontSize(12)
                        .fontColor('#666')
                        .margin({ top: 12 })
                        .fontFamily('Monospace')
                    } else {
                      // --- 正常英语模式 (Front) ---
                      if (this.reviewMode === 1) {
                        Column({ space: 16 }) { Text(this.hintText).fontSize(32).fontWeight(FontWeight.Bold).fontColor('#0A59F7').letterSpacing(2).margin({ top: 30 }); TextInput({ placeholder: 'Type the word...', text: this.userInput }).height(56).fontSize(20).fontWeight(FontWeight.Bold).textAlign(TextAlign.Center).fontColor(this.isSpellingCorrect === false ? '#FF4D4F' : '#1A1A1A').onChange((val) => { this.userInput = val; this.isSpellingCorrect = null; }).onSubmit(() => { this.checkSpelling() }); Button('Check').backgroundColor('#F0F2F5').fontColor('#333').height(40).onClick(() => { this.checkSpelling() }) }
                      } else {
                        Row({ space: 8 }) { Text(this.words[this.currentIndex].spelling).fontSize(36).fontWeight(FontWeight.Bold).fontColor('#1A1A1A'); Button({ type: ButtonType.Circle }) { Image($r('sys.media.ohos_ic_public_sound')).width(20).height(20).fillColor('#0A59F7') }.width(36).height(36).backgroundColor('rgba(10, 89, 247, 0.1)').onClick(() => { this.playWord(this.words[this.currentIndex].spelling) }) }.margin({ top: 40 }).alignItems(VerticalAlign.Center)
                      }
                      if (this.words[this.currentIndex].phonetic) Text(this.words[this.currentIndex].phonetic).fontSize(18).fontColor('#888').margin({ top: 10 })
                      if (this.reviewMode === 0 && this.scenarioOptions.length > 0) {
                        Column({ space: 8 }) {
                          Text('多义场景选择题').fontSize(14).fontColor('#0A59F7').fontWeight(FontWeight.Medium)
                          Text(this.scenarioQuestion).fontSize(14).fontColor('#555').textAlign(TextAlign.Center).margin({ bottom: 4 })
                          ForEach(this.scenarioOptions, (option: string, index?: number) => {
                            Button(option).width('100%').height(40).backgroundColor('#F5F7FA').fontColor('#1A1A1A').border({ width: 1, color: '#E5E7EB' }).onClick(() => { this.selectScenarioOption(option) }).enabled(!this.scenarioAnswered)
                          }, (option: string, index?: number) => `${option}-${index}`)
                          if (this.scenarioFeedback) Text(this.scenarioFeedback).fontSize(12).fontColor(this.scenarioFeedback.includes('正确答案') ? '#FF4D4F' : '#10B981')
                        }.width('100%').padding({ left: 8, right: 8, top: 10 }).backgroundColor('#F8FAFF').borderRadius(12).margin({ top: 16 })
                      }
                    }

                    // 点击翻转区域
                    if (this.reviewMode === 0) {
                      Column() {
                        Text(this.isCodeMode ? '> 查看实现 (View Impl)' : 'Tap to Show Answer')
                          .fontSize(16)
                          .fontColor('#BBB')
                          .fontFamily(this.isCodeMode ? 'Monospace' : '')
                      }
                      .height(200).justifyContent(FlexAlign.Center).width('100%')
                      .onClick(() => {
                        this.showAnswerWithFlip();
                        // 翻转时如果不是编程模式，再次朗读
                        if (!this.isCodeMode) this.playWord(this.words[this.currentIndex].spelling);
                      })
                    }
                  }.width('100%').height('65%')
                }
                // === 卡片背面 (Back) ===
                else {
                  Column() {
                    if (this.isCodeMode) {
                      // --- 极客编程模式 (Back) ---
                      Column() {
                        // 标题 (API Name)
                        Text(this.words[this.currentIndex].spelling)
                          .fontSize(24).fontWeight(FontWeight.Bold).fontColor('#0A59F7').fontFamily('Monospace').margin({ top: 20 })

                        Divider().color('#EEE').width('90%').margin({ top: 15, bottom: 15 })

                        // 解释 (Description)
                        Text(this.words[this.currentIndex].meaning)
                          .fontSize(16).fontColor('#333').textAlign(TextAlign.Start).width('90%').lineHeight(24)

                        // 代码示例区 (Code Snippet)
                        if (this.words[this.currentIndex].example) {
                          Column() {
                            Text(this.words[this.currentIndex].example)
                              .fontColor('#A9B7C6') // 代码灰
                              .fontSize(14)
                              .fontFamily('Monospace')
                          }
                          .width('90%')
                          .padding(12)
                          .backgroundColor('#2B2B2B') // 代码背景
                          .borderRadius(8)
                          .margin({ top: 16 })
                          .alignItems(HorizontalAlign.Start)
                        }

                        // 笔记/Tags
                        if (this.words[this.currentIndex].note) {
                          Text(`// ${this.words[this.currentIndex].note}`)
                            .fontSize(12).fontColor('#6A9955').fontFamily('Monospace').margin({ top: 10 }).width('90%')
                        }
                      }.width('100%')
                    } else {
                      // --- 正常英语模式 (Back) ---
                      Row({ space: 8 }) { Text(this.words[this.currentIndex].spelling).fontSize(32).fontWeight(FontWeight.Bold).fontColor('#1A1A1A'); Button({ type: ButtonType.Circle }) { Image($r('sys.media.ohos_ic_public_sound')).width(20).height(20).fillColor('#0A59F7') }.width(32).height(32).backgroundColor('rgba(10, 89, 247, 0.1)').onClick(() => { this.playWord(this.words[this.currentIndex].spelling) }) }.margin({ top: 20 })
                      Divider().color('#EEE').width('40%').margin({ top: 20, bottom: 20 })
                      Scroll() { Column({ space: 10 }) {
                        Text(this.words[this.currentIndex].meaning).fontSize(22).fontColor('#333').fontWeight(FontWeight.Medium).textAlign(TextAlign.Center);
                        if (this.words[this.currentIndex].example) Text(this.words[this.currentIndex].example).fontSize(16).fontColor('#666').fontStyle(FontStyle.Italic).textAlign(TextAlign.Center).margin({ top: 10 });

                        if ((this.words[this.currentIndex].roots && this.words[this.currentIndex].roots!.length > 0) || (this.words[this.currentIndex].affixes && this.words[this.currentIndex].affixes!.length > 0)) {
                          this.KnowledgeChips('词根词缀卡', (this.words[this.currentIndex].roots || []).concat(this.words[this.currentIndex].affixes || []), '#EEF2FF');
                        }

                        if (this.words[this.currentIndex].collocations && this.words[this.currentIndex].collocations!.length > 0) this.CollocationPractice(this.words[this.currentIndex].collocations!);

                        if (this.words[this.currentIndex].derivatives && this.words[this.currentIndex].derivatives!.length > 0) this.KnowledgeChips('词族树', this.words[this.currentIndex].derivatives, '#F0FDF4');

                        if (this.words[this.currentIndex].synonyms && this.words[this.currentIndex].synonyms!.length > 0) {
                          this.KnowledgeChips('同义/反义', (this.words[this.currentIndex].synonyms || []).concat(this.words[this.currentIndex].antonyms || []), '#F8FAFC');
                        }

                        if (this.words[this.currentIndex].senses && this.words[this.currentIndex].senses!.length > 0) this.KnowledgeChips('多义解读', this.words[this.currentIndex].senses, '#FFF7ED');

                        if (this.currentNote) Column() { Text('NOTE').fontSize(10).fontColor('#0A59F7').fontWeight(FontWeight.Bold); Text(this.currentNote).fontSize(14).fontColor('#666').margin({ top: 4 }) }.width('100%').padding(12).backgroundColor('#F0F9FF').borderRadius(8).alignItems(HorizontalAlign.Start).margin({ top: 20 }).onClick(() => { this.noteController.open() })
                      }.padding({ left: 20, right: 20 }) }.layoutWeight(1).scrollBar(BarState.Auto)
                    }
                  }
                  .width('100%').height('65%')
                  .rotate({ x: 0, y: 1, z: 0, angle: 180 })
                }
              }
              .rotate({ x: 0, y: 1, z: 0, angle: this.cardAngle })
            }
          }.padding({ left: 20, right: 20, top: 30 }).layoutWeight(1)

          if (this.isAnswerShown) { Row({ space: 12 }) { this.ReviewButton('Again', '#FF4D4F', () => { this.submitReview(ReviewGrade.AGAIN) }); this.ReviewButton('Hard', '#FAAD14', () => { this.submitReview(ReviewGrade.HARD) }); this.ReviewButton('Good', '#0A59F7', () => { this.submitReview(ReviewGrade.GOOD) }); this.ReviewButton('Easy', '#10B981', () => { this.submitReview(ReviewGrade.EASY) }) }.padding({ bottom: 30, left: 16, right: 16 }) }
          else { if (this.reviewMode === 0) Button('Show Answer').width('90%').height(56).backgroundColor('#0A59F7').fontSize(18).onClick(() => { this.showAnswerWithFlip(); if(!this.isCodeMode) this.playWord(this.words[this.currentIndex].spelling); }).margin({ bottom: 40 }); else Button('I don\'t know').width('90%').height(56).backgroundColor(Color.Transparent).fontColor('#999').fontSize(14).onClick(() => { this.showAnswerWithFlip(); if(!this.isCodeMode) this.playWord(this.words[this.currentIndex].spelling); }).margin({ bottom: 40 }) }
        }
      }.width('100%').height('100%').backgroundColor('#F5F7FA').padding({ top: 48 })
    }.hideTitleBar(true)
  }
  async recordKnowledge(correct: boolean = true): Promise<void> {
    const word = this.words[this.currentIndex];
    if (word && word.id !== undefined) {
      await DatabaseManager.getInstance().recordKnowledgePractice(word.id, correct);
      try { promptAction.showToast({ message: correct ? '已记录知识练习' : '已记录纠错' }); } catch (e) {}
    }
  }
  @Builder KnowledgeChips(title: string, items?: string[], bgColor: string = '#F5F7FA') {
    if (items && items.length > 0) {
      Column({ space: 8 }) {
        Text(title).fontSize(12).fontColor('#0F172A').fontWeight(FontWeight.Medium)
        Flex({ wrap: FlexWrap.Wrap }) {
          ForEach(items, (item: string, index?: number) => {
            Text(item)
              .padding({ left: 10, right: 10, top: 6, bottom: 6 })
              .margin({ right: 8, bottom: 8 })
              .backgroundColor(bgColor)
              .borderRadius(10)
              .fontColor('#111827')
              .fontSize(12)
          }, (item: string, index?: number) => `${item}-${index}`)
        }
        .width('100%')
      }
      .padding(12)
      .backgroundColor(Color.White)
      .borderRadius(12)
      .border({ width: 1, color: '#EEF2F7' })
    }
  }
  @Builder CollocationPractice(list: string[]) {
    Column({ space: 8 }) {
      Row({ space: 6 }) {
        Text('搭配练习').fontSize(12).fontColor('#0F172A').fontWeight(FontWeight.Medium)
        Button('已熟悉').type(ButtonType.Normal).height(28).padding({ left: 10, right: 10 }).fontSize(12).backgroundColor('#E0F2FE').fontColor('#0369A1').onClick(() => { this.recordKnowledge(true); })
      }
      ForEach(list, (item: string, index?: number) => {
        Row() {
          Text(item).fontSize(14).fontColor('#111827').layoutWeight(1)
          Button('不熟').type(ButtonType.Capsule).height(28).padding({ left: 10, right: 10 }).fontSize(12).backgroundColor('#FFF1F2').fontColor('#DC2626').onClick(() => { this.recordKnowledge(false); })
        }
        .padding({ top: 4, bottom: 4 })
      }, (item: string, index?: number) => `${item}-${index}`)
    }
    .padding(12)
    .backgroundColor('#F8FAFC')
    .borderRadius(12)
    .border({ width: 1, color: '#E5E7EB' })
  }
  @Builder ReviewButton(l: string, c: string, a: () => void) { Button(l).layoutWeight(1).height(50).backgroundColor(Color.White).fontColor(c).border({ width: 1, color: c }).fontSize(14).fontWeight(FontWeight.Medium).onClick(a) }
}
@CustomDialog struct NoteDialog { controller: CustomDialogController; @State text: string = ''; onConfirm: (val: string) => void = () => {}; build() { Column({ space: 16 }) { Text('Edit Note').fontSize(18).fontWeight(FontWeight.Bold).width('100%'); TextArea({ text: this.text, placeholder: 'Write your thoughts...' }).height(120).backgroundColor('#F9F9F9').onChange((val) => { this.text = val }); Row({ space: 12 }) { Button('Cancel').layoutWeight(1).backgroundColor('#F5F7FA').fontColor('#666').onClick(() => this.controller.close()); Button('Save').layoutWeight(1).backgroundColor('#0A59F7').fontColor(Color.White).onClick(() => { this.onConfirm(this.text); this.controller.close(); }) } }.padding(20).backgroundColor(Color.White).borderRadius({ topLeft: 24, topRight: 24 }).width('100%') } }