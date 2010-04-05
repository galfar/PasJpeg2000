object MainForm: TMainForm
  Left = 1028
  Top = 272
  Caption = 'PasJpeg2000 VLC Sample'
  ClientHeight = 730
  ClientWidth = 695
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'Tahoma'
  Font.Style = []
  OldCreateOrder = False
  Position = poScreenCenter
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  DesignSize = (
    695
    730)
  PixelsPerInch = 96
  TextHeight = 13
  object Image: TImage
    Left = 0
    Top = 184
    Width = 697
    Height = 547
    Anchors = [akLeft, akTop, akRight, akBottom]
    Center = True
    Proportional = True
    Stretch = True
  end
  object Label1: TLabel
    Left = 24
    Top = 125
    Width = 66
    Height = 13
    Caption = 'Lossy quality:'
  end
  object Label2: TLabel
    Left = 24
    Top = 152
    Width = 215
    Height = 13
    Caption = 'Quality 1..100 (100 = nicer image/larger file)'
  end
  object BtnOpenJP2: TButton
    Left = 24
    Top = 16
    Width = 185
    Height = 25
    Caption = 'Open JPEG 2000 image'
    TabOrder = 0
    OnClick = BtnOpenJP2Click
  end
  object BtnSaveJP2: TButton
    Left = 24
    Top = 47
    Width = 185
    Height = 25
    Caption = 'Save as JPEG 2000 image'
    TabOrder = 1
    OnClick = BtnSaveJP2Click
  end
  object BtnOpenGr: TButton
    Left = 312
    Top = 16
    Width = 185
    Height = 25
    Caption = 'Open any VCL supported image'
    TabOrder = 2
    OnClick = BtnOpenGrClick
  end
  object BtnSaveGr: TButton
    Left = 312
    Top = 47
    Width = 185
    Height = 25
    Caption = 'Save as any VCL supported image'
    TabOrder = 3
    OnClick = BtnSaveGrClick
  end
  object CheckLossless: TCheckBox
    Left = 24
    Top = 78
    Width = 153
    Height = 17
    Caption = 'Lossless compression'
    TabOrder = 4
  end
  object TrackQuality: TTrackBar
    Left = 88
    Top = 119
    Width = 129
    Height = 27
    Hint = 'Quality 1..100 (100 = nicer image/larger file)'
    LineSize = 5
    Max = 100
    Min = 1
    ParentShowHint = False
    PageSize = 5
    Frequency = 20
    Position = 80
    PositionToolTip = ptRight
    ShowHint = False
    TabOrder = 5
  end
  object CheckMCT: TCheckBox
    Left = 24
    Top = 96
    Width = 215
    Height = 17
    Caption = 'Save with MCT (when applicable)'
    Checked = True
    State = cbChecked
    TabOrder = 6
  end
  object OpenDialog: TOpenDialog
    Filter = 'JPEG 2000 Images (*.jp2, *.j2k, *.jpc)|*.jp2;*.j2k;*.jpc'
    Left = 160
    Top = 320
  end
  object OpenPictureDialog: TOpenPictureDialog
    Left = 160
    Top = 416
  end
  object SavePictureDialog: TSavePictureDialog
    Left = 392
    Top = 408
  end
  object SaveDialog: TSaveDialog
    DefaultExt = 'jp2'
    Filter = 'JPEG 2000 Images (*.jp2)|*.jp2'
    Left = 384
    Top = 304
  end
end
