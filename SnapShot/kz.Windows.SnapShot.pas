unit kz.Windows.SnapShot;

(*

  TkzSnapShot - A very easy to use class to create snapshots from windows desktop

  supports 4 different snapshot engines:
    - GDI (Graphics Device Interface) - fast, may be blocked due overlay
    - DDA (Desktop Duplication API)   - extreme fast, may be blocked by "target window (anti-snapshot)" to work for you
    - DX9 (DirectX 9)                 - slow, very stable
    - PRINT (Windows PrintWindow API) - very fast, limited to "entire screen" and "focused window", may be blocked due overlay
                                      - currently on my system not working anymore, i can not find my mistake

  supports 3 different hotkeys
    - snap entire screen (alt+print)
    - snap focused window (ctrl+print)
    - snap with a region select (shift+print)
      - using left mouse button to select a region for a normal snapshot
      - using middle mouse button to select a region for a inverted colors snapshot

  features
    - copy bitmap to clipboard
    - exclude your application window from snapping
    - event driven, not much code needed to setup this class in your application

  author of this compilation: KodeZwerg
  License: Unlicensed

*)


interface

uses
  Winapi.Windows, Winapi.Messages,
  System.SysUtils, System.Classes, System.Types,
  System.Win.ComObj,
  Vcl.Clipbrd, Vcl.Graphics, Vcl.Controls, Vcl.ExtCtrls, Vcl.Forms,
  Winapi.Direct3D9, Winapi.DwmApi,
  Execute.DesktopDuplicationAPI,
  uCapture;

//https://learn.microsoft.com/en-us/windows/win32/api/psapi/nf-psapi-getprocessimagefilenamew
function GetProcessImageFileName(hProcess: THandle; lpImageFileName: LPTSTR; nSize: DWORD): DWORD; stdcall; external 'PSAPI.dll' name 'GetProcessImageFileNameW';
//https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-printwindow
function PrintWindow(HWND: HWND; hdcBlt: HDC; nFlags: UINT): BOOL; stdcall; external 'user32.dll' name 'PrintWindow';

type
  TkzHotkey = packed record
    Hotkey: Cardinal;
    Modifier: UInt;
    ALT: Boolean;
    CONTROL: Boolean;
    SHIFT: Boolean;
    WIN: Boolean;
    NoRepeat: Boolean;
  end;
  TkzSnapShot = class(TObject)
    strict private
      FOnMessage:       TNotifyEvent;
      FImageHeight:     Integer;
      FImageWidth:      Integer;
      FBorderHeight:    Integer;
      FBorderWidth:     Integer;
      FBMP:             TBitmap;
      FBitmap:          TBitmap;
      FCanvas:          TCanvas;
      FRect:            TRect;
      FCaption:         string;
      FFilename:        string;
      FPID:             DWORD;
      FHWND:            HWND;
      FGetFocused:      Boolean;
      FSuccess:         Boolean;
      FHotkeyAll:       TkzHotkey;
      FHotkeyWnd:       TkzHotkey;
      FHotkeyRec:       TkzHotkey;
      FActivateHotkey:  Boolean;
      FAutoClipboard:   Boolean;
      FCreationTime:    TDateTime;
      fHiddenWnd:       HWND;
      fHiddenClass:     ATOM;
      FOwner:           TComponent;
      FSender:          TObject;
      FInverted:        Boolean;
      FAlphaBlendValue: Integer;
      FUseGDI:          Boolean;
      FUseDDA:          Boolean;
      FUseDX9:          Boolean;
      FUsePrint:        Boolean;
      FAutoHide:        Boolean;
      FDuplication:     TDesktopDuplicationWrapper;
    private
      function GetBorderHeight: Integer;
      function GetBorderWidth: Integer;
      procedure SetHotkeyAll(const AValue: TkzHotkey);
      procedure SetHotkeyWnd(const AValue: TkzHotkey);
      procedure SetHotkeyRec(const AValue: TkzHotkey);
      procedure SetActivateHotkey(const AValue: Boolean);
      procedure SetUseGDI(const AValue: Boolean);
      procedure SetUseDDA(const AValue: Boolean);
      procedure SetUseDX9(const AValue: Boolean);
      procedure SetUsePrint(const AValue: Boolean);
    protected
      procedure CreateHidden;
      procedure DestroyHidden;
    public
      constructor Create(const ASender: TObject; const AOwner: TComponent);
      destructor Destroy; Override;
      procedure Reset;
      procedure SnapShot(const ALeft, ATop, ARight, ABottom: Integer);
      procedure SnapShotGDI(const ALeft, ATop, ARight, ABottom: Integer);
      procedure SnapShotDDA(const ALeft, ATop, ARight, ABottom: Integer);
      procedure SnapShotDX9(const ALeft, ATop, ARight, ABottom: Integer);
      procedure SnapShotPrint(const ALeft, ATop, ARight, ABottom: Integer);
      procedure Snap;
      procedure CopyToClipboard;
    public
      property OnMessage: TNotifyEvent read FOnMessage write FOnMessage;
      property GetFocused: Boolean read FGetFocused write FGetFocused;
      property Success: Boolean read FSuccess write FSuccess;
      property Bitmap: TBitmap read FBitmap;
      property Caption: string read FCaption write FCaption;
      property Filename: string read FFilename write FFilename;
      property CreationTime: TDateTime read FCreationTime write FCreationTime;
      property AutoHide: Boolean read FAutoHide write FAutoHide;
      property AutoToClipboard: Boolean read FAutoClipboard write FAutoClipboard;
      property ImageHeight: Integer read FImageHeight write FImageHeight;
      property ImageWidth: Integer read FImageWidth write FImageWidth;
      property BorderHeight: Integer read GetBorderHeight write FBorderHeight;
      property BorderWidth: Integer read GetBorderWidth write FBorderWidth;
      property Owner: TComponent read FOwner;
      property Sender: TObject read FSender;
      property ProcessID: DWORD read FPID;
      property ProcessHWND: HWND read FHWND;
      property HotkeyAll: TkzHotkey read FHotkeyAll write SetHotkeyAll;
      property HotkeyWnd: TkzHotkey read FHotkeyWnd write SetHotkeyWnd;
      property HotkeyRec: TkzHotkey read FHotkeyRec write SetHotkeyRec;
      property ActivateHotkey: Boolean read FActivateHotkey write SetActivateHotkey;
      property Inverted: Boolean read FInverted write FInverted;
      property AlphaBlendValue: Integer read FAlphaBlendValue write FAlphaBlendValue;
      property UseGDI: Boolean read FUseGDI write SetUseGDI;
      property UseDDA: Boolean read FUseDDA write SetUseDDA;
      property UseDX9: Boolean read FUseDX9 write SetUseDX9;
      property UsePrint: Boolean read FUsePrint write SetUsePrint;
  end;

implementation

const
  kzHotkeyAll = WM_APP + 1001;
  kzHotkeyWnd = WM_APP + 1002;
  kzHotkeyRec = WM_APP + 1003;
  CAPTUREBLT  = $40000000;


constructor TkzSnapShot.Create(const ASender: TObject; const AOwner: TComponent);
begin
  inherited Create;
  FSender            := ASender;
  FOwner             := AOwner;
  Reset;
  FBitmap            := TBitmap.Create;
  FCanvas            := TCanvas.Create;
  FDuplication       := TDesktopDuplicationWrapper.Create;
  FOnMessage         := nil;
  CreateHidden;

  FHotkeyAll.Hotkey   := VK_SNAPSHOT;
  FHotkeyAll.Modifier := MOD_ALT;
  FHotkeyAll.ALT      := True;
  FHotkeyAll.CONTROL  := False;
  FHotkeyAll.SHIFT    := False;
  FHotkeyAll.WIN      := False;
  FHotkeyAll.NoRepeat := False;

  FHotkeyWnd.Hotkey   := VK_SNAPSHOT;
  FHotkeyWnd.Modifier := MOD_CONTROL;
  FHotkeyWnd.ALT      := True;
  FHotkeyWnd.CONTROL  := False;
  FHotkeyWnd.SHIFT    := False;
  FHotkeyWnd.WIN      := False;
  FHotkeyWnd.NoRepeat := False;

  FHotkeyRec.Hotkey   := VK_SNAPSHOT;
  FHotkeyRec.Modifier := MOD_SHIFT;
  FHotkeyRec.ALT      := True;
  FHotkeyRec.CONTROL  := False;
  FHotkeyRec.SHIFT    := False;
  FHotkeyRec.WIN      := False;
  FHotkeyRec.NoRepeat := False;

  FActivateHotkey := False;
  SetActivateHotkey(FActivateHotkey);

  FAutoHide        := True;
  FAutoClipboard   := False;

  FUseGDI          := False;
  FUseDDA          := True;
  FUseDX9          := False;
  FUsePrint        := False;

  GetBorderHeight;
  GetBorderWidth;
end;

destructor TkzSnapShot.Destroy;
begin
  UnregisterHotKey(fHiddenWnd, kzHotkeyAll);
  UnregisterHotKey(fHiddenWnd, kzHotkeyWnd);
  UnregisterHotKey(fHiddenWnd, kzHotkeyRec);
  Reset;
  FOnMessage := nil;
  FBitmap.Free;
  FCanvas.Free;
  FDuplication.Free;
  DestroyHidden;
  inherited Destroy;
end;

procedure TkzSnapShot.Reset;
begin
  FImageHeight     := 0;
  FImageWidth      := 0;
  FBorderHeight    := 0;
  FBorderWidth     := 0;
  FPID             := 0;
  FHWND            := 0;
  FCreationTime    := 0;
  FAlphaBlendValue := 75;
  FCaption         := '';
  FFilename        := '';
  FGetFocused      := True;
  FSuccess         := False;
  FInverted        := False;
  FRect.Empty;
end;

function TkzSnapShot.GetBorderHeight: Integer;
begin
  FBorderHeight := GetSystemMetrics(SM_CXDLGFRAME) + GetSystemMetrics(SM_CXSIZEFRAME) + GetSystemMetrics(SM_CXEDGE);
  Result := FBorderHeight;
end;

function TkzSnapShot.GetBorderWidth: Integer;
begin
  FBorderWidth := GetSystemMetrics(SM_CYDLGFRAME) + GetSystemMetrics(SM_CYSIZEFRAME) + GetSystemMetrics(SM_CYEDGE);
  Result := FBorderWidth;
end;

procedure TkzSnapShot.SetUseGDI(const AValue: Boolean);
begin
  FUseGDI := AValue;
  if FUseGDI then
    begin
      FUseDX9 := False;
      FUseDDA := False;
      FUsePrint := False;
    end
    else
      FUseDDA := True;
end;

procedure TkzSnapShot.SetUseDDA(const AValue: Boolean);
begin
  FUseDDA := AValue;
  if FUseDDA then
    begin
      FUseDX9 := False;
      FUseGDI := False;
      FUsePrint := False;
    end
    else
      FUseGDI := True;
end;

procedure TkzSnapShot.SetUseDX9(const AValue: Boolean);
begin
  FUseDX9 := AValue;
  if FUseDX9 then
    begin
      FUseGDI := False;
      FUseDDA := False;
      FUsePrint := False;
    end
    else
      FUseGDI := True;
end;

procedure TkzSnapShot.SetUsePrint(const AValue: Boolean);
begin
  FUsePrint := AValue;
  if FUsePrint then
    begin
      FUseDX9 := False;
      FUseDDA := False;
      FUseGDI := False;
    end
    else
      FUseDDA := True;
end;


procedure TkzSnapShot.SnapShot(const ALeft, ATop, ARight, ABottom: Integer);
var
  fDisable: BOOL;
begin
  FSuccess := False;
  if ((Win32MajorVersion >= 6) and Winapi.DwmApi.DwmCompositionEnabled) then
    begin
      fDisable := True;
      OleCheck(Winapi.DwmApi.DwmSetWindowAttribute(Application.MainForm.Handle, DWMWA_TRANSITIONS_FORCEDISABLED, @fDisable, SizeOf(fDisable)));
    end;
  try
    if FAutoHide then
      Application.MainForm.Hide;
    Sleep(25);
    try
      if FUseGDI then
        SnapShotGDI(ALeft, ATop, ARight, ABottom);
      if FUseDDA then
        SnapShotDDA(ALeft, ATop, ARight, ABottom);
      if FUseDX9 then
        SnapShotDX9(ALeft, ATop, ARight, ABottom);
      if FUsePrint then
        SnapShotPrint(ALeft, ATop, ARight, ABottom);
    finally
      Sleep(25);
      if FAutoHide then
        Application.MainForm.Show;
    end;
  finally
    if ((Win32MajorVersion >= 6) and Winapi.DwmApi.DwmCompositionEnabled) then
      begin
        fDisable := False;
        Winapi.DwmApi.DwmSetWindowAttribute(Application.MainForm.Handle, DWMWA_TRANSITIONS_FORCEDISABLED, @fDisable, SizeOf(fDisable));
      end;
  end;
end;

procedure TkzSnapShot.SnapShotGDI(const ALeft, ATop, ARight, ABottom: Integer);
var
  ShotDC: HDC;
  lpPal: PLogPalette;
begin
//  MessageBox(0, 'GDI', 'GDI', MB_OK);
  FSuccess     := False;
  FRect.Left   := ALeft;
  FRect.Top    := ATop;
  FRect.Right  := ARight;
  FRect.Bottom := ABottom;
  FImageWidth  := FRect.Right - FRect.Left;
  FImageHeight := FRect.Bottom - FRect.Top;
  ShotDC       := GetDCEx(GetDesktopWindow, 0, DCX_WINDOW or DCX_PARENTCLIP or DCX_CLIPSIBLINGS or DCX_CLIPCHILDREN);
  try
    FBMP := TBitmap.Create;
    try
      FBMP.PixelFormat := TPixelFormat.pf24bit;
      FBMP.Width       := FImageWidth;
      FBMP.Height      := FImageHeight;
      FCanvas.Handle   := ShotDC;

      if (GetDeviceCaps(ShotDC, RASTERCAPS) and RC_PALETTE = RC_PALETTE) then
        begin
          GetMem(lpPal, SizeOf(TLOGPALETTE) + (255 * SizeOf(TPALETTEENTRY)));
          FillChar(lpPal^, SizeOf(TLOGPALETTE) + (255 * SizeOf(TPALETTEENTRY)), #0);
          lpPal^.palVersion := $300;
          lpPal^.palNumEntries := GetSystemPaletteEntries(ShotDC, 0, 256, lpPal^.palPalEntry);
          if (lpPal^.palNumEntries <> 0) then
            FBMP.Palette := CreatePalette(lpPal^);
          FreeMem(lpPal, SizeOf(TLOGPALETTE) + (255 * SizeOf(TPALETTEENTRY)));
        end;

      if FInverted then
        begin
          FInverted := False;
          FBMP.Canvas.CopyMode := cmSrcInvert or CAPTUREBLT;
        end
        else
          FBMP.Canvas.CopyMode := cmSrcCopy or CAPTUREBLT;
      FBMP.Canvas.CopyRect(
          Rect(0, 0, FImageWidth, FImageHeight),
          FCanvas,
          Rect(FRect.Left,
               FRect.Top,
               FRect.Right,
               FRect.Bottom));
      FBitmap.ReleaseHandle;
      FBitmap.Assign(FBMP);
    finally
      FBMP.Free;
      FBitmap.Dormant;
      FBitmap.FreeImage;
    end;
  finally
    ReleaseDC(GetDesktopWindow, ShotDC);
    FSuccess := True;
  end;
  if (FSuccess and FAutoClipboard) then
    CopyToClipboard;
end;

procedure TkzSnapShot.SnapShotDDA(const ALeft, ATop, ARight, ABottom: Integer);
var
  BMP:   TBitmap;
  lpPal: PLogPalette;
begin
//  MessageBox(0, 'DWM', 'DWM', MB_OK);
  FSuccess     := False;
  FRect.Left   := ALeft;
  FRect.Top    := ATop;
  FRect.Right  := ARight;
  FRect.Bottom := ABottom;
  FImageWidth  := FRect.Right - FRect.Left;
  FImageHeight := FRect.Bottom - FRect.Top;
  BMP := TBitmap.Create;
  try
    if FDuplication.GetFrame then
      begin
        FDuplication.DrawFrame(BMP);
        FBMP := TBitmap.Create;
        try
          FBMP.PixelFormat := TPixelFormat.pf24bit;
          FBMP.Width       := FImageWidth;
          FBMP.Height      := FImageHeight;
          FCanvas.Handle   := BMP.Canvas.Handle;
          if FInverted then
            begin
              FInverted := False;
              FBMP.Canvas.CopyMode := cmSrcInvert or CAPTUREBLT;
            end
            else
              FBMP.Canvas.CopyMode := cmSrcCopy or CAPTUREBLT;
              FBMP.Canvas.CopyRect(
                  Rect(0, 0, FImageWidth, FImageHeight),
                  FCanvas,
                  Rect(FRect.Left + 2, FRect.Top + 2, FRect.Right - 2, FRect.Bottom - 2));
          if (GetDeviceCaps(FCanvas.Handle, RASTERCAPS) and RC_PALETTE = RC_PALETTE) then
            begin
              GetMem(lpPal, SizeOf(TLOGPALETTE) + (255 * SizeOf(TPALETTEENTRY)));
              FillChar(lpPal^, SizeOf(TLOGPALETTE) + (255 * SizeOf(TPALETTEENTRY)), #0);
              lpPal^.palVersion := $300;
              lpPal^.palNumEntries := GetSystemPaletteEntries(FCanvas.Handle, 0, 256, lpPal^.palPalEntry);
              if (lpPal^.palNumEntries <> 0) then
                FBMP.Palette := CreatePalette(lpPal^);
              FreeMem(lpPal, SizeOf(TLOGPALETTE) + (255 * SizeOf(TPALETTEENTRY)));
            end;
          FBitmap.ReleaseHandle;
          FBitmap.Assign(FBMP);
        finally
          FBMP.Free;
          FBitmap.Dormant;
          FBitmap.FreeImage;
          FSuccess := True;
        end;
      end;
  finally
    BMP.Free;
  end;
  if (FSuccess and FAutoClipboard) then
    CopyToClipboard;
end;

procedure TkzSnapShot.SnapShotDX9(const ALeft, ATop, ARight, ABottom: Integer);
var
  BitsPerPixel: Byte;
  pD3D: IDirect3D9;
  pSurface: IDirect3DSurface9;
  g_pD3DDevice: IDirect3DDevice9;
  D3DPP: TD3DPresentParameters;
  ARect: TRect;
  LockedRect: TD3DLockedRect;
  BMP: TBitmap;
  i, p: Integer;
  lpPal: PLogPalette;
begin
//  MessageBox(0, 'DirectX9', 'DirectX9', MB_OK);
  FSuccess               := False;
  FRect.Left             := ALeft;
  FRect.Top              := ATop;
  FRect.Right            := ARight;
  FRect.Bottom           := ABottom;
  FImageWidth            := FRect.Right - FRect.Left;
  FImageHeight           := FRect.Bottom - FRect.Top;
  BitsPerPixel           := GetDeviceCaps(Application.MainForm.Canvas.Handle, BITSPIXEL);
  FillChar(d3dpp, SizeOf(d3dpp), 0);
  D3DPP.Windowed         := True;
  D3DPP.Flags            := D3DPRESENTFLAG_LOCKABLE_BACKBUFFER;
  D3DPP.SwapEffect       := D3DSWAPEFFECT_DISCARD;
  D3DPP.BackBufferWidth  := Screen.Width;
  D3DPP.BackBufferHeight := Screen.Height;
  D3DPP.BackBufferFormat := D3DFMT_X8R8G8B8;
  pD3D                   := Direct3DCreate9(D3D_SDK_VERSION);
  pD3D.CreateDevice(D3DADAPTER_DEFAULT, D3DDEVTYPE_HAL, GetDesktopWindow,
    D3DCREATE_SOFTWARE_VERTEXPROCESSING, @D3DPP, g_pD3DDevice);
  g_pD3DDevice.CreateOffscreenPlainSurface(Screen.Width, Screen.Height, D3DFMT_A8R8G8B8, D3DPOOL_SCRATCH, pSurface, nil);
  g_pD3DDevice.GetFrontBufferData(0, pSurface);
  ARect := FRect;
  pSurface.LockRect(LockedRect, @ARect, D3DLOCK_NO_DIRTY_UPDATE or D3DLOCK_NOSYSLOCK or D3DLOCK_READONLY);
  BMP := TBitmap.Create;
  try
    BMP.Width := FImageWidth;
    BMP.Height := FImageHeight;
    case BitsPerPixel of
      8:  BMP.PixelFormat := pf8bit;
      16: BMP.PixelFormat := pf16bit;
      24: BMP.PixelFormat := pf24bit;
      32: BMP.PixelFormat := pf32bit;
      else
        BMP.PixelFormat := TPixelFormat.pfDevice;
    end;
    p := Cardinal(LockedRect.pBits);
    for i := 0 to Pred(FImageHeight) do
      begin
        CopyMemory(BMP.ScanLine[i], Ptr(p), FImageWidth * BitsPerPixel div 8);
        p := p + LockedRect.Pitch;
      end;
    FBMP := TBitmap.Create;
    try
      FBMP.PixelFormat := TPixelFormat.pf24bit;
      FBMP.Width       := BMP.Width;
      FBMP.Height      := BMP.Height;
      FCanvas.Handle   := BMP.Canvas.Handle;
      if FInverted then
        begin
          FInverted := False;
          FBMP.Canvas.CopyMode := cmSrcInvert or CAPTUREBLT;
        end
        else
          FBMP.Canvas.CopyMode := cmSrcCopy or CAPTUREBLT;
      FBMP.Canvas.CopyRect(
          Rect(0, 0, FImageWidth, FImageHeight),
          FCanvas,
          Rect(0, 0, Pred(FImageWidth), Pred(FImageHeight)));
      if (GetDeviceCaps(FCanvas.Handle, RASTERCAPS) and RC_PALETTE = RC_PALETTE) then
        begin
          GetMem(lpPal, SizeOf(TLOGPALETTE) + (255 * SizeOf(TPALETTEENTRY)));
          FillChar(lpPal^, SizeOf(TLOGPALETTE) + (255 * SizeOf(TPALETTEENTRY)), #0);
          lpPal^.palVersion := $300;
          lpPal^.palNumEntries := GetSystemPaletteEntries(FCanvas.Handle, 0, 256, lpPal^.palPalEntry);
          if (lpPal^.palNumEntries <> 0) then
            FBMP.Palette := CreatePalette(lpPal^);
          FreeMem(lpPal, SizeOf(TLOGPALETTE) + (255 * SizeOf(TPALETTEENTRY)));
        end;
      FBitmap.ReleaseHandle;
      FBitmap.Assign(FBMP);
    finally
      FBMP.Free;
      FBitmap.Dormant;
      FBitmap.FreeImage;
    end;
  finally
    BMP.Free;
    pSurface.UnlockRect;
    FSuccess := True;
  end;
  if (FSuccess and FAutoClipboard) then
    CopyToClipboard;
end;

procedure TkzSnapShot.SnapShotPrint(const ALeft, ATop, ARight, ABottom: Integer);
const
  PW_CLIENTONLY        = $00000001;
  PW_RENDERFULLCONTENT = $00000002;
begin
//  MessageBox(0, 'PrintWindow', 'PrintWindow', MB_OK);
  FSuccess               := False;
  FRect.Left             := ALeft;
  FRect.Top              := ATop;
  FRect.Right            := ARight;
  FRect.Bottom           := ABottom;
  FImageWidth            := FRect.Right - FRect.Left;
  FImageHeight           := FRect.Bottom - FRect.Top;
  FBMP := TBitmap.Create;
  try
    FBMP.PixelFormat := TPixelFormat.pf24bit;
    FBMP.Width := FImageWidth;
    FBMP.Height := FImageHeight;
//    SendMessage(FHWND, WM_PRINT, WPARAM(FBMP.Canvas.Handle), LPARAM(PRF_CHILDREN or PRF_CLIENT or PRF_ERASEBKGND or PRF_NONCLIENT or PRF_OWNED));
    FSuccess := PrintWindow(FHWND, FBMP.Canvas.Handle, PW_CLIENTONLY);
    FBitmap.ReleaseHandle;
    FBitmap.Assign(FBMP);
  finally
    FBMP.Free;
    FBitmap.Dormant;
    FBitmap.FreeImage;
  end;
  if (FSuccess and FAutoClipboard) then
    CopyToClipboard;
end;

procedure TkzSnapShot.Snap;
  function GetWindowPath(const AHWND: HWND): string;
    function GetPIDbyHWND(const AHWND: HWND): DWORD;
    var
      PID: DWORD;
    begin
      if (AHWND <> 0) then
        begin
          GetWindowThreadProcessID(AHWND, @PID);
          Result := PID;
        end
        else
          Result := 0;
      FPID := Result;
    end;
    function PhysicalToVirtualPath(APath: string): string;
    var
      i          : Integer;
      ADrive     : string;
      ABuffer    : array[0..Pred(MAX_PATH)] of Char;
      ACandidate : string;
    begin
      {$I-}
      for I := 0 to 25 do
        begin
          ADrive := Format('%s:', [Chr(Ord('A') + i)]);
          if (QueryDosDevice(PWideChar(ADrive), ABuffer, MAX_PATH) = 0) then
            Continue;
          ACandidate := string(ABuffer).ToLower();
          if (string(Copy(APath, 1, Length(ACandidate))).ToLower() = ACandidate) then
            begin
              Delete(APath, 1, Length(ACandidate));
              Result := Format('%s%s', [ADrive, APath]);
            end;
        end;
      {$I+}
    end;
  var
    AHandle: THandle;
    ALength    : Cardinal;
    AImagePath : String;
  const
    PROCESS_QUERY_LIMITED_INFORMATION = $00001000;
  begin
    Result := '';
    AHandle := OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, False, GetPIDbyHWND(AHWND));
    if (AHandle = 0) then
      Exit;
    try
      SetLength(AImagePath, MAX_PATH);
      ALength := GetProcessImageFileName(AHandle, @AImagePath[1], MAX_PATH);
      if (ALength > 0) then
        begin
          SetLength(AImagePath, ALength);
          Result := PhysicalToVirtualPath(AImagePath);
        end;
    finally
      CloseHandle(AHandle);
    end;
  end;
  function GetWindowTitle(const AHWND: HWND): string;
  var
    LTitle: string;
    LLen: Integer;
  begin
    Result := '';
    LLen := GetWindowTextLength(AHWND) + 1;
    SetLength(LTitle, LLen);
    GetWindowText(AHWND, PChar(LTitle), LLen);
    Result := Trim(LTitle);
  end;
begin
  FSuccess := False;
  if FGetFocused then
    FHWND := GetForegroundWindow
    else
    FHWND := GetDesktopWindow;
  try
    FCaption := GetWindowTitle(FHWND);
    FFilename := GetWindowPath(FHWND);
    if (FCaption = '') then
      FCaption := 'Everything';
    if (FFilename = '') then
      FFilename := 'kzScreenShot';

    if (FGetFocused and (Win32MajorVersion >= 6) and Winapi.DwmApi.DwmCompositionEnabled) then
      Winapi.DwmApi.DwmGetWindowAttribute(FHWND, DWMWA_EXTENDED_FRAME_BOUNDS, @FRect, SizeOf(FRect))
      else
      Winapi.Windows.GetWindowRect(FHWND, FRect);

    if (not FGetFocused) then
      begin
        FRect.Left   := 0;
        FRect.Top    := 0;
        FRect.Right  := GetSystemMetrics(SM_CXVIRTUALSCREEN);
        FRect.Bottom := GetSystemMetrics(SM_CYVIRTUALSCREEN);
      end;

    SnapShot(FRect.Left, FRect.Top, FRect.Right, FRect.Bottom);
  finally
    FCreationTime := Now;
    if Assigned(FOnMessage) then
      FOnMessage(Self);
  end;
end;

function ToHotkey(const AValue: TkzHotkey): TkzHotkey;
begin
  Result.Hotkey   := AValue.Hotkey;
  Result.Modifier := AValue.Modifier;
  Result.ALT      := AValue.ALT;
  Result.CONTROL  := AValue.CONTROL;
  Result.SHIFT    := AValue.SHIFT;
  Result.WIN      := AValue.WIN;
  Result.NoRepeat := AValue.NoRepeat;
  if (Result.Modifier = 0) then
    begin
      if Result.ALT then
        Result.Modifier := Result.Modifier + MOD_ALT;
      if Result.CONTROL then
        Result.Modifier := Result.Modifier + MOD_CONTROL;
      if Result.SHIFT then
        Result.Modifier := Result.Modifier + MOD_SHIFT;
      if Result.WIN then
        Result.Modifier := Result.Modifier + MOD_WIN;
      if Result.NoRepeat then
        Result.Modifier := Result.Modifier + MOD_NOREPEAT;
    end;
end;

procedure TkzSnapShot.SetHotkeyAll(const AValue: TkzHotkey);
begin
  UnregisterHotKey(fHiddenWnd, kzHotkeyAll);
  FHotkeyAll := ToHotkey(AValue);
  if FActivateHotkey then
    if (not RegisterHotkey(fHiddenWnd, kzHotkeyAll, FHotkeyAll.Modifier, FHotkeyAll.Hotkey)) then
      MessageBox(Application.MainForm.Handle,
        PChar('Hotkey (entire screen) could not be set!'),
        PChar('Error - Hotkey!'),
        MB_OK);
end;

procedure TkzSnapShot.SetHotkeyWnd(const AValue: TkzHotkey);
begin
  UnregisterHotKey(fHiddenWnd, kzHotkeyWnd);
  FHotkeyWnd := ToHotkey(AValue);
  if FActivateHotkey then
    if (not RegisterHotkey(fHiddenWnd, kzHotkeyWnd, FHotkeyWnd.Modifier, FHotkeyWnd.Hotkey)) then
      MessageBox(Application.MainForm.Handle,
        PChar('Hotkey (window client) could not be set!'),
        PChar('Error - Hotkey!'),
        MB_OK);
end;

procedure TkzSnapShot.SetHotkeyRec(const AValue: TkzHotkey);
begin
  UnregisterHotKey(fHiddenWnd, kzHotkeyRec);
  FHotkeyRec := ToHotkey(AValue);
  if FActivateHotkey then
    if (not RegisterHotkey(fHiddenWnd, kzHotkeyRec, FHotkeyRec.Modifier, FHotkeyRec.Hotkey)) then
      MessageBox(Application.MainForm.Handle,
        PChar('Hotkey (rectangle select) could not be set!'),
        PChar('Error - Hotkey!'),
        MB_OK);
end;

procedure TkzSnapShot.SetActivateHotkey(const AValue: Boolean);
begin
  FActivateHotkey := AValue;
  if FActivateHotkey then
  begin
    SetHotkeyAll(FHotkeyAll);
    SetHotkeyWnd(FHotkeyWnd);
    SetHotkeyRec(FHotkeyRec);
  end
  else
  begin
    UnregisterHotKey(fHiddenWnd, kzHotkeyAll);
    UnregisterHotKey(fHiddenWnd, kzHotkeyWnd);
    UnregisterHotKey(fHiddenWnd, kzHotkeyRec);
  end;
end;

procedure TkzSnapShot.CopyToClipboard;
var
  Image: TImage;
begin
  // MessageBox(0, 'CopyToClipboard', 'CopyToClipboard', MB_OK);
  Image := TImage.Create(Self.Owner);
  try
    Image.Picture.Bitmap.Assign(FBitmap);
    Clipboard.Assign(Image.Picture.Graphic);
  finally
    Image.Free;
  end;
end;

function HiddenProc(AWnd: HWND; AMsg: UINT; AWParam: WPARAM; ALParam: LPARAM): LRESULT; stdcall;
var
  SS:    TkzSnapShot;
  Dummy: Boolean;
begin
  Result := 0;
  case AMsg of
    WM_HOTKEY: case AWParam of
                 kzHotkeyAll: begin
                                SS := TkzSnapShot(GetWindowLongPtr(AWnd, GWL_USERDATA));
                                if Assigned(SS) then
                                  begin
                                    Dummy := SS.GetFocused;
                                    SS.GetFocused := False;
                                    SS.Snap;
                                    SS.GetFocused := Dummy;
                                  end;
                                Result := 1;
                              end;
                 kzHotkeyWnd: begin
                                SS := TkzSnapShot(GetWindowLongPtr(AWnd, GWL_USERDATA));
                                if Assigned(SS) then
                                  begin
                                    Dummy := SS.GetFocused;
                                    SS.GetFocused := True;
                                    SS.Snap;
                                    SS.GetFocused := Dummy;
                                  end;
                                Result := 1;
                              end;
                 kzHotkeyRec: begin
                                if (frmCapture <> nil) then
                                  begin
                                    Result := 1;
                                    Exit;
                                  end;
                                SS := TkzSnapShot(GetWindowLongPtr(AWnd, GWL_USERDATA));
                                if Assigned(SS) then
                                  begin
                                    SS.Success := False;
                                    frmCapture := TfrmCapture.Create(SS.Owner);
                                    try
                                      frmCapture.AlphaBlendValueX := SS.AlphaBlendValue;
                                      SS.AlphaBlendValue := frmCapture.AlphaBlendValueX;
                                      Application.Restore;
                                      Application.BringToFront;
                                      if SS.AutoHide then
                                        TForm(SS.Owner).Visible := False;
                                      frmCapture.ShowModal;
                                      SS.Reset;
                                      SS.Inverted := frmCapture.Inverted;
                                      SS.SnapShot(frmCapture.RectX.Left, frmCapture.RectX.Top, frmCapture.RectX.Right, frmCapture.RectX.Bottom);
                                      if SS.AutoHide then
                                        TForm(SS.Owner).Visible := True;
                                      SS.Caption      := 'Rectangle';
                                      SS.Filename     := 'kzScreenShot';
                                      SS.CreationTime := Now;
                                      SS.Success      := True;
                                      if Assigned(SS.OnMessage) then
                                        SS.OnMessage(SS);
                                    finally
                                      frmCapture.Free;
                                      frmCapture := nil;
                                    end;
                                  end;
                                Result := 1;
                              end;
               end;
  end;
  if (Result = 0) then
    Result := DefWindowProc(AWnd, AMsg, AWParam, ALParam);
end;

procedure TkzSnapShot.CreateHidden;
var
  WndClass: TWndClass;
  S: string;
  hMenuHandle: HMENU;
  dwExStyle: DWORD;
begin
  if ((fHiddenClass <> 0) or (fHiddenWnd <> 0)) then
    DestroyHidden;
  FillChar(WndClass, SizeOf(WndClass), 0);
  WndClass.style := CS_NOCLOSE or CS_VREDRAW or CS_HREDRAW;
  WndClass.lpfnWndProc := @HiddenProc;
  WndClass.cbClsExtra := 0;
  WndClass.cbWndExtra := 0;
  WndClass.hInstance := HInstance;
  WndClass.hIcon := LoadIcon(0, IDI_APPLICATION);
  WndClass.hCursor := LoadCursor(0, IDC_APPSTARTING);
  WndClass.hbrBackground := GetSysColorBrush(COLOR_WINDOW);
  WndClass.lpszMenuName := '';
  S := Format('%s@%x', [Self.ClassName, GetCurrentThreadId]);
  WndClass.lpszClassName := PChar(S);
  fHiddenClass := Winapi.Windows.RegisterClass(WndClass);
  Sleep(1);
  dwExStyle := WS_EX_TOOLWINDOW;
  dwExStyle := dwExStyle or WS_EX_TRANSPARENT;
  dwExStyle := dwExStyle or WS_EX_LAYERED;
  if (fHiddenClass = 0) then
    Exit
  else
    fHiddenWnd := CreateWindowEx(dwExStyle,
                          MakeIntResource(fHiddenClass),
                          PChar(S),
                          WS_POPUP or WS_VISIBLE or WS_CLIPSIBLINGS or WS_CLIPCHILDREN,
                          0, 0, 0, 0,
                          Self.FHWND, 0, HInstance, nil);
  if (fHiddenWnd <> 0) then
    begin
      Winapi.Windows.SetLayeredWindowAttributes(fHiddenWnd, 0, 127, LWA_ALPHA or ULW_ALPHA);
      EnableWindow(fHiddenWnd, LongBool(not Transparent));
      hMenuHandle := GetSystemMenu(fHiddenWnd, False);
      if (hMenuHandle <> 0) then
        begin
          DeleteMenu(hMenuHandle, SC_SIZE, MF_BYCOMMAND);
          DeleteMenu(hMenuHandle, SC_MAXIMIZE, MF_BYCOMMAND);
          DeleteMenu(hMenuHandle, SC_MINIMIZE, MF_BYCOMMAND);
          DeleteMenu(hMenuHandle, SC_RESTORE, MF_BYCOMMAND);
          DeleteMenu(hMenuHandle, SC_MOVE, MF_BYCOMMAND);
          DeleteMenu(hMenuHandle, SC_CLOSE, MF_BYCOMMAND);
          DeleteMenu(hMenuHandle, 0, MF_BYCOMMAND);
          CloseHandle(hMenuHandle);
        end;
      SetWindowLongPtr(fHiddenWnd, GWL_USERDATA, NativeInt(Self));
    end;
end;

procedure TkzSnapShot.DestroyHidden;
begin
  if (fHiddenWnd <> 0) then
    DestroyWindow(fHiddenWnd);
  if (fHiddenClass <> 0) then
    Winapi.Windows.UnregisterClass(MakeIntResource(fHiddenClass), HInstance);
  fHiddenWnd := 0;
  fHiddenClass := 0;
end;

end.
