unit UGTMFull;

{$mode objfpc}{$H+}

interface

uses
  {$IFDEF GUI}Dialogs,{$ENDIF}
  Classes, SysUtils, streamex, UGTMBase, utypes, ISIDA_descriptor,
  ioSVM, upca, usvd, ulinalg,math;

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
    fiScaleInit: integer;//scaling manifold initialization (0: original scaling; 1: scale to max data extent; 2: custom)
    ffScaleInit: double;//scaling factor
    fbPC123Set: boolean;//PC123 is set or not.
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
    property iScaleInit: integer read fiScaleInit write fiScaleInit;
    property fScaleInit: double read ffScaleInit write ffScaleInit;
    property bPC123Set: boolean read fbPC123Set;
    procedure DimMean(Ub: Integer);
    procedure DimMean;
    procedure DimSD(Ub: Integer);
    procedure DimSD;
    procedure DimPC123(Ub1, Ub2: integer);
    procedure DimPC123;
    procedure SetPC123mat(aPC123: TMatrix);
    procedure ReadPC123mat(PCFle: string);
    procedure ReadMols(RF: TFileReader; const L: integer = -1); virtual;
    procedure ReadMols(RF: TFileReader; L1, L2: integer); virtual;
    procedure ReadMols(const flenme: string; L1: integer = 0; L2: integer = -1); virtual;
    procedure ReadMols(RF: TFileReader; var ZT: TMatrix; var Nmax: integer;
      const L: integer = -1); virtual;
    procedure ReadMols(RF: TFileReader; var ZT: TMatrix; var Nmax: integer;
      L1, L2: integer); virtual;
    procedure ReadMols(const flenme: string; var ZT: TMatrix; var Nmax: integer;
      L1: integer = 0; L2: integer = -1); virtual;
    procedure SetX; virtual;
    procedure SetX(aX: TMatrix); virtual;
    procedure SetZ(aZ: TMatrix);
    procedure Init(); override;
    procedure Init(kSamples, mTraits: integer; asigma: double); override;
    procedure SetW(CX: TMatrix); virtual;
    procedure Project(); override;
    procedure Project(ZT: TMatrix; Nmax: integer); virtual; abstract;
    procedure Project(flenme: string);
    procedure Zremove(aii: integer);//Remove an instance from X and Z matrices
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
    {$IFDEF GUI}
    ShowMessage('ERROR TGTMFull.DimMean: input space dimension D not set.');
    {$ELSE}
    WriteLn('ERROR TGTMFull.DimMean: input space dimension D not set.');
    {$ENDIF}
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
    {$IFDEF GUI}
    ShowMessage('ERROR TGTMFull.DimSD: input space dimension D not set.');
    {$ELSE}
    WriteLn('ERROR TGTMFull.DimSD: input space dimension D not set.');
    {$ENDIF}
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
    {$IFDEF GUI}
    ShowMessage('ERROR TGTMFull.DimPC123: input space dimension D not set.');
    {$ELSE}
    WriteLn('ERROR TGTMFull.DimPC123: input space dimension D not set.');
    {$ENDIF}
    Exception.Create('ERROR TGTMFull.DimPC123: input space dimension D not set.');
    Halt;
  end;
end;

procedure TGTMFull.SetPC123mat(aPC123: TMatrix);
//Set the PC matrix externally. The eigenvalues must be stored at index 0.
begin
  if High(aPC123)<>fD then
  begin
    raise Exception.Create('ERROR SetPC123mat: incompatible dimensions: '+IntToStr(High(aPC123))+' <> '+IntToStr(fD)+' (provided PC vs data dimensions)');
    halt;
  end;
  if High(aPC123[0])<>3 then
  begin
    raise Exception.Create('ERROR SetPC123mat: abnormal number of columns: '+IntToStr(High(aPC123[0])));
    halt;
  end;
  fPC123:=aPC123;
  fbPC123Set:=True;
end;

procedure TGTMFull.ReadPC123mat(PCFle: string);
var
  SLPC123: TStringList;
  SLValues: TStringList;
  i,ii: integer;
  ErrCode: integer;
begin
  ErrCode:=0;
  SLValues:=TStringList.Create;
  SLPC123:=TStringList.Create;
  SLPC123.LoadFromFile(PCFle);
  //
  DimPC123;
  for i:=0 to D do
  begin
    ii:=i+1;//line number; 1st line is a title
    SLValues.CommaText:=SLPC123[ii];
    val(SLValues[0],fPC123[i,1],ErrCode);
    val(SLValues[1],fPC123[i,2],ErrCode);
    val(SLValues[2],fPC123[i,3],ErrCode);
    if ErrCode>0 then
    begin
      Exception.Create('ERROR ReadPC123mat: error interpreting line '+IntToStr(i)+' : '+SLPC123[ii]);
      halt;
    end;
  end;
  fbPC123Set:=True;
  FreeAndNil(SLPC123);
  FreeAndNil(SLValues);
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
      if mol.Count=0 then
      begin
        raise Exception.Create('ERROR ReadMols: empty vector at line '+IntToStr(il));
        halt;
      end;
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
    {$IFDEF GUI}
    ShowMessage('ERROR: dataset size ('+IntToStr(fN)+') over the maximum allowed ('+IntToStr(MaxSize)+')');
    {$ELSE}
    WriteLn('ERROR: dataset size ('+IntToStr(fN)+') over the maximum allowed ('+IntToStr(MaxSize)+')');
    {$ENDIF}
     Halt;
  end;
  if fD>MaxSize then
  begin
    {$IFDEF GUI}
    ShowMessage('ERROR: number of attributes ('+IntToStr(fD)+') over the maximum allowed ('+IntToStr(MaxSize)+')');
    {$ELSE}
    WriteLn('ERROR: number of attributes ('+IntToStr(fD)+') over the maximum allowed ('+IntToStr(MaxSize)+')');
    {$ENDIF}
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
    {$IFDEF GUI}
    ShowMessage('ERROR: dataset size ('+IntToStr(Nmax)+') over the maximum allowed ('+IntToStr(MaxSize)+')');
    {$ELSE}
    WriteLn('ERROR: dataset size ('+IntToStr(Nmax)+') over the maximum allowed ('+IntToStr(MaxSize)+')');
    {$ENDIF}
     Halt;
  end;
  if fD>MaxSize then
  begin
    {$IFDEF GUI}
    ShowMessage('ERROR: number of attributes ('+IntToStr(fD)+') over the maximum allowed ('+IntToStr(MaxSize)+')');
    {$ELSE}
    WriteLn('ERROR: number of attributes ('+IntToStr(fD)+') over the maximum allowed ('+IntToStr(MaxSize)+')');
    {$ENDIF}
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
  ScaleVar(XT, 1, Nmax, fD, fMean, fSD, ZT);
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

procedure TGTMFull.SetX;
begin
  //Assume that X has been set but has changed and is now depecated
  VecMean(fX, 1, fN, fD, fMean);
  VecSD(fX, 1, fN, fD, fMean, fSD);
  ScaleVar(X, 1, fN, fD, fMean, fSD, fZ, istd);
end;

procedure TGTMFull.SetX(aX: TMatrix);
begin
  //Set the matrix X from an external process
  fX:=aX;
  fN:=High(fX);//Rows of X are molecules
  fD:=High(fX[Low(fX)]);//Number of descriptors is the number of columns
  //Size matrices
  DimVector(fMean,fD);
  DimVector(fSD,fD);
  DimMatrix(fZ,fN,fD);
  //
  VecMean(fX, 1, fN, fD, fMean);
  VecSD(fX, 1, fN, fD, fMean, fSD);
  ScaleVar(X, 1, fN, fD, fMean, fSD, fZ, istd);
end;

procedure TGTMFull.SetZ(aZ: TMatrix);
begin
  //Set the matrix Z from an external process
  //Z is already processed so X=Z
  fX:=aZ;
  fZ:=aZ;
  fN:=High(fX);//Rows of X are molecules
  fD:=High(fX[Low(fX)]);//Number of descriptors is the number of columns
  //Size matrices
  DimMatrix(fR,K,fN);
  DimVector(fMean,fD);
  DimVector(fSD,fD);
end;

procedure TGTMFull.Init();
begin
  inherited Init();
  //Responsabilities
  DimMatrix(fR, K, fN);
end;

procedure TGTMFull.Init(kSamples, mTraits: integer; asigma: double);
var
  CX, Phi1: TMatrix;
  lbd1, lbd2: double;
  ii,id, ik, im: integer;
  vt1nrm, vt2nrm: double;
  P1,P2,P3,P1max,P2max,P3max: double;
  rr: double;
  U, V: TMatrix;
  S: TVector;
  vL: TVector; //To store eigenvalues
  {Debugging the initialization state of the manifold.
  PCX, CX2: TMatrix;
  tmpLog: TStringList;
  }
begin
  inherited Init(kSamples, mTraits, asigma);
  //Responsabilities
  DimMatrix(fR, fK, fN);
  //Data
  if (not fRestart) then
  begin
    if (not fbPC123Set) then
    begin
      fPC123:=nil; vL:=nil; CX:=nil;
      NIPALS(fZ,fPC123,vL,3,1,fN,fD);
      fPC123[0,1]:=vL[1];
      fPC123[0,2]:=VL[2];
      fPC123[0,3]:=VL[3];
      fbPC123Set:=True;
    end else
    begin
      DimVector(vL,3);
      vL[1]:=fPC123[0,1];
      VL[2]:=fPC123[0,2];
      VL[3]:=fPC123[0,3];
    end;
    //NIPALS outputs normalized PCA.
    for ii:=1 to fN do
    begin
      P1:=0;
      P2:=0;
      P3:=0;
      for id:=1 to fD do
      begin
        P1:=P1+fPC123[id,1]*fZ[ii,id];
        P2:=P2+fPC123[id,2]*fZ[ii,id];
        P3:=P3+fPC123[id,3]*fZ[ii,id];
      end;
      P1:=abs(P1);
      P2:=abs(P2);
      P3:=abs(P3);
      If P1>P1max then P1max:=P1;
      If P2>P2max then P2max:=P2;
      If P3>P3max then P3max:=P3;
    end;
    //writeln('P1max: '+FloatToStr(P1max)+' vL[1]:'+FloatToStr(sqrt(vL[1])));
    //writeln('P2max: '+FloatToStr(P2max)+' vL[2]:'+FloatToStr(sqrt(vL[2])));
    //writeln('P3max: '+FloatToStr(P3max)+' vL[3]:'+FloatToStr(sqrt(vL[3])));
    for id:=1 to fD do
    begin
      case fiScaleInit of
        0: begin //Loadings to initialize the GTM.
          fPC123[id,1]:=fPC123[id,1]*sqrt(vL[1]);///fN);
          fPC123[id,2]:=fPC123[id,2]*sqrt(vL[2]);///fN);
          fPC123[id,3]:=fPC123[id,3]*sqrt(vl[3]);///fN);
        end;
        1: begin
          fPC123[id,1]:=fPC123[id,1]*P1max;//Scales to the farthest datapoint
          fPC123[id,2]:=fPC123[id,2]*P2max;//fPC123 is unit scaled
          fPC123[id,3]:=fPC123[id,3]*P3max;
        end;
        2: begin
          fPC123[id,1]:=fPC123[id,1]*sqrt(vL[1])*ffScaleInit;///fN);
          fPC123[id,2]:=fPC123[id,2]*sqrt(vL[2])*ffScaleInit;///fN);
          fPC123[id,3]:=fPC123[id,3]*sqrt(vl[3])*ffScaleInit;///fN);
        end;
        else begin
          Exception.Create('ERROR: unsupported initialization of manifold option: '+IntToStr(fiScaleInit));
          Halt;
        end;
      end;
    end;
    //DimMatrix(CX, fD, fK);
    DimMatrix(CX, fK, fD);
    for id := 1 to fD do
      for ik := 1 to fK do
        CX[ik, id] := matX[ik, 1] * fPC123[id,1] + matX[ik, 2] * fPC123[id,2];
    //Initialize W by minimizing the map distance to PC1xPC2 plane
    SetW(CX);
    //1/fbeta is set to 3rd eigenvalue.
    fbeta:=VL[3];
    fbeta:=1/fbeta;
    {U:=nil; S:=nil; V:=nil; Phi1:=nil;
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
      {$IFDEF GUI}
      ShowMessage('ERROR Init: Non-convergence (inverse matrix)!');
      {$ELSE}
      WriteLn('ERROR Init: Non-convergence (inverse matrix)!');
      {$ENDIF}
      Halt;
    end;
    if MathErr = MatErrDim then
    begin
      {$IFDEF GUI}
      ShowMessage('ERROR Init: BUG!! nrows=' + IntToStr(fM) + '< ncols=' + IntToStr(fK) +
        '. SVD not defined. Number of nodes should be larger than number of RBF.');
      {$ELSE}
      WriteLn('ERROR Init: BUG!! nrows=' + IntToStr(fM) + '< ncols=' + IntToStr(fK) +
        '. SVD not defined. Number of nodes should be larger than number of RBF.');
      {$ENDIF}
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
      end;}
    //
    {Debugging the initialization state of the manifold.
    DimMatrix(PCX,fK,3);
    DimMatrix(CX2,fD,fK);
    for id:=1 to fD do
      for ik:=1 to fK do
      begin
        CX2[id,ik]:=0;
        for im:=1 to fM do
            CX2[id,ik]:=CX2[id,ik]+W[id,im]*Phi[ik,im];
      end;
    for ik:=1 to fK do
      for ii:=1 to 3 do
      begin
        PCX[ik,ii]:=0;
        for id:=1 to fD do
          PCX[ik,ii]:=PCX[ik,ii]+fPC123[id,ii]*CX2[id,ik];
      end;
    tmpLog:=TStringList.Create;
    PrintMat(PCX,'Manifold 0',1,fK,1,3,tmpLog);
    tmpLog.SaveToFile('Manifold0.mat');
    FreeAndNil(tmpLog);
    }
    //
    //1/beta = the square of the half of grid spacing of PCA projected latent sample points
    {
    fbeta := 0;
    for ik:=2 to fK do
      for id := 1 to fD do
        fbeta := fbeta + sqr(CX[id, ik] - CX[id, ik-1]);
    if (fK>1) then fbeta:=fbeta/(fK-1) else fbeta:=0;
    fbeta:=fbeta/4;
    //write('fbeta='+FloatToStr(fbeta)+' VL[3]='+FloatToStr(VL[3]));
    //1/beta is the larger of either PCA eigenvalue or previous computed value
    if (fbeta<VL[3]) then fbeta:=VL[3];
    //writeln(' fbeta='+FloatToStr(fbeta));
    }
  end;
end;

procedure TGTMFull.SetW(CX: TMatrix);
//Use manifold coordinates CX to set the values of W
var
  U,V,Phi1: TMatrix;
  S: TVector;
  im,ik,id,ii: integer;
begin
  DimW;//Presumably, W geometry is not set
  //Find W for the manifold to fit CX
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
    {{$IFDEF GUI}
    ShowMessage('ERROR SetW: Non-convergence (inverse matrix)!');
    {$ELSE}
    WriteLn('ERROR SetW: Non-convergence (inverse matrix)!');
    {$ENDIF}}
    raise Exception.Create('ERROR SetW: Non-convergence (inverse matrix)!');
    Halt;
  end;
  if MathErr = MatErrDim then
  begin
    {{$IFDEF GUI}
    ShowMessage('ERROR SetW: BUG!! nrows=' + IntToStr(fM) + '< ncols=' + IntToStr(fK) +
      '. SVD not defined. Number of nodes should be larger than number of RBF.');
    {$ELSE}
    WriteLn('ERROR SetW: BUG!! nrows=' + IntToStr(fM) + '< ncols=' + IntToStr(fK) +
      '. SVD not defined. Number of nodes should be larger than number of RBF.');
    {$ENDIF}}
    raise Exception.Create('ERROR SetW: BUG!! nrows=' + IntToStr(fM) + '< ncols=' + IntToStr(fK) +
      '. SVD not defined. Number of nodes should be larger than number of RBF.');
    halt;
  end;
  fDeff:=SV_SetZero(S, 1, M, 1E-18); //Beware of this constant if increasing precision (E-18)
  InvSVD(U, S, V, 1, K, M, Phi1); //
  for id := 1 to fD do
    for im := 1 to fM do//
    begin
      W[id, im] := 0;
      for ik := 1 to fK do
      begin
        W[id, im] := W[id, im] + Phi1[im, ik] * CX[ik, id];
      end;
    end;
end;

procedure TGTMFull.Project();
begin
  inherited Project;
end;

procedure TGTMFull.Project(flenme: string);
begin
  ReadMols(flenme);
  Project();
end;

procedure TGTMFull.Zremove(aii: integer);
var
  ii,id: integer;
begin
  for ii:=aii+1 to fN do
  begin
    for id:=1 to fD do
    begin
      fZ[ii-1,id]:=fZ[ii,id];
      fX[ii-1,id]:=fX[ii,id];
    end;
  end;
  N:=N-1;
  DimMatrix(fZ,fN,fD);
  DimMatrix(fX,fN,fD);
  //Warning: fZ and fX has changed geometry; not R and matPrj
end;

constructor TGTMFull.Create;
begin
  inherited Create;
  Randomize;//Initiate a random number generator;
  // Initialize matrices to nil
  fX:=nil;
  fMean:=nil;
  fSD:=nil;
  fZ:=nil;
  fistd:=1;//default is standardize
  fiScaleInit:=0;
  ffScaleInit:=0.0;
  fbPC123Set:=False;
end;

destructor TGTMFull.Destroy;
begin
  inherited Destroy;
end;

end.
