unit uform1;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, FileUtil, Forms, Controls, Graphics, Dialogs,
  StrUtils, Unix, BaseUnix,
  StdCtrls, uForm2, uForm4, BGRABitmap, BGRABitmapTypes, LCLINTF,
  GraphType, ComCtrls, ExtCtrls;

type

  { TForm1 }
  Tnode = class(TObject)
    nr: integer; //real node number;
    x, y: real; // node real-value coords;
    dens, prop, dev: real; //the three key properties
  end;

  TForm1 = class(TForm)
    procedure FormClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure FormMouseMove(Sender: TObject; Shift: TShiftState; X, Y: integer);
    procedure FormPaint(Sender: TObject);
  private
    { private declarations }
    AImage: TImage;
    currx, curry: integer;
    sz, x0, y0: longint;
    lsnr: byte;
    procedure resize_plot;
    procedure DrawBitmap;
    procedure CrossFire;
    //procedure DrawBitMap(x0,y0:longint);
  public
    { public declarations }
    closestNode: integer;
    nodelist: TFPList;
    fname: string;
    lmargin, rmargin, tmargin, bmargin, pixres, cf: integer;
    rx, ry: real;
    f2: TForm2;
    f4: TForm4;
    procedure getRGBA(const rgba: string);
    procedure getClosestNode;
  end;

var
  Form1: TForm1;

implementation

{$R *.lfm}

procedure TForm1.getClosestNode;
var
  i, best: integer;
  dmin, dd: real;
  node: TNode;

begin
  if nodelist = nil then
    writeln('No rgba data was input for landscape ', lsnr)
  else
  begin
    best := -1;
    dmin := 999999.99;
    for i := 0 to nodelist.Count - 1 do
    begin
      node := TNode(nodelist[i]);
      dd := sqr(node.x - rx) + sqr(node.y - ry);
      if dd < dmin then
      begin
        best := i;
        dmin := dd;
      end;
    end;
    node := TNode(nodelist[best]);
    if node.dens > 1e-5 then
      writeln('Closest node to current position is node ', node.nr,
        ' featuring in landscape #', lsnr, ' a density of ', FormatFloat(
        '0.00000', node.dens), ' and a propery value of ', FormatFloat(
        '0.000', node.prop), ' +/- ', FormatFloat('0.000', node.dev))
    else
      writeln('Closest node to current position is node ', node.nr,
        ' which is not populated in landscape #', lsnr);
  end;
  closestNode := node.nr;
  if f2 <> nil then
    f2.reportClosestNode(node.nr);
  if f4 <> nil then
    f4.reportClosestNode(node.nr);
end;


procedure TForm1.getRGBA(const rgba: string);
var
  sline: string;
  line: TStringList;
  err, sumerr: integer;
  ff: Text;
  node: TNode;
begin
  if FileExists(rgba) then
  begin
    writeln('Reading ', rgba);
    nodelist := TFPList.Create;
    if ExtractWord(wordCount(rgba, ['.']), rgba, ['.']) = 'gz' then
    begin
      //Work on a compressed file
      popen(ff, 'zcat ' + rgba, 'R');
    end
    else
    begin
      //Read plain file
      AssignFile(ff, rgba);
      reset(ff);
    end;
    while not EOF(ff) do
    begin
      readln(ff, sline);
      if AnsiContainsStr(sline, ' 1 ') then
        if ExtractWord(3, sline, [#32]) = '1' then
        begin
          line := TStringList.Create;
          line.Delimiter := ' ';
          line.DelimitedText := sline;
          node := Tnode.Create;
          val(line[0], node.x, err);
          val(line[1], node.y, err);
          val(line[3], node.nr, err);
          val(line[6], node.dens, err);
          val(line[7], node.prop, err);
          val(line[8], node.dev, err);
          nodelist.add(node);
          FreeAndNil(line);
          //writeln('Last node in pos ',nodelist.Count-1,' is ',TNode(nodelist[nodelist.Count-1]).nr);
        end;
    end;
    if ExtractWord(wordCount(rgba, ['.']), rgba, ['.']) = 'gz' then
      pclose(ff)
    else
      closeFile(ff);
  end;
end;



{ TForm1 }
procedure TForm1.CrossFire;
var
  cw: integer;
begin
  drawbitmap;
  Canvas.Brush.Style := bsSolid;
  cw := (cf * sz) div (2 * pixres);
  if cw < 4 then
    cw := 2;
  Canvas.Brush.Color := clYellow;
  Canvas.Rectangle(currx - 11 * cw, curry - 2 * cw, currx + 11 * cw, curry + 2 * cw);
  Canvas.Rectangle(currx - 2 * cw, curry - 11 * cw, currx + 2 * cw, curry + 11 * cw);
  Canvas.Brush.Color := clBlack;
  Canvas.Rectangle(currx - 10 * cw, curry - cw, currx + 10 * cw, curry + cw);
  Canvas.Rectangle(currx - cw, curry - 10 * cw, currx + cw, curry + 10 * cw);
  getClosestNode;
end;


procedure TForm1.FormClick(Sender: TObject);
var
  cl, cr: real;
begin
  cl := x0 + lmargin * sz / pixres;
  cr := (pixres - rmargin - lmargin) / pixres * sz;
  rx := 2 * (currx - cl) / cr - 1;
  cl := y0 + tmargin * sz / pixres;
  cr := (pixres - tmargin - bmargin) / pixres * sz;
  ry := -2 * (curry - cl) / cr + 1;
  {writeln('Mouse is at ', currx, ' ', curry, ' -> ', FormatFloat('0.0000', rx),
    FormatFloat(' 0.0000', ry));      }
  CrossFire;
  if f2 <> nil then
    f2.CrossFire(rx, ry);
  if f4 <> nil then
    f4.CrossFire(rx, ry);
end;


procedure TForm1.FormCreate(Sender: TObject);
begin
  AImage := nil;
  f2 := nil;
  f4 := nil;
  nodelist := nil;
  lsnr := 1;
  cf := 20; //default CrossFire width
end;

procedure TForm1.FormDestroy(Sender: TObject);
begin
  AImage.Free;
  Close;
end;

procedure TForm1.FormMouseMove(Sender: TObject; Shift: TShiftState; X, Y: integer);
begin
  currx := x;
  curry := y;
end;

procedure TForm1.FormPaint(Sender: TObject);
begin
  if (Aimage = nil) and FileExists(fname) then
  begin
    AImage := TImage.Create(Self);
    AImage.Picture.LoadFromFile(fname);
    writeln(fname, ' was input');
  end
  else if AImage = nil then
  begin
    writeln('No image loaded yet');
    exit;
  end;
  resize_plot;
end;

procedure TForm1.DrawBitmap;
var
  bmpBGRA: TBGRABitmap;
begin
  Canvas.Brush.Style := bsSolid;
  Canvas.Brush.Color := Color;
  Canvas.Rectangle(0, 0, ClientWidth, ClientHeight);
  bmpBGRA := TBGRABitmap.Create(AImage.Picture.bitmap); // original image
  bmpBGRA.ResampleFilter := rfBestQuality;
  BGRAReplace(bmpBGRA, bmpBGRA.Resample(sz, sz, rmFineResample) as TBGRABitmap);
  bmpBGRA.Draw(Canvas, x0, y0, False);  // Use false for transparency
  FreeAndNil(bmpBGRA);
end;



procedure TForm1.resize_plot;

begin
  x0 := 0;
  y0 := 0;
  if ClientHeight > ClientWidth then
  begin
    sz := ClientWidth;
    y0 := (ClientHeight - sz) div 2;
  end
  else
  begin
    sz := ClientHeight;
    x0 := (ClientWidth - sz) div 2;
  end;
  drawbitmap;
  //writeln('Resized to ', ClientWidth, '-', ClientHeight);
end;

end.
