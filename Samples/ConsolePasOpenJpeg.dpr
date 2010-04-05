{
  PasJpeg2000 Console OpenJpeg Header Demo
  http://code.google.com/p/pasjpeg2000
}
{
  Console application demonstrating how to use OpenJpeg
  header translation to load and save JPEG 2000 image.
  Image file name is passed as command line parameter,
  image is loaded, some info about it is displayed, and
  finally it is saved to another file.

  Tested in Delphi 7, Delphi 2009, and FPC 2.2.2
  Tested in Windows, Fedora x64, Mandriva, and Mac OS X 10.5

}
program ConsolePasOpenJpeg;

{$APPTYPE CONSOLE}

{$IFDEF FPC}
  {$MODE DELPHI}
{$ENDIF}

uses
  SysUtils,
  Classes,
  OpenJpeg;

type
  { Type Jpeg 2000 file (needed for OpenJPEG codec settings).}
  TJpeg2000FileType = (jtInvalid, jtJP2, jtJ2K, jtJPT);

  TChar8 = array[0..7] of AnsiChar;
  TChar4 = array[0..3] of AnsiChar;

const
  JP2Signature: TChar8 = #0#0#0#$0C#$6A#$50#$20#$20;
  J2KSignature: TChar4 = #$FF#$4F#$FF#$51;

  function LoadImage(const FileName: string): popj_image_t;
  var
    Stream: TStream;
    Buffer: Pointer;
    BufLen: Integer;
    dinfo: popj_dinfo_t;
    parameters: opj_dparameters_t;
    cio: popj_cio_t;

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

  begin
    Result := nil;

    Stream := TFileStream.Create(FileName, fmOpenRead);
    // Determine which codec to use
    case GetFileType of
      jtJP2: dinfo := opj_create_decompress(CODEC_JP2);
      jtJ2K: dinfo := opj_create_decompress(CODEC_J2K);
    else
      Exit;
    end;

    // Currently OpenJPEG can load images only from memory so we have to
    // preload whole input to mem buffer. Not good but no other way now.
    // At least we set stream pos to end of JP2 data after loading (we will now
    // the exact size by then).
    BufLen := Stream.Size;
    GetMem(Buffer, BufLen);
    try
      Stream.ReadBuffer(Buffer^, BufLen);
    finally
      Stream.Free;
    end;

    opj_set_default_decoder_parameters(@parameters);
    // Set event manager to nil to avoid getting messages
    dinfo.event_mgr := nil;
    // Open OpenJPEG's io on buffer with image file
    cio := opj_cio_open(opj_common_ptr(dinfo), Buffer, BufLen);
    opj_setup_decoder(dinfo, @parameters);

    try
      // Finally decode the file
      Result := opj_decode(dinfo, cio);
    finally
      opj_destroy_decompress(dinfo);
      opj_cio_close(cio);
      FreeMem(Buffer);
    end;
  end;

  function SaveImage(const image: popj_image_t; const FileName: string): Boolean;
  var
    Stream: TStream;
    cinfo: popj_cinfo_t;
    parameters: opj_cparameters_t;
    cio: popj_cio_t;

    procedure SetCompParams;
    begin
      parameters.cod_format := 1;
      parameters.numresolution := 6;
      parameters.tcp_numlayers := 1;
      parameters.cp_disto_alloc := 1;
      // Set rate to 0 -> lossless
      parameters.tcp_rates[0] := 0;
    end;

  begin
    Result := True;
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
      // Encode the image
      if not opj_encode(cinfo, cio, image, nil) then
      begin
        Result := False;
        Exit;
      end;
    finally
      opj_destroy_compress(cinfo);
    end;

    Stream := TFileStream.Create(FileName, fmCreate);
    try
      // Finally write buffer with encoded image to output
      Stream.WriteBuffer(cio.buffer^, cio_tell(cio));
    finally
      Stream.Free;
      opj_cio_close(cio);
    end;
  end;

  procedure PrintInfo(const image: popj_image_t);
  var
    ColorSpace, CompType: string;
    I: Integer;
  begin
    // Print out some info about image and its components
    WriteLn;
    WriteLn('[[ Image Info ]]');
    WriteLn('Dimensions: ', image.x1 - image.x0, 'x', image.y1 - image.y0);
    case image.color_space of
      CLRSPC_UNKNOWN: ColorSpace := 'Unknown/Not defined';
      CLRSPC_SRGB   : ColorSpace := 'RGB';
      CLRSPC_GRAY   : ColorSpace := 'Grayscale';
      CLRSPC_SYCC   : ColorSpace := 'YCbCr';
    end;
    WriteLn('Color space: ', ColorSpace);
    WriteLn('# of Components: ', image.numcomps);
    for I := 0 to image.numcomps - 1 do
    begin
      WriteLn('[ Component Info ]');
      WriteLn('  Dimensions: ', image.comps[I].w, 'x', image.comps[I].h);
      case image.comps[I].comp_type of
        COMPTYPE_UNKNOWN: CompType := 'Unknown/Not defined';
        COMPTYPE_R      : CompType := 'Red';
        COMPTYPE_G      : CompType := 'Green';
        COMPTYPE_B      : CompType := 'Blue';
        COMPTYPE_Y      : CompType := 'Intensity';
        COMPTYPE_CB     : CompType := 'Cb';
        COMPTYPE_CR     : CompType := 'Cr';
        COMPTYPE_OPACITY: CompType := 'Opacity';
      end;
      WriteLn('  Type: ', CompType);
      WriteLn('  Precision: ', image.comps[I].prec, ' bits');
      WriteLn('  Subsampling: ', image.comps[I].dx, 'x', image.comps[I].dy);
    end;
    WriteLn;
  end;

  procedure Terminate(Code: Integer = 0);
  begin
    WriteLn;
    WriteLn('Press ENTER to exit');
    ReadLn;
    Halt(Code);
  end;

var
  FileName: string;
  image: popj_image_t;

begin
{$IF Defined(DEBUG) and (CompilerVersion >= 18.0)}
  System.ReportMemoryLeaksOnShutdown := True;
{$IFEND}

  if ParamCount < 1 then
  begin
    WriteLn('No parameter found: provide path to JPEG 2000 image file');
    Terminate(1);
  end;

  FileName := ParamStr(1);
  if not FileExists(FileName) then
  begin
    WriteLn('Given file does not exist: ', FileName);
    Terminate(1);
  end;

  try
    // Load image from file
    image := LoadImage(FileName);

    if image = nil then
    begin
      WriteLn('Image decoding failed: ', FileName);
      Terminate(1);
    end
    else
      WriteLn('Image loaded successfully: ', FileName);

    // Print some info about image
    PrintInfo(image);

    // Save it again to another file
    try
      FileName := FileName + 'copy.jp2';
      if not SaveImage(image, FileName) then
      begin
        WriteLn('Image encoding failed: ', FileName);
        Terminate(1);
      end
      else
        WriteLn('Image saved successfully: ', FileName);
    finally
      opj_image_destroy(image);
    end;
  except
    on E:Exception do
      Writeln(E.Classname, ': ', E.Message);
  end;

  Terminate;
end.
