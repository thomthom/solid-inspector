Dim objShell
Set objShell = WScript.CreateObject("WScript.Shell")
objShell.Run("""C:\Program Files (x86)\SketchUp\SketchUp 2014\SketchUp.exe"" -rdebug ""ide port=7000""")
Set objShell = Nothing