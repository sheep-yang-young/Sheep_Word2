import { notificationManager } from '@kit.NotificationKit';

class ReminderScheduler {
  timerId: number | null = null;
  content: string = '';
  title: string = '';
  time: string = '08:00';
}

export class ReminderManager {
  private static instance: ReminderManager;
  private scheduler: ReminderScheduler = new ReminderScheduler();

  public static getInstance(): ReminderManager {
    if (!ReminderManager.instance) {
      ReminderManager.instance = new ReminderManager();
    }
    return ReminderManager.instance;
  }

  async scheduleDailyReminder(time: string, title: string, content: string): Promise<void> {
    await this.cancelReminder();
    this.scheduler.time = time;
    this.scheduler.title = title;
    this.scheduler.content = content;

    const delay = this.computeDelay(time);
    this.scheduler.timerId = globalThis.setTimeout(async () => {
      await this.publishNotification(title, content);
      this.scheduler.timerId = null;
      // 继续下一次
      await this.scheduleDailyReminder(time, title, content);
    }, delay) as unknown as number;
  }

  async publishNotification(title: string, content: string): Promise<void> {
    try {
      await notificationManager.publish({
        id: Date.now(),
        content: {
          contentType: notificationManager.ContentType.NOTIFICATION_CONTENT_BASIC_TEXT,
          normal: { title, text: content }
        }
      } as notificationManager.NotificationRequest);
    } catch (e) {
      console.error('[Lumina] Notification failed', JSON.stringify(e));
    }
  }

  async cancelReminder(): Promise<void> {
    if (this.scheduler.timerId !== null) {
      clearTimeout(this.scheduler.timerId);
      this.scheduler.timerId = null;
    }
  }

  private computeDelay(time: string): number {
    const [h, m] = time.split(':').map((v) => parseInt(v));
    const now = new Date();
    const target = new Date();
    target.setHours(h, m, 0, 0);

    let diff = target.getTime() - now.getTime();
    if (diff <= 0) {
      diff += 24 * 60 * 60 * 1000; // 下一天
    }
    return diff;
  }
}
