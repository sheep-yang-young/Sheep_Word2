import { fileIo as fs, picker } from '@kit.CoreFileKit';
import { media } from '@kit.MediaKit';
import { avSession } from '@kit.AVSessionKit';
import { common } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { promptAction } from '@kit.ArkUI';

// --- 数据模型 ---
class LocalAudio {
  fileName: string;
  filePath: string; // 沙箱绝对路径
  duration: number; // 时长(ms)

  constructor(name: string, path: string, duration: number = 0) {
    this.fileName = name;
    this.filePath = path;
    this.duration = duration;
  }
}

@Component
export struct PodcastPage {
  @Consume('pageStack') pageStack: NavPathStack;

  // --- 状态变量 ---
  @State audioList: LocalAudio[] = [];
  @State currentAudio: LocalAudio | null = null;

  @State isPlaying: boolean = false;
  @State currentTime: number = 0;
  @State totalTime: number = 0;
  @State sliderValue: number = 0;
  @State isSliderDragging: boolean = false;

  // --- 内部实例 ---
  private avPlayer: media.AVPlayer | null = null;
  private session: avSession.AVSession | null = null;
  private context = getContext(this) as common.UIAbilityContext;
  private currentFileHandle: fs.File | null = null;

  // --- 生命周期 ---
  async aboutToAppear() {
    // 1. 初始化播放器
    await this.initAVPlayer();
    // 2. 初始化实况窗
    await this.initAVSession();
    // 3. 加载本地文件
    this.loadAudioList();
  }

  async aboutToDisappear() {
    if (this.avPlayer) {
      await this.avPlayer.release();
      this.avPlayer = null;
    }
    if (this.session) {
      await this.session.destroy();
      this.session = null;
    }
    if (this.currentFileHandle) {
      fs.closeSync(this.currentFileHandle);
      this.currentFileHandle = null;
    }
  }

  // --- 核心逻辑：加载列表 (不做后缀过滤) ---
  loadAudioList() {
    try {
      const filesDir = this.context.filesDir;
      const fileNames = fs.listFileSync(filesDir);

      // 修改点：不过滤后缀，只过滤掉以点开头的隐藏文件(可选)
      const visibleFiles = fileNames.filter(name => !name.startsWith('.'));

      this.audioList = visibleFiles.map(name => {
        return new LocalAudio(name, `${filesDir}/${name}`);
      });

      // 如果当前没有播放，且列表有数据，预选中第一个
      if (this.audioList.length > 0 && !this.currentAudio) {
        this.currentAudio = this.audioList[0];
        this.loadSource(this.currentAudio.filePath);
      }
    } catch (e) {
      console.error(`[Podcast] Load list error: ${e}`);
    }
  }

  // --- 核心逻辑：导入 (真实文件名 + 严格去重) ---
  async importAudio() {
    try {
      const audioPicker = new picker.AudioViewPicker(this.context);
      // SelectOptions 不设置 MIME 类型，允许选择所有文件
      const result = await audioPicker.select(new picker.AudioSelectOptions());

      if (result.length > 0) {
        let successCount = 0;
        let duplicateCount = 0;

        result.forEach(uri => {
          // 1. 获取真实文件名
          // 这里的 decodeURIComponent 是为了把 %20 等符号转回空格
          let fileName = decodeURIComponent(uri.split('/').pop() || '');

          // 如果解析失败（极少见），才给个默认名
          if (!fileName) fileName = `Audio_${Date.now()}.mp3`;

          // 2. 检查沙箱是否已存在同名文件 (去重)
          const destPath = `${this.context.filesDir}/${fileName}`;
          const isExist = fs.accessSync(destPath);

          if (!isExist) {
            // 不存在 -> 复制
            this.copyFileToSandbox(uri, fileName);
            successCount++;
          } else {
            // 存在 -> 跳过
            duplicateCount++;
            console.info(`[Podcast] 跳过重复文件: ${fileName}`);
          }
        });

        // 3. 刷新列表
        this.loadAudioList();

        // 4. 提示
        let msg = `导入成功 ${successCount} 个`;
        if (duplicateCount > 0) msg += `，跳过重复 ${duplicateCount} 个`;
        promptAction.showToast({ message: msg });
      }
    } catch (e) {
      console.error(`[Podcast] Import error: ${e}`);
    }
  }

  copyFileToSandbox(srcUri: string, fileName: string) {
    try {
      const srcFile = fs.openSync(srcUri, fs.OpenMode.READ_ONLY);
      const destPath = `${this.context.filesDir}/${fileName}`;
      fs.copyFileSync(srcFile.fd, destPath);
      fs.closeSync(srcFile);
    } catch (e) {
      console.error(`[Podcast] Copy failed: ${e}`);
    }
  }

  deleteAudio(audio: LocalAudio) {
    try {
      if (fs.accessSync(audio.filePath)) {
        fs.unlinkSync(audio.filePath);
      }
      this.audioList = this.audioList.filter(item => item.filePath !== audio.filePath);

      if (this.currentAudio?.filePath === audio.filePath) {
        if (this.audioList.length > 0) {
          this.switchAudio(this.audioList[0], false);
        } else {
          this.currentAudio = null;
          this.avPlayer?.reset();
          this.isPlaying = false;
          this.updateSessionState(avSession.PlaybackState.PLAYBACK_STATE_PAUSE);
        }
      }
      promptAction.showToast({ message: '已删除' });
    } catch (e) {
      console.error(`[Podcast] Delete failed: ${e}`);
    }
  }

  // --- AVSession (实况窗) ---
  async initAVSession() {
    try {
      this.session = await avSession.createAVSession(this.context, 'DreamAbyssPodcast', 'audio');
      await this.session.activate();

      this.session.on('play', () => this.togglePlay());
      this.session.on('pause', () => this.togglePlay());
      this.session.on('playNext', () => this.playNext());
      this.session.on('playPrevious', () => this.playPrev());
      this.session.on('seek', (time) => this.seekTo(time / this.totalTime * 100));
    } catch (e) {
      console.error(`[Podcast] Session init error: ${e}`);
    }
  }

  async updateSessionMetadata(audio: LocalAudio) {
    if (!this.session) return;
    const metadata: avSession.AVMetadata = {
      assetId: audio.fileName,
      title: audio.fileName,
      artist: '本地音频',
      duration: this.totalTime > 0 ? this.totalTime : undefined
    };
    await this.session.setAVMetadata(metadata).catch((e: BusinessError) => console.error(JSON.stringify(e)));
  }

  async updateSessionState(state: avSession.PlaybackState) {
    if (!this.session) return;
    const playbackState: avSession.AVPlaybackState = {
      state: state,
      position: {
        elapsedTime: this.currentTime,
        updateTime: new Date().getTime(),
      },
      duration: this.totalTime,
    };
    await this.session.setAVPlaybackState(playbackState).catch((e: BusinessError) => console.error(JSON.stringify(e)));
  }

  // --- AVPlayer ---
  async initAVPlayer() {
    this.avPlayer = await media.createAVPlayer();

    this.avPlayer.on('stateChange', async (state, reason) => {
      switch (state) {
        case 'initialized':
          await this.avPlayer?.prepare();
          break;
        case 'prepared':
          this.totalTime = this.avPlayer?.duration || 0;
          if (this.currentAudio) this.updateSessionMetadata(this.currentAudio);
          if (this.isPlaying) await this.avPlayer?.play();
          break;
        case 'playing':
          this.isPlaying = true;
          // 修正：使用 PLAY
          this.updateSessionState(avSession.PlaybackState.PLAYBACK_STATE_PLAY);
          break;
        case 'paused':
          this.isPlaying = false;
          // 修正：使用 PAUSE
          this.updateSessionState(avSession.PlaybackState.PLAYBACK_STATE_PAUSE);
          break;
        case 'completed':
          this.playNext();
          break;
        case 'error':
          this.isPlaying = false;
          break;
      }
    });

    this.avPlayer.on('timeUpdate', (time) => {
      if (!this.isSliderDragging) {
        this.currentTime = time;
        if (this.totalTime > 0) {
          this.sliderValue = (this.currentTime / this.totalTime) * 100;
        }
      }
    });
  }

  async loadSource(filePath: string) {
    if (!this.avPlayer) return;
    try {
      await this.avPlayer.reset();
      if (this.currentFileHandle) {
        fs.closeSync(this.currentFileHandle);
        this.currentFileHandle = null;
      }
      this.currentFileHandle = fs.openSync(filePath, fs.OpenMode.READ_ONLY);
      this.avPlayer.url = `fd://${this.currentFileHandle.fd}`;
    } catch (e) {
      console.error(`[Podcast] Load source failed: ${e}`);
    }
  }

  async togglePlay() {
    if (!this.avPlayer) return;
    if (this.isPlaying) {
      await this.avPlayer.pause();
    } else {
      if (this.avPlayer.state === 'idle' && this.currentAudio) {
        this.loadSource(this.currentAudio.filePath);
        this.isPlaying = true;
      } else {
        await this.avPlayer.play();
      }
    }
  }

  switchAudio(audio: LocalAudio, autoPlay: boolean = true) {
    this.currentAudio = audio;
    this.isPlaying = autoPlay;
    this.updateSessionMetadata(audio);
    this.loadSource(audio.filePath);
  }

  playNext() {
    if (this.audioList.length === 0) return;
    const idx = this.audioList.findIndex(a => a.filePath === this.currentAudio?.filePath);
    const nextIdx = (idx + 1) % this.audioList.length;
    this.switchAudio(this.audioList[nextIdx]);
  }

  playPrev() {
    if (this.audioList.length === 0) return;
    const idx = this.audioList.findIndex(a => a.filePath === this.currentAudio?.filePath);
    const prevIdx = (idx - 1 + this.audioList.length) % this.audioList.length;
    this.switchAudio(this.audioList[prevIdx]);
  }

  seekTo(sliderVal: number) {
    if (this.avPlayer && this.totalTime > 0) {
      const targetTime = (sliderVal / 100) * this.totalTime;
      this.avPlayer.seek(targetTime);
      this.currentTime = targetTime;
    }
  }

  formatTime(ms: number): string {
    if (!ms || ms < 0) return '00:00';
    const totalSec = Math.floor(ms / 1000);
    return `${Math.floor(totalSec / 60).toString().padStart(2, '0')}:${(totalSec % 60).toString().padStart(2, '0')}`;
  }

  // --- UI 构建 ---
  build() {
    NavDestination() {
      Column() {
        // 顶部栏
        Row() {
          Button({ type: ButtonType.Circle }) {
            SymbolGlyph($r('sys.symbol.chevron_left')).fontSize(24)
          }
          .backgroundColor(Color.Transparent).width(40).height(40)
          .onClick(() => this.pageStack.pop())

          Text('本地随声听')
            .fontSize(20).fontWeight(FontWeight.Bold).margin({ left: 8 })

          Blank()

          Button({ type: ButtonType.Circle }) {
            SymbolGlyph($r('sys.symbol.plus')).fontSize(24)
          }
          .backgroundColor(Color.Transparent).width(40).height(40)
          .onClick(() => this.importAudio())
        }
        .width('100%').padding({ top: 40, bottom: 12, left: 16, right: 16 })

        // 播放器卡片
        Column({ space: 16 }) {
          Stack() {
            Circle({ width: 200, height: 200 }).fill('#F0F2F5')
            // 修改点：使用系统默认音乐图标，防止报错
            Image($r('app.media.icon'))
              .width(100).height(100)
              .rotate({ angle: this.isPlaying ? 360 : 0 })
              .animation({ duration: 10000, iterations: -1, curve: Curve.Linear })
          }

          Text(this.currentAudio ? this.currentAudio.fileName : '暂无播放')
            .fontSize(18).fontWeight(FontWeight.Bold)
            .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
            .padding({ left: 32, right: 32 })

          Column() {
            Slider({ value: this.sliderValue, min: 0, max: 100 })
              .showSteps(false)
              .onTouch((e) => {
                if (e.type === TouchType.Down) this.isSliderDragging = true;
                if (e.type === TouchType.Up) this.isSliderDragging = false;
              })
              .onChange((val, mode) => {
                this.sliderValue = val;
                if (mode === SliderChangeMode.End) {
                  this.seekTo(val);
                  this.isSliderDragging = false;
                }
              })

            Row() {
              Text(this.formatTime(this.currentTime)).fontSize(12).fontColor('#999')
              Blank()
              Text(this.formatTime(this.totalTime)).fontSize(12).fontColor('#999')
            }.width('100%')
          }.padding({ left: 24, right: 24 })

          Row({ space: 48 }) {
            Image($r('sys.media.ohos_ic_public_arrow_left')).width(32).height(32)
              .onClick(() => this.playPrev())

            Image(this.isPlaying ? $r('sys.media.ohos_ic_public_pause') : $r('sys.media.ohos_ic_public_play'))
              .width(64).height(64).fillColor('#007DFF')
              .onClick(() => this.togglePlay())

            Image($r('sys.media.ohos_ic_public_arrow_right')).width(32).height(32)
              .onClick(() => this.playNext())
          }
        }
        .width('100%')
        .padding({ top: 20, bottom: 30 })
        .backgroundColor(Color.White)
        .shadow({ radius: 20, color: 'rgba(0,0,0,0.05)' })

        // 播放列表
        List() {
          ForEach(this.audioList, (item: LocalAudio, index: number) => {
            ListItem() {
              Row() {
                if (this.currentAudio?.filePath === item.filePath) {
                  Image($r('sys.media.ohos_ic_public_sound')).width(16).height(16).fillColor('#007DFF').margin({ right: 12 })
                } else {
                  Text(`${index + 1}`).fontSize(14).fontColor('#999').margin({ right: 16 })
                }

                Text(item.fileName)
                  .fontSize(16)
                  .fontColor(this.currentAudio?.filePath === item.filePath ? '#007DFF' : '#333')
                  .layoutWeight(1).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
              }
              .width('100%').padding(16)
              .backgroundColor(Color.White)
              .onClick(() => this.switchAudio(item))
            }
            .swipeAction({
              end: this.DeleteButton(item)
            })
          })
        }
        .layoutWeight(1)
        .divider({ strokeWidth: 1, color: '#F2F2F2', startMargin: 16, endMargin: 16 })
        .width('100%')

      }
      .height('100%')
      .backgroundColor('#F1F3F5')
    }
    .hideTitleBar(true)
  }

  @Builder DeleteButton(item: LocalAudio) {
    Button() {
      // 修正点：使用系统自带删除图标
      Image($r('sys.media.ohos_ic_public_remove')).width(24).height(24).fillColor(Color.White)
    }
    .width(60).height('100%')
    .backgroundColor('#FF4040')
    .type(ButtonType.Normal)
    .onClick(() => this.deleteAudio(item))
  }
}