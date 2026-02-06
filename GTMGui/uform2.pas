unit uform2;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, FileUtil, Forms, Controls, Graphics, Dialogs,
  StrUtils, Unix, BaseUnix,
  StdCtrls, BGRABitmap, BGRABitmapTypes, LCLINTF, GraphType, ComCtrls, ExtCtrls;

type

  Tnode = class(TObject)
    nr: integer; //real node number;
    x, y: real; // node real-value coords;
    dens, prop, dev: real; //the three key properties
  end;

  { Tform2 }

  Tform2 = class(TForm)
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure FormPaint(Sender: TObject);
  private
    { private declarations }
    AImage: TImage;
    sz, x0, y0: longint;
    lsnr: byte;
    procedure resize_plot;
    procedure DrawBitMap;
  public
    { public declarations }
    nodelist: TFPList;
    fname: string;
    lmargin, rmargin, tmargin, bmargin, pixres, cf: integer;
    procedure CrossFire(rx, ry: real);
    procedure getRGBA(const rgba: string);
    procedure reportClosestNode(n: integer);
  end;

var
  form2: Tform2;

implementation

{$R *.lfm}

{ Tform2 }

procedure TForm2.getRGBA(const rgba: string);
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
          //val(line[0], node.x, err);
          //val(line[1], node.y, err);
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


procedure Tform2.FormCreate(Sender: TObject);
begin
  AImage := nil;
  cf := 20;
  nodelist := nil;
  lsnr := 2;
end;

procedure Tform2.FormDestroy(Sender: TObject);
begin
  AImage.Free;
  Close;
end;

procedure Tform2.FormPaint(Sender: TObject);
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

procedure TForm2.reportClosestNode(n: integer);
var
  i: integer;
  node: TNode;

begin
  if nodelist = nil then
    writeln('No rgba data was input for landscape ', lsnr)
  else
  begin
    i := -1;
    repeat
      Inc(i);
      node := TNode(nodelist[i]);
    until node.nr = n;
    if node.dens > 1e-5 then
      writeln('In landscape #', lsnr, ' node ', node.nr, ' has a density of ',
        FormatFloat('0.00000', node.dens), ' and a propery value of ',
        FormatFloat('0.000', node.prop), ' +/- ', FormatFloat('0.000', node.dev))
    else
      writeln('Node ', node.nr, ' is not populated in landscape #', lsnr);
  end;
end;


procedure TForm2.DrawBitmap;
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

procedure TForm2.CrossFire(rx, ry: real);
var
  cw, currx, curry: integer;
  cl, cr: real;

begin
  cl := x0 + lmargin * sz / pixres;
  cr := (pixres - rmargin - lmargin) / pixres * sz;
  currx := round((rx + 1) * cr / 2 + cl);
  cl := y0 + tmargin * sz / pixres;
  cr := (pixres - tmargin - bmargin) / pixres * sz;
  curry := round((1 - ry) * cr / 2 + cl);
  //writeln('In frame 2, Mouse is at ', currx, ' ', curry,
  //  ' -> ', FormatFloat('0.0000', rx), FormatFloat(' 0.0000', ry));
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
end;


procedure TForm2.resize_plot;

begin
  x0 := 0;
  y0 := 0;
  if Height > Width then
  begin
    sz := Width;
    y0 := (Height - sz) div 2;
  end
  else
  begin
    sz := Height;
    x0 := (Width - sz) div 2;
  end;

  drawbitmap;

  //writeln('Resized to ', Width, '-', Height);
end;

end.
