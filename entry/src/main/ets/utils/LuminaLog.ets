import hilog from '@ohos.hilog';

type ErrorLike = {
  code?: number | string;
  message?: string;
};

export class LuminaLog {
  private static readonly DOMAIN: number = 0xA03D; // 你日志里就是 A03D00
  private static readonly TAG: string = 'LuminaBall';

  static i(msg: string): void {
    hilog.info(LuminaLog.DOMAIN, LuminaLog.TAG, '%{public}s', msg);
  }

  static w(msg: string): void {
    hilog.warn(LuminaLog.DOMAIN, LuminaLog.TAG, '%{public}s', msg);
  }

  static e(msg: string): void {
    hilog.error(LuminaLog.DOMAIN, LuminaLog.TAG, '%{public}s', msg);
  }

  static err(err: unknown): string {
    const errorObj = err as ErrorLike;
    const code = errorObj && errorObj.code !== undefined ? String(errorObj.code) : '';
    const message = errorObj && errorObj.message ? String(errorObj.message) : String(err);
    return `code=${code} message=${message}`;
  }
}
