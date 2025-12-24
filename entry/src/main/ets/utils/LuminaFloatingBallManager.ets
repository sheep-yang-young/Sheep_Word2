import hilog from '@ohos.hilog';
import { common, missionManager, Want } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import floatingBall from '@ohos.window.floatingBall';
import { CapsuleFlow } from './CapsuleFlow';

const DOMAIN: number = 0xA0A03D;
const TAG: string = 'LuminaBall';

export class LuminaFloatingBallManager {
  private static inst: LuminaFloatingBallManager = new LuminaFloatingBallManager();

  private ctx: common.UIAbilityContext | null = null;
  private controller: floatingBall.FloatingBallController | null = null;
  private started: boolean = false;

  static getInstance(): LuminaFloatingBallManager {
    return LuminaFloatingBallManager.inst;
  }

  init(context: common.UIAbilityContext): void {
    this.ctx = context;
  }

  /**
   * 启动悬浮球
   */
  async start(): Promise<void> {
    if (!this.ctx) {
      hilog.warn(DOMAIN, TAG, 'Floating ball start skipped: context not initialized');
      return;
    }
    if (this.started) {
      hilog.info(DOMAIN, TAG, 'Already started');
      return;
    }

    try {
      hilog.info(DOMAIN, TAG, 'Attempting to create floating ball...');
      this.logContext();

      // [修复] 参数必须包裹在对象中
      this.controller = await floatingBall.create({ context: this.ctx });

      if (!this.controller) {
        hilog.error(DOMAIN, TAG, 'Controller creation failed (null)');
        return;
      }

      hilog.info(DOMAIN, TAG, 'FloatingBallController created');

      // 设置点击监听
      this.controller.on('click', async () => {
        hilog.info(DOMAIN, TAG, 'onClick event received from floating ball');
        await this.onBallClick();
      });

      // 设置状态监听
      this.controller.on('stateChange', (st: floatingBall.FloatingBallState) => {
        hilog.info(DOMAIN, TAG, 'stateChange=%{public}s', JSON.stringify(st));
      });

      // 设置属性
      const params: floatingBall.FloatingBallParams = {
        template: floatingBall.FloatingBallTemplate.NORMAL,
        title: 'Lumina',
        content: '选截图识别'
      };

      await this.controller.startFloatingBall(params);
      this.started = true;
      hilog.info(DOMAIN, TAG, 'startFloatingBall OK with params=%{public}s', JSON.stringify(params));
    } catch (err) {
      const error = err as BusinessError;
      hilog.error(DOMAIN, TAG, 'startFloatingBall FAILED: %{public}s', JSON.stringify(error));
    }
  }

  /**
   * 停止悬浮球
   */
  async stop(): Promise<void> {
    try {
      if (this.controller) {
        await this.controller.stopFloatingBall();
        this.controller.off('click');
        this.controller.off('stateChange');
        // 销毁引用
        this.controller = null;
      }
      this.started = false;
      hilog.info(DOMAIN, TAG, 'stopFloatingBall OK');
    } catch (err) {
      const error = err as BusinessError;
      hilog.warn(DOMAIN, TAG, 'stopFloatingBall err=%{public}s', JSON.stringify(error));
    } finally {
      this.started = false;
    }
  }

  private async onBallClick(): Promise<void> {
    hilog.info(DOMAIN, TAG, 'onBallClick invoked');

    if (!this.ctx) {
      hilog.error(DOMAIN, TAG, 'onBallClick aborted: context missing');
      return;
    }

    const abilityInfo = this.ctx.abilityInfo;
    if (!abilityInfo || !abilityInfo.bundleName) {
      hilog.error(DOMAIN, TAG, 'onBallClick aborted: abilityInfo missing bundleName. abilityInfo=%{public}s',
        JSON.stringify(abilityInfo));
      return;
    }

    // 标记：进入页面后自动拉起选择截图
    CapsuleFlow.markAutoPickPending();

    const bundleName = abilityInfo.bundleName;
    const moduleName = abilityInfo.moduleName ?? 'entry';
    const abilityName = abilityInfo.name ?? 'EntryAbility';

    const want: Want = {
      deviceId: '',
      bundleName: bundleName,
      moduleName: moduleName,
      abilityName: abilityName,
      parameters: {
        // 这个参数将在 EntryAbility 中被捕获
        openCapsuleImport: true
      }
    };

    hilog.info(DOMAIN, TAG, 'ball click -> target want: %{public}s', JSON.stringify(want));

    const broughtToFront = await this.tryBringMissionToFront(bundleName);
    if (broughtToFront) {
      hilog.info(DOMAIN, TAG, 'mission moved to front; waiting for onNewWant/onForeground handling');
    }

    this.ctx.startAbility(want).then(() => {
      hilog.info(DOMAIN, TAG, 'startAbility success');
    }).catch((err: BusinessError) => {
      if ((err as BusinessError).code === 2097177) {
        hilog.error(DOMAIN, TAG, 'startAbility denied (likely background start). err=%{public}s', JSON.stringify(err));
      } else {
        hilog.error(DOMAIN, TAG, 'startAbility failed=%{public}s', JSON.stringify(err));
      }
    });
  }

  private async tryBringMissionToFront(bundleName: string): Promise<boolean> {
    try {
      const infos = await missionManager.getMissionInfos('', 16);
      const mission = infos?.find((it) => it.bundleName === bundleName);
      if (!mission) {
        hilog.warn(DOMAIN, TAG, 'No mission found for bundle=%{public}s', bundleName);
        return false;
      }

      hilog.info(DOMAIN, TAG, 'moveMissionToFront id=%{public}d, state=%{public}s', mission.missionId,
        JSON.stringify(mission.runningState));
      await missionManager.moveMissionToFront(mission.missionId);
      hilog.info(DOMAIN, TAG, 'moveMissionToFront success');
      return true;
    } catch (err) {
      hilog.warn(DOMAIN, TAG, 'moveMissionToFront failed=%{public}s', JSON.stringify(err));
      return false;
    }
  }

  private logContext(): void {
    if (!this.ctx) {
      hilog.warn(DOMAIN, TAG, 'logContext skipped: ctx missing');
      return;
    }

    hilog.info(DOMAIN, TAG, 'context ability=%{public}s', JSON.stringify(this.ctx.abilityInfo));
  }
}