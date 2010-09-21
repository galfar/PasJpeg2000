{
  $Id$
  PasJpeg2000 by Marek Mauder
  http://code.google.com/p/pasjpeg2000
  http://galfar.vevb.net/pasjpeg2000

  The contents of this file are used with permission, subject to the Mozilla
  Public License Version 1.1 (the "License"); you may not use this file except
  in compliance with the License. You may obtain a copy of the License at
  http://www.mozilla.org/MPL/MPL-1.1.html

  Software distributed under the License is distributed on an "AS IS" basis,
  WITHOUT WARRANTY OF ANY KIND, either express or implied. See the License for
  the specific language governing rights and limitations under the License.

  Alternatively, the contents of this file may be used under the terms of the
  GNU Lesser General Public License (the  "LGPL License"), in which case the
  provisions of the LGPL License are applicable instead of those above.
  If you wish to allow use of your version of this file only under the terms
  of the LGPL License and not to allow others to use your version of this file
  under the MPL, indicate your decision by deleting  the provisions above and
  replace  them with the notice and other provisions required by the LGPL
  License.  If you do not delete the provisions above, a recipient may use
  your version of this file under either the MPL or the LGPL License.

  For more information about the LGPL: http://www.gnu.org/copyleft/lesser.html
}

{ Lightweight crossplatform JPEG 2000 reader and writer classes.}
unit Jpeg2000ImageIO;

{$IFDEF FPC}
  {$DEFINE HAS_INLINE}
  {$MODE DELPHI}
{$ELSE}
  {$IF CompilerVersion >= 17}
     {$DEFINE HAS_INLINE}
  {$IFEND}
{$ENDIF}

interface

uses
  SysUtils, Classes, OpenJpeg;

type
  EOpenJpegError = class(Exception);
  EJpeg2000ImageIOError = class(Exception);

  TJpeg2000QualityRange = 1..100;

  TJpeg2000ColorSpace = (
    csUnknown,
    csLuminance,
    csIndexed,
    csRGB,
    csYCbCr,
    csCMYK,
    csRestrictedICC);

  TJpeg2000ComponentType = (
    cpUnknown,
    cpOpacity,
    cpLuminance,
    cpIndex,
    cpBlue,
    cpGreen,
    cpRed,
    cpChromaRed,
    cpChromaBlue,
    cpCyan,
    cpMagenta,
    cpYellow,
    cpBlack);

  TJpeg2000ComponentInfo = record
    Width: Integer;
    Height: Integer;
    CompType: TJpeg2000ComponentType;
    Precision: Byte;
    Signed: Boolean;
    SubsampX: Integer;
    SubsampY: Integer;
    XOffset: Integer;
    YOffset: Integer;
    UnsignedShift: Integer;
    UnsignedMaxValue: LongWord;
  end;
  PJpeg2000ComponentInfo = ^TJpeg2000ComponentInfo;

  TJpeg2000ImageInfo = record
    Width: Integer;
    Height: Integer;
    ColorSpace: TJpeg2000ColorSpace;
    ComponentCount: Integer;
    HasOpacity: Boolean;
    XOffset: Integer;
    YOffset: Integer;
  end;

type

  TJpeg2000Options = class(TPersistent)
  private
    FLosslessCompression: Boolean;
    FLossyQuality: TJpeg2000QualityRange;
    FSaveWithMCT: Boolean;
    FSaveCodestreamOnly: Boolean;
  public
    constructor Create;
    procedure Assign(Source: TPersistent); override;
  published
    { If set to True bitmap is saved as lossless JPEG 2000, otherwise it
      uses lossy compression.}
    property LosslessCompression: Boolean read FLosslessCompression write FLosslessCompression;
    { Quality of lossy compression where 1 is "ugly image/small file" and
      100 is "max quality/large file".}
    property LossyQuality: TJpeg2000QualityRange read FLossyQuality write FLossyQuality;
    { Optionally uses multi-component color transformation when saving images.
      (usually produces smaller compressed files. Only applicable for
      3 channel RGB images. Default value is True.}
    property SaveWithMCT: Boolean read FSaveWithMCT write FSaveWithMCT;
  end;

  TJpeg2000ImageIO = class
  private
    function GetEmpty: Boolean;
    function GetComponent(Index: Integer): TJpeg2000ComponentInfo;
    function GetBitsPerPixel: Integer;
  protected
    FOptions: TJpeg2000Options;
    FOpjImage: POpjImage;
    FImageInfo: TJpeg2000ImageInfo;
    FComponents: array of TJpeg2000ComponentInfo;
  public
    constructor Create;
    destructor Destroy; override;

    //procedure CopyPixels();

    procedure ReadFromFile(const FileName: string);
    procedure ReadFromStream(Stream: TStream);
    procedure GetComponentData(AIndex: Integer; Samples: PByte; ScanlineIndex,
      Stride, DestBpp: Integer; UpsampleIfNeeded: Boolean = True);


    procedure BeginNewImage(AWidth, AHeight: Integer; AColorSpace: TJpeg2000ColorSpace;
      AHasOpacity: Boolean; AComponentCount: Integer = 0; AXOffset: Integer = 0; AYOffset: Integer = 0);
    procedure DefineComponent(AIndex: Integer; AWidth, AHeight,APrecision: Integer;
      CompType: TJpeg2000ComponentType; SubsampX: Integer = 1; SubsampY: Integer = 1);
    procedure BuildNewImage;
    procedure SetComponentData(AIndex: Integer; Samples: PByte; ScanlineIndex, Stride: Integer);
    procedure WriteToFile(const FileName: string);
    procedure WriteToStream(Stream: TStream);


    function GetComponentTypeIndex(AType: TJpeg2000ComponentType): Integer;
    procedure ClearImage;

    //procedure CopyToARGB32Image();



//    procedure ReadFromMemory();



    property Empty: Boolean read GetEmpty;
    property Width: Integer read FImageInfo.Width;
    property Height: Integer read FImageInfo.Height;
    property XOffset: Integer read FImageInfo.XOffset;
    property YOffset: Integer read FImageInfo.YOffset;
    property ColorSpace: TJpeg2000ColorSpace read FImageInfo.ColorSpace;
    property ComponentCount: Integer read FImageInfo.ComponentCount;
    property Components[Index: Integer]: TJpeg2000ComponentInfo read GetComponent;
    property BitsPerPixel: Integer read GetBitsPerPixel;
    property HasOpacity: Boolean read FImageInfo.HasOpacity;
    property RawImage: POpjImage read FOpjImage;
    property Options: TJpeg2000Options read FOptions;
  end;

function ClampToByte(Value: LongInt): LongInt; {$IFDEF HAS_INLINE}inline;{$ENDIF}
procedure YCbCrToRGB(Y, Cb, Cr: Byte; var R, G, B: Byte); {$IFDEF HAS_INLINE}inline;{$ENDIF}
procedure CMYKToRGB(C, M, Y, K: Byte; var R, G, B: Byte); {$IFDEF HAS_INLINE}inline;{$ENDIF}
function MulDiv(Number, Numerator, Denominator: LongWord): LongWord; {$IFDEF HAS_INLINE}inline;{$ENDIF}

implementation

type
  { Type Jpeg 2000 file (needed for OpenJPEG codec settings).}
  TJpeg2000FileType = (jtInvalid, jtJP2, jtJ2K, jtJPT);

  TChar8 = array[0..7] of AnsiChar;
  TChar4 = array[0..3] of AnsiChar;

const
  JP2Signature: TChar8 = #0#0#0#$0C#$6A#$50#$20#$20;
  J2KSignature: TChar4 = #$FF#$4F#$FF#$51;
  MaxComponentCount = 32;

  Jpeg2000DefaultLosslessCompression = False;
  Jpeg2000DefaultLossyQuality = 80;

function ClampToByte(Value: Integer): Integer;
begin
  Result := Value;
  if Result > 255 then
    Result := 255
  else if Result < 0 then
    Result := 0;
end;

procedure YCbCrToRGB(Y, Cb, Cr: Byte; var R, G, B: Byte);
begin
  R := ClampToByte(Round(Y                        + 1.40200 * (Cr - 128)));
  G := ClampToByte(Round(Y - 0.34414 * (Cb - 128) - 0.71414 * (Cr - 128)));
  B := ClampToByte(Round(Y + 1.77200 * (Cb - 128)));
end;

procedure CMYKToRGB(C, M, Y, K: Byte; var R, G, B: Byte);
begin
   R := (255 - (C - MulDiv(C, K, 255) + K));
   G := (255 - (M - MulDiv(M, K, 255) + K));
   B := (255 - (Y - MulDiv(Y, K, 255) + K));
end;

function MulDiv(Number, Numerator, Denominator: LongWord): LongWord;
begin
  Result := Number * Numerator div Denominator;
end;

function Jpeg2000CompTypeToOpjCompType(CompType: TJpeg2000ComponentType): TOpjComponentType;
begin
  case CompType of
    cpOpacity:    Result := COMPTYPE_OPACITY;
    cpLuminance:  Result := COMPTYPE_L;
    cpIndex: ;
    cpBlue:       Result := COMPTYPE_B;
    cpGreen:      Result := COMPTYPE_G;
    cpRed:        Result := COMPTYPE_R;
    cpChromaRed:  Result := COMPTYPE_CR;
    cpChromaBlue: Result := COMPTYPE_CB;
    cpCyan:       Result := COMPTYPE_C;
    cpMagenta:    Result := COMPTYPE_M;
    cpYellow:     Result := COMPTYPE_Y;
    cpBlack:      Result := COMPTYPE_K;
  else
    Result := COMPTYPE_UNKNOWN;
  end;
end;

{ TJpeg2000Options }

constructor TJpeg2000Options.Create;
begin
  FLosslessCompression := Jpeg2000DefaultLosslessCompression;
  FLossyQuality := Jpeg2000DefaultLossyQuality;
  FSaveWithMCT := True;
end;

procedure TJpeg2000Options.Assign(Source: TPersistent);
var
  SrcOpts: TJpeg2000Options;
begin
  if Source is TJpeg2000Options then
  begin
    SrcOpts := TJpeg2000Options(Source);
    FLosslessCompression := SrcOpts.FLosslessCompression;
    FLossyQuality := SrcOpts.FLossyQuality;
    FSaveWithMCT := SrcOpts.FSaveWithMCT;
  end
  else
    inherited;
end;

{ TJpeg2000ImageIO }

constructor TJpeg2000ImageIO.Create;
begin
  FOptions := TJpeg2000Options.Create;
end;

destructor TJpeg2000ImageIO.Destroy;
begin
  FOptions.Free;
  inherited;
end;

function TJpeg2000ImageIO.GetEmpty: Boolean;
begin
  Result := FOpjImage = nil;
end;

function TJpeg2000ImageIO.GetBitsPerPixel: Integer;
var
  I: Integer;
begin
  Result := 0;
  for I := 0 to FImageInfo.ComponentCount - 1 do
    Inc(Result, FComponents[I].Precision);
end;

function TJpeg2000ImageIO.GetComponent(Index: Integer): TJpeg2000ComponentInfo;
begin
  Result := FComponents[Index];
end;

procedure TJpeg2000ImageIO.GetComponentData(AIndex: Integer; Samples: PByte;
  ScanlineIndex, Stride, DestBpp: Integer; UpsampleIfNeeded: Boolean);
var
  X, SX, XRepeat: Integer;
  Info: TJpeg2000ComponentInfo;
  SrcLine: PInteger;
  Sample: LongWord;
begin
  Assert(AIndex in [0..ComponentCount - 1]);
  Assert(DestBpp in [1, 8, 16, 32]);
  Info := FComponents[AIndex];

  if UpsampleIfNeeded then
    ScanlineIndex := ScanlineIndex div Info.SubsampY
  else if ScanlineIndex >= Info.Height then
    Exit;

  XRepeat := Info.SubsampX - 1;
  if not UpsampleIfNeeded then
    XRepeat := 0;

  SrcLine := @FOpjImage.comps[AIndex].data[ScanlineIndex * Info.Width];

  for X := 0 to Info.Width - 1 do
  begin
    if Info.Signed then
      Sample := SrcLine^ + Info.UnsignedShift
    else
      Sample := SrcLine^;

    if DestBpp <> Info.Precision then
    begin
      case DestBpp of
        8:  Sample := MulDiv(Sample, $FF, Info.UnsignedMaxValue);
        16: Sample := MulDiv(Sample, $FFFF, Info.UnsignedMaxValue);
        32: Sample := MulDiv(Sample, $FFFFFFFF, Info.UnsignedMaxValue);
      end;
    end;

    if Info.XOffset + X * Info.SubsampX + XRepeat >= Width - 1 then
      XRepeat := Width - 1 - Info.XOffset - X * Info.SubsampX;

    for SX := 0 to XRepeat do
    begin
      case DestBpp of
        1:  ;
        8:  Samples^ := Sample;
        16: PWord(Samples)^ := Sample;
        32: PLongWord(Samples)^ := Sample;
      end;

      Inc(Samples, Stride);
    end;

    Inc(SrcLine);
  end;
end;

function TJpeg2000ImageIO.GetComponentTypeIndex(
  AType: TJpeg2000ComponentType): Integer;
begin
  for Result := 0 to ComponentCount - 1 do
    if FComponents[Result].CompType = AType then
      Exit;
  Result := -1;
end;

procedure TJpeg2000ImageIO.BeginNewImage(AWidth, AHeight: Integer;
  AColorSpace: TJpeg2000ColorSpace; AHasOpacity: Boolean;
  AComponentCount, AXOffset, AYOffset: Integer);

  function DetermineDefaultComponentCount: Integer;
  begin
    Result := 0;
    case AColorSpace of
      csLuminance, csIndexed: Result := 1;
      csRGB, csYCbCr:         Result := 3;
      csCMYK:                 Result := 4;
    end;
    if AHasOpacity then
      Inc(Result);
  end;

begin
  Assert((AColorSpace <> csUnknown) and (AWidth > 0) and (AHeight > 0));
  ClearImage;

  FImageInfo.Width := AWidth;
  FImageInfo.Height := AHeight;
  FImageInfo.XOffset := AXOffset;
  FImageInfo.YOffset := AYOffset;
  FImageInfo.ColorSpace := AColorSpace;
  FImageInfo.HasOpacity := AHasOpacity;

  FImageInfo.ComponentCount := AComponentCount;
  if FImageInfo.ComponentCount = 0 then
    FImageInfo.ComponentCount := DetermineDefaultComponentCount
  else if FImageInfo.ComponentCount > MaxComponentCount then
    FImageInfo.ComponentCount := MaxComponentCount;

  SetLength(FComponents, FImageInfo.ComponentCount);
end;

procedure TJpeg2000ImageIO.DefineComponent(AIndex, AWidth, AHeight,
  APrecision: Integer; CompType: TJpeg2000ComponentType; SubsampX,
  SubsampY: Integer);
var
  Info: PJpeg2000ComponentInfo;
begin
  Assert(AIndex in [0..ComponentCount - 1]);
  Info := @FComponents[AIndex];

  Info.Width := AWidth;
  Info.Height := AHeight;
  Info.CompType := CompType;
  Info.Precision := APrecision;
  Info.SubsampX := SubsampX;
  Info.SubsampY := SubsampY;
  Info.Signed := False;
  Info.XOffset := 0;
  Info.YOffset := 0;
end;

procedure TJpeg2000ImageIO.SetComponentData(AIndex: Integer;
  Samples: PByte; ScanlineIndex, Stride: Integer);
begin
  Assert(AIndex in [0..ComponentCount - 1]);

end;

procedure TJpeg2000ImageIO.BuildNewImage;
var
  Params: array of TOpjImageCompParam;
  OpjColorSpace: TOpjColorSpace;
  I: Integer;
  Info: TJpeg2000ComponentInfo;
begin
  OpjColorSpace := CLRSPC_UNKNOWN;
  case FImageInfo.ColorSpace of
    csLuminance: OpjColorSpace := CLRSPC_GRAY;
    csIndexed:   OpjColorSpace := CLRSPC_SRGB;
    csRGB:       OpjColorSpace := CLRSPC_SRGB;
    csYCbCr:     OpjColorSpace := CLRSPC_SYCC;
    csCMYK:      OpjColorSpace := CLRSPC_CMYK;
  end;

  SetLength(Params, FImageInfo.ComponentCount);

  for I := 0 to FImageInfo.ComponentCount - 1 do
  begin
    Info := FComponents[I];
    Params[I].w := Info.Width;
    Params[I].h := Info.Height;
    Params[I].dx := Info.SubsampX;
    Params[I].dy := Info.SubsampY;
    Params[I].x0 := Info.XOffset;
    Params[I].y0 := Info.YOffset;
    Params[I].prec := Info.Precision;
    Params[I].bpp := Info.Precision;
    Params[I].sgnd := Ord(Info.Signed);
    Params[I].comp_type := Jpeg2000CompTypeToOpjCompType(Info.CompType);
  end;

  // Check validity of settings (like component outside image etc., Cr in CMYK etc)

  FOpjImage := opj_image_create(FImageInfo.ComponentCount, @Params[0], OpjColorSpace);

  if FOpjImage = nil then
    raise EJpeg2000ImageIOError.Create('aaa');

  FOpjImage.x0 := FImageInfo.XOffset;
  FOpjImage.y0 := FImageInfo.YOffset;
  FOpjImage.x1 := FImageInfo.XOffset + FImageInfo.Width;
  FOpjImage.y1 := FImageInfo.YOffset + FImageInfo.Height;
end;

procedure TJpeg2000ImageIO.ReadFromFile(const FileName: string);
var
  Stream: TStream;
begin
  Stream := TFileStream.Create(FileName, fmOpenRead or fmShareDenyWrite);
  try
    ReadFromStream(Stream);
  finally
    Stream.Free;
  end;
end;

procedure TJpeg2000ImageIO.ReadFromStream(Stream: TStream);
var
  Info: POpjDInfo;
  Parameters: TOpjDParameters;
  IO: POpjCio;
  Buffer: array of Byte;
  BufferLen: Integer;

  function GetFileType: TJpeg2000FileType;
  var
    Count: Integer;
    Id: TChar8;
  begin
    Result := jtInvalid;
    Count := Stream.Read(Id, SizeOf(Id));
    if Count = SizeOf(Id) then
    begin
      // Check if we have full JP2 file format or just J2K code stream
      if CompareMem(@Id, @JP2Signature, SizeOf(JP2Signature)) then
        Result := jtJP2
      else if CompareMem(@Id, @J2KSignature, SizeOf(J2KSignature)) then
        Result := jtJ2K;
    end;
    Stream.Seek(-Count, soFromCurrent);
  end;

  procedure FillImageAndComponentInfos;
  var
    I: Integer;
    Info: PJpeg2000ComponentInfo;
    SrcComp: POpjImageComp;
  begin
    FImageInfo.Width := FOpjImage.x1 - FOpjImage.x0;
    FImageInfo.Height := FOpjImage.y1 - FOpjImage.y0;
    FImageInfo.ComponentCount := FOpjImage.numcomps;
    FImageInfo.XOffset := FOpjImage.x0;
    FImageInfo.YOffset := FOpjImage.y0;
    FImageInfo.HasOpacity := False;

    case FOpjImage.color_space of
      CLRSPC_GRAY: FImageInfo.ColorSpace := csLuminance;
      CLRSPC_SRGB: FImageInfo.ColorSpace := csRGB;
      CLRSPC_SYCC: FImageInfo.ColorSpace := csYCbCr;
      CLRSPC_CMYK: FImageInfo.ColorSpace := csCMYK;
    else
      FImageInfo.ColorSpace := csUnknown;
    end;

    // Mark image as indexed if there is a palette with entries for all channels
    if (FOpjImage.palette <> nil) and (FOpjImage.numcomps = FOpjImage.palette.numchans) then
      FImageInfo.ColorSpace := csIndexed;

    SetLength(FComponents, FImageInfo.ComponentCount);

    for I := 0 to FImageInfo.ComponentCount - 1 do
    begin
      Info := @FComponents[I];
      SrcComp := @FOpjImage.comps[I];

      // Basic props
      Info.Width := SrcComp.w;
      Info.Height := SrcComp.h;
      Info.XOffset := SrcComp.x0;
      Info.YOffset := SrcComp.y0;
      Info.SubsampX := SrcComp.dx;
      Info.SubsampY := SrcComp.dy;
      Info.Precision := SrcComp.prec;
      Info.Signed := SrcComp.sgnd = 1;
      Info.CompType := cpUnknown;

      // Signed componets must be scaled to [0, 1] interval (depends on precision)
      if Info.Signed then
        Info.UnsignedShift := 1 shl (Info.Precision - 1);
      // Scaling value used when converting samples from
      // more exotic bpp representations
      Info.UnsignedMaxValue := 1 shl Info.Precision - 1;

      // Component type
      case SrcComp.comp_type of
        COMPTYPE_UNKNOWN:
          begin
            // Missing CDEF box in JP2 file, we just guess component associations
            case FImageInfo.ColorSpace of
              csLuminance:
                Info.CompType := cpLuminance;
              csRGB:
                // Usually [msb]BGR/ABGR[lsb] order
                case I of
                  0: Info.CompType := cpRed;
                  1: Info.CompType := cpGreen;
                  2: Info.CompType := cpBlue;
                end;
              csYCbCr:
                // Usually [msb]CCY/ACCY[lsb] order
                case I of
                  0: Info.CompType := cpLuminance;
                  1: Info.CompType := cpChromaBlue;
                  2: Info.CompType := cpChromaRed;
                end;
              csCMYK:
                // Usually [msb]KYMC[lsb] order
                case I of
                  0: Info.CompType := cpCyan;
                  1: Info.CompType := cpMagenta;
                  2: Info.CompType := cpYellow;
                  3: Info.CompType := cpBlack;
                end;
            end;
            if (ComponentCount in [2, 4]) and (I = ComponentCount - 1) and
              (FImageInfo.ColorSpace in [csRGB, csYCbCr, csLuminance]) then
            begin
              Info.CompType := cpOpacity;
            end;
          end;
        COMPTYPE_R:       Info.CompType := cpRed;
        COMPTYPE_G:       Info.CompType := cpGreen;
        COMPTYPE_B:       Info.CompType := cpBlue;
        COMPTYPE_CB:      Info.CompType := cpChromaBlue;
        COMPTYPE_CR:      Info.CompType := cpChromaRed;
        COMPTYPE_OPACITY: Info.CompType := cpOpacity;
        COMPTYPE_L:       Info.CompType := cpLuminance; // Y is intensity part of YCC or independent gray channel
        COMPTYPE_C:       Info.CompType := cpCyan;
        COMPTYPE_M:       Info.CompType := cpMagenta;
        COMPTYPE_Y:       Info.CompType := cpYellow;
        COMPTYPE_K:       Info.CompType := cpBlack;
      end;

      if Info.CompType = cpOpacity then
        FImageInfo.HasOpacity := True;
    end;
  end;

begin
  ClearImage;
  opj_set_default_decoder_parameters(@Parameters);

  // Determine which codec to use
  case GetFileType of
    jtJP2: Info := opj_create_decompress(CODEC_JP2);
    jtJ2K: Info := opj_create_decompress(CODEC_J2K);
  else
    raise EJpeg2000ImageIOError.Create('Unknown JPEG 2000 file type');
  end;

  // Set event manager to nil to avoid getting messages
  Info.event_mgr := nil;
  // Currently OpenJPEG can load images only from memory so we have to
  // preload whole input to mem buffer. Not good but no other way now.
  // At least we set stream pos to end of JP2 data after loading (we will
  // know the exact size by then).
  BufferLen := Stream.Size - Stream.Position;
  SetLength(Buffer, BufferLen);
  Stream.ReadBuffer(Buffer[0], BufferLen);
  // Open OpenJPEG's IO on buffer with compressed image
  IO := opj_cio_open(opj_common_ptr(Info), @Buffer[0], BufferLen);
  opj_setup_decoder(Info, @Parameters);

  try
    // Decode image
    FOpjImage := opj_decode(Info, IO);
    if FOpjImage = nil then
      raise EJpeg2000ImageIOError.Create('JPEG 2000 image decoding failed');
  finally
    // Set the input position just after end of image
    Stream.Seek(-BufferLen + (Integer(IO.bp) - Integer(IO.start)), soFromCurrent);
    SetLength(Buffer, 0);
    opj_destroy_decompress(Info);
    opj_cio_close(IO);
  end;

  // Get info about image and its components in more user friendly format
  FillImageAndComponentInfos;
end;

procedure TJpeg2000ImageIO.WriteToFile(const FileName: string);
var
  Stream: TStream;
begin
  Stream := TFileStream.Create(FileName, fmOpenRead or fmShareDenyWrite);
  try
    WriteToStream(Stream);
  finally
    Stream.Free;
  end;
end;

procedure TJpeg2000ImageIO.WriteToStream(Stream: TStream);
var
  IO: POpjCio;
  Info: POpjCInfo;
  Parameters: TOpjCParameters;

  procedure SetCompParams;
  var
    Rate, TargetSize: Single;
    NumDataItems: Integer;
  begin
    Parameters.cod_format := 1;
    Parameters.numresolution := 6;
    Parameters.tcp_numlayers := 1;
    Parameters.cp_disto_alloc := 1;
    // Use MCT (multi-color component transform) RGB->YCbCr, OpenJpeg uses it only for 3 channel images though
    Parameters.tcp_mct := Ord(Options.SaveWithMCT);

    if Options.LosslessCompression then
    begin
      // Set rate to 0 -> lossless
      Parameters.tcp_rates[0] := 0;
    end
    else
    begin
      // Use irreversible DWT
      Parameters.irreversible := 1;
      // Quality -> Rate computation taken from ImageMagick
      Rate := 100.0 / Sqr(115 - Options.LossyQuality);
      NumDataItems := Width * Height * ComponentCount;
      TargetSize := (NumDataItems * Rate) + 550 + (ComponentCount - 1) * 142;
      Parameters.tcp_rates[0] := 1.0 / (TargetSize / NumDataItems);
    end;
  end;

begin
  // Create JP2 compressor (save JP2 boxes + code stream)
  Info := opj_create_compress(CODEC_JP2);
  // Set event manager to nil to avoid getting messages
  Info.event_mgr := nil;
  // Set various sompression params and then setup encoder
  opj_set_default_encoder_parameters(@Parameters);
  SetCompParams;
  opj_setup_encoder(Info, @Parameters, FOpjImage);
  // Open OpenJPEG output
  IO := opj_cio_open(opj_common_ptr(Info), nil, 0);

  try
    // Try to encode the image
    if not opj_encode(Info, IO, FOpjImage, nil) then
      raise EJpeg2000ImageIOError.Create('JPEG 2000 image encoding failed');;
    // Finally write buffer with encoded image to output
    Stream.WriteBuffer(IO.buffer^, cio_tell(IO));
  finally
    opj_destroy_compress(Info);
    opj_cio_close(IO);
  end;
end;

procedure TJpeg2000ImageIO.ClearImage;
begin
  opj_image_destroy(FOpjImage);
  FOpjImage := nil;

  SetLength(FComponents, 0);
  FillChar(FImageInfo, SizeOf(FImageInfo), 0);
end;

end.
