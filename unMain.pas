unit unMain;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, Contnrs, StdCtrls, jpeg, ExtCtrls, GR32, Vcl.Samples.Spin,
  Vcl.ComCtrls;

type
  // Brightness (0..255) -> ASCII character
  TAsciiPalette = array[byte] of char;
  PAsciiPalette = ^TAsciiPalette;

  TAsciiConverterThread = class(TThread)
  private
    FPalette: PAsciiPalette;
    FPtrSource: PColor32;
    FPtrTarget: PChar;
    FRowCount, FRowLength: integer;
  protected
    procedure Execute; override;
  public
    constructor Create(PtrSource: PColor32; PtrTarget: PChar; RowCount, RowLength: integer;
      Palette: PAsciiPalette);
  end;

  TAsciiConverter = class
  private
    FThreadCount: integer;
    FText: string;
    FBitmap32: TBitmap32;
    FPalette: TAsciiPalette;
    procedure SetBitmap(const Value: TBitmap);
    procedure Process;
  public
    property ThreadCount: integer read FThreadCount write FThreadCount;
    property Bitmap: TBitmap write SetBitmap;
    property Palette: TAsciiPalette read FPalette write FPalette;
    property Text: string read FText;

    constructor Create;
  end;

  TForm1 = class(TForm)
    Panel1: TPanel;
    Button1: TButton;
    Button2: TButton;
    ScrollBar1: TScrollBar;
    Button3: TButton;
    OpenDialog1: TOpenDialog;
    Label1: TLabel;
    SpinEdit1: TSpinEdit;
    ScrollBar2: TScrollBar;
    Label2: TLabel;
    Label3: TLabel;
    ScrollBar3: TScrollBar;
    Label4: TLabel;
    ScrollBox1: TScrollBox;
    Image1: TImage;
    FontDialog1: TFontDialog;
    Button4: TButton;
    StatusBar1: TStatusBar;
    RadioButton1: TRadioButton;
    RadioButton2: TRadioButton;
    Bevel1: TBevel;
    CheckBox1: TCheckBox;
    Label5: TLabel;
    ScrollBar4: TScrollBar;
    ScrollBar5: TScrollBar;
    Label6: TLabel;
    Label7: TLabel;
    Memo1: TMemo;
    procedure FormCreate(Sender: TObject);
    procedure Button2Click(Sender: TObject);
    procedure Button1Click(Sender: TObject);
    procedure ScrollBar1Change(Sender: TObject);
    procedure Button3Click(Sender: TObject);
    procedure ScrollBar2Change(Sender: TObject);
    procedure Button4Click(Sender: TObject);
    procedure RadioButton1Click(Sender: TObject);
    procedure RadioButton2Click(Sender: TObject);
    procedure CheckBox1Click(Sender: TObject);
  private
    { Private-Deklarationen }
  public
    { Public-Deklarationen }
    FPalette: TAsciiPalette;
    FBitmap: TBitmap32;
    FAsciiCreator: TAsciiConverter;

    procedure PrintText(s: string);
  end;

var
  Form1: TForm1;

// Just some values for testing purposes:
const
  Chars: array[0..15] of Char =
    (' ', '.', ',', '-', '^', '³', '+', ';', '/', '>', 'C', 'T', '8', '&', '$', '#');

implementation

{$R *.dfm}

{ TAsciiCreator }

constructor TAsciiConverterThread.Create(PtrSource: PColor32; PtrTarget: PChar;
  RowCount, RowLength: integer; Palette: PAsciiPalette);
begin
  inherited Create(True);
  FPtrSource := PtrSource;
  FPtrTarget := PtrTarget;
  FRowCount := RowCount;
  FRowLength := RowLength;
  FPalette := Palette;
end;

procedure TAsciiConverterThread.Execute;
var
  PtrEnd: PColor32;
  PtrSource: PColor32;
  PtrTarget: PChar;
  G: Byte;
  i: Integer;
begin
  PtrSource := FPtrSource;
  PtrTarget := FPtrTarget;
  for i := 0 to FRowCount - 1 do
  begin
    PtrEnd := PColor32(cardinal(PtrSource)+FRowLength*SizeOf(TColor32));
    while cardinal(PtrSource) < cardinal(PtrEnd) do
    begin
      // Calculate brightness
      G := ((PtrSource^ and $000000FF) +
            ((PtrSource^ and $0000FF00) shr 8) +
            ((PtrSource^ and $00FF0000) shr 16)) div 3;
      // Output ASCII character
      PtrTarget^ := FPalette^[G];
      inc(PtrSource);
      inc(PtrTarget);
    end;
    // Add line break
    PtrTarget^ := #13;
    inc(PtrTarget);
    PtrTarget^ := #10;
    inc(PtrTarget);
  end;

end;

{ TAsciiCreator }

constructor TAsciiConverter.Create;
begin
  FBitmap32 := TBitmap32.Create;
end;

procedure TAsciiConverter.Process;
var
  TmpThread: TAsciiConverterThread;
  HandleArray: array of THandle;
  ThreadArray: array of TAsciiConverterThread;
  i: Integer;
begin
  SetLength(FText, (FBitmap32.Width+2)*FBitmap32.Height);
  SetLength(HandleArray, ThreadCount);
  SetLength(ThreadArray, ThreadCount);
  // Create workerthreads
  for i := 0 to ThreadCount - 1 do
  begin
    TmpThread := TAsciiConverterThread.Create(
        // pointer to first pixel of row
        FBitmap32.PixelPtr[0, (FBitmap32.Height div ThreadCount)*i],
        // pointer to corresponding text character
        PChar(Cardinal(@FText[1])+
          (FBitmap32.Height div ThreadCount)*i*(FBitmap32.Width+2)*SizeOf(Char)),
        // row count
        (FBitmap32.Height - (FBitmap32.Height div ThreadCount)*i),
        // row length
        FBitmap32.Width,
        // pointer to character palette
        @FPalette);
    HandleArray[i] := TmpThread.Handle;
    ThreadArray[i] := TmpThread;
    TmpThread.FreeOnTerminate := True;
  end;
  // Start...
  for i := 0 to ThreadCount - 1 do
    ThreadArray[i].Resume;
  WaitForMultipleObjects(ThreadCount, @HandleArray[0], True, INFINITE);
end;

procedure TAsciiConverter.SetBitmap(const Value: TBitmap);
begin
  FBitmap32.Assign(Value);
  Process;
end;

procedure TForm1.Button1Click(Sender: TObject);
begin
  Memo1.Clear;
  Memo1.Visible := true;
  Form1.Repaint;
  FAsciiCreator.Bitmap := Image1.Picture.Bitmap;

  Memo1.Text := FAsciiCreator.Text;

  PrintText(FAsciiCreator.Text);
  Form1.Update;
end;

procedure TForm1.Button2Click(Sender: TObject);
var
  i: integer;
  Bmp: TBitmap;
  a: double;
begin
  Memo1.Visible := false;
  Form1.Repaint;
  Form1.Update;

  Bmp := TBitmap.Create;
  try
    Bmp.SetSize(ScrollBar3.Position, ScrollBar3.Position);
    for i := 0 to SpinEdit1.Value do
    begin
      // Draw stupid rotating line
      Bmp.Canvas.FillRect(rect(0,0, ScrollBar3.Position, ScrollBar3.Position));
      Bmp.Canvas.MoveTo(ScrollBar3.Position div 2,ScrollBar3.Position div 2);
      a := 2*pi/ 1000 * getTickCount;
      Bmp.Canvas.LineTo(round(ScrollBar3.Position div 2 +
                             cos(a) * (ScrollBar3.Position div 2)),
                             round( (ScrollBar3.Position div 2) +
                             sin(a) * (ScrollBar3.Position div 2)));

      bmp.Canvas.TextOut( ScrollBar4.Position, ScrollBar5.Position,IntToStr(i));

      // Convert to ASCII
      FAsciiCreator.Bitmap := Bmp;

      // Print
      PrintText(FAsciiCreator.Text);
      sleep(10);
    end;
  finally
    Bmp.Free;
  end;
end;

procedure TForm1.Button3Click(Sender: TObject);
begin
  if OpenDialog1.Execute then
  Image1.Picture.Bitmap.LoadFromFile(OpenDialog1.FileName);
end;

procedure TForm1.Button4Click(Sender: TObject);
begin
  if FontDialog1.Execute then begin
  StatusBar1.Panels[1].Text := FontDialog1.Font.Name;
  StatusBar1.Panels[3].Text := IntToStr(FontDialog1.Font.Size);
  end;

end;

procedure TForm1.CheckBox1Click(Sender: TObject);
begin
  if CheckBox1.Checked = true then begin
    StatusBar1.Panels[6].Text := 'Bold';
    end else begin
    StatusBar1.Panels[6].Text := 'Normal';
    end;
end;

procedure TForm1.FormCreate(Sender: TObject);
var
  i: Integer;
  j: Integer;
begin
  Form1.DoubleBuffered := true;
  FAsciiCreator := TAsciiConverter.Create;
  
  // initialize ASCII palette:
  for i := 0 to 16 - 1 do
  begin
    for j := 0 to 16 - 1 do
      FPalette[i*16+j] := Chars[i];
  end;
  
  FAsciiCreator.Palette := FPalette;
  FAsciiCreator.ThreadCount := 4;

  FontDialog1.Font.Name := 'Terminal';
  FontDialog1.Font.Size := 11;
  FontDialog1.Font.Color := clSilver;
  Memo1.Font.Name := 'Terminal';
  Memo1.Font.Size := 5;
end;

procedure TForm1.PrintText(s: string);
var
  StringList: TStringlist;
  i: integer;

  Picture : TPicture;
  bmp : TBitmap;

begin
  StringList := TStringlist.Create;
  StringList.Text := s;
  for i := 0 to StringList.Count - 1 do begin

    if RadioButton1.Checked = true then begin
    Canvas.Brush.Style := bsSolid;
    Canvas.Brush.Color := clGray;
    StatusBar1.Panels[5].Text := 'Solid';
    end;

    if RadioButton2.Checked = true then begin
    Canvas.Brush.Style := bsClear;
    StatusBar1.Panels[5].Text := 'Clear';
    end;


    Canvas.Font.Size := FontDialog1.Font.Size;
    Canvas.Font.Name := FontDialog1.Font.Name;
    Canvas.Font.Color := FontDialog1.Font.Color;

    if CheckBox1.Checked = true then begin
    Canvas.Font.Style := [fsBold];
    end else begin
    Canvas.Font.Style := [];
    end;


    Canvas.TextOut(ScrollBar1.Position, i * ScrollBar2.Position , StringList[i]);

  end;


  StringList.Free;
end;

procedure TForm1.RadioButton1Click(Sender: TObject);
begin
  if RadioButton1.Checked = true then
    StatusBar1.Panels[5].Text := 'Solid';
end;

procedure TForm1.RadioButton2Click(Sender: TObject);
begin
  if RadioButton2.Checked = true then
    StatusBar1.Panels[5].Text := 'Clear';
end;

procedure TForm1.ScrollBar1Change(Sender: TObject);
begin
  Button1.Click;
  Application.ProcessMessages;
end;

procedure TForm1.ScrollBar2Change(Sender: TObject);
begin
   Button1.Click;
  Application.ProcessMessages;
end;

end.
