{
  $Id: Jpeg2000Handlers.pas 16 2010-04-05 21:36:19Z galfar $
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

type

  TJpeg2000Options = class(TPersistent)
  private
    FLosslessCompression: Boolean;
    FLossyQuality: TJpeg2000QualityRange;
    FSaveWithMCT: Boolean;
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
    function GetIntProp(const Index: Integer): Integer;
    function GetComponent(Index: Integer): TJpeg2000ComponentInfo;
  protected
    FOptions: TJpeg2000Options;
    FImage: POpjImage;
    FColorSpace: TJpeg2000ColorSpace;
    FHasOpacity: Boolean;
    FComponents: array of TJpeg2000ComponentInfo;
  public
    constructor Create;
    destructor Destroy; override;

    //procedure CopyPixels();

    procedure NewImage(AWidth, AHeight: Integer; AColorSpace: TJpeg2000ColorSpace;
      AHasOpacity: Boolean; AComponentCount: Integer = 0; AXOffset: Integer = 0; AYOffset: Integer = 0);

//    procedure SetComponentData(AIndex: Integer; ABitsPerComponent: Integer;
//      Samples: PByte; Stride: Integer; SubX: Integer = 0; SubY: Integer = 0);

    procedure GetComponentData(AIndex: Integer; Samples: PByte; ScanlineIndex,
      Stride, DestBpp: Integer; UpsampleIfNeeded: Boolean = True);

    function GetComponentTypeIndex(AType: TJpeg2000ComponentType): Integer;

    procedure GetDataUInt8(AIndex: Integer; Samples: PByte; ScanlineIndex, Stride: Integer);

    //procedure CopyToARGB32Image();


    procedure ReadFromFile(const FileName: string);
    procedure ReadFromStream(Stream: TStream);
//    procedure ReadFromMemory();

    procedure WriteToFile(const FileName: string);
    procedure WriteToStream(Stream: TStream);

    property Empty: Boolean read GetEmpty;
    property Width: Integer index 1 read GetIntProp;
    property Height: Integer index 2 read GetIntProp;
    property XOffset: Integer index 3 read GetIntProp;
    property YOffset: Integer index 4 read GetIntProp;
    property ColorSpace: TJpeg2000ColorSpace read FColorSpace;
    property ComponentCount: Integer index 5 read GetIntProp;
    property Components[Index: Integer]: TJpeg2000ComponentInfo read GetComponent;
    property BitsPerPixel: Integer index 6 read GetIntProp;
    property HasOpacity: Boolean read FHasOpacity;
    property RawImage: POpjImage read FImage;
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
  Jpeg2000DefaultSaveWithMCT = True;

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

{ TJpeg2000Options }

constructor TJpeg2000Options.Create;
begin
  FLosslessCompression := Jpeg2000DefaultLosslessCompression;
  FLossyQuality := Jpeg2000DefaultLossyQuality;
  FSaveWithMCT := Jpeg2000DefaultSaveWithMCT;
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
  Result := FImage = nil;
end;

function TJpeg2000ImageIO.GetIntProp(const Index: Integer): Integer;
var
  I: Integer;
begin
  Assert(Index in [1..6]);

  Result := 0;
  case Index of
    1: Result := FImage.x1;
    2: Result := FImage.y1;
    3: Result := FImage.x0;
    4: Result := FImage.y0;
    5: Result := FImage.numcomps;
    6:
      for I := 0 to FImage.numcomps - 1 do
        Inc(Result, FImage.comps[I].prec);
  end;
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
  Assert(DestBpp in [1, 8, 16, 32]);
  Info := FComponents[AIndex];

  if UpsampleIfNeeded then
    ScanlineIndex := ScanlineIndex div Info.SubsampY
  else if ScanlineIndex >= Info.Height then
    Exit;

  XRepeat := Info.SubsampX - 1;
  if not UpsampleIfNeeded then
    XRepeat := 0;

  SrcLine := @FImage.comps[AIndex].data[ScanlineIndex * Info.Width];

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

procedure TJpeg2000ImageIO.GetDataUInt8(AIndex: Integer; Samples: PByte;
  ScanlineIndex, Stride: Integer);
var
  X: Integer;
begin
  for X := 0 to FComponents[AIndex].Width - 1 do
  begin


    Inc(Samples, Stride);
  end;
end;

procedure TJpeg2000ImageIO.NewImage(AWidth, AHeight: Integer;
  AColorSpace: TJpeg2000ColorSpace; AHasOpacity: Boolean;
  AComponentCount, AXOffset, AYOffset: Integer);
var
  Params: array of TOpjImageCompParam;
  OpjColorSpace: TOpjColorSpace;

  function DetermineDefaultComponentCount: Integer;
  begin
    Result := 0;
    case AColorSpace of
      csLuminance: ;
      csIndexed: ;
      csRGB: ;
      csYCbCr: ;
      csCMYK: ;
    end;
  end;

begin
  Assert((AColorSpace <> csUnknown) and (AWidth > 0) and (AHeight > 0));

  opj_image_destroy(FImage);
  FImage := nil;

  if AComponentCount = 0 then
    AComponentCount := DetermineDefaultComponentCount
  else if AComponentCount > MaxComponentCount then
    AComponentCount := MaxComponentCount;

  OpjColorSpace := CLRSPC_UNKNOWN;
  case AColorSpace of
    csLuminance: OpjColorSpace := CLRSPC_GRAY;
    csIndexed:   OpjColorSpace := CLRSPC_SRGB;
    csRGB:       OpjColorSpace := CLRSPC_SRGB;
    csYCbCr:     OpjColorSpace := CLRSPC_SYCC;
//    csCMYK:      OpjColorSpace := CLRSPC_SRGB;
  end;

  SetLength(Params, AComponentCount);


  FImage := opj_image_create(AComponentCount, @Params[0], OpjColorSpace);
//  FImage.x0


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
    FHasOpacity := False;
    SetLength(FComponents, ComponentCount);

    case FImage.color_space of
      CLRSPC_GRAY: FColorSpace := csLuminance;
      CLRSPC_SRGB: FColorSpace := csRGB;
      CLRSPC_SYCC: FColorSpace := csYCbCr;
    else
      FColorSpace := csUnknown;
    end;

    for I := 0 to ComponentCount - 1 do
    begin
      Info := @FComponents[I];
      SrcComp := @FImage.comps[I];

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
      // more exotic bpp reprsentations
      Info.UnsignedMaxValue := 1 shl Info.Precision - 1;

      // Component type
      case SrcComp.comp_type of
        COMPTYPE_UNKNOWN:
          begin
            // Missing CDEF box in JP2 file, we just guess component associations
            case FColorSpace of
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
            end;
            if (ComponentCount in [2, 4]) and (I = ComponentCount - 1) then
              Info.CompType := cpOpacity;
          end;
        COMPTYPE_R:       Info.CompType := cpRed;
        COMPTYPE_G:       Info.CompType := cpGreen;
        COMPTYPE_B:       Info.CompType := cpBlue;
        COMPTYPE_CB:      Info.CompType := cpChromaBlue;
        COMPTYPE_CR:      Info.CompType := cpChromaRed;
        COMPTYPE_OPACITY: Info.CompType := cpOpacity;
        COMPTYPE_Y:       Info.CompType := cpLuminance; // Y is intensity part of YCC or independent gray channel
      end;

      if Info.CompType = cpOpacity then
        FHasOpacity := True;
    end;
  end;

begin
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
    FImage := opj_decode(Info, IO);
    if FImage = nil then
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
begin

end;

end.
