unit UiGTM;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, UGTMFull, UcGTM, utypes, ulinalg, math, ucholesk, usvd;

type

  { TiGTM }

  TiGTM = class(TcGTM)
  private
    fRo, fdist2o: TMatrix;
    fbetao: double;
    fLL: double;
    finmin, finmax, fNblk: integer;//Number of blocks.
    //procedure UpdatePr(iimin, iimax: integer);
  public
    property Nblk: integer read fNblk write fNblk;
    property LL: double read fLL write fLL;
    procedure Init(Nb: integer);
    procedure Init(kSamples, mTraits: integer; Nb: integer; asigma: double=-1.0);
    procedure Init1(kSamples, mTraits: integer; Nb: integer; asigma: double=-1.0; aalpha: double=-1.0; aiScaleInit: integer=0; afScaleInit: double=0.0);
    procedure CompDist2(iimin,iimax: integer);
    procedure Expectation(iimin, iimax: integer);
    procedure Maximization(iimin, iimax: integer);
    function LogLikelyHood(iimin, iimax: integer): double;
    constructor Create;
    destructor Destroy; override;
  end;

implementation

{ TiGTM }

{procedure TiGTM.UpdatePr(iimin, iimax: integer);
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
  // Compute the probabilities of instances.
  for ik:=1 to K do
    for ii:=iimin to iimax do
    begin
      if (beta<0) or (fdist2[ii,ik]<0) then
      begin
        writeln('BUG: beta='+FloatToStr(beta)+' fdist2['+IntToStr(ii)+','+IntToStr(ik)+']='+FloatToStr(fdist2[ii,ik]));
        halt;
      end;
      val:=exp(-beta*(fdist2[ii,ik]-fdist2min)/2);//Don't forget this factor to compute final probability value.
      if IsInfinite(val) or IsNan(val) or IsZero(val) then
        fPr[ii,ik]:=MinDouble//0
      else
        fPr[ii,ik]:=val*power(beta/(2*3.14159265359),D);
    end;
end;}

procedure TiGTM.Init(Nb: integer);
begin
  fNblk:=Nb;
  inherited Init();
  DimMatrix(fRo,K,fNblk);
  DimMatrix(fdist2o,fNblk,K);
end;

procedure TiGTM.Init(kSamples, mTraits: integer; Nb: integer; asigma: double);
begin
  fNblk:=Nb;
  inherited Init(kSamples, mTraits, asigma);
  DimMatrix(fRo,K,fNblk);
  DimMatrix(fdist2o,fNblk,K);
end;

procedure TiGTM.Init1(kSamples, mTraits: integer; Nb: integer; asigma: double;
  aalpha: double; aiScaleInit: integer; afScaleInit: double);
begin
  fNblk:=Nb;
  iScaleInit:=aiScaleInit;
  fScaleInit:=afScaleInit;
  inherited Init1(kSamples, mTraits, asigma, aalpha);
  DimMatrix(fRo,K,fNblk);
  DimMatrix(fdist2o,fNblk,K);
end;

procedure TiGTM.CompDist2(iimin, iimax: integer);
//Compute (Y-Z)^2
var
  ii, ii1, ik, id: integer;
begin
  for ii:=iimin to iimax do
  begin
    ii1:=ii-iimin;
    for ik:=1 to K do
    begin
      fdist2o[ii1,ik]:=fdist2[ii,ik];
    end;
  end;
  for ii:=iimin to iimax do
    for ik:=1 to K do
    begin
     fdist2[ii,ik]:=0;
     for id:=1 to D do
       fdist2[ii,ik]:=fdist2[ii,ik]+sqr(fmatY[ik,id]-Z[ii,id]);
    end;
end;

procedure TiGTM.Expectation(iimin, iimax: integer);
const
  valmin=-36.84136;
  evalmin=exp(-36.84136);
var
  ik, ii, ii1, id: integer;
  val, Rmin, Pmin: double;
  nrm: double;
begin
  {Rin=p(tn|xi)/sum_j p(tn|xj). Normalisation factors of gaussians do not depend
  on n or i.
  Normalization: Sum_i Rin=1
  R=exp(-beta(Y_i-t_n)) can be impossible to evaluate. Removing the min value
  of -beta(Y_i-t_n) for fixed value of n does not change the result because of
  normalization over i index.}
  for ii:=iimin to iimax do
  begin
    ii1:=ii-iimin;
    for ik:=1 to K do
    begin
      fRo[ik,ii1]:=fR[ik,ii];
    end;
  end;
  for ii:=iimin to iimax do
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
    NormalizeByColumn1(fR,1,K,ii);
  end;
end;

procedure TiGTM.Maximization(iimin, iimax: integer);
var
  im, im1, im2, ik, id, ii, ii1: integer;
  dist2: double;
  dW,dWsum: double;
  XX, B: TVector;
  U,V: TMatrix;
  S: TVector;
begin
  //Compute G
  for ik:=1 to K do
  begin
    for ii:=iimin to iimax do
    begin
      ii1:=ii-iimin+1;
      fG[ik]:=fG[ik]+fR[ik,ii]-fRo[ik,ii1];//Substitute old block responsabilities with updated ones
    end;
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
      for ii:=iimin to iimax do
      begin
        ii1:=ii-iimin;
        fRZ[ik,id]:=fRZ[ik,id]+(fR[ik,ii]-fRo[ik,ii1])*Z[ii,id];//Substitute old block responsabilities with updated ones
      end;
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
  UpdateMatY(True);
  CompDist2(iimin,iimax);
  //Update beta
  beta:=beta/(N*D);
  beta:=1/beta;
  for ii:=iimin to iimax do
  begin
    ii1:=ii-iimin;
    for ik:=1 to K do
    begin
      beta:=beta+R[ik,ii]*fdist2[ii,ik]-fRo[ik,ii1]*fdist2o[ii1,ik];//Substitute old block responsabilities and distances with updated ones
    end;
  end;
  beta:=N*D/beta;
  //increment EM count
  Inc(fnIter);
end;

function TiGTM.LogLikelyHood(iimin, iimax: integer): double;
const
  valmin=-103.2109;
var
  ii,ik,dN: integer;
  val,sum,mindist2: double;
begin
  dN:=iimax-iimin+1;
  //The min distance between the manifold and the datapoint is factorized
  //The factor is then added to the calculation of the dataset loglikelyhood
  Result:=0;
  for ii:=iimin to iimax do
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
  Result:=Result/dN;
end;
{Previous implementation
var
  ii,ik: integer;
  sum, val, dsum: double;
  LLo, LLn: double;
begin
  LLo:=0;
  for ii:=iimin to iimax do
  begin
    sum:=0;
    for ik:=1 to K do
      if fPr[ii,ik]>0 then
      begin
        sum:=sum+fPr[ii,ik];
      end;
    if sum>0 then
    begin
      LLo:=LLo+ln(sum/K);
    end;
  end;
  //
  UpdatePr(iimin,iimax);
  //
  LLn:=0;
  for ii:=iimin to iimax do
  begin
    sum:=0;
    for ik:=1 to K do
      if fPr[ii,ik]>0 then
      begin
        sum:=sum+fPr[ii,ik];
      end;
    if sum>0 then
    begin
      LLn:=LLn+ln(sum/K);
    end;
  end;
  //
  fLL:=fLL+LLn-LLo;
  Result:=fLL/fN;
end;}

constructor TiGTM.Create;
begin
  inherited Create;
  fRo:=nil;
  fdist2o:=nil;
  fbetao:=0;
end;

destructor TiGTM.Destroy;
begin
  inherited Destroy;
end;

end.

