Output demo.gif

Set Shell "zsh"
Set FontSize 14
Set Width 720
Set Height 340
Set Theme "Catppuccin Mocha"
Set Padding 20
Set TypingSpeed 80ms
Set PlaybackSpeed 0.9

# Bootstrap: source the plugin and set a real API key for the demo
Hide
Type "source '/Users/mattnorthwood/Claude Playground/wtf-terminal/wtf.zsh'"
Enter
Sleep 300ms
Show

# --- Scene 1: a failing npm command ---
Sleep 500ms
Type "npm install"
Sleep 200ms
Enter
Sleep 3s

# --- Scene 2: type wtf and get the explanation ---
Sleep 400ms
Type "wtf"
Sleep 200ms
Enter
Sleep 7s

# --- Scene 3: show the why alias too ---
Sleep 1s
Type "cat /etc/shadow"
Sleep 200ms
Enter
Sleep 2s

Sleep 400ms
Type "why"
Sleep 200ms
Enter
Sleep 7s

Sleep 2s
