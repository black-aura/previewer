import atomacos

def closeAllPopups():
    atomacos.launchAppByBundleId('com.ableton.Live')
    live = atomacos.getAppRefByLocalizedName('Live')
    windows = live.windows()
    window = [w for w in windows if w.AXMain][0]

    for w in windows:
        if not w.AXMain:
            print(w.Raise())
            try:
                [c for c in w.AXChildren if getattr(c, 'AXRoleDescription', '') and c.AXRoleDescription=='close button'][0].Press()
            except:
                pass
