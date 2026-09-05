import { UIAbility, Want, AbilityConstant } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import type { Configuration } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';

const DOMAIN = 0x0201;

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    hilog.info(DOMAIN, 'OHEmacs', 'EntryAbility onCreate');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    hilog.info(DOMAIN, 'OHEmacs', 'onWindowStageCreate');
    windowStage.loadContent('pages/Index', (err) => {
      if (err && err.code !== 0) {
        hilog.error(DOMAIN, 'OHEmacs', 'loadContent failed %{public}d %{public}s', err.code, err.message);
      } else {
        hilog.info(DOMAIN, 'OHEmacs', 'loadContent ok');
      }
    });
  }

  onForeground(): void {
    hilog.info(DOMAIN, 'OHEmacs', 'onForeground');
  }

  onBackground(): void {
    hilog.info(DOMAIN, 'OHEmacs', 'onBackground');
  }

  onWindowStageDestroy(): void {
    hilog.info(DOMAIN, 'OHEmacs', 'onWindowStageDestroy');
  }

  onConfigurationUpdate(config: Configuration): void {
    hilog.info(DOMAIN, 'OHEmacs', 'onConfigurationUpdate');
  }
}
