unit UGTMFull;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, streamex, UGTMBase, utypes, ISIDA_descriptor,
  ioSVM, upca, usvd, ulinalg;

type

  { TGTMFull }

  TGTMFull = class(TGTMBase)
  private
    fX: TMatrix; //Data matrix
    fMean, fSD: TVector; //Mean and SD of X columns
    fPC123: TMatrix; //First 3 PC
    fbeta: double;
    fDeff: double; //Rank of the data matrix - according to SVD
    fistd: integer;
  protected
    fZ: TMatrix; //Standardized X
  public
    property X: TMatrix read fX;
    property Z: TMatrix read fZ;
    property Mean: TVector read fMean write fMean;
    property SD: TVector read fSD write fSD;
    property PC123: TMatrix read fPC123;
    property beta: double read fbeta write fbeta;
    property Deff: double read fDeff write fDeff;
    property istd: integer read fistd write fistd;
    procedure DimMean(Ub: Integer);
    procedure DimMean;
    procedure DimSD(Ub: Integer);
    procedure DimSD;
    procedure DimPC123(Ub1, Ub2: integer);
    procedure DimPC123;
    procedure ReadMols(RF: TFileReader; const L: integer = -1); virtual;
    procedure ReadMols(RF: TFileReader; L1, L2: integer); virtual;
    procedure ReadMols(const flenme: string; L1: integer = 0; L2: integer = -1); virtual;
    procedure ReadMols(RF: TFileReader; var ZT: TMatrix; var Nmax: integer;
      const L: integer = -1); virtual;
    procedure ReadMols(RF: TFileReader; var ZT: TMatrix; var Nmax: integer;
      L1, L2: integer); virtual;
    procedure ReadMols(const flenme: string; var ZT: TMatrix; var Nmax: integer;
      L1: integer = 0; L2: integer = -1); virtual;
    procedure Init(); override;
    procedure Init(kSamples, mTraits: integer; asigma: double); override;
    procedure Project(); override;
    procedure Project(ZT: TMatrix; Nmax: integer); virtual; abstract;
    constructor Create; override;
    destructor Destroy; override;
  end;


implementation

{ TGTMFull }

procedure TGTMFull.DimMean(Ub: Integer);
begin
  DimVector(fMean,Ub);
end;

procedure TGTMFull.DimMean;
begin
  if fD<>0 then DimVector(fMean,fD)
  else begin
    writeln('ERROR TGTMFull.DimMean: input space dimension D not set.');
    Exception.Create('ERROR TGTMFull.DimMean: input space dimension D not set.');
    Halt;
  end;
end;

procedure TGTMFull.DimSD(Ub: Integer);
begin
  DimVector(fSD,Ub);
end;

procedure TGTMFull.DimSD;
begin
  if fD<>0 then DimVector(fSD,fD)
  else begin
    writeln('ERROR TGTMFull.DimSD: input space dimension D not set.');
    Exception.Create('ERROR TGTMFull.DimSD: input space dimension D not set.');
    Halt;
  end;
end;

procedure TGTMFull.DimPC123(Ub1, Ub2: integer);
begin
  DimMatrix(fPC123,Ub1,Ub2);
end;

procedure TGTMFull.DimPC123;
begin
  if fD<>0 then DimMatrix(fPC123,fD,3)
  else begin
    writeln('ERROR TGTMFull.DimPC123: input space dimension D not set.');
    Exception.Create('ERROR TGTMFull.DimPC123: input space dimension D not set.');
    Halt;
  end;
end;

procedure TGTMFull.ReadMols(RF: TFileReader; const L: integer);
var
  il, id, ic, ir: integer;
  sline: string;
  pitem: PRDsc;
  mol: LRDsc;
  mols: LRSMFv2;
  bstop: boolean;
  ii: integer;
begin
  bstop := False;
  il := 0;
  fN := 0;
  fD := 0;
  mols := LRSMFv2.Create;
  repeat
    if (not RF.Eof) then
    begin
      RF.ReadLine(sline);
      Inc(il);
      mol := ReadLNSVM(sline);
      mols.Add(mol);
      pitem := mol.Last;
      if pitem^.Idx > fD then //Get the number of descriptors
        fD := pitem^.Idx;
      if (L < 0) then
        bstop := RF.EOF
      else
        bstop := (il >= L);
    end else bstop:=True;
  until bstop;
  //Create matrix from dataset
  fN := mols.Count; //Get the number of molecules
  if fN>MaxSize then
  begin
     writeln('ERROR: dataset size ('+IntToStr(fN)+') over the maximum allowed ('+IntToStr(MaxSize)+')');
     Halt;
  end;
  if fD>MaxSize then
  begin
     writeln('ERROR: number of attributes ('+IntToStr(fD)+') over the maximum allowed ('+IntToStr(MaxSize)+')');
     Halt;
  end;
  DimMatrix(fX, fN, fD);
  DimMatrix(fZ, fN, fD);
  //DimVector(fY, fN);
  for il := 0 to mols.Count - 1 do
  begin
    mol := mols.Items[il] as LRDsc;
    ir := il + 1;
    //fY[ir] := mol.prp;
    for id := 0 to mol.Count - 1 do
    begin
      pitem := PRDsc(mol.Items[id]);
      ic := pitem^.Idx;
      fX[ir, ic] := pitem^.Cnt;
    end;
  end;
  if (not fRestart) then // compute mean and SD if needed
  begin
    DimVector(fMean, fD);
    DimVector(fSD, fD);
    VecMean(fX, 1, fN, fD, fMean);
    VecSD(fX, 1, fN, fD, fMean, fSD);
  end;
  // Normalize the dataset
  ScaleVar(X, 1, fN, fD, fMean, fSD, fZ, istd);
  FreeAndNil(mols);
end;

procedure TGTMFull.ReadMols(RF: TFileReader; L1, L2: integer);
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

procedure TGTMFull.ReadMols(const flenme: string; L1: integer; L2: integer);
var
  RF: TFileReader;
begin
  RF := TFileReader.Create(flenme);
  ReadMols(RF, L1, L2);
  FreeAndNil(RF);
end;

procedure TGTMFull.ReadMols(RF: TFileReader; var ZT: TMatrix; {var YT: TVector;} var Nmax: integer; const L: integer);
var
  il, id, ic, ir: integer;
  sline: string;
  pitem: PRDsc;
  mol: LRDsc;
  mols: LRSMFv2;
  bstop: boolean;
  XT: TMatrix;
  ii: integer;
begin
  bstop := False;
  il := 0;
  mols := LRSMFv2.Create;
  repeat
    if (not RF.Eof) then
    begin
      RF.ReadLine(sline);
      Inc(il);
      mol := ReadLNSVM(sline);
      mols.Add(mol);
      pitem := mol.Last;
      if (L < 0) then
        bstop := RF.EOF
      else
        bstop := (il >= L);
    end else bstop:=True;
  until bstop;
  Nmax := mols.Count; //Get the number of molecules
  XT:=nil; ZT:=nil;
  if Nmax>MaxSize then
  begin
     writeln('ERROR: dataset size ('+IntToStr(Nmax)+') over the maximum allowed ('+IntToStr(MaxSize)+')');
     Halt;
  end;
  if fD>MaxSize then
  begin
     writeln('ERROR: number of attributes ('+IntToStr(fD)+') over the maximum allowed ('+IntToStr(MaxSize)+')');
     Halt;
  end;
  DimMatrix(XT, Nmax, fD);
  DimMatrix(ZT, Nmax, fD);
  for il := 0 to mols.Count - 1 do
  begin
    mol := mols.Items[il] as LRDsc;
    ir := il + 1;
    for id := 0 to mol.Count - 1 do
    begin
      pitem := PRDsc(mol.Items[id]);
      ic := pitem^.Idx;
      if (ic <= fD) then
        XT[ir, ic] := pitem^.Cnt;
    end;
  end;
  FreeAndNil(mols);
  //Standardize the input matrix
  // Mean and SD are assumed to have been already set
  ScaleVar(XT, 1, Nmax, fD, fMean, fSD, ZT,istd);
end;

procedure TGTMFull.ReadMols(RF: TFileReader; var ZT: TMatrix; var Nmax: integer; L1, L2: integer);
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

procedure TGTMFull.ReadMols(const flenme: string; var ZT: TMatrix; var Nmax: integer;
  L1: integer; L2: integer);
var
  RF: TFileReader;
begin
  RF := TFileReader.Create(flenme);
  ReadMols(RF, ZT, Nmax, L1, L2);
  FreeAndNil(RF);
end;

procedure TGTMFull.Init;
begin
  inherited Init();
  //Responsabilities
  DimMatrix(fR, K, fN);
end;

procedure TGTMFull.Init(kSamples, mTraits: integer; asigma: double);
var
  CX, Phi1: TMatrix;
  //lbd1, lbd2: double;
  ii,id, ik, im: integer;
  //vt1nrm, vt2nrm: double;
  //rr: double;
  U, V: TMatrix;
  S: TVector;
  vL: TVector; //To store eigenvalues
  Elps: TMatrix; //Ellipsoid coordinates in 3 PCA space
  zmax: double; //Estimates of the extent of the dataset, to properly scale the initial manifold
  slog: TStringList;
begin
  inherited Init(kSamples, mTraits, asigma);
  //Responsabilities
  DimMatrix(fR, fK, fN);
  //Data
  if (not fRestart) then
  begin
    fPC123:=nil; vL:=nil; CX:=nil; zmax:=0;
    for id:=1 to fD do
      for ii:=1 to fN do
        if (zmax<abs(fZ[ii,id])) then zmax:=abs(fZ[ii,id]);
    NIPALS(fZ,fPC123,vL,3,1,fN,fD);
    //NIPALS outputs normalized PCA.
    //Loadings are a better choice to initialize the GTM.
    {for id:=1 to fD do
    begin
      fPC123[id,1]:=fPC123[id,1];//*sqrt(vL[1]);///fN);
      fPC123[id,2]:=fPC123[id,2];//*sqrt(vL[2]);///fN);
      fPC123[id,3]:=fPC123[id,3];//*sqrt(vl[3]);///fN);
    end;}
    DimMatrix(CX, fD, fK);
    //Compute CX: it is an ellipsoid with axes proportional to eigenvalues and
    //scaled to the extent of the dataset.
    //First compute the coordinates in 3D
    DimMatrix(Elps,fK,3);
    for ik:=1 to fK do
    begin
      Elps[ik,1]:={sqrt(vL[1])*}zmax*(VL[3]/VL[1])*sin(matX[ik,1])*cos(matX[ik,2]);
      Elps[ik,2]:={sqrt(vL[2])*}zmax*(VL[2]/VL[1])*sin(matX[ik,1])*sin(matX[ik,2]);
      Elps[ik,3]:={sqrt(vL[3])*}zmax*cos(matX[ik,1]);
    end;
    {slog:=TStringList.create;
    PrintMat(Elps,'Ellipse',1,fK,1,3,slog);
    slog.SaveToFile('Elps.mat');
    Freeandnil(slog);}
    //Express the ellipsoid in the D dimensional input space
    for id := 1 to fD do
      for ik := 1 to fK do
        CX[id, ik] := Elps[ik, 1] * fPC123[id,1] + Elps[ik, 2] * fPC123[id,2]+Elps[ik,3]*fPC123[id,3];
    //Initialize W by minimizing the map distance to PC1xPC2 plane
    U:=nil; S:=nil; V:=nil; Phi1:=nil;
    DimMatrix(U, K, M); //U is a copy of Phi that will be destroyed by SVD
    DimVector(S, M);
    DimMatrix(V, M, M);
    DimMatrix(Phi1, M, K);
    for im := 1 to fM do  //
      for ik := 1 to fK do
        U[ik, im] := Phi[ik, im];
    SV_Decomp(U, 1, fK, fM, S, V);//
    if MathErr = MatNonConv then
    begin
      WriteLn('Non-convergence (inverse matrix)!');
      Halt;
    end;
    if MathErr = MatErrDim then
    begin
      writeln('BUG!! nrows=' + IntToStr(fM) + '< ncols=' + IntToStr(fK) +
        '. SVD not defined. Number of nodes should be larger than number of RBF.');
      halt;
    end;
    fDeff:=SV_SetZero(S, 1, M, 1E-18); //Beware of this constant if increasing precision
    InvSVD(U, S, V, 1, K, M, Phi1); //
    for id := 1 to fD do
      for im := 1 to fM do//
      begin
        W[id, im] := 0;
        for ik := 1 to fK do
        begin
          W[id, im] := W[id, im] + Phi1[im, ik] * CX[id, ik];
        end;
      end;
    //1/beta = the square of the half of grid spacing of PCA projected latent sample points 1 and 2
    fbeta := 0;
    for id := 1 to fD do
      fbeta := fbeta + sqr(CX[id, 1] - CX[id, 2]);
    fbeta:=fbeta/4;
    //write('fbeta='+FloatToStr(fbeta)+' VL[3]='+FloatToStr(VL[3]));
    //1/beta is the larger of either PCA eigenvalue or previous computed value
    if (fbeta<VL[3]) then fbeta:=VL[3];
    //writeln(' fbeta='+FloatToStr(fbeta));
    fbeta:=1/fbeta;
  end;
end;

procedure TGTMFull.Project;
begin
  inherited Project;
end;

constructor TGTMFull.Create;
begin
  inherited Create;
  // Initialize matrices to nil
  fX:=nil;
  fMean:=nil;
  fSD:=nil;
  fZ:=nil;
  fistd:=1;//default is standardize
end;

destructor TGTMFull.Destroy;
begin
  inherited Destroy;
end;

end.
