export class ScreenshotFlow {
  private static pendingOpen: boolean = false;
  private static pendingPath: string | null = null;
  private static autoRecognize: boolean = false;

  static markPendingOpen(path?: string | null, autoRecognize: boolean = false): void {
    ScreenshotFlow.pendingOpen = true;
    ScreenshotFlow.pendingPath = path ?? null;
    ScreenshotFlow.autoRecognize = autoRecognize;
  }

  static consumePendingOpen(): boolean {
    const flag = ScreenshotFlow.pendingOpen;
    ScreenshotFlow.pendingOpen = false;
    return flag;
  }

  static consumePendingPath(): string | null {
    const path = ScreenshotFlow.pendingPath;
    ScreenshotFlow.pendingPath = null;
    return path;
  }

  static consumeAutoRecognize(): boolean {
    const flag = ScreenshotFlow.autoRecognize;
    ScreenshotFlow.autoRecognize = false;
    return flag;
  }
}
