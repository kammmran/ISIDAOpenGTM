unit ULinAlgSparse;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, utypes;

type
  PTRecMatrix = ^TRecMatrix;
  TRecMatrix = record
    ir,ic: integer;
    dval: double;
  end;

  { TSMatrix }

  TSMatrix = class(TList)
  private
    firmax, ficmax: integer;
  public
    constructor Create;
    destructor Destroy; override;
    procedure AddElement(r,c: integer; v: double);
    procedure DeleteElement(r,c: integer);
    procedure DeleteElement(i: integer);
    function FindItem(r,c: integer; out idx: integer): PTRecMatrix;
    function FindValue(r,c: integer; out idx: integer): double;
    procedure PrintSMatrix();
    procedure Clear; override;
    property irmax: integer read firmax;
    property icmax: integer read ficmax;
  end;
  procedure MatElemProduct(A,B,C: TSMatrix);
  procedure MatElemDiv(A,B,C: TSMatrix);
  procedure TMatSMatMult(A,C: TMatrix; B: TSMatrix; Lb, Ub, CLb1, CUb1, CLb2, CUb2: integer);
  procedure TMattSMatMult(A,C: TMatrix; B: TSMatrix; Lb, Ub, CLb1, CUb1, CLb2, CUb2: integer);
  procedure SMatTMatMult(A: TSMatrix; B, C: TMatrix; Lb, Ub, CLb1, CUb1, CLb2, CUb2: integer);
  procedure SMatTMatMultt(A: TSMatrix; B, C: TMatrix; Lb, Ub, CLb1, CUb1, CLb2, CUb2: integer);

implementation

procedure MatElemProduct(A, B, C: TSMatrix);
var
  pitemA, pitemB: PTRecMatrix;
  tmpA,tmpB: TSMatrix;
  iA, iB, ir, ic: integer;
  vA, vB: double;
begin
  tmpA:=TSMatrix.Create;
  tmpB:=TSMatrix.Create;
  C.Clear;
  if A.Count<=B.Count then
  begin
    for iA:=0 to A.Count-1 do tmpA.Add(A.Items[iA]); //Partial copy
    for iB:=0 to B.Count-1 do tmpB.Add(B.Items[iB]); //Partial copy
  end else begin
    for iA:=0 to A.Count-1 do tmpB.Add(A.Items[iA]); //Partial copy
    for iB:=0 to B.Count-1 do tmpA.Add(B.Items[iB]); //Partial copy
  end;
  for iA:=0 to tmpA.Count-1 do
  begin
    pitemA:=PTRecMatrix(tmpA.Items[iA]);
    ir:=pitemA^.ir;
    ic:=pitemA^.ic;
    vA:=pitemA^.dval;
    vB:=tmpB.FindValue(ir,ic,iB);
    if vB<>0 then
    begin
      tmpB.Delete(iB);
      C.AddElement(ir,ic,vA*vB);
    end;
  end;
  for iA:=tmpA.Count-1 downto 0 do; tmpA.Delete(iA);
  for iB:=tmpB.Count-1 downto 0 do; tmpB.Delete(iB);
  FreeAndNil(tmpA);
  FreeAndNil(tmpB);
end;

procedure MatElemDiv(A, B, C: TSMatrix);
var
  pitemA, pitemB: PTRecMatrix;
  tmpA,tmpB: TSMatrix;
  iA, iB, ir, ic: integer;
  vA, vB: double;
begin
  tmpA:=TSMatrix.Create;
  tmpB:=TSMatrix.Create;
  C.Clear;
  for iA:=0 to A.Count-1 do tmpA.Add(A.Items[iA]); //Partial copy
  for iB:=0 to B.Count-1 do tmpB.Add(B.Items[iB]); //Partial copy
  for iA:=0 to tmpA.Count-1 do
  begin
    pitemA:=PTRecMatrix(tmpA.Items[iA]);
    ir:=pitemA^.ir;
    ic:=pitemA^.ic;
    vA:=pitemA^.dval;
    vB:=tmpB.FindValue(ir,ic,iB);
    if vB<>0 then
    begin
      tmpB.Delete(iB);
      C.AddElement(ir,ic,vA/vB);
    end;
  end;
  for iA:=tmpA.Count-1 downto 0 do; tmpA.Delete(iA);
  for iB:=tmpB.Count-1 downto 0 do; tmpB.Delete(iB);
  FreeAndNil(tmpA);
  FreeAndNil(tmpB);
end;

procedure TMatSMatMult(A, C: TMatrix; B: TSMatrix; Lb, Ub, CLb1, CUb1, CLb2,
  CUb2: integer);
var
  i, j, k, l: integer;
  PMatItem: PTRecMatrix;
begin
  for i:=CLb1 to CUb1 do
  begin
    for j:=CLb2 to CUb2 do
    begin
      C[i,j]:=0;
    end;
  end;
  for k:=0 to B.Count-1 do
  begin
    PMatItem:=PTRecMatrix(B.Items[k]);
    l:=PMatItem^.ir;
    j:=PMatItem^.ic;
    for i:=CLb1 to CUb1 do
    begin
      C[i,j]:=C[i,j]+PMatItem^.dval*A[i,l];
    end;
  end;
end;

procedure TMattSMatMult(A, C: TMatrix; B: TSMatrix; Lb, Ub, CLb1, CUb1, CLb2,
  CUb2: integer);
var
  i, j, k, l: integer;
  PMatItem: PTRecMatrix;
begin
  for i:=CLb1 to CUb1 do
  begin
    for j:=CLb2 to CUb2 do
    begin
      C[i,j]:=0;
    end;
  end;
  for k:=0 to B.Count-1 do
  begin
    PMatItem:=PTRecMatrix(B.Items[k]);
    l:=PMatItem^.ir;
    j:=PMatItem^.ic;
    for i:=CLb1 to CUb1 do
    begin
      C[i,j]:=C[i,j]+PMatItem^.dval*A[l,i];
    end;
  end;
end;

procedure SMatTMatMult(A: TSMatrix; B, C: TMatrix; Lb, Ub, CLb1, CUb1, CLb2,
  CUb2: integer);
var
  i, j, k, l: integer;
  PMatItem: PTRecMatrix;
begin
  for i:=CLb1 to CUb1 do
  begin
    for j:=CLb2 to CUb2 do
    begin
      C[i,j]:=0;
    end;
  end;
  for k:=0 to A.Count-1 do
  begin
    PMatItem:=PTRecMatrix(A.Items[k]);
    i:=PMatItem^.ir;
    l:=PMatItem^.ic;
    for j:=CLb2 to CUb2 do
    begin
      C[i,j]:=C[i,j]+PMatItem^.dval*B[l,j];
    end;
  end;
end;

procedure SMatTMatMultt(A: TSMatrix; B, C: TMatrix; Lb, Ub, CLb1, CUb1, CLb2,
  CUb2: integer); //Transpose the result of the AxB operation. Bug. Does not work
var
  i, j, k, l: integer;
  PMatItem: PTRecMatrix;
begin
  for i:=CLb1 to CUb1 do
  begin
    for j:=CLb2 to CUb2 do
    begin
      C[i,j]:=0;
    end;
  end;
  for k:=0 to A.Count-1 do
  begin
    PMatItem:=PTRecMatrix(A.Items[k]);
    i:=PMatItem^.ir;
    l:=PMatItem^.ic;
    for j:=CLb1 to CUb1 do
    begin
      C[i,j]:=C[i,j]+PMatItem^.dval*B[l,j];
    end;
  end;
end;

{ TSMatrix }

constructor TSMatrix.Create;
begin
  inherited Create;
  firmax:=0;
  ficmax:=0;
end;

destructor TSMatrix.Destroy;
begin
  Clear;
  inherited Destroy;
end;

procedure TSMatrix.AddElement(r, c: integer; v: double);
var
  pitem: PTRecMatrix;
begin
  new(pitem);
  if (r>firmax) then firmax:=r;
  if (c>ficmax) then ficmax:=c;
  pitem^.ir:=r;
  pitem^.ic:=c;
  pitem^.dval:=v;
  Add(pitem);
end;

procedure TSMatrix.DeleteElement(r, c: integer);
var
  i: integer;
  pitem: PTRecMatrix;
  bFound: boolean;
begin
  i:=0;
  bFound:=False;
  while (i<Count) and (not bFound) do
  begin
    pitem:=PTRecMatrix(Items[i]);
    bFound:=(pitem^.ir=r) and (pitem^.ic=c);
    inc(i);
  end;
  if bFound then DeleteElement(i);
end;

procedure TSMatrix.DeleteElement(i: integer);
var
  pitem: PTRecMatrix;
  j: integer;
begin
  pitem:=PTRecMatrix(Items[i]);
  dispose(pitem);
  Delete(i);
  //Update the matrix geometry
  firmax:=0;
  ficmax:=0;
  for j:=0 to Count-1 do
  begin
    pitem:=PTRecMatrix(Items[j]);
    if (pitem^.ir>firmax) then firmax:=pitem^.ir;
    if (pitem^.ic>ficmax) then ficmax:=pitem^.ic;
  end;
end;

function TSMatrix.FindItem(r, c: integer; out idx: integer): PTRecMatrix;
var
  i: integer;
  pitem: PTRecMatrix;
  bFound: boolean;
begin
  Result:=nil; idx:=-1;
  i:=0;
  bFound:=False;
  while (i<Count) and (not bFound) do
  begin
    pitem:=PTRecMatrix(Items[i]);
    bFound:=(pitem^.ir=r) and (pitem^.ic=c);
    inc(i);
  end;
  if bFound then
  begin
    Result:=pitem;
    idx:=i-1;
  end;
end;

function TSMatrix.FindValue(r, c: integer; out idx: integer): double;
var
  pitem: PTRecMatrix;
begin
  Result:=0; idx:=-1;
  pitem:=FindItem(r,c,idx);
  if pitem<>nil then Result:=pitem^.dval;
end;

procedure TSMatrix.PrintSMatrix;
var
  i: integer;
  pitem,pitem1: PTRecMatrix;
  s: string;
begin
  if Count<=0 then Exit;
  pitem1:=PTRecMatrix(Items[0]);
  s:=IntToStr(pitem1^.ir)+','+IntToStr(pitem1^.ic)+':'+FloatToStrF(pitem1^.dval,ffGeneral,3,5)+' ';
  for i:=1 to Count-1 do
  begin
    pitem:=PTRecMatrix(Items[i]);
    if (pitem^.ir<>pitem1^.ir) then
    begin
      writeln(s);
      s:='';
    end;
    s:=s+IntToStr(pitem^.ir)+','+IntToStr(pitem^.ic)+':'+FloatToStrF(pitem^.dval,ffGeneral,3,5)+' ';
    pitem1:=pitem;
  end;
  writeln(s);
end;

procedure TSMatrix.Clear;
var
  i: integer;
  pitem: PTRecMatrix;
begin
  for i:=Count-1 downto 0 do
  begin
    pitem:=PTRecMatrix(Items[i]);
    dispose(pitem);
    pitem:=nil;
  end;
  ficmax:=0;
  firmax:=0;
  inherited Clear;
end;

end.
