unit UGTMSparse;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, streamex, UGTMBase, utypes, ISIDA_descriptor,
  ioSVM, upca, usvd, ulinalg, ULinAlgSparse;

type

  { TGTMSparse }

  TGTMSparse = class(TGTMBase)
  private
  protected
    fZ: TSMatrix; //Data matrix
    {Remark: a sparse implementation cannot be standardized. If the mean is
     removed, the zeros of the initial matrix will be shifted to the actual
     non-zero mean. The information content does not change, but the matrix
     is non longer sparse.}
  public
    property Z: TSMatrix read fZ;
    procedure ReadMols(RF: TFileReader; const L: integer = -1); virtual;
    procedure ReadMols(RF: TFileReader; L1, L2: integer); virtual;
    procedure ReadMols(const flenme: string; L1: integer = 0; L2: integer = -1); virtual;
    procedure ReadMols(RF: TFileReader; var ZT: TSMatrix; var Nmax: integer;
      const L: integer = -1); virtual;
    procedure ReadMols(RF: TFileReader; var ZT: TSMatrix; var Nmax: integer;
      L1, L2: integer); virtual;
    procedure ReadMols(const flenme: string; var ZT: TSMatrix; var Nmax: integer;
      L1: integer = 0; L2: integer = -1); virtual;
    procedure Init(); override;
    procedure Init(kSamples, mTraits: integer; asigma: double); override;
    procedure Project(ZT: TSMatrix); virtual; abstract;
    procedure Project(); override;
    constructor Create; override;
    destructor Destroy; override;
  end;

implementation

{ TGTMSparse }

procedure TGTMSparse.ReadMols(RF: TFileReader; const L: integer);
var
  id: integer;
  pitem: PRDsc;
  mol: LRDsc;
  bstop: boolean;
  sline: string;
begin
  bstop := False;
  fN := 0;
  fD := 0;
  repeat
    if (not RF.Eof) then
      RF.ReadLine(sline)
    else break;
    Inc(fN);
    mol := ReadLNSVM(sline);
    for id := 0 to mol.Count - 1 do
    begin
      pitem:=PRDsc(mol.Items[id]);
      fZ.AddElement(fN,pitem^.Idx,pitem^.Cnt); //row, colum, value
    end;
    if (L < 0) then
      bstop := RF.EOF
    else
      bstop := (fN >= L);
  until bstop;
  fD:=fZ.icmax;
  FreeAndNil(mol);
end;

procedure TGTMSparse.ReadMols(RF: TFileReader; L1, L2: integer);
var
  il, Lmax: integer;
begin
  il := 0;
  while (il < L1) and (not RF.EOF) do
  begin
    RF.ReadLine;
    Inc(il);
  end;
  if (L2 > 0) then
    Lmax := L2 - L1
  else
    Lmax := -1;
  ReadMols(RF, Lmax);
end;

procedure TGTMSparse.ReadMols(const flenme: string; L1: integer; L2: integer);
var
  RF: TFileReader;
begin
  RF := TFileReader.Create(flenme);
  ReadMols(RF, L1, L2);
  FreeAndNil(RF);
end;

procedure TGTMSparse.ReadMols(RF: TFileReader; var ZT: TSMatrix;
  var Nmax: integer; const L: integer);
var
  ii,id: integer;
  pitem: PRDsc;
  mol: LRDsc;
  bstop: boolean;
  sline: string;
begin
  bstop := False;
  ii:=0;
  repeat
    RF.ReadLine(sline);
    Inc(ii);
    mol := ReadLNSVM(sline);
    for id := 0 to mol.Count - 1 do
    begin
      pitem:=PRDsc(mol.Items[id]);
      if (pitem^.Idx<=fD) then
        ZT.AddElement(ii,pitem^.Idx,pitem^.Cnt) //row, colum, value
      else Writeln('WARNING: Found a value for a new descriptor ('+IntToStr(pitem^.Idx)+':'+pitem^.Nme+'). Ignoring this value.');
    end;
    Nmax:=ZT.irmax;
    if (L < 0) then
      bstop := RF.EOF
    else
      bstop := (ii >= L);
  until bstop;
  FreeAndNil(mol);
end;

procedure TGTMSparse.ReadMols(RF: TFileReader; var ZT: TSMatrix;
  var Nmax: integer; L1, L2: integer);
var
  il, Lmax: integer;
begin
  il := 0;
  while (il < L1) and (not RF.EOF) do
  begin
    RF.ReadLine;
    Inc(il);
  end;
  if (L2 > 0) then
    Lmax := L2 - L1
  else
    Lmax := -1;
  ReadMols(RF, ZT, Nmax, Lmax);
end;

procedure TGTMSparse.ReadMols(const flenme: string; var ZT: TSMatrix;
  var Nmax: integer; L1: integer; L2: integer);
var
  RF: TFileReader;
begin
  RF := TFileReader.Create(flenme);
  ReadMols(RF, ZT, Nmax, L1, L2);
  FreeAndNil(RF);
end;

procedure TGTMSparse.Init;
begin
  inherited Init;
  //Responsabilities
  DimMatrix(fR, K, fN);
end;

procedure TGTMSparse.Init(kSamples, mTraits: integer; asigma: double);
var
  id, im: integer;
  amax: double;
begin
  Randomize;
  inherited Init(kSamples, mTraits, asigma);
  //Initialize W if not set externally
  if (fD>=fM) then amax:=fD-1 else amax:=fM-1;
  if(not Restart) then
    for id:=1 to fD do //fW arbitrarily initialized as a linearly decreasing distance-to-diagonal matrix
      for im:=1 to fM do
        W[id,im]:=1-abs(id-im)/amax;
    {for id:=1 to fD do
        for im:=1 to fM do
            fW[id,im]:=1-Random;} //W random initialization is possible. The wrong choice is to take fA homogeneous
  NormalizeByColumn(fW,1,fD,1,fM);
  NormalizeByLine(fPhi,1,fK,1,fM);
end;

procedure TGTMSparse.Project;
begin
  inherited Project;
end;

constructor TGTMSparse.Create;
begin
  inherited Create;
  fZ:= TSMatrix.Create;
end;

destructor TGTMSparse.Destroy;
begin
  FreeAndNil(fZ);
  inherited Destroy;
end;

end.

