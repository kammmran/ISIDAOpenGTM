unit UGTMBase;

{$mode objfpc}{$H+}

interface

uses
  {$IFDEF GUI}Dialogs,{$ENDIF}
  Classes, SysUtils, ULinAlgSparse, utypes, ulinalg;

type

  { TGTMBase }

  TGTMBase = class(TObject)
  private
    fmatM, fmatX: TMatrix; //2D latent space positions of RBF centers and sample points
    function GetSelNode(i: integer): boolean;
    procedure SetK(AValue: integer);
    procedure SetSelNode(i: integer; AValue: boolean);
  protected
    fPhi: TMatrix;//Phi: KxM latent to traits space transfer function;
    fN, fD, fK, fM: integer; { N, Number of instances;
                               D, dimension of initial space;
                               K, number of latent space samples;
                               M, number of traits }
    fnIter: integer; //Count the number of EM iterations
    fsigma: double; // Width of the latent space RBF: Phi_i(x)=exp(-((x-u_i)/sigma)^2)
    frnode: double; //mean radius of node (sqrt(4*Pi/K))
    fW, fR: TMatrix; { W: DxM model parameters matrix;
                       R: KxN, responsabilities; }
    fmatPrj: TMatrix;//Nx2 matrix Projected data on the latent manifold
    faSelNode: TBoolVector; //Array of selected nodes ID; Selected = True
    fRestart: boolean;//True: the manifold is initialized externally to start EM
    //fnHeat: integer;//Number of Monte Carlo steps to perform when generating data points before recording - thermalisation
    procedure DimSelNode(sze: integer);
    Procedure IsValidIdOrDie(aIndex: integer);
  public
    property N: integer read fN write fN;
    property D: integer read fD write fD;
    property K: integer read fK write SetK;
    property M: integer read fM write fM;
    property rnode: double read frnode;
    property W: TMatrix read fW write fW;
    property Phi: TMatrix read fPhi;
    property matM: TMatrix read fmatM;
    property matX: TMatrix read fmatX;
    property SelNode[i: integer]: boolean read GetSelNode write SetSelNode;
    property R: TMatrix read fR;
    property matPrj: TMatrix read fmatPrj;
    property sigma: double read fsigma write fsigma;
    property nIter: integer read fnIter write fnIter;
    property Restart: boolean read fRestart write fRestart;
    //property nHeat: integer read fnHeat write fnHeat;
    procedure DimR(Ub1,Ub2: integer);
    procedure DimR;
    procedure DimW(Ub1,Ub2: integer);
    procedure DimW;
    procedure DimMatM(Ub1: integer);
    procedure DimMatM;
    procedure DimMatX(Ub1: integer);
    procedure DimMatX;
    procedure DimMatPrj();
    procedure DimMatPrj(Ub1: integer);
    procedure ResizeMatX(newK: integer); virtual;
    procedure ResizeMatX(newKr,newKc: integer); virtual;
    procedure SetMatX(A: TMatrix);
    procedure SetMatM(A: TMatrix);
    procedure SetPhi();
    procedure DimSelNode();
    procedure ResetSelNode();
    procedure Init(kSamples, mTraits: integer; asigma: double = -1.0); virtual;
    procedure Init(); virtual;
    function LogLikelyHood(): double; virtual; abstract;
    function MxR(aIndex: integer): double;
    function NodeMxR(aIndex: integer): integer;
    procedure MxR(aIndex: integer; out aMxNode: integer; out aMxR: double);
    procedure Project(); virtual;
    procedure ProjectOnSelected();
    constructor Create; virtual;
    destructor Destroy; override;
  published
  end;

function createMMatrix(numM: integer): TMatrix;
//Quasi-uniform grid of numM points on a [-1,1]x[-1,1] range
function createMMatrix(numMr,numMc: integer): TMatrix;
//Rectangulargrid of numMr x numMc points on a [-1,1]x[-1,1] range

implementation

function createMMatrix(numM: integer): TMatrix;
var
  i: integer;
  dtmp: double;
  xc, yx: double;
  xmin, ymin: double;
  xmax, ymax: double;
begin
  DimMatrix(Result, numM, 2);
  if numM>1 then
  begin
    xmin:=1/numM;
    xmax:=1;
    ymin:=1;
    ymax:=0;
    for i:=1 to numM do
    begin
      Result[i,1]:=i/numM;
      dtmp:=i*(sqrt(5)+1)/2;
      Result[i,2]:=dtmp-int(dtmp);
      if Result[i,2]<ymin then ymin:=Result[i,2];
      if Result[i,2]>ymax then ymax:=Result[i,2];
    end;
    for i:=1 to numM do
    begin
        Result[i,1]:=2*(Result[i,1]-xmin)/(xmax-xmin)-1;
        Result[i,2]:=2*(Result[i,2]-ymin)/(ymax-ymin)-1;
    end;
  end else
  begin
    Result[1,1]:=0;
    Result[1,2]:=0;
  end;
end;

function createMMatrix(numMr, numMc: integer): TMatrix;
var
  numM: integer;
  i, j, k: integer;
begin
  numM:=numMr*numMc;
  DimMatrix(Result,numM,2);
  if (numMr>1) and (numMc>1) then
  begin
    k:=0;
    for i:=0 to numMr-1 do
      for j:=0 to numMc-1 do
      begin
        Inc(k);
        Result[k,1]:=-1+i*2/(numMr-1);
        Result[k,2]:=-1+j*2/(numMc-1);
      end;
  end else if (numMc=1) then begin
    k:=0;
    for i:=0 to numMr-1 do
    begin
      Inc(k);
      Result[k,1]:=-1+i*2/(numMr-1);
      Result[k,2]:=0;
    end;
  end else if (numMr=1) then begin
    k:=0;
    for j:=0 to numMc-1 do
    begin
      Inc(k);
      Result[k,1]:=0;
      Result[k,2]:=-1+j*2/(numMr-1);
    end;
  end else
  begin
    Result[1,1]:=0;
    Result[1,2]:=0;
  end;
end;

{ TGTMBase }

function TGTMBase.GetSelNode(i: integer): boolean;
//Return the ID of the ith selected node; Default returned value is False
begin
  try
    Result:=faSelNode[i];
  except
    raise Exception.Create('ERROR: TGTMBase.GetSelNode('+IntToStr(i)+'). Out of range access.');
  end;
end;

procedure TGTMBase.SetK(AValue: integer);
begin
  if fK=AValue then Exit;
  fK:=AValue;
  frnode:=sqrt(4/(Pi*fK));
end;

procedure TGTMBase.SetSelNode(i: integer; AValue: boolean);
//Set the ID of the ith selected node
begin
  try
    faSelNode[i]:=AValue;
  except
    raise Exception.Create('ERROR: TGTMBase.SetSelNode('+IntToStr(i)+','+BoolToStr(AValue)+'). Out of range access.');
  end;
end;

procedure TGTMBase.DimR(Ub1, Ub2: integer);
begin
  DimMatrix(fR,Ub1,Ub2);
end;

procedure TGTMBase.DimR;
begin
  if (fK<>0) and (fN<>0) then DimMatrix(fR,fK,fN)
  else begin
    {$IFDEF GUI}
    ShowMessage('ERROR TGTMBase.DimR: number of samples K and/or number of instances N not set.');
    {$ELSE}
    WriteLn('ERROR TGTMBase.DimR: number of samples K and/or number of instances N not set.');
    {$ENDIF}
    Exception.Create('ERROR TGTMBase.DimR: number of samples K and/or number of instances N not set.');
    Halt;
  end;
end;

procedure TGTMBase.DimW(Ub1, Ub2: integer);
begin
  DimMatrix(fW,Ub1,Ub2);
end;

procedure TGTMBase.DimW;
begin
  if (fD<>0) and (fM<>0) then DimMatrix(fW,fD,fM)
  else begin
    {$IFDEF GUI}
    ShowMessage('ERROR TGTMBase.DimW: input space dimension D and/or number of traits M not set.');
    {$ELSE}
    WriteLn('ERROR TGTMBase.DimW: input space dimension D and/or number of traits M not set.');
    {$ENDIF}
    Exception.Create('ERROR TGTMBase.DimW: input space dimension D and/or number of traits M not set.');
    Halt;
  end;
end;

procedure TGTMBase.DimMatM(Ub1: integer);
begin
  DimMatrix(fmatM,Ub1,2);
end;

procedure TGTMBase.DimMatM;
begin
  if (fM<>0) then DimMatrix(fmatM,fM,2)
  else begin
    {$IFDEF GUI}
    ShowMessage('ERROR TGTMBase.DimMatM: number of traits M not set.');
    {$ELSE}
    WriteLn('ERROR TGTMBase.DimMatM: number of traits M not set.');
    {$ENDIF}
    Exception.Create('ERROR TGTMBase.DimMatM: number of traits M not set.');
    Halt;
  end;
end;

procedure TGTMBase.DimMatX(Ub1 : integer);
begin
  DimMatrix(fmatX,Ub1,2);
  DimSelNode(Ub1);
end;

procedure TGTMBase.DimMatX;
begin
  if (fK<>0) then DimMatrix(fmatX,fK,2)
  else begin
    {$IFDEF GUI}
    ShowMessage('ERROR TGTMBase.DimMatX: number of samples K not set.');
    {$ELSE}
    WriteLn('ERROR TGTMBase.DimMatX: number of samples K not set.');
    {$ENDIF}
    Exception.Create('ERROR TGTMBase.DimMatX: number of samples K not set.');
    Halt;
  end;
end;

procedure TGTMBase.DimMatPrj();
begin
  DimMatrix(fmatPrj,fN,2);
end;

procedure TGTMBase.DimMatPrj(Ub1: integer);
begin
  DimMatrix(fmatPrj,Ub1,2);
end;

procedure TGTMBase.ResizeMatX(newK: integer);
var
  ik,im: integer;
begin
  fmatX:=createMMatrix(newK);
  DimSelNode(newK);
  // Phi, matrix of basis functions
  SetPhi();
end;

procedure TGTMBase.ResizeMatX(newKr, newKc: integer);
var
  ik,im: integer;
begin
  fmatX:=createMMatrix(newKr,newKc);
  DimSelNode(newKr*newKc);
  // Phi, matrix of basis functions
  SetPhi();
end;

procedure TGTMBase.SetMatX(A: TMatrix);
var
  i, j: integer;
begin
  if (High(A)<>High(fMatX)) or (High(A[0])<>High(fMatX[0])) then begin
     raise Exception.Create('ERROR UGTMBase.SetMatX: assignement of incompatible matrices');
     halt;
  end;
  for i:=Low(fMatX) to High(fMatX) do
    for j:=Low(fMatX[0]) to High(fMatX[0]) do
      fMatX[i,j]:=A[i,j];
end;

procedure TGTMBase.SetMatM(A: TMatrix);
var
  i, j: integer;
begin
  if (High(A)<>High(fMatM)) or (High(A[0])<>High(fMatM[0])) then begin
     raise Exception.Create('ERROR UGTMBase.SetMatX: assignement of incompatible matrices');
     halt;
  end;
  for i:=Low(fMatM) to High(fMatM) do
    for j:=Low(fMatM[0]) to High(fMatM[0]) do
      fMatM[i,j]:=A[i,j];
end;

procedure TGTMBase.SetPhi;
var
  ik, im: integer;
  sl: TStringList;
begin
  // Phi, matrix of basis functions
  if High(fPhi)<fK then DimMatrix(fPhi,fK,fM);
  for ik := 1 to fK do
    for im := 1 to fM do//exp(-0.5*((x_i-m_i)/sigma)^2)
      fPhi[ik, im] := exp(-(sqr(fmatM[im, 1] - fmatX[ik, 1]) +
        sqr(fmatM[im, 2] - fmatX[ik, 2]) / sqr(fsigma)) / 2);
end;

procedure TGTMBase.DimSelNode();
begin
  if fK<>0 then
    DimSelNode(fK)
  else
  begin
    raise Exception.Create('ERROR DimSelNode: no number of nodes defined');
    halt;
  end;
end;

procedure TGTMBase.DimSelNode(sze: integer);
//Set size of faSelNode and set all elements to True
var
  i: integer;
begin
  DimBoolVector(faSelNode,sze);
  for i:=Low(faSelNode) to High(faSelNode) do faSelNode[i]:=True;
end;

procedure TGTMBase.IsValidIdOrDie(aIndex: integer);
// Test is aIndex is a valid molecule Id or die
begin
  if (aIndex<1) or (aIndex>N) then begin
    raise Exception.Create('ERROR UGTMBase.IsValidIdOrDie: try to access compound Id '+IntToStr(aIndex)+' but it does not exist.');
    halt;
  end;
end;

procedure TGTMBase.ResetSelNode();
var
  i: integer;
begin
  for i:=0 to High(faSelNode) do faSelNode[i]:=False;
end;

procedure TGTMBase.Init(kSamples, mTraits: integer; asigma: double);
begin
  M := mTraits;
  K := kSamples;
  if asigma <= 0 then
    fsigma := 5.64 / sqrt(fK) // Recommendation to have O(100) samples within 2 sigma radius
  else
    fsigma := asigma;
  Init;
end;

procedure TGTMBase.Init();
var
  ik, im: integer;
begin
  DimMatrix(fPhi, fK, fM);
  if (not fRestart) then DimMatrix(fW, fD, fM);
  // Samples and RBF centers, try to preserve these matrix if they are already defined
  if (fmatM=nil) or (High(fmatM)<>fM) then fmatM := createMMatrix(fM);
  if (fmatX=nil) or (High(fmatX)<>fK) then fmatX := createMMatrix(fK);
  // Prepare list of selected nodes
  if (faSelNode=nil) or (High(faSelNode)<>fK) then DimSelNode(fK);
  // Phi, matrix of basis functions
  SetPhi();
end;

function TGTMBase.MxR(aIndex: integer): double;
//Return the maximum responsibility value for a given molecule
var
  ik: integer;
begin
  IsValidIdOrDie(aIndex);
  Result:=0;
  for ik:=1 to fK do
    if Result<R[ik,aIndex] then Result:=R[ik,aIndex];
end;

function TGTMBase.NodeMxR(aIndex: integer): integer;
//Return the smallest node id with the nmaximum responsibility value for a given molecule
var
  ik: integer;
  aMxR: double;
begin
  IsValidIdOrDie(aIndex);
  Result:=0;
  aMxR:=0;
  for ik:=1 to fK do
    if aMxR<R[ik,aIndex] then begin
      aMxR:=R[ik,aIndex];
      Result:=ik
    end;
end;

procedure TGTMBase.MxR(aIndex: integer; out aMxNode: integer; out aMxR: double);
//Return the smallest node id with the nmaximum responsibility value for a given molecule
var
  ik: integer;
begin
  IsValidIdOrDie(aIndex);
  aMxNode:=0;
  aMxR:=0;
  for ik:=1 to fK do
    if aMxR<R[ik,aIndex] then begin
      aMxR:=R[ik,aIndex];
      aMxNode:=ik
    end;
end;

procedure TGTMBase.Project();
var
  ii, ik: integer;
begin
  DimMatrix(fmatPrj, fN, 2);
  for ii := 1 to N do
  begin
    fmatPrj[ii, 1] := 0;
    fmatPrj[ii, 2] := 0;
    for ik := 1 to K do
    begin
      fmatPrj[ii, 1] := fmatPrj[ii, 1] + fR[ik, ii] * fmatX[ik, 1];
      fmatPrj[ii, 2] := fmatPrj[ii, 2] + fR[ik, ii] * fmatX[ik, 2];
    end;
  end;
end;

procedure TGTMBase.ProjectOnSelected();
var
  ii, ik: integer;
begin
  DimMatrix(fmatPrj, fN, 2);
  for ii := 1 to N do
  begin
    fmatPrj[ii, 1] := 0;
    fmatPrj[ii, 2] := 0;
    for ik := 1 to K do
    begin
      if SelNode[ik] then begin
        fmatPrj[ii, 1] := fmatPrj[ii, 1] + fR[ik, ii] * fmatX[ik, 1];
        fmatPrj[ii, 2] := fmatPrj[ii, 2] + fR[ik, ii] * fmatX[ik, 2];
      end;
    end;
  end;
end;

constructor TGTMBase.Create;
begin
  fM := 0;
  fK := 0;
  fN := 0;
  fD := 0;
  fsigma := 1.0;
  fnIter:=0;
  //fnHeat:=0;
  fRestart:=False;
  //Initialize matrices to nil
  fPhi:=nil;
  fmatM:=nil;
  fmatX:=nil;
  faSelNode:=nil;
  //fY:=nil;
  fW:=nil;
  fR:=nil;
  fmatPrj:=nil;
end;

destructor TGTMBase.Destroy;
begin
  {if fPhi=nil then writeln('Phi');
  if fmatM=nil then writeln('matM');
  if fmatX=nil then writeln('matX');
  if fY=nil then writeln('Y');
  if fW=nil then writeln('W');
  if fR=nil then writeln('R');
  if fWPhi=nil then writeln('WPhi');
  if fmatPrj=nil then writeln('matPrj');}
  inherited Destroy;
end;

end.
