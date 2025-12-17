import { DatabaseManager } from '../utils/DatabaseManager';
import { Word } from '../model/WordModel';
import { media } from '@kit.MediaKit';
import { avSession } from '@kit.AVSessionKit';
import { audio } from '@kit.AudioKit';
import { common } from '@kit.AbilityKit';
import { PreferenceManager } from '../utils/PreferenceManager';

// 播放阶段枚举
enum PlayStage {
  WORD = 0,    // 正在读英文
  MEANING = 1, // 正在读中文
  WAITING = 2  // 等待下一首
}

@Component
export struct PodcastPage {
  @Consume('pageStack') pageStack: NavPathStack;
  @State isPlaying: boolean = false;
  @State currentIndex: number = 0;
  @State playList: Word[] = [];
  @State currentWord: Word = { id: 0, bookId: '', spelling: 'Loading...', meaning: '', proficiency: 0, repetition: 0, interval: 0, easeFactor: 0, lastReviewTime: 0, nextReviewTime: 0 };

  private avPlayer: media.AVPlayer | null = null;
  private session: avSession.AVSession | null = null;
  private timer: number = -1;
  private currentStage: PlayStage = PlayStage.WORD; // 当前播放阶段

  async aboutToAppear() {
    const bookId = await PreferenceManager.getInstance().getCurrentBook();
    const limit = await PreferenceManager.getInstance().getDailyLimit();

    // 获取单词
    let words = await DatabaseManager.getInstance().getTodayWordList(bookId, limit, 0);
    if (words.length === 0) {
      words = await DatabaseManager.getInstance().getRandomWords(bookId, 20);
    }

    // 洗牌算法：彻底打乱数组
    this.shuffleArray(words);
    this.playList = words;

    if (this.playList.length > 0) {
      this.currentWord = this.playList[0];
      await this.initSession();
      await this.initPlayer();
    }
  }

  // [修复] Fisher-Yates 洗牌算法 (使用临时变量交换，替代解构赋值)
  shuffleArray(array: Word[]) {
    for (let i = array.length - 1; i > 0; i--) {
      const j = Math.floor(Math.random() * (i + 1));
      // ArkTS 不支持 [a, b] = [b, a] 写法，改为传统交换
      let temp = array[i];
      array[i] = array[j];
      array[j] = temp;
    }
  }

  async aboutToDisappear() {
    this.stopPlay();
    if (this.avPlayer) { await this.avPlayer.release(); this.avPlayer = null; }
    if (this.session) { await this.session.destroy(); this.session = null; }
  }

  async initSession() {
    try {
      const context = getContext(this) as common.UIAbilityContext;
      this.session = await avSession.createAVSession(context, 'LuminaPodcast', 'audio');
      await this.session.activate();
      this.session.on('play', () => { this.togglePlay() });
      this.session.on('pause', () => { this.togglePlay() });
      this.session.on('playNext', () => { this.playNext() });
      this.session.on('playPrevious', () => { this.playPrev() });
    } catch (e) {}
  }

  async updateSessionMetadata() {
    if (!this.session) return;
    try {
      const metadata: avSession.AVMetadata = {
        assetId: this.currentWord.id?.toString() || '0',
        title: this.currentWord.spelling,
        artist: this.currentWord.meaning,
      };
      await this.session.setAVMetadata(metadata);
    } catch (e) {}
  }

  async updateSessionState(state: avSession.PlaybackState) {
    if (!this.session) return;
    try {
      const playbackState: avSession.AVPlaybackState = {
        state: state,
        position: { elapsedTime: 0, updateTime: new Date().getTime() }
      };
      await this.session.setAVPlaybackState(playbackState);
    } catch (e) {}
  }

  async initPlayer() {
    try {
      this.avPlayer = await media.createAVPlayer();
      this.avPlayer.audioRendererInfo = {
        usage: audio.StreamUsage.STREAM_USAGE_MEDIA,
        rendererFlags: 0
      };

      this.avPlayer.on('stateChange', async (state) => {
        switch (state) {
          case 'initialized':
            await this.avPlayer?.prepare();
            break;
          case 'prepared':
            this.avPlayer?.play();
            this.isPlaying = true;
            this.updateSessionState(avSession.PlaybackState.PLAYBACK_STATE_PLAY);
            break;
          case 'completed':
            // 播放完成后的状态流转
            this.handlePlaybackComplete();
            break;
          case 'error':
            this.isPlaying = false;
            this.updateSessionState(avSession.PlaybackState.PLAYBACK_STATE_ERROR);
            break;
        }
      });
    } catch (e) {}
  }

  // 播放完成处理逻辑
  handlePlaybackComplete() {
    if (this.currentStage === PlayStage.WORD) {
      // 英文读完了 -> 读中文
      this.currentStage = PlayStage.MEANING;
      this.timer = setTimeout(() => {
        this.playAudio(true); // true 表示读中文
      }, 500);
    } else if (this.currentStage === PlayStage.MEANING) {
      // 中文读完了 -> 进入等待 -> 下一首
      this.currentStage = PlayStage.WAITING;
      this.updateSessionState(avSession.PlaybackState.PLAYBACK_STATE_COMPLETED);
      this.timer = setTimeout(() => {
        this.playNext();
      }, 1500); // 间隔 1.5 秒
    }
  }

  // 播放音频核心方法
  async playAudio(isChinese: boolean) {
    if (!this.avPlayer) return;
    try {
      await this.avPlayer.reset();

      // 更新播控中心信息
      if (!isChinese) await this.updateSessionMetadata();

      let text = '';
      let langParam = '';

      if (isChinese) {
        // 读中文：截取前50个字符防止太长，并进行 URL 编码
        text = encodeURIComponent(this.currentWord.meaning.substring(0, 50));
        langParam = '&le=zh';
      } else {
        // 读英文
        text = this.currentWord.spelling;
        langParam = '&type=2'; // 美音
      }

      this.avPlayer.url = `https://dict.youdao.com/dictvoice?audio=${text}${langParam}`;
    } catch (e) {
      this.playNext(); // 出错跳过
    }
  }

  playNext() {
    if (this.playList.length === 0) return;
    // 顺序循环播放（因为列表已经是乱序的了）
    this.currentIndex = (this.currentIndex + 1) % this.playList.length;
    this.currentWord = this.playList[this.currentIndex];

    // 重置为读英文阶段
    this.currentStage = PlayStage.WORD;
    this.playAudio(false);
  }

  playPrev() {
    if (this.playList.length === 0) return;
    this.currentIndex = (this.currentIndex - 1 + this.playList.length) % this.playList.length;
    this.currentWord = this.playList[this.currentIndex];

    this.currentStage = PlayStage.WORD;
    this.playAudio(false);
  }

  async togglePlay() {
    if (!this.avPlayer) return;
    if (this.isPlaying) {
      await this.avPlayer.pause();
      this.isPlaying = false;
      this.updateSessionState(avSession.PlaybackState.PLAYBACK_STATE_PAUSE);
      clearTimeout(this.timer);
    } else {
      if (this.avPlayer.state === 'idle' || this.avPlayer.state === 'initialized') {
        this.playAudio(this.currentStage === PlayStage.MEANING);
      } else {
        await this.avPlayer.play();
        this.isPlaying = true;
        this.updateSessionState(avSession.PlaybackState.PLAYBACK_STATE_PLAY);
      }
    }
  }

  async stopPlay() {
    this.isPlaying = false;
    await this.avPlayer?.stop();
    this.updateSessionState(avSession.PlaybackState.PLAYBACK_STATE_STOP);
    clearTimeout(this.timer);
  }

  build() {
    NavDestination() {
      Column() {
        // 顶部栏
        Row() {
          Button({ type: ButtonType.Circle }) { SymbolGlyph($r('sys.symbol.chevron_left')).fontSize(24).fontColor([Color.Black]) }
          .backgroundColor(Color.Transparent).width(48).height(48).onClick(() => this.pageStack.pop())
          Text('随声听').fontSize(20).fontWeight(FontWeight.Bold).margin({ left: 4 })
        }.width('100%').padding({ top: 56, left: 16, right: 16, bottom: 10 }).alignItems(VerticalAlign.Center)

        // 唱片动画区
        Column() {
          Stack({ alignContent: Alignment.Center }) {
            Circle({ width: 260, height: 260 })
              .fill('#E0E0E0')
              .opacity(0.3)

            Image($r('app.media.icon'))
              .width(200).height(200)
              .borderRadius(100)
              .rotate({ angle: this.isPlaying ? 360 : 0 })
              .animation({
                duration: 10000,
                iterations: -1,
                curve: Curve.Linear,
                playMode: PlayMode.Normal
              })
          }
          .margin({ top: 60, bottom: 40 })

          Text(this.currentWord.spelling)
            .fontSize(36).fontWeight(FontWeight.Bold).fontColor('#1A1A1A')

          Text(this.currentWord.phonetic ? `/${this.currentWord.phonetic}/` : '')
            .fontSize(16).fontColor('#666').margin({ top: 8 })

          Text(this.currentWord.meaning)
            .fontSize(18)
            .fontWeight(this.currentStage === PlayStage.MEANING ? FontWeight.Bold : FontWeight.Normal)
            .fontColor(this.currentStage === PlayStage.MEANING ? '#0A59F7' : '#333')
            .textAlign(TextAlign.Center)
            .padding({ left: 30, right: 30 })
            .margin({ top: 20 })
            .maxLines(4)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .animation({ duration: 300 })
        }
        .layoutWeight(1)

        // 控制栏
        Row({ space: 40 }) {
          Image($r('sys.media.ohos_ic_public_arrow_left'))
            .width(32).height(32)
            .onClick(() => this.playPrev())

          Image(this.isPlaying ? $r('sys.media.ohos_ic_public_pause') : $r('sys.media.ohos_ic_public_play'))
            .width(64).height(64)
            .fillColor('#0A59F7')
            .onClick(() => this.togglePlay())

          Image($r('sys.media.ohos_ic_public_arrow_right'))
            .width(32).height(32)
            .onClick(() => this.playNext())
        }
        .padding({ bottom: 60 })
      }
      .width('100%').height('100%').backgroundColor('#F5F7FA')
    }
    .hideTitleBar(true)
    .onReady(async () => {
      // 自动开始 (如需要)
      // this.playAudio(false);
    })
  }
}