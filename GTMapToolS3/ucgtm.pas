unit UcGTM;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, UGTMFull, utypes, ulinalg, math, ucholesk;

type

  { TcGTM }

  TcGTM = class(TGTMFull)
  private
    //procedure UpdatePr();
  protected
    falpha: double; //Regularization factor
    fmatY: TMatrix; //KxD matrix of K latent variable samples in the D dimensional data space
    fdist2: TMatrix; //NxK matrix of squared distance between Yik and Zii
    fPRZ, fW_D: TVector; //M Vectors, the right hand member of W update, the Dth update of W.
    fLLM: TVector;//Contribution of a compound to the Loglikelyhood
    fPGP, fPGPL: TMatrix; //Phi^T*G*Phi, an intermediate MxM matrix to update W, PGPL is the cholesky decomposition of PGP
    fRZ: TMatrix; //KxD matrix, calculation intermediate
    fG: TVector; //Gik=sum_ii=1^N R_ik,ii, the diagonal matrix to update W
    //fPr: TMatrix; // NxK Probability of instance n for a sample k
    procedure UpdateMatY();
    procedure CompDist2();
  public
    property alpha: double read falpha write falpha;
    property matY: TMatrix read fmatY;
    property LLM: TVector read fLLM;
    procedure LoadZ(ZT: TMatrix);
    procedure Init(); override;
    procedure Init(Nmax: integer);
    procedure Init(kSamples, mTraits: integer; asigma: double=-1.0); override;
    procedure Init1(kSamples, mTraits: integer; asigma: double=-1.0; aalpha: double=-1.0);
    procedure Initb(ZT: TMatrix; Nmax: integer);
    procedure Expectation();
    procedure Maximization();
    function LogLikelyHood(): double; override;
    procedure Project(ZT: TMatrix; Nmax: integer); override;
    constructor Create; override;
    destructor Destroy; override;
  published
  end;

implementation

{ TcGTM }

procedure TcGTM.UpdateMatY;
var
  ik, id, im: integer;
begin
  //Y=W*Phi
  for ik:=1 to K do
    for id:=1 to D do
    begin
      fmatY[ik,id]:=0;
      for im:=1 to M do
        fmatY[ik,id]:=fmatY[ik,id]+W[id,im]*Phi[ik,im];
    end;
  //WARNING: fdist2 is obsolete now. Use CompDist2  for update
end;

procedure TcGTM.CompDist2;
//Compute (Y-Z)^2
var
  ii, ik, id: integer;
begin
  for ii:=1 to N do
    for ik:=1 to K do
    begin
     fdist2[ii,ik]:=0;
     for id:=1 to D do
       fdist2[ii,ik]:=fdist2[ii,ik]+sqr(fmatY[ik,id]-Z[ii,id]);
    end;
end;

{procedure TcGTM.UpdatePr;
const
  valmin=-103.2109;
var
  ik, ii: integer;
  val: double;
begin
  // Compute the non-normalized probabilities of instances.
  // In high dimensional spaces, the probabilities cannot be valued.
  // Therefore, they are scaled by a factor exp(-min(beta*dist2/2)).
  fdist2min:=MaxDouble;
  for ik:=1 to K do
    for ii:=1 to N do
      if fdist2[ii,ik]<fdist2min then fdist2min:=fdist2[ii,ik]; //got the min distance from manifold to data
  //
  for ik:=1 to K do
    for ii:=1 to N do
    begin
      if (beta<0) or (fdist2[ii,ik]<0) then
      begin
        writeln('BUG: beta='+FloatToStr(beta)+' fdist2['+IntToStr(ii)+','+IntToStr(ik)+']='+FloatToStr(fdist2[ii,ik]));
        halt;
      end;
      val:=-beta*(fdist2[ii,ik]-fdist2min)/2; //Don't forget this factor to compute final probability value.
      if val > valmin then
        fPr[ii,ik]:=exp(val)
      else
        fPr[ii,ik]:=MinDouble;
      //val:=exp(-beta*(fdist2[ii,ik]-fdist2min)/2);
      //if IsInfinite(val) or IsNan(val) or (IsZero(val,2*MinDouble)) then
      //  fPr[ii,ik]:=MinDouble// 0
      //else
      //  fPr[ii,ik]:=val;
    end;
end;}

procedure TcGTM.LoadZ(ZT: TMatrix);
var
  ii, id: integer;
begin
  for ii:=1 to N do
    for id:=1 to fD do
      fZ[ii,id]:=ZT[ii,id];
end;

procedure TcGTM.Init;
begin
  inherited Init;
  DimMatrix(fmatY,K,D);
  DimVector(fPRZ,M);
  DimVector(fW_D,M);
  DimMatrix(fRZ,K,D);
  DimMatrix(fdist2,N,K);
  DimVector(fG,K);
  DimMatrix(fPGP,M,M);
  DimMatrix(fPGPL,M,M);
  //DimMatrix(fPr,N,K);
  DimVector(fLLM,N);
end;

procedure TcGTM.Init(Nmax: integer);
begin
  fN:=Nmax;
  Init;
  DimMatrix(fZ,N,D);
end;

procedure TcGTM.Init(kSamples, mTraits: integer; asigma: double);
begin
  inherited Init(kSamples, mTraits, asigma);
  DimMatrix(fmatY,K,D);
  DimVector(fPRZ,M);
  DimVector(fW_D,M);
  DimMatrix(fRZ,K,D);
  DimMatrix(fdist2,N,K);
  DimVector(fG,K);
  DimMatrix(fPGP,M,M);
  DimMatrix(fPGPL,M,M);
  //DimMatrix(fPr,N,K);
  DimVector(fLLM,N);
  UpdateMatY();
  CompDist2;
end;

procedure TcGTM.Init1(kSamples, mTraits: integer; asigma: double; aalpha: double
  );
begin
  Init(kSamples,mTraits,asigma);
  if aalpha=-1.0 then
  begin
    falpha:=1/(D*M);//W distribution standard dev set to unity
    writeln('Default value of the regularization factor: '+FloatToStrF(falpha,ffGeneral,8,5));
  end
  else falpha:=aalpha;
end;

procedure TcGTM.Initb(ZT: TMatrix; Nmax: integer);
//Initialization procedure for block based GTM
//The Z matrix is replaced by the one of a new data block
begin
  N:=Nmax; //The number of instances might have changed
  //Resize matrices according to new value of N
  DimMatrix(fZ,N,D);
  DimMatrix(fdist2,N,K);
  //DimMatrix(fPr,N,K);
  DimMatrix(fR,K,N);
  //Load data to Z, compute Y and update dist2
  LoadZ(ZT);
  //UpdateMatY();
  CompDist2();
end;

procedure TcGTM.Expectation;
const
  //valmin=-1E300;
  valmin=-103.2109;//-36.84136;
  evalmin=1.5E-45;//exp(valmin);
var
  ik, ii: integer;
  val, Rmin: double;
begin
  {Rin=p(tn|xi)/sum_j p(tn|xj). Normalisation factors of gaussians do not depend
  on n or i.
  Normalization: Sum_i Rin=1
  R=exp(-beta(Y_i-t_n)) can be impossible to evaluate. Removing the min value
  of -beta(Y_i-t_n) for fixed value of n does not change the result because of
  normalization over i index.}
  for ii:=1 to N do
  begin
    Rmin:=MaxDouble;
    for ik:=1 to K do
    begin
      fR[ik,ii]:=beta*fdist2[ii,ik]/2;
      if fR[ik,ii]<=Rmin then Rmin:=fR[ik,ii];
    end;
    for ik:=1 to K do
    begin
      val:=Rmin-fR[ik,ii];
      if val < valmin then //Do not count responsabilities below 1E-16
        fR[ik,ii]:=0//MinDouble//evalmin //Cancel insignificant responsibilities improves the speed and does not deteriorate the result.
      else
        fR[ik,ii]:=exp(val);//exp(-beta*(Yik-Tii)^2/2);
    end;
  end;
  NormalizeByColumn(fR,1,K,1,N);
end;

procedure TcGTM.Maximization;
var
  im, im1, im2, ik, id, ii: integer;
begin
  //Compute G
  for ik:=1 to K do
  begin
    fG[ik]:=0;
    for ii:=1 to N do
      fG[ik]:=fG[ik]+fR[ik,ii];
  end;
  //Compute Phi^T*G*Phi
  for im1:=1 to M do
  begin
    for im2:=1 to M do
    begin
      fPGP[im1,im2]:=0;
      for ik:=1 to K do
        fPGP[im1,im2]:=fPGP[im1,im2]+Phi[ik,im1]*Phi[ik,im2]*fG[ik];
    end;
    fPGP[im1,im1]:=fPGP[im1,im1]+falpha/beta;
  end;
  Cholesky(fPGP,fPGPL,1,M);
  // Compute RZ
  for ik:=1 to K do
    for id:=1 to D do
    begin
      fRZ[ik,id]:=0;
      for ii:=1 to N do
        fRZ[ik,id]:=fRZ[ik,id]+R[ik,ii]*Z[ii,id];
    end;
  // Update W
  for id:=1 to D do
  begin
    for im:=1 to M do
    begin
      fPRZ[im]:=0;
      for ik:=1 to K do
        fPRZ[im]:=fPRZ[im]+Phi[ik,im]*fRZ[ik,id];
    end;
    SolvCh(fPGPL,1,M,fPRZ,fW_D);
    for im:=1 to M do
      fW[id,im]:=fW_D[im];
  end;
  //Update Y and Compute (Y-Z)^2
  UpdateMatY();
  CompDist2;
  //Update beta
  beta:=0;
  for ii:=1 to N do
    for ik:=1 to K do
    begin
      beta:=beta+R[ik,ii]*fdist2[ii,ik];
    end;
  beta:=N*D/beta;
  //increment EM count
  Inc(fnIter);
end;

function TcGTM.LogLikelyHood(): double;
const
  valmin=-103.2109;
var
  ii,ik: integer;
  mindist2,val,sum,LLbase: double;
begin
  //The min distance between the manifold and the datapoint is factorized
  //The factor is then added to the calculation of the dataset loglikelyhood
  Result:=0;
  for ii:=1 to N do
  begin
    mindist2:=MaxDouble;
    for ik:=1 to K do
      if fdist2[ii,ik]<mindist2 then mindist2:=fdist2[ii,ik]; //got the min distance from manifold to data
    fLLM[ii]:=D*ln(beta/(2*3.14159265359))/2-ln(K)-beta*mindist2/2;
    sum:=0;
    for ik:=1 to K do
    begin
      val:=-beta*(fdist2[ii,ik]-mindist2)/2; //Don't forget this factor to compute final probability value.
      if val > valmin then
        sum:=sum+exp(val);
    end;
    fLLM[ii]:=fLLM[ii]+ln(sum);
    Result:=Result+fLLM[ii];
  end;
  Result:=Result/N;
end;

procedure TcGTM.Project(ZT: TMatrix; Nmax: integer);
var
  i: integer;
begin
  If (N<>Nmax) then
  begin
    N:=Nmax;
    setlength(fZ,0,0);
    setlength(fdist2,0,0);
    setlength(fR,0,0);
    setlength(fLLM,0);
    //Resize matrices according to new value of N
    DimMatrix(fZ,N,D);
    DimMatrix(fdist2,N,K);
    DimMatrix(fR,K,N);
    DimVector(fLLM,N);
  end;
  //Load data to Z, compute Y and update dist2
  LoadZ(ZT);
  UpdateMatY();
  CompDist2();
  //Update R and Pr
  Expectation();
  //UpdatePr();
  //Compute projection
  inherited Project();
end;

constructor TcGTM.Create;
begin
  inherited Create;
  falpha:=0;
  //Initialize matrices to nil
  fmatY:=nil;
  fPRZ:=nil;
  fW_D:=nil;
  fRZ:=nil;
  fdist2:=nil;
  fG:=nil;
  fPGP:=nil;
  fPGPL:=nil;
  //fPr:=nil;
  fLLM:=nil;
  //fdist2min:=-1;
end;

destructor TcGTM.Destroy;
begin
  inherited Destroy;
end;

end.

