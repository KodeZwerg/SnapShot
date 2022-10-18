unit uCapture;

interface

uses
  Winapi.Windows,
  System.Classes, System.Types,
  Vcl.Controls,
  Vcl.Forms,
  Vcl.ComCtrls;

type

  TfrmCapture = class(TForm)
    procedure FormShow(Sender: TObject);
    procedure FormMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
    procedure FormMouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure FormMouseUp(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure FormCreate(Sender: TObject);
  private
    FX: Integer;
    FY: Integer;
    FCapturing: Boolean;
    DrawRect: TRect;
    DrawStart: TPoint;
    FInverted: Boolean;
    FAlphaBlendValue: Integer;
    FRect: TRect;
  private
    procedure SetAlphaBlendValue(const AValue: Integer);
  protected
    procedure CreateParams(var Params: TCreateParams); override;
  public
    property Inverted: Boolean read FInverted;
    property AlphaBlendValueX: Integer read FAlphaBlendValue write SetAlphaBlendValue;
    property RectX: TRect read FRect;
  end;

var
  frmCapture: TfrmCapture;

implementation

{$R *.dfm}

procedure TfrmCapture.CreateParams(var Params: TCreateParams);
  begin
    inherited CreateParams(Params);
    if (TWincontrol(Self.Owner) <> nil) then
      Params.WndParent := TWincontrol(Self.Owner).Handle
      else
      if (Application.Mainform <> nil) then
        Params.WndParent := Application.Mainform.Handle;
  end;

procedure TfrmCapture.FormCreate(Sender: TObject);
begin
  Self.AlphaBlendValue := 50;
end;

procedure TfrmCapture.FormShow(Sender: TObject);
begin
  FCapturing := False;
  FInverted := False;
  Self.Left := Screen.DesktopLeft;
  Self.Top := Screen.DesktopTop;
  Self.Height := Screen.DesktopHeight;
  Self.Width := Screen.DesktopWidth;
  FRect.Empty;
end;

procedure TfrmCapture.SetAlphaBlendValue(const AValue: Integer);
begin
  FAlphaBlendValue := AValue;
  if (AValue > 255) then
    FAlphaBlendValue := 255;
  if (AValue < 1) then
    FAlphaBlendValue := 1;
  Self.AlphaBlendValue := FAlphaBlendValue;
end;

procedure TfrmCapture.FormKeyDown(Sender: TObject; var Key: Word;
  Shift: TShiftState);
begin
  if (Key = VK_ESCAPE) then
    Self.Close;
end;

procedure TfrmCapture.FormMouseDown(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
var
  oMouse: TPoint;
begin
  FCapturing := False;
  if (Button = mbLeft) then
    begin
      FCapturing := True;
      GetCursorPos(oMouse);
      FX := oMouse.X;
      FY := oMouse.Y;
      DrawRect.Left := FX;
      DrawRect.Top := FY;
      DrawRect.Right := DrawRect.Left;
      DrawRect.Bottom := DrawRect.Top;
      DrawStart.x := FX;
      DrawStart.y := FY;
    end;
  if (Button = mbMiddle) then
    begin
      FCapturing := True;
      FInverted := True;
      GetCursorPos(oMouse);
      FX := oMouse.X;
      FY := oMouse.Y;
      DrawRect.Left := FX;
      DrawRect.Top := FY;
      DrawRect.Right := DrawRect.Left;
      DrawRect.Bottom := DrawRect.Top;
      DrawStart.x := FX;
      DrawStart.y := FY;
    end;
end;

procedure TfrmCapture.FormMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
var
  ScreenDC: HDC;
  Region1,
  Region2: hRgn;
  oMouse: TPoint;
begin
  GetCursorPos(oMouse);
  X := oMouse.X;
  Y := oMouse.Y;
  if FCapturing then
    begin
      ScreenDC := GetDC(GetDesktopWindow);
      DrawFocusRect(ScreenDC, Rect(DrawRect.Left, DrawRect.Top, DrawRect.Right, DrawRect.Bottom));
      if X >= DrawStart.x then
        begin
          if DrawRect.Left <> DrawStart.X then
            DrawRect.Left := Succ(DrawStart.X);
          DrawRect.Right := X
        end
        else
        begin
          if DrawRect.Right <> DrawStart.X then
            DrawRect.Right := Pred(DrawStart.X);
          DrawRect.Left := X;
        end;
      if Y >= DrawStart.y then
        begin
          if DrawRect.Top <> DrawStart.Y then
            DrawRect.Top := Succ(DrawStart.Y);
          DrawRect.Bottom := Y;
        end
        else
        begin
          if DrawRect.Bottom <> DrawStart.Y then
            DrawRect.Bottom := Pred(DrawStart.Y);
          DrawRect.Top := Y;
        end;

      Region1 := CreateRectRgn(0, 0, Self.Width, Self.Height);
      Region2 := CreateRectRgnIndirect(Rect(DrawRect.Left + 2, DrawRect.Top + 2, DrawRect.Right - 2, DrawRect.Bottom - 2));
      CombineRgn(Region1, Region1, Region2, RGN_DIFF);
      SetWindowRgn(Handle, Region1, False);

//      DrawFocusRect(ScreenDC, DrawRect);
      ReleaseDC(GetDesktopWindow, ScreenDC);
    end;
end;

procedure TfrmCapture.FormMouseUp(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
var
  x1, x2, y1, y2: Integer;
  oMouse: TPoint;
begin
  GetCursorPos(oMouse);
  X := oMouse.X;
  Y := oMouse.Y;
  if (Button = mbRight) then
    begin
      Close;
    end;
  if FCapturing then
    begin
      Self.Visible := False;
      if ((FX <> X) or (FY <> Y)) then
        begin
          if X < FX then
            begin
              x1 := X;
              x2 := FX;
            end
            else
            begin
              x1 := FX;
              x2 := X;
            end;
          if Y < FY then
            begin
              y1 := Y;
              y2 := FY;
            end
            else
            begin
              y1 := FY;
              y2 := Y;
            end;
          FRect.Create(x1, y1, x2, y2);
        end;
      Close;
    end;
end;

end.
