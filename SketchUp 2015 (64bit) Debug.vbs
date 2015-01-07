Dim objShell
Set objShell = WScript.CreateObject("WScript.Shell")
objShell.Run("""C:\Program Files\SketchUp\SketchUp 2015\SketchUp.exe"" -rdebug ""ide port=7000""")
Set objShell = Nothing
