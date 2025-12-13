import { AbilityConstant, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { DatabaseManager } from '../utils/DatabaseManager';
import { PreferenceManager } from '../utils/PreferenceManager';

export default class EntryAbility extends UIAbility {
  async onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): Promise<void> {
    await PreferenceManager.getInstance().init(this.context);
    await DatabaseManager.getInstance().init(this.context);
    try { this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET); } catch (err) {}
  }
  onWindowStageCreate(windowStage: window.WindowStage): void {
    windowStage.getMainWindow().then((win) => { try { win.setWindowLayoutFullScreen(true); win.setWindowSystemBarProperties({ statusBarColor: '#00000000', navigationBarColor: '#00000000', statusBarContentColor: '#000000', navigationBarContentColor: '#000000' }); } catch (err) {} });
    windowStage.loadContent('pages/Index');
  }
}