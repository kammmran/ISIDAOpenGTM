unit pilotform;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, FileUtil, Forms, Controls, Graphics, Dialogs, ComCtrls, LCLType,
  ExtDlgs, StdCtrls, uform1, uform2, uform4, intlist, Strutils, Unix, BaseUnix;

type

  { TForm3 }

  TForm3 = class(TForm)
    Button1: TButton;
    Button2: TButton;
    Button3: TButton;
    Edit1: TEdit;
    Edit2: TEdit;
    Edit3: TEdit;
    Edit4: TEdit;
    Label1: TLabel;
    Label2: TLabel;
    SelectFile: TOpenDialog;
    SelectRGBA: TOpenDialog;
    OpenLandscape: TButton;
    SelectLandscape: TOpenPictureDialog;
    procedure Button1Click(Sender: TObject);
    procedure Button2Click(Sender: TObject);
    procedure Button3Click(Sender: TObject);
    procedure Edit3Change(Sender: TObject);
    procedure Edit4EditingDone(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure OpenLandscapeClick(Sender: TObject);
  private
    { private declarations }
    resp: array of array of integer;
    topresp: array of integer;
    nnodes, ncomp: integer;
    f1: TForm1;
    f2: TForm2;
    f4: TForm4;
    smiles: TStringList;
    assnode: TFPList;
    threshold, minthreshold: real;
    maxshow: integer;
    procedure readResp;
    procedure pickItems;
  public
    { public declarations }
  end;

var
  Form3: TForm3;

implementation

{$R *.lfm}

{ TForm3 }



procedure TForm3.OpenLandscapeClick(Sender: TObject);
begin
  if f1 = nil then
  begin
    f1 := TForm1.Create(nil);
    f1.lmargin := 24;
    // by default, the map pngs have a 8-px margin around the actual square
    f1.rmargin := 30;
    // by default, the map pngs have a 8-px margin around the actual square
    f1.tmargin := 21;
    // by default, the map pngs have a 8-px margin around the actual square
    f1.bmargin := 21;
    // by default, the map pngs have a 8-px margin around the actual square
    f1.pixres := 2000; // by default, the png is 2000 x 2000 in pixels
    if SelectLandscape.Execute then
      f1.fname := SelectLandscape.FileName;
    if FileExists(ChangeFileExt(f1.fname, '.rgba')) then
      f1.getRGBA(ChangeFileExt(f1.fname, '.rgba'))
    else if FileExists(ChangeFileExt(f1.fname, '.rgba.gz')) then
      f1.getRGBA(ChangeFileExt(f1.fname, '.rgba.gz'))
    else if SelectRGBA.Execute then
      f1.getRGBA(SelectRGBA.FileName);
    nnodes := f1.nodelist.Count;
    ncomp := 0;
    f1.Show;
  end
  else if f2 = nil then
  begin
    f2 := TForm2.Create(nil);
    f2.lmargin := 24;
    // by default, the map pngs have a 8-px margin around the actual square
    f2.rmargin := 30;
    // by default, the map pngs have a 8-px margin around the actual square
    f2.tmargin := 21;
    // by default, the map pngs have a 8-px margin around the actual square
    f2.bmargin := 21;
    // by default, the map pngs have a 8-px margin around the actual square
    f2.pixres := 2000; // by default, the png is 2000 x 2000 in pixels
    f1.f2 := f2;       // send the pointer to f2 to object f1, the leader - it will be
    if SelectLandscape.Execute then
      f2.fname := SelectLandscape.FileName;
    if FileExists(ChangeFileExt(f2.fname, '.rgba')) then
      f2.getRGBA(ChangeFileExt(f2.fname, '.rgba'))
    else if FileExists(ChangeFileExt(f2.fname, '.rgba.gz')) then
      f2.getRGBA(ChangeFileExt(f2.fname, '.rgba.gz'))
    else if SelectRGBA.Execute then
      f2.getRGBA(SelectRGBA.FileName);
    f2.Show;
  end
  else if f4 = nil then
  begin
    f4 := TForm4.Create(nil);
    f4.lmargin := 24;
    // by default, the map pngs have a 8-px margin around the actual square
    f4.rmargin := 30;
    // by default, the map pngs have a 8-px margin around the actual square
    f4.tmargin := 21;
    // by default, the map pngs have a 8-px margin around the actual square
    f4.bmargin := 21;
    // by default, the map pngs have a 8-px margin around the actual square
    f4.pixres := 2000; // by default, the png is 2000 x 2000 in pixels
    f1.f4 := f4;       // send the pointer to f2 to object f1, the leader - it will be
    if SelectLandscape.Execute then
      f4.fname := SelectLandscape.FileName;
    if FileExists(ChangeFileExt(f4.fname, '.rgba')) then
      f4.getRGBA(ChangeFileExt(f4.fname, '.rgba'))
    else if FileExists(ChangeFileExt(f4.fname, '.rgba.gz')) then
      f4.getRGBA(ChangeFileExt(f4.fname, '.rgba.gz'))
    else if SelectRGBA.Execute then
      f4.getRGBA(SelectRGBA.FileName);
    f4.Show;
  end
  else
  begin
    Application.MessageBox('You have reached the maximum of supported landscapes',
      'Info', MB_ICONHAND);
  end;
end;




procedure TForm3.Button1Click(Sender: TObject);
var
  fname, line: string;
  ff: Text;
begin
  if SelectFile.Execute then
  begin
    fname := SelectFile.FileName;
    Edit1.Text := fname;
    FreeAndNil(smiles);
    smiles := TStringList.Create;
    assignFile(ff, fname);
    reset(ff);
    while not EOF(ff) do
    begin
      readln(ff, line);
      smiles.Add(line);
    end;
    CloseFile(ff);
    writeln('Read ', smiles.Count, ' entries from ', fname);
  end;
end;


procedure TForm3.Button2Click(Sender: TObject);
var
  fname: string;

begin
  if SelectFile.Execute then
  begin
    fname := SelectFile.FileName;
    Edit2.Text := fname;
    readResp;
    pickItems;
  end;
end;

procedure TForm3.Button3Click(Sender: TObject);
var
  showsmi: TIntList;
  nl: TIntList;
  i, old: integer;
  ff: Text;
begin
  if assnode.Count <> smiles.Count then
    Application.MessageBox('SMILES and RESPONSIBILITY files do not match',
      'FATAL', MB_ICONHAND)
  else
  begin
    showsmi := TIntList.Create;
    for i := 0 to assnode.Count - 1 do
    begin
      nl := TIntList(assnode[i]);
      if nl.Find(f1.closestNode) >= 0 then
        showsmi.add(i);
    end;
    writeln('Found ', showsmi.IntCount, ' residing in node ', f1.closestNode,
      ' with responsibilities above threshold');
    old := showsmi.IntCount;
    while showsmi.IntCount > maxshow do
    begin
      i := trunc(showsmi.IntCount * random());
      showsmi.Delete(i);
    end;
    if showsmi.IntCount < old then
      writeln('Randomly removed residents in order to limit display to ', maxshow);
    if showsmi.IntCount = 0 then
      Application.MessageBox('Sorry - no qualifying residents in node',
        'Bad Luck', MB_ICONHAND)
    else
    begin
      popen(ff, getEnvironmentVariable('CHEMINFO_BIN') + '/mview -', 'W');
      for i := 0 to showsmi.IntCount - 1 do
        writeln(ff, smiles[showsmi[i]],
          ' Resp=', FormatFloat('0.00', resp[showsmi[i]+1, f1.closestNode] / 1000.0));
      PClose(ff);
    end;
  end;
end;


procedure TForm3.Edit3Change(Sender: TObject);
var
  err: integer;
begin
  val(Edit3.Text, threshold, err);
  if (err < 0) or (threshold < minthreshold) then
    threshold := minthreshold;
  if threshold > 1.0 then
    threshold := 1.0;
  pickItems;
end;

procedure TForm3.Edit4EditingDone(Sender: TObject);
begin
  maxshow := StrToInt(Edit4.Text);
end;




procedure TForm3.readResp;
var
  fname, line: string;
  ff: Text;
  i, err, inode: integer;
  xline: TStringList;
  r: real;
begin
  fname := Edit2.Text;
  if FileExists(fname) then
  begin
    if ExtractWord(wordCount(fname, ['.']), fname, ['.']) = 'gz' then
    begin
      //Work on a compressed file
      popen(ff, 'zcat ' + fname, 'R');
    end
    else
    begin
      //Read plain file
      AssignFile(ff, fname);
      reset(ff);
    end;
    setlength(topresp, nnodes + 1);
    ncomp := 0;
    while not EOF(ff) do
    begin
      Inc(ncomp);
      setlength(resp, ncomp + 1, nnodes + 1);
      readln(ff, line);
      xline := TStringList.Create;
      xline.Delimiter := ' ';
      xline.DelimitedText := line;
      for i := 1 to xline.Count - 1 do
      begin
        r := 0;
        inode := StrToInt(ExtractWord(1, xline[i], [':']));
        val(ExtractWord(2, xline[i], [':']), r, err);
        if (err < 0) or (inode > nnodes) or (inode < 1) then
        begin
          writeln('FATAL - cannot make sense of ', xline[i], ' on line ',
            ncomp, ' of the responsibility file!');
          Halt;
        end;
        resp[ncomp, inode] := round(1000 * r);
        if resp[ncomp, inode] > topresp[inode] then
          topresp[inode] := resp[ncomp, inode];
      end;
    end;
    CloseFile(ff);
    writeln('Read ', ncomp, ' entries from ', fname);
  end
  else
    writeln(fname, ' does not exist - use Responsibilities button to make a valid choice');
end;


procedure TForm3.pickItems;
var
  nl: TIntList;
  i, k: integer;

begin
  for i := 0 to assnode.Count - 1 do
  begin
    nl := TIntList(assnode[i]);
    FreeAndNil(nl);
  end;
  FreeAndNil(assnode);
  assnode := TFPList.Create;

  for i := 1 to ncomp do
  begin
    nl := TIntList.Create;
    for k := 1 to nnodes do
      if (topresp[k]>0) and (resp[i, k] >= threshold * topresp[k]) then
        nl.Add(k);
    assnode.Add(nl);
    //writeln('Compound ', assnode.Count, ' is associated to ', TIntList(
    //  assnode[assnode.Count - 1]).IntCount, ' nodes');
  end;
end;


procedure TForm3.FormCreate(Sender: TObject);
begin
  smiles := TStringList.Create;
  assnode := TFPList.Create;
  threshold := 0.5;
  minthreshold := 0.1;
  maxshow := 100;
  Edit1.Text := 'Pick a SMILES file of compounds to locate on map';
  Edit2.Text := 'Pick the RESPONSIBILITY file of compounds to locate on map';
  Edit3.Text := FormatFloat('0.00', threshold);
  Edit4.Text := IntToStr(maxshow);
end;



end.
