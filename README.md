# SnapShot
 A Windows Desktop SnapShot class for Delphi by KodeZwerg.

This is a collection of routines I found on different sources to produce SnapShots combined in one easy to use class.


supports 4 different engines to choose from
  - GDI (Graphics Device Interface)
  - DDA (Desktop Duplication API)
  - DX9 (DirectX 9 / 32bit only)
  - Print (Windows API)
 
supports 4 different Hotkeys (by default disabled but configured to use)
  - ALT+PRINT = capture entire desktop
  - CTRL+PRINT = capture focused window
  - SHIFT+PRINT = region selected capture
  - CTRL+SHIFT+PRINT = repeat capture last region
