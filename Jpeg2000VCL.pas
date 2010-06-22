unit Jpeg2000VCL;

{$IFDEF FPC}
  {$ERROR 'This unit is for Delphi VCL only'}
{$ENDIF}

interface

uses
  Windows, SysUtils, Classes, Graphics, Jpeg2000ImageIO;

type
  EJpeg2000BitmapError = class(Exception);

  TJpeg2000Bitmap = class(TBitmap)
  private
    FOptions: TJpeg2000Options;
  public
    constructor Create; override;
    destructor Destroy; override;

    procedure LoadFromStream(Stream: TStream); override;
    procedure SaveToStream(Stream: TStream); override;

    property Options: TJpeg2000Options read FOptions;
  end;

implementation

resourcestring
  SJpeg2000ImageFile = 'JPEG 2000 Image';
  SComponentNotFound = 'Requested component/channel not found in source JPEG 2000 image.';

{ TJpeg2000Bitmap }

constructor TJpeg2000Bitmap.Create;
begin
  inherited;
  FOptions := TJpeg2000Options.Create;
end;

destructor TJpeg2000Bitmap.Destroy;
begin
  FOptions.Free;
  inherited;
end;

procedure TJpeg2000Bitmap.LoadFromStream(Stream: TStream);
var
  IO: TJpeg2000ImageIO;
  NewPF: TPixelFormat;
  Y, BytesPerPixel: Integer;

  procedure DeterminePixelFormatAndBpp(var PF: TPixelFormat; var Bpp: Integer);
  begin
    PF := pf32bit;
    Bpp := 4;

    case IO.ComponentCount of
      1:
        begin
          PF := pf8bit;
          Bpp := 1;
        end;
      3:
        begin
          PF := pf24bit;
          Bpp := 3;
        end;
    end;
  end;

  procedure ReadComponent(const Types: array of TJpeg2000ComponentType; ScanIdx, Stride: Integer);
  var
    CompIdx, I: Integer;
  begin
    for I := 0 to Length(Types) - 1 do
    begin
      CompIdx := I;
      if Types[I] <> cpUnknown then
        CompIdx := IO.GetComponentTypeIndex(Types[I]);
      if CompIdx >= IO.ComponentCount then
        CompIdx := IO.ComponentCount - 1;

      if CompIdx < 0 then
        raise EJpeg2000BitmapError.Create(SComponentNotFound);

      IO.GetComponentData(CompIdx, @PByteArray(ScanLine[ScanIdx])[I], Y, Stride, 8);
    end;
  end;

  procedure SetupPalette;
  var
    I: Integer;
    LogPalette: TMaxLogPalette;
  begin
    FillChar(LogPalette, SizeOf(LogPalette), 0);
    LogPalette.palVersion := $300;
    LogPalette.palNumEntries := 256;

    if IO.ColorSpace = csIndexed then
    begin
      // Read palette from decoded image

    end
    else
    begin
      // Create linear palette for luminance and unknown formats
      for I := 0 to 255 do
      with LogPalette do
      begin
        palPalEntry[I].peRed :=   I;
        palPalEntry[I].peGreen := I;
        palPalEntry[I].peBlue :=  I;
      end;
    end;

    Self.Palette := CreatePalette(PLogPalette(@LogPalette)^);
  end;

  procedure ConvertFromYCC;
  var
    X, I: Integer;
    Ptr: PByteArray;
    Yc, Cb, Cr: Byte;
  begin
    for I := 0 to Height - 1 do
    begin
      Ptr := ScanLine[I];
      for X := 0 to Width - 1 do
      begin
        Yc := Ptr[2];
        Cb := Ptr[1];
        Cr := Ptr[0];
        YCbCrToRGB(Yc, Cb, Cr, Ptr[2], Ptr[1], Ptr[0]);
        Ptr := @Ptr[BytesPerPixel];
      end;
    end;
  end;

  procedure ConvertFromCMYK;
  var
    X, I: Integer;
    Ptr: PByteArray;
    C, M, Y, K: Byte;
  begin
    for I := 0 to Height - 1 do
    begin
      Ptr := ScanLine[I];
      for X := 0 to Width - 1 do
      begin
        C := Ptr[3];
        M := Ptr[2];
        Y := Ptr[1];
        K := Ptr[0];
        CMYKToRGB(C, M, Y, K, Ptr[2], Ptr[1], Ptr[0]);
        Ptr := @Ptr[BytesPerPixel];
      end;
    end;
  end;

begin
  IO := TJpeg2000ImageIO.Create;
  try
    IO.ReadFromStream(Stream);

    DeterminePixelFormatAndBpp(NewPF, BytesPerPixel);
    PixelFormat := NewPF;
  {$IF CompilerVersion >= 18.0}
    SetSize(IO.Width, IO.Height);
  {$ELSE}
    Width := IO.Width;
    Height := IO.Height;
  {$IFEND}

    // 8bit bitmaps need palette to be set up before pixels are written
    if PixelFormat = pf8Bit then
      SetupPalette;

    // Now read sanlines from decoded JPEG 2000 image base on pixel format
    // and color space
    for Y := 0 to Height - 1 do
    begin
      FillChar(ScanLine[Y]^, Width * BytesPerPixel, 0);

      case NewPF of
        pf8bit:
          case IO.ColorSpace of
            csLuminance: ReadComponent([cpLuminance], Y, 1);
            csIndexed:   ReadComponent([cpIndex], Y, 1);
          else
            ReadComponent([cpUnknown], Y, 1);
          end;

        pf24bit:
          case IO.ColorSpace of
            csRGB:   ReadComponent([cpBlue, cpGreen, cpRed], Y, 3);
            csYCbCr: ReadComponent([cpChromaRed, cpChromaBlue, cpLuminance], Y, 3);
          else
            ReadComponent([cpUnknown, cpUnknown, cpUnknown], Y, 3);
          end;

        pf32bit:
          case IO.ColorSpace of
            csLuminance: ReadComponent([cpLuminance, cpLuminance, cpLuminance, cpOpacity], Y, 4);  // Luminance+Alpha
            csRGB:       ReadComponent([cpBlue, cpGreen, cpRed, cpOpacity], Y, 4);                 // Standard RGB+Alpha
            csYCbCr:     ReadComponent([cpChromaRed, cpChromaBlue, cpLuminance, cpOpacity], Y, 4); // YCC+Alpha
            csCMYK:      ReadComponent([cpBlack, cpYellow, cpMagenta, cpCyan], Y, 4);              // CMYK
          else
            ReadComponent([cpUnknown, cpUnknown, cpUnknown, cpUnknown], Y, 4);
          end;
      end;
    end;

    // Convert to RGB colorspace if needed
    case IO.ColorSpace of
      csYCbCr:   ConvertFromYCC;
      csCMYK:    ConvertFromCMYK;
    end;

  {$IF CompilerVersion >= 20.0}
    // Delphi 2009 and newer support alpha transparency
    if (PixelFormat = pf32bit) and IO.HasOpacity then
      AlphaFormat := afDefined;
  {$IFEND}

  finally
    IO.Free;
  end;
end;

procedure TJpeg2000Bitmap.SaveToStream(Stream: TStream);
var
  IO: TJpeg2000ImageIO;
begin
  inherited;
 { IO := TJpeg2000ImageIO.Create;
  try

    IO.Options.Assign(Options);
    IO.WriteToStream(Stream);
  finally
    IO.Free;
  end;}
end;

initialization
  TPicture.RegisterFileFormat('jp2', SJpeg2000ImageFile, TJpeg2000Bitmap);
  TPicture.RegisterFileFormat('j2k', SJpeg2000ImageFile, TJpeg2000Bitmap);
  TPicture.RegisterFileFormat('jpc', SJpeg2000ImageFile, TJpeg2000Bitmap);
finalization
  TPicture.UnregisterGraphicClass(TJpeg2000Bitmap);
end.
