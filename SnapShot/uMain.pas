unit uMain;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs,ClipBrd, Vcl.StdCtrls, Vcl.ExtCtrls,
  kz.Windows.SnapShot;

type
  TfrmMain = class(TForm)
    lblStatus: TLabel;
    imgMain: TImage;
    pnlOptions: TPanel;
    pnlEngine: TPanel;
    rbGDI: TRadioButton;
    rbDDA: TRadioButton;
    rbDX9: TRadioButton;
    rbPrint: TRadioButton;
    pnlHide: TPanel;
    cbAutoHide: TCheckBox;
    pnlClipboard: TPanel;
    cbClipboard: TCheckBox;
    procedure FormCreate(Sender: TObject);
    procedure rbGDIClick(Sender: TObject);
    procedure rbDDAClick(Sender: TObject);
    procedure rbDX9Click(Sender: TObject);
    procedure rbPrintClick(Sender: TObject);
    procedure cbAutoHideClick(Sender: TObject);
    procedure cbClipboardClick(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
  private
    { Private-Deklarationen }
    procedure DoMessage(ASender: TObject);
  public
    SS: TkzSnapShot;
    { Public-Deklarationen }
  end;

var
  frmMain: TfrmMain;

implementation

{$R *.dfm}


procedure TfrmMain.FormCreate(Sender: TObject);
begin
  SS := TkzSnapShot.Create(Sender, Self);
  SS.ActivateHotkey := True;
  SS.OnMessage := DoMessage;
end;

procedure TfrmMain.FormClose(Sender: TObject; var Action: TCloseAction);
begin
  SS.Free;
end;

procedure TfrmMain.DoMessage(ASender: TObject);
begin
  imgMain.Picture.Bitmap.Assign(SS.Bitmap);
  lblStatus.Caption := Format('Image copied to clipboard = %s - %s - %s - %s - %d x %d', [BoolToStr(SS.AutoToClipboard, True), FormatDateTime('hh:nn:ss', SS.CreationTime), ExtractFileName(SS.Filename), SS.Caption, SS.ImageWidth, SS.ImageHeight]);
end;

procedure TfrmMain.rbGDIClick(Sender: TObject);
begin
  SS.UseGDI := rbGDI.Checked;
end;

procedure TfrmMain.rbDDAClick(Sender: TObject);
begin
  SS.UseDDA := rbDDA.Checked;
end;

procedure TfrmMain.rbDX9Click(Sender: TObject);
begin
  SS.UseDX9 := rbDX9.Checked;
end;

procedure TfrmMain.rbPrintClick(Sender: TObject);
begin
  SS.UsePrint := rbPrint.Checked;
end;

procedure TfrmMain.cbAutoHideClick(Sender: TObject);
begin
  SS.AutoHide := cbAutoHide.Checked;
end;

procedure TfrmMain.cbClipboardClick(Sender: TObject);
begin
  SS.AutoToClipboard := cbClipboard.Checked;
end;

end.
