program kzSnapShot;

{$APPTYPE GUI}

uses
  Vcl.Forms,
  uMain in 'uMain.pas' {frmMain};

{$R *.res}

begin
  ReportMemoryLeaksOnShutdown := DebugHook <> 0;
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TfrmMain, frmMain);
  Application.Run;
end.
