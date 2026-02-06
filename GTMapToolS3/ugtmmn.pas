unit UGTMMN;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, ulinalg, utypes, ULinAlgSparse, ISIDA_descriptor, UGTMSparse;

type

  PdXY= ^dXY;
  dXY=record
    X: double;
    Y: double;
  end;

  AdXY= array of dXY;

  { TuGTMMN }

  TuGTMMN = class(TGTMSparse)
  private
    fepsilon: double; //Fixed granularity. a=b if |a-b|<fespilon
    fWPhi, flWPhi: TMatrix;//DxK temporary storage for WPhi and log(WPhi)
    fPrior: TVector; //Prior probabilities for the K concepts
    fLmax, fKmax: integer; //fKmax and fLmax are the length of the squares (square roots of fK and fL)
    fNblk: integer; //Block size for online algorithm
  public
    constructor Create;
    destructor Destroy; override;
    procedure ResetZ;
    procedure RedimR(newN,newK :integer);
    procedure Init(); override;
    procedure Init(Nmax: integer);
    procedure Init(kSamples, mTraits: integer; asigma: double); override;
    procedure Init(kSamples, mTraits: integer; asigma: double; Nb: integer);
    procedure Expectation(); //Compute responsabilities. R = exp(log(APhi)D).
    function Maximization(): double; //Maximization step. Anew=Aold.*((DR)./APhi)*Phi.
    function LogLikelyhood(): double; //Compute Loglikelyhood - Best map is the one that maximize out-of-the-bag likelyhood varying the complexity L with a fixed resolution K
    procedure Project(ZT: TSMatrix); override;
    procedure Project(); override;
    property epsilon: double read fepsilon write fepsilon;//fepsilon should set 1E-16
    property NBlk: integer read fNblk;
    property WPhi: TMatrix read fWPhi;//DxK storage. The coordinates of latent space in D-dimensional space
  end;

function Equal(a, b, e: double): boolean;

implementation

function Equal(a, b, e: double): boolean;
begin
  Result:=abs(a-b)<e;
end;

{ TGTMMN }

constructor TuGTMMN.Create;
begin
  fepsilon:=1E-16;
  fWPhi:=nil; flWPhi:=nil;
  fPrior:=nil;
  fLmax:=0; fKmax:=0;
  fNblk:=0;
  inherited Create;
end;

destructor TuGTMMN.Destroy;
begin
  inherited Destroy;
end;

procedure TuGTMMN.ResetZ;
begin
  fZ.Clear;//beware that number of columns shall be keep fixed.
end;

procedure TuGTMMN.RedimR(newN, newK: integer);
begin
  DimMatrix(fR,newK,newN);
end;

procedure TuGTMMN.Init;
begin
  inherited Init;
  //Phi are normalized RBF over m. Is not sparse unless fM>12.
  NormalizeByLine(fPhi,1,fK,1,fM);
  // Set memory space for WPhi matrices and for the priors.
  DimMatrix(fWPhi,fD,fK);
  DimMatrix(flWPhi,fD,fK);
  DimVector(fPrior,fK);
  //init grids   Xl->matM Xk->matX
end;

procedure TuGTMMN.Init(Nmax: integer);
begin
  fN:=Nmax;
  Init;
end;

procedure TuGTMMN.Init(kSamples, mTraits: integer; asigma: double);
begin
  if asigma<=0 then
  begin
    asigma:=2*2/(mTraits-1);
    asigma:=2/(2*sqrt(asigma));//sigma=twice the distance between two neighboring x_m
    writeln('Default RBF width value: '+FloatToStr(asigma));
  end;
  inherited Init(kSamples, mTraits, asigma);
end;

procedure TuGTMMN.Init(kSamples, mTraits: integer; asigma: double; Nb: integer);
begin
  fNblk:=Nb;
  Init(kSamples,mTraits,asigma);
end;

procedure TuGTMMN.Expectation;
var
  ir, ik, id, im, il: integer;
  Rmax, dval: double;
begin
  //matmatmult(fW,fPhi,fWPhi,1,fM,1,fD,1,fK);//fWPhi dim DxK, W dim DxM, Phi dim KxM
  for id:=1 to fD do
    for ik:=1 to fK do
    begin
      fWPhi[id,ik]:=0;
      for im:=1 to M do
        fWPhi[id,ik]:=fWPhi[id,ik]+W[id,im]*fPhi[ik,im]
    end;
  NormalizeByColumn(fWPhi,1,fD,1,fK);//Sum over t of APhi is one
  for id:=1 to fD do
    for ik:=1 to fK do
      if (fWPhi[id,ik]<>0) then
        flWPhi[id,ik]:=ln(fWPhi[id,ik])
      else flWPhi[id,ik]:=0;
  //Product [APhi]^t[D]
  for ik:=1 to fK do
    for ir:=1 to fN do
      fR[ik,ir]:=0;
  for il:=0 to fZ.Count-1 do
  begin
    ir:=PTRecMatrix(fZ.Items[il])^.ir;
    id:=PTRecMatrix(fZ.Items[il])^.ic;
    dval:=PTRecMatrix(fZ.Items[il])^.dval;
    for ik:=1 to fK do
      fR[ik,ir]:=fR[ik,ir]+dval*flWPhi[id,ik];
  end;
  //SMatTMatMultt(fZ,flWPhi,fR,1,fD,1,fK,1,fN); //Bug wrong geometry of fR?
  for ir:=1 to fN do //Set the max value of R=log(APhi)*D to 0 so that expenential calculation is stable.
  begin
    Rmax:=fR[1,ir];
    for ik:=1 to fK do
      if Rmax<fR[ik,ir] then Rmax:=fR[ik,ir];
    for ik:=1 to fK do fR[ik,ir]:=fR[ik,ir]-Rmax;
  end;
  for ir:=1 to fN do
    for ik:=1 to fK do
      fR[ik,ir]:=exp(fR[ik,ir]);//Round to zero when necessary
  NormalizeByColumn(fR,1,fK,1,fN);
end;

function TuGTMMN.Maximization(): double;//output the convergence criteria
var
  ii,id,im,ik,ikk: integer;
  val, Update: double;
  Zele: PTRecMatrix;
  Wnew: TMatrix;
begin
  Wnew:=nil;
  DimMatrix(Wnew,fD,fM);
  for ikk:=0 to fZ.Count-1 do //Anew=A.*((DR./APhi)*Phi)
  begin
    Zele:=PTRecMatrix(fZ[ikk]);
    ii:=Zele^.ir;
    id:=Zele^.ic;
    val:=Zele^.dval;
    for im:=1 to fM do
    begin
      Update:=0;
      for ik:=1 to fK do
        if (fWPhi[id,ik]<>0) then
          Update:=Update+fR[ik,ii]*fPhi[ik,im]/fWPhi[id,ik];
      Wnew[id,im]:=Wnew[id,im]+val*Update*fW[id,im];
    end;
  end;
  NormalizeByColumn(Wnew,1,fD,1,fM); //normalize Anew
  Result:=0;
  for id:=1 to fD do //A<-Anew
    for im:=1 to fM do
      begin
        Result:=Result+abs(fW[id,im]-Wnew[id,im]);
        fW[id,im]:=Wnew[id,im];
      end;
  Result:=Result/(fD*fM); // scale independent of geometry
end;

function TuGTMMN.LogLikelyhood: double;
var
  ikk,ii,id,ik: integer;
  val: double;
  Zele: PTRecMatrix;
  Pnk:TMatrix; //ln(P(dn|xk))
begin
  DimMatrix(Pnk,fN,fK);
  for ikk:=0 to fZ.Count-1 do //Anew=A.*((DR./APhi)*Phi)
  begin
    Zele:=PTRecMatrix(fZ[ikk]);
    ii:=Zele^.ir;
    id:=Zele^.ic;
    val:=Zele^.dval;
    for ik:=1 to fK do
      Pnk[ii,ik]:=Pnk[ii,ik]+flWPhi[id,ik]*val;
  end;
  Result:=0;
  for ii:=1 to fN do
    for ik:=1 to fK do
      Result:=Result+exp(Pnk[ii,ik]);
  Result:=ln(Result)/(fN*fK);
end;

procedure TuGTMMN.Project(ZT: TSMatrix);
var
  ii, id: integer;
  pitem: PTRecMatrix;
begin
  //Load data to Z
  fZ.Clear;
  for ii:=0 to ZT.Count-1 do //Deep copy of ZT
  begin
    pitem:=PTRecMatrix(ZT[ii]);
    fZ.AddElement(pitem^.ir,pitem^.ic,pitem^.dval);
  end;
  N:=fZ.irmax;
  DimMatrix(fR,fK,fN);
  //Update R and Pr
  Expectation();
  //Compute projection
  Project();
end;

procedure TuGTMMN.Project;
begin
  inherited Project;
end;

end.

