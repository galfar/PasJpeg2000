{
  $Id: Jpeg2000Bitmap.pas 16 2010-04-05 21:36:19Z galfar $
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

{ VCL TBitmap descendant which loads and saves raster data as JPEG 2000 images.
  Tested in Delphi 7 and 2010.}
unit Jpeg2000Bitmap;

{$IFDEF FPC}               
  {$ERROR 'This unit is for Delphi VCL only'}
{$ENDIF}

interface

uses
  Windows, SysUtils, Classes, Graphics;

type
  TJpeg2000QualityRange = 1..100;

  { TBitmap descendant which loads and saves raster data as JPEG 2000 images.
    It can load both files with JP2 header and raw code streams. Only files
    with JP2 header are saved. When saving bitmap as JPEG 2000 image
    user can choose whether to use lossy or lossless compression and
    quality of lossy compression.

    Images with more/less than 8 bits per channel are resampled to 8 bit. Images
    using YCC color space are converted to RGB. Grayscale JPEG 2000 images
    are loaded as 8bit indexed bitmaps and default grayscale palette is used.
    Images with 2 or 5+ channels are treated like grayscale and only first
    channel is loaded. JPEG 2000 images that use ICC profile
    or palette are not supported - raw pixel data is loaded though.

    Opacity/alpha channel is supported - 32bit bitmap is created if
    opacity component is present in file. When using Delphi 2009+
    TBitmap's alpha format property is properly set.}
  TJpeg2000Bitmap = class(TBitmap)
  private
    FLossless: Boolean;
    FQuality: TJpeg2000QualityRange;
    FSaveWithMCT: Boolean;
  public
    constructor Create; override;

    procedure LoadFromStream(Stream: TStream); override;
    procedure SaveToStream(Stream: TStream); override;

    { If set to True bitmap is saved as lossless JPEG 2000, otherwise it
      uses lossy compression.}
    property LosslessCompression: Boolean read FLossless write FLossless;
    { Quality of lossy compression where 1 is "ugly image/small file" and
      100 is "max quality/large file".}
    property CompressionQuality: TJpeg2000QualityRange read FQuality write FQuality;
    { Optionally uses multi-component color transformation when saving images.
      (usually produces smaller compressed files. Only applicable for
      3 channel RGB images. Default value is True.}
    property SaveWithMCT: Boolean read FSaveWithMCT write FSaveWithMCT;
  end;

resourcestring
  SJpeg2000ImageFile = 'JPEG 2000 Image';

const
  Jpeg2000DefaultLosslessCompression = False;
  Jpeg2000DefaultLossyQuality = 80;
  Jpeg2000DefaultSaveWithMCT = True;

implementation

uses
  OpenJpeg;

type
  EJpeg2000Error = class(EInvalidGraphic);

  { Type Jpeg 2000 file (needed for OpenJPEG codec settings).}
  TJpeg2000FileType = (jtInvalid, jtJP2, jtJ2K, jtJPT);

  TChar8 = array[0..7] of AnsiChar;
  TChar4 = array[0..3] of AnsiChar;

const
  JP2Signature: TChar8 = #0#0#0#$0C#$6A#$50#$20#$20;
  J2KSignature: TChar4 = #$FF#$4F#$FF#$51;

function ClampToByte(Value: LongInt): LongInt;
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

function MulDiv(Number, Numerator, Denominator: Integer): Integer;
begin
  Result := Number * Numerator div Denominator;
end;

{ TJpeg2000Bitmap }

constructor TJpeg2000Bitmap.Create;
begin
  inherited Create;
  FLossless := Jpeg2000DefaultLosslessCompression;
  FQuality := Jpeg2000DefaultLossyQuality;
  FSaveWithMCT := Jpeg2000DefaultSaveWithMCT;
end;

procedure TJpeg2000Bitmap.LoadFromStream(Stream: TStream);
type
  TChannelInfo = record
    DestOffset: Integer;
    CompType: OPJ_COMPONENT_TYPE;
    MaxValue: Integer;
    Shift: Integer;
  end;
var
  Buffer: array of Byte;
  BufferLen: Integer;
  Channels: array of TChannelInfo;
  ChannelCount: Integer;
  I, BytesPerPixel: Integer;
  dinfo: popj_dinfo_t;
  parameters: opj_dparameters_t;
  cio: popj_cio_t;
  image: popj_image_t;

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

  procedure CreateGrayPalette;
  var
    I: Integer;
    LogPalette: TMaxLogPalette;
  begin
    FillChar(LogPalette, SizeOf(LogPalette), 0);
    LogPalette.palVersion := $300;
    LogPalette.palNumEntries := 256;
    for I := 0 to 255 do
    with LogPalette do
    begin
      palPalEntry[I].peRed :=   I;
      palPalEntry[I].peGreen := I;
      palPalEntry[I].peBlue :=  I;
    end;
    Self.Palette := CreatePalette(PLogPalette(@LogPalette)^);
  end;

  procedure ConvertYCCToRGB;
  var
    X, Y: Integer;
    Ptr: PByteArray;
    YY, Cb, Cr: Byte;
  begin
    for Y := 0 to Height - 1 do
    begin
      Ptr := ScanLine[Y];
      for X := 0 to Width - 1 do
      begin
        YY := Ptr[2];
        Cb := Ptr[1];
        Cr := Ptr[0];
        YCbCrToRGB(YY, Cb, Cr, Ptr[2], Ptr[1], Ptr[0]);
        Ptr := @Ptr[BytesPerPixel];
      end;
    end;
  end;  

  procedure ReadChannel(const Info: TChannelInfo; const Comp: opj_image_comp;  BytesPerPixel: Integer);
  var
    X, Y, SX, SY: Integer;
    DestPtr, NewPtr, LineUpPtr: PByte;
  begin
    if (Comp.dx = 1) and (Comp.dy = 1) then
    begin
      // X and Y sample separation is 1 so just need to assign component values
      // to image pixels one by one
      for Y := 0 to Height - 1 do
      begin
        DestPtr := @PByteArray(ScanLine[Y])[Info.DestOffset];
        for X := 0 to Width - 1 do
        begin
          if Comp.prec = 8 then
            DestPtr^ := Comp.data[Y * Width + X] + Info.Shift
          else
            DestPtr^ := MulDiv(Comp.data[Y * Width + X] + Info.Shift, 255, Info.MaxValue);
          Inc(DestPtr, BytesPerPixel);
        end;
      end;
    end
    else
    begin
      // Sample separation is active - component is sub-sampled. Real component
      // dimensions are [Comp.w * Comp.dx, Comp.h * Comp.dy]
      for Y := 0 to Comp.h - 1 do
      begin
        DestPtr := @PByteArray(ScanLine[Y * Comp.dy])[Info.DestOffset];

        for X := 0 to Comp.w - 1 do
        begin
          if Comp.prec = 8 then
            DestPtr^ := Comp.data[Y * Comp.w + X] + Info.Shift
          else
            DestPtr^ := MulDiv(Comp.data[Y * Comp.w + X] + Info.Shift, 255, Info.MaxValue);
          NewPtr := DestPtr;

          for SX := 1 to Comp.dx - 1 do
          begin
            if X * Comp.dx + SX >= Width then Break;          
            // Replicate pixels on line
            Inc(NewPtr, BytesPerPixel);
            NewPtr^ := DestPtr^;
          end;

          Inc(DestPtr, BytesPerPixel * Comp.dx);
        end;

        for SY := 1 to Comp.dy - 1 do
        begin
          if Y * Comp.dy + SY >= Height then Break;
          // Replicate lines
          LineUpPtr := @PByteArray(ScanLine[Y * Comp.dy])[Info.DestOffset];
          NewPtr := @PByteArray(ScanLine[Y * Comp.dy + SY])[Info.DestOffset];
          for X := 0 to Width - 1 do
          begin
            NewPtr^ := LineUpPtr^;
            Inc(NewPtr, BytesPerPixel);
            Inc(LineUpPtr, BytesPerPixel);
          end;
        end;
      end;
    end;
  end;

begin
  opj_set_default_decoder_parameters(@parameters);
  // Determine which codec to use
  case GetFileType of
    jtJP2: dinfo := opj_create_decompress(CODEC_JP2);
    jtJ2K: dinfo := opj_create_decompress(CODEC_J2K);
  else
    raise EJpeg2000Error.Create('Unknown JPEG 2000 file type');
  end;
  // Set event manager to nil to avoid getting messages
  dinfo.event_mgr := nil;
  // Currently OpenJPEG can load images only from memory so we have to
  // preload whole input to mem buffer. Not good but no other way now.
  // At least we set stream pos to end of JP2 data after loading (we will now
  // the exact size by then).
  BufferLen := Stream.Size - Stream.Position;
  SetLength(Buffer, BufferLen);
  Stream.ReadBuffer(Buffer[0], BufferLen);
  // Open OpenJPEG's io on buffer with image file
  cio := opj_cio_open(opj_common_ptr(dinfo), @Buffer[0], BufferLen);
  opj_setup_decoder(dinfo, @parameters);

  try
    // Decode image
    image := opj_decode(dinfo, cio);
    if image = nil then
      raise EJpeg2000Error.Create('JPEG 2000 image decoding failed');
  finally
    // Set the input position just after end of image
    Stream.Seek(-BufferLen + (Integer(cio.bp) - Integer(cio.start)), soFromCurrent);
    SetLength(Buffer, 0);
    opj_destroy_decompress(dinfo);
    opj_cio_close(cio);
  end;

  // Determine pixel format according to components
  ChannelCount := image.numcomps;
  case image.numcomps of
    3: PixelFormat := pf24bit;
    4: PixelFormat := pf32bit;
  else
    // 1, 2, or 5+ components: take just the first one and treat it like grayscale
    ChannelCount := 1;
    PixelFormat := pf8bit;
  end;

  // Fill some channel info needed for writing right data to right mem adresses
  SetLength(Channels, ChannelCount);
  for I := 0 to ChannelCount - 1 do
  begin
    // Get component type for this channel and based on this
    // determine where in bitmap write this channel's data
    Channels[I].CompType := image.comps[I].comp_type;
    case Channels[I].CompType of
      COMPTYPE_UNKNOWN:
        begin
          if ChannelCount <> 4 then
          begin
            // Missing CDEF box in file - usually BGR order
            Channels[I].DestOffset := image.numcomps - I - 1
          end
          else
          begin
            // Missing CDEF box in file - usually ABGR order
            if I = 3 then
              Channels[I].DestOffset := 3
            else
              Channels[I].DestOffset := image.numcomps - I - 2
          end;
        end;
      COMPTYPE_R:       Channels[I].DestOffset := 2;
      COMPTYPE_G:       Channels[I].DestOffset := 1;
      COMPTYPE_B:       Channels[I].DestOffset := 0;
      COMPTYPE_CB:      Channels[I].DestOffset := 1;
      COMPTYPE_CR:      Channels[I].DestOffset := 0;
      COMPTYPE_OPACITY: Channels[I].DestOffset := 3;
      COMPTYPE_Y:
        case image.color_space of
          CLRSPC_SYCC: Channels[I].DestOffset := 2; // Y is intensity part of YCC
          CLRSPC_GRAY: Channels[I].DestOffset := 0; // Y is independent gray channel
        end;
    end;
    // Signed componets must be scaled to [0, 1] interval (depends on precision)
    if image.comps[I].sgnd = 1 then
      Channels[I].Shift := 1 shl (image.comps[I].prec - 1);
    // TBitmap supports max 8 bits per channel, this is max value of
    // JPEG 2000 comp used later to get 8 bit value
    Channels[I].MaxValue := 1 shl image.comps[I].prec - 1;
  end;

  // Only 1 byte per channel data supported for TBitmap
  BytesPerPixel := ChannelCount;

  // Create grayscale palette for 8bit images - palette must be ready before
  // storing pixel data to bitmap!
  if PixelFormat = pf8bit then
    CreateGrayPalette;

  // Allocate image and write data for each channel
{$IF CompilerVersion >= 18.0}
  SetSize(image.x1 - image.x0, image.y1 - image.y0);
{$ELSE}
  Width := image.x1 - image.x0;
  Height := image.y1 - image.y0;
{$IFEND}
  try
    for I := 0 to ChannelCount - 1 do
      ReadChannel(Channels[I], image.comps[I], BytesPerPixel);
    // If we have YCC image we need to convert it to RGB
    if (image.color_space = CLRSPC_SYCC) and (ChannelCount in [3, 4]) then
      ConvertYCCToRGB;
  finally
    opj_image_destroy(image);
  end;

  // Delphi 2009 and newer support alpha transparency
{$IF CompilerVersion >= 20.0}
  if PixelFormat = pf32bit then
    AlphaFormat := afDefined;
{$IFEND}
end;

procedure TJpeg2000Bitmap.SaveToStream(Stream: TStream);
var
  WorkBmp: TBitmap;
  I, ChannelCount: Integer;
  image: popj_image_t;
  cio: popj_cio_t;
  cinfo: popj_cinfo_t;
  parameters: opj_cparameters_t;
  compparams: array[0..3] of opj_image_cmptparm_t;
  ChannelOffsets: array[0..3] of Byte;

  function GetComponentType(Comp: Integer): OPJ_COMPONENT_TYPE;
  begin
    // Store components in JP2 file in BGR order instead of RGB order of TBitmap.
    // This is not needed for decoders that parse CDEF properly but 
    // some don't and assume BGR order (like original OpenJpeg without CDEF patch)
    Assert(Comp in [0..3]);
    Result := COMPTYPE_UNKNOWN;  
    // Set channel offset in each source pixel in bytes, switch BGR<>RGB order  
    ChannelOffsets[Comp] := Comp;
    case Comp of
      0:
        begin
          Result := COMPTYPE_R;
          ChannelOffsets[Comp] := 2;
        end;
      1: Result := COMPTYPE_G;
      2: 
        begin
          Result := COMPTYPE_B;
          ChannelOffsets[Comp] := 0;
        end;
      3: Result := COMPTYPE_OPACITY;
    end;
  end;

  procedure SetCompParams;
  var
    Rate, TargetSize: Single;
    NumDataItems: Integer; 
  begin
    parameters.cod_format := 1;
    parameters.numresolution := 6;
    parameters.tcp_numlayers := 1;
    parameters.cp_disto_alloc := 1;
    // Use MCT (multi-color component transform) RGB->YCbCr, OpenJpeg uses it only for 3 channel images though
    parameters.tcp_mct := Ord(FSaveWithMCT);

    if FLossless then
    begin
      // Set rate to 0 -> lossless
      parameters.tcp_rates[0] := 0;
    end
    else
    begin
      // Use irreversible DWT
      parameters.irreversible := 1;
      // Quality -> Rate computation taken from ImageMagick
      Rate := 100.0 / Sqr(115 - FQuality);
      NumDataItems := Width * Height * ChannelCount;
      TargetSize := (NumDataItems * Rate) + 550 + (ChannelCount - 1) * 142;
      parameters.tcp_rates[0] := 1.0 / (TargetSize / NumDataItems);
    end;
  end;

  procedure WriteChannel(SrcOffset: Integer; const Comp: opj_image_comp; BytesPerPixel: Integer);
  var
    Y, X: Integer;
    SrcPtr: PByte;
  begin
    for Y := 0 to Height - 1 do
    begin
      SrcPtr := @PByteArray(WorkBmp.ScanLine[Y])[SrcOffset];
      for X := 0 to Width - 1 do
      begin
        Comp.data[Y * Width + X] := SrcPtr^;
        Inc(SrcPtr, BytesPerPixel);
      end; 
    end;   
  end;
  
begin
  // Saving only supports 24 and 32bit bitmaps, OpenJpeg doesn't 
  // handle palettized images yet. For incompatible pixel formats
  // temp working bitmap is created.
  if not (PixelFormat in [pf24bit, pf32bit]) then
  begin
    WorkBmp := TBitmap.Create;
    WorkBmp.Assign(Self);
    WorkBmp.PixelFormat := pf24bit;
  end
  else
    WorkBmp := Self;

  // Fill component parameters array  
  if WorkBmp.PixelFormat = pf24bit then
    ChannelCount := 3
  else
    ChannelCount := 4;    

  for I := 0 to ChannelCount - 1 do
  with compparams[I] do
  begin
    dx := 1;
    dy := 1;
    w  := Width;
    h  := Height;
    bpp := 8;
    prec := 8;
    sgnd := 0;
    comp_type := GetComponentType(I);
    x0 := 0;
    y0 := 0;
  end;

  // Create OpenJpeg image struct from component params and use RGB color space
  image := opj_image_create(ChannelCount, @compparams[0], CLRSPC_SRGB);
  if image = nil then 
    raise EJpeg2000Error.Create('Failed to create JPEG 2000 image struct for saving');
  image.x1 := Width;
  image.y1 := Height;

  // Create JP2 compressor (save JP2 boxes + code stream)
  cinfo := opj_create_compress(CODEC_JP2);
  // Set event manager to nil to avoid getting messages
  cinfo.event_mgr := nil;  
  // Set various sompression params and then setup encoder
  opj_set_default_encoder_parameters(@parameters);
  SetCompParams;
  opj_setup_encoder(cinfo, @parameters, image);
  // Open OpenJPEG output
  cio := opj_cio_open(opj_common_ptr(cinfo), nil, 0);
  
  try
    // Write channels one by one
    for I := 0 to ChannelCount - 1 do
      WriteChannel(ChannelOffsets[I], image.comps[I], ChannelCount);
    // Try to encode the image
    if not opj_encode(cinfo, cio, image, nil) then
      raise EJpeg2000Error.Create('JPEG 2000 image encoding failed');;
    // Finally write buffer with encoded image to output
    Stream.WriteBuffer(cio.buffer^, cio_tell(cio));  
  finally
    opj_image_destroy(image);
    opj_destroy_compress(cinfo);
    opj_cio_close(cio);
    if WorkBmp <> Self then
      WorkBmp.Free;
  end;
end;

initialization
  TPicture.RegisterFileFormat('jp2', SJpeg2000ImageFile, TJpeg2000Bitmap);
  TPicture.RegisterFileFormat('j2k', SJpeg2000ImageFile, TJpeg2000Bitmap);
  TPicture.RegisterFileFormat('jpc', SJpeg2000ImageFile, TJpeg2000Bitmap);
finalization
  TPicture.UnregisterGraphicClass(TJpeg2000Bitmap);

{
  File Notes:

  -- 1.10 (2009-??-??) Changes/Bug Fixes -----------------------------------
    - Optional MCT (multi-component transform) = RGB->YCbCr transform,
      usually produces smaller files (only appliable for 3 channel RGB images).
      Controlled by SaveWithMCT property.
    - Uses ireversible DWT in lossless mode.
    - Fixed bug in reconstruction of subsamled files (Y was effectively treated
      as subsampled too).
    - Changed order of alpha channel in 4-component JP2 files without CDEF box
      to properly load these.
    - SJpeg2000ImageFile is now resourcestring.

  -- 1.00 (2009-06-07) Changes/Bug Fixes -----------------------------------
    - Initial version of TJpeg2000Bitmap.
}

end.
