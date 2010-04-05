{
  PasJpeg2000 VCL TJpeg2000Bitmap Demo
  http://code.google.com/p/pasjpeg2000
}
{
  In this VCL sample application you can load and save JPEG 2000 images
  and also preview them.

  "Open JPEG 2000 image" button loads image using TJpeg2000Bitmap class
  into TImage on form.
  "Save JPEG 2000 image" button saves currently loaded image using
  TJpeg2000Bitmap class. You can set compression setting to be used
  using controls bellow this button.
  "Open/Save any VCL supported image" buttons will load/save images
  using all image handlers currently registerd in VCL.

  Tested in Delphi 7 and 2010.
}
unit VCLTestAppForm;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, ExtCtrls, StdCtrls, ExtDlgs,
{$IF CompilerVersion >= 18.5}
  GifImg,
{$IFEND}
{$IF CompilerVersion >= 20.0}
  PngImage,
{$IFEND}
  jpeg,
  Jpeg2000Bitmap, ComCtrls;

type
  TMainForm = class(TForm)
    Image: TImage;
    OpenDialog: TOpenDialog;
    BtnOpenJP2: TButton;
    OpenPictureDialog: TOpenPictureDialog;
    BtnSaveJP2: TButton;
    BtnOpenGr: TButton;
    BtnSaveGr: TButton;
    SavePictureDialog: TSavePictureDialog;
    SaveDialog: TSaveDialog;
    CheckLossless: TCheckBox;
    Label1: TLabel;
    TrackQuality: TTrackBar;
    Label2: TLabel;
    CheckMCT: TCheckBox;
    procedure BtnOpenJP2Click(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure BtnOpenGrClick(Sender: TObject);
    procedure BtnSaveGrClick(Sender: TObject);
    procedure BtnSaveJP2Click(Sender: TObject);
  public
    JP2Bmp: TJpeg2000Bitmap;
  end;

var
  MainForm: TMainForm;

implementation

{$R *.dfm}

procedure TMainForm.BtnOpenJP2Click(Sender: TObject);
begin
  if OpenDialog.Execute then
  begin
    // Load JPEG 2000 file into Jpeg2k bitmap and assign it to TImage's picture.
    JP2Bmp.LoadFromFile(OpenDialog.FileName);
    Image.Picture.Assign(JP2Bmp);
  end;
end;

procedure TMainForm.BtnSaveJP2Click(Sender: TObject);
begin
  if Image.Picture.Graphic = nil then
  begin
    ShowMessage('No image loaded');
    Exit;
  end;

  if SaveDialog.Execute then
  begin
    // Assign current image from TImage to Jpeg2k bitmap, set
    // compression options and save it to file.
    JP2Bmp.Assign(Image.Picture.Graphic);
    JP2Bmp.LosslessCompression := CheckLossless.Checked;
    JP2Bmp.CompressionQuality := TrackQuality.Position;
    JP2Bmp.SaveWithMCT := CheckMCT.Checked;
    JP2Bmp.SaveToFile(SaveDialog.FileName);
  end;

  {JP2Bmp.Assign(Image.Picture.Graphic);
  JP2Bmp.LosslessCompression:= CheckLossless.Checked;
  JP2Bmp.CompressionQuality := TrackQuality.Position;
  JP2Bmp.SaveWithMCT := CheckMCT.Checked;
  JP2Bmp.SaveToFile(ExtractFilePath(Application.ExeName) + '\Out.jp2');}
end;

procedure TMainForm.BtnOpenGrClick(Sender: TObject);
begin
  if OpenPictureDialog.Execute then
    // Just load file using any registred image handler
    Image.Picture.LoadFromFile(OpenPictureDialog.FileName);
end;

procedure TMainForm.BtnSaveGrClick(Sender: TObject);
begin
  if SavePictureDialog.Execute then
    // Just save image using any registred image handler
    Image.Picture.SaveToFile(SavePictureDialog.FileName);
end;

procedure TMainForm.FormCreate(Sender: TObject);
begin
{$IF Defined(DEBUG) and (CompilerVersion >= 18.0)}
  System.ReportMemoryLeaksOnShutdown := True;
{$IFEND}
  JP2Bmp := TJpeg2000Bitmap.Create;
end;

procedure TMainForm.FormDestroy(Sender: TObject);
begin
  JP2Bmp.Free;
end;

end.
