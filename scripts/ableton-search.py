import atomacos, sys, subprocess
from common import *

atomacos.launchAppByBundleId('com.ableton.Live')
live=atomacos.getAppRefByLocalizedName('Live')
windows=live.windows()
window=[w for w in windows if w.AXMain][0]

closeAllPopups()

search=sys.argv[1]

[
    c for c in [c for c in window.AXChildren[0].AXChildren if 'Browser' in (getattr(c, 'AXTitle', '') or '')][0].AXChildren if 'Search' in (getattr(c, 'AXDescription', '') or '')][0].AXValue=search

import time; time.sleep(0.2)

for element in [c for c in [c for c in window.AXChildren[0].AXChildren if 'Browser' in (getattr(c, 'AXTitle', '') or '')][0].AXChildren if 'Searching ' in (getattr(c, 'AXDescription', '') or '')][0].AXChildren:
    if element.AXTitle==search:
        p=subprocess.Popen(['cliclick', 'dc:%d,%d' % (element.AXPosition.x+5,element.AXPosition.y+5)])
