import hilog from '@ohos.hilog';

// [Fix] 使用 class 替代 interface/type，符合 ArkTS 严格模式要求
class ErrorLike {
  code?: number | string;
  message?: string;
}

export class LuminaLog {
  private static readonly DOMAIN: number = 0xA03D;
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

  // [Fix] 接收 Object 类型，避免 catch 块传递 unknown 导致的编译错误
  static err(err: Object | null | undefined): string {
    if (!err) return '';

    // 使用断言访问属性
    const errorObj = err as ErrorLike;
    const code = errorObj.code !== undefined ? String(errorObj.code) : '';
    const message = errorObj.message ? String(errorObj.message) : String(err);

    return `code=${code} message=${message}`;
  }
}