program VCLTestApp;

uses
  Forms,
  VCLTestAppForm in 'VCLTestAppForm.pas' {MainForm},
  Jpeg2000Bitmap in '..\Jpeg2000Bitmap.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.Title := 'VCL Test App';
  Application.CreateForm(TMainForm, MainForm);
  Application.Run;
end.
