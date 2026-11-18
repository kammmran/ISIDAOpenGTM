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
    procedure CompDist2();
  public
    procedure UpdateMatY(bFixSelNode: boolean=False);
    property alpha: double read falpha write falpha;
    property matY: TMatrix read fmatY;
    property LLM: TVector read fLLM;
    procedure LoadZ(ZT: TMatrix);
    procedure ResizeMatX(newK: integer); override;
    procedure ResizeMatX(newKr,newKc: integer); override;
    procedure Init(); override;
    procedure Init(Nmax: integer);
    procedure Init(kSamples, mTraits: integer; asigma: double=-1.0); override;
    procedure Init1(kSamples, mTraits: integer; asigma: double=-1.0; aalpha: double=-1.0; aiScaleInit: integer=0; afScaleInit: double=0.0);
    procedure Initb(ZT: TMatrix; Nmax: integer);
    procedure Expectation();
    procedure ExpectationOnSelected();
    procedure Maximization();
    function LogLikelyHood(): double; override;
    function LogLikelyHoodOnSelected(): double;
    function LogLikelyHoodFromManifold(amatY: TMatrix): double;
    function LogLikelyHood(aZ: TVector; var aR: TVector): double;//LLikelihood of one instance
    function LogLikelyHood(aZ: TMatrix): double;//LLikelihood of a batch of instance
    function LogLikelyHoodOnSelected(aZ: TMatrix): double;//LLikelihood of a batch of instance about selected nodes
    procedure MapToSpace(amatX: TMatrix);//From sampling of a part of the manifold, recompute the manifold, changes fmatY
    procedure MapToSpace(amatX,amatY: TMatrix);//From sampling of a part of the manifold, recompute the manifold, output amatY
    procedure Generate(Nsmple:integer; var SmpleZ, SmpleX:TMatrix);
    procedure Project(); override;
    procedure Project(bmatY,bselnode,bdist2,bexpectation:boolean);//Projection method with control over elements of the model: update the manifold (matY), restrict to selected nodes, update the distance matrix, recompute the responsibilites
    procedure Project(ZT: TMatrix; Nmax: integer); override;
    procedure Zremove(LLt: double);//Remove unlikely instances
    procedure SetX; override;//update the scaling if data have changed
    procedure SetX(aX: TMatrix); override;
    procedure SetW(CX: TMatrix);override;//Fit the manifold to a user defined geometry
    constructor Create; override;
    destructor Destroy; override;
  published
  end;

implementation

{ TcGTM }

procedure TcGTM.UpdateMatY(bFixSelNode: boolean);
var
  ik, id, im: integer;
  sl:TStringList;
begin
  //Y=W*Phi
  //
  if not bFixSelNode then
  begin
    for ik:=1 to K do
      for id:=1 to D do
      begin
        fmatY[ik,id]:=0;
        for im:=1 to M do
        begin
          fmatY[ik,id]:=fmatY[ik,id]+W[id,im]*Phi[ik,im];
        end;
      end;
  end else // I think this should not be used... unless the fmatY (coordinates of the manifold in the dataframe) are setup properly
  begin
    for ik:=1 to K do
      if (SelNode[ik]=True) then //Selected nodes are updatable
        for id:=1 to D do
        begin
          fmatY[ik,id]:=0;
          for im:=1 to M do
          begin
            fmatY[ik,id]:=fmatY[ik,id]+W[id,im]*Phi[ik,im];
          end;
        end;
  end;
  //WARNING: fdist2 is obsolete at this point. Use CompDist2  for update
end;

procedure TcGTM.CompDist2();
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

procedure TcGTM.ResizeMatX(newK: integer);
begin
  fK:=newK;
  Init();
  inherited ResizeMatX(newK);
end;

procedure TcGTM.ResizeMatX(newKr, newKc: integer);
begin
  fK:=newKr*newKc;
  Init();
  inherited ResizeMatX(newKr, newKc);
end;

procedure TcGTM.Init();
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
  inherited Init(kSamples, mTraits, asigma);//It goes through Init()
  {DimMatrix(fmatY,K,D);
  DimVector(fPRZ,M);
  DimVector(fW_D,M);
  DimMatrix(fRZ,K,D);
  DimMatrix(fdist2,N,K);
  DimVector(fG,K);
  DimMatrix(fPGP,M,M);
  DimMatrix(fPGPL,M,M);
  //DimMatrix(fPr,N,K);
  DimVector(fLLM,N);}
  //W is either initialized above or loaded from a model file (Restart).
  //In both cases Y and the distances must be computed, otherwise the first
  //Expectation step sees all distances as zero, the responsibilities become
  //uniform and continued training collapses the manifold.
  UpdateMatY();
  CompDist2;
end;

procedure TcGTM.Init1(kSamples, mTraits: integer; asigma: double; aalpha: double;
  aiScaleInit: integer; afScaleInit: double);
begin
  iScaleInit:=aiScaleInit;
  fScaleInit:=afScaleInit;
  Init(kSamples,mTraits,asigma);
  if aalpha=-1.0 then
  begin
    falpha:=1.0;///(D*M);//W distribution standard dev set to unity
    //writeln('Default value of the regularization factor: '+FloatToStrF(falpha,ffGeneral,8,5));
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

procedure TcGTM.Expectation();
const
  //valmin=-1E300;
  valmin=-103.2109;//-36.84136;
  //evalmin=1.5E-45;//exp(valmin);
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
  //PrintMat(fdist2,1,5,1,5);
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
      else//931, 952, 973, 986, 994, 1007, 1015, 1020, 1028, 1036, 1041, 1049, 1057, 1062, 1070, 1075, *1083, 1091, 1096, **1104, 1112, 1117, *1125, **1138, 1146, 1151, **1159, 1172, *1180, 1193, 1201, 1214
        fR[ik,ii]:=exp(val);//+MinDouble//+evalmin//exp(-beta*(Yik-Tii)^2/2);
    end;
  end;
  NormalizeByColumn(fR,1,K,1,N);
end;

procedure TcGTM.ExpectationOnSelected();
//Responsibility calculations restricted to selected nodes
const
  //valmin=-1E300;
  valmin=-103.2109;//-36.84136;
  //evalmin=1.5E-45;//exp(valmin);
var
  ik, ii: integer;
  val, Rmin: double;
  R0: TMatrix;
begin
  {Rin=p(tn|xi)/sum_j p(tn|xj). Normalisation factors of gaussians do not depend
  on n or i.
  Normalization: Sum_i Rin=1
  R=exp(-beta(Y_i-t_n)) can be impossible to evaluate. Removing the min value
  of -beta(Y_i-t_n) for fixed value of n does not change the result because of
  normalization over i index.}
  DimMatrix(R0,K,N);
  for ik:=1 to K do
    for ii:=1 to N do
      R0[ik,ii]:=fR[ik,ii]; // Save the current responsibilities
  Expectation();
  for ik:=1 to K do
    for ii:=1 to N do
      if not SelNode[ik] then
        fR[ik,ii]:=R0[ik,ii]; // Restore the previous responsibilities for frozen nodes
  {for ii:=1 to N do
  begin
    Rmin:=MaxDouble;
    for ik:=1 to K do
      if SelNode[ik] then //SelNodes are used for computing projections and are updatable during optimization
      begin
        fR[ik,ii]:=beta*fdist2[ii,ik]/2;
        if fR[ik,ii]<=Rmin then Rmin:=fR[ik,ii];
      end else begin

      end;
    for ik:=1 to K do
      if SelNode[ik] then
        begin
          val:=Rmin-fR[ik,ii];
          if val < valmin then //Do not count responsabilities below 1E-16
            fR[ik,ii]:=0//MinDouble//evalmin //Cancel insignificant responsibilities improves the speed and does not deteriorate the result.
          else//931, 952, 973, 986, 994, 1007, 1015, 1020, 1028, 1036, 1041, 1049, 1057, 1062, 1070, 1075, *1083, 1091, 1096, **1104, 1112, 1117, *1125, **1138, 1146, 1151, **1159, 1172, *1180, 1193, 1201, 1214
            fR[ik,ii]:=exp(val);//+MinDouble//+evalmin//exp(-beta*(Yik-Tii)^2/2);
        end;
  end;
  NormalizeByColumn(fR,1,K,1,N);//Normalisation is made on all nodes, but non selected nodes are set to 0}
end;

procedure TcGTM.Maximization();
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
  UpdateMatY(True); //The D-space position of non-selected nodes is reset
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
  mindist2,val,sum{,LLbase}: double;
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

function TcGTM.LogLikelyHoodOnSelected(): double;
//Compute the responsibilities and the likelihood based on a portion of map.
//If you need responsibilities, use the Expectation function
const
  valmin=-103.2109;
var
  ii, ik, id: integer;
  mindist2,val,sum{,LLbase}: double;
begin
  {Rin=p(tn|xi)/sum_j p(tn|xj). Normalisation factors of gaussians do not depend
  on n or i.
  Normalization: Sum_i Rin=1
  R=exp(-beta(Y_i-t_n)) can be impossible to evaluate. Removing the min value
  of -beta(Y_i-t_n) for fixed value of n does not change the result because of
  normalization over i index.}
  //Compute the loglikelihood at the same time.
  Result:=0;
  for ii:=1 to N do
  begin
    mindist2:=MaxDouble;
    for ik:=1 to K do
      if SelNode[ik] then // Compute with selected nodes only
        if fdist2[ii,ik]<mindist2 then mindist2:=fdist2[ii,ik]; //got the min distance from manifold to data
    if mindist2<MaxDouble then
      fLLM[ii]:=D*ln(beta/(2*3.14159265359))/2-ln(K)-beta*mindist2/2
    else fLLM[ii]:=-Infinity;
    sum:=0;
    for ik:=1 to K do
      if SelNode[ik] then // Compute only on selected nodes
      begin
        val:=-beta*(fdist2[ii,ik]-mindist2)/2; //Don't forget this factor to compute final probability value.
        if val > valmin then
          sum:=sum+exp(val);
      end;
    if (sum>0) then fLLM[ii]:=fLLM[ii]+ln(sum) else fLLM[ii]:=-Infinity;
    Result:=Result+fLLM[ii];
  end;
  Result:=Result/N;
end;

function TcGTM.LogLikelyHoodFromManifold(amatY: TMatrix): double;
//Compute the responsibilities and the likelihood based on a portion of map.
const
  valmin=-103.2109;
var
  ii, ik, id: integer;
  Rmin,val,sum{,LLbase}: double;
  adist2: TMatrix;
begin
  adist2:=nil;
  //Compute (Y-Z)^2
  DimMatrix(adist2,N,K);
  for ii:=1 to N do
    for ik:=1 to K do
    begin
      adist2[ii,ik]:=0;
      for id:=1 to D do
        adist2[ii,ik]:=adist2[ii,ik]+sqr(amatY[ik,id]-Z[ii,id]);
    end;
  fdist2:=nil; fdist2:=adist2;//Replace distance matrix with the new one
  //
  {Rin=p(tn|xi)/sum_j p(tn|xj). Normalisation factors of gaussians do not depend
  on n or i.
  Normalization: Sum_i Rin=1
  R=exp(-beta(Y_i-t_n)) can be impossible to evaluate. Removing the min value
  of -beta(Y_i-t_n) for fixed value of n does not change the result because of
  normalization over i index.}
  //Compute the loglikelihood at the same time.
  Result:=0;
  for ii:=1 to N do
  begin
    Rmin:=MaxDouble;
    for ik:=1 to K do
    begin
      fR[ik,ii]:=beta*adist2[ii,ik]/2;
      if fR[ik,ii]<=Rmin then Rmin:=fR[ik,ii];
    end;
    fLLM[ii]:=D*ln(beta/(2*Pi))/2-ln(K)-Rmin;
    sum:=0;
    for ik:=1 to K do
    begin
      val:=Rmin-fR[ik,ii];
      if val < valmin then //Do not count responsabilities below 1E-16
        fR[ik,ii]:=0//MinDouble//evalmin //Cancel insignificant responsibilities improves the speed and does not deteriorate the result.
      else begin
        fR[ik,ii]:=exp(val);//+MinDouble//+evalmin//exp(-beta*(Yik-Tii)^2/2);
        sum:=sum+fR[ik,ii];
      end;
    end;
    if sum>0 then fLLM[ii]:=fLLM[ii]+ln(sum);
    Result:=Result+fLLM[ii];
  end;
  Result:=Result/N;
  NormalizeByColumn(fR,1,K,1,N);
end;

function TcGTM.LogLikelyHood(aZ: TVector; var aR: TVector): double;
const
  valmin=-103.2109;
var
  {ii,} ik, id: integer;
  Rmin,val,sum{,LLbase},aLL: double;
  adist2: TVector;
begin
  aR:=nil;
  adist2:=nil;
  DimVector(aR,K);
  DimVector(adist2,K);
  //Compute (Y-Z)^2
  for ik:=1 to K do
  begin
    adist2[ik]:=0;
    for id:=1 to D do
      adist2[ik]:=adist2[ik]+sqr(matY[ik,id]-aZ[id]);
  end;
  //
  {Rin=p(tn|xi)/sum_j p(tn|xj). Normalisation factors of gaussians do not depend
  on n or i.
  Normalization: Sum_i Rin=1
  R=exp(-beta(Y_i-t_n)) can be impossible to evaluate. Removing the min value
  of -beta(Y_i-t_n) for fixed value of n does not change the result because of
  normalization over i index.}
  //Compute the loglikelihood at the same time.
  Rmin:=MaxDouble;
  for ik:=1 to K do
  begin
    aR[ik]:=beta*adist2[ik]/2;
    if aR[ik]<=Rmin then Rmin:=aR[ik];
  end;
  aLL:=D*ln(beta/(2*Pi))/2-ln(K)-Rmin;
  sum:=0;
  for ik:=1 to K do
  begin
    val:=Rmin-aR[ik];
    if val < valmin then //Do not count responsabilities below 1E-16
      aR[ik]:=0//MinDouble//evalmin //Cancel insignificant responsibilities improves the speed and does not deteriorate the result.
    else begin
      aR[ik]:=exp(val);//+MinDouble//+evalmin//exp(-beta*(Yik-Tii)^2/2);
      sum:=sum+aR[ik];
    end;
  end;
  if sum>0 then aLL:=aLL+ln(sum);
  Result:=aLL;
  for ik:=1 to K do
    if sum>0 then aR[ik]:=aR[ik]/sum;
end;

function TcGTM.LogLikelyHood(aZ: TMatrix): double;
begin
  SetZ(aZ);
  DimVector(fLLM,N);
  CompDist2();
  Expectation();
  Result:=LogLikelyHood();
end;

function TcGTM.LogLikelyHoodOnSelected(aZ: TMatrix): double;
begin
  SetZ(aZ);
  DimVector(fLLM,N);
  CompDist2();
  ExpectationOnSelected();
  Result:=LogLikelyHoodOnSelected();
end;

procedure TcGTM.MapToSpace(amatX: TMatrix);
//Compute the coordinates of aN map locations (amatX) in the original space (fmatY)->fmatY is updated
var
  im,ik,id: integer;
  aPhi: TMatrix;
begin
  UpdateMatY(False);//Be sure that the manifold coordinates are computed for all nodes
  aPhi:=nil;
  DimMatrix(aPhi,K,M);
  // Phi, matrix of basis functions
  for ik := 1 to fK do
    for im := 1 to fM do//exp(-0.5*((x_i-m_i)/sigma)^2)
    begin
      aPhi[ik, im] := exp(-(sqr(matM[im, 1] - amatX[ik, 1]) +
        sqr(matM[im, 2] - amatX[ik, 2]) / sqr(fsigma)) / 2);
    end;
  //
  for ik:=1 to K do
    for id:=1 to D do
    begin
      fmatY[ik,id]:=0;
      for im:=1 to M do
        fmatY[ik,id]:=fmatY[ik,id]+W[id,im]*aPhi[ik,im];
    end;
end;

procedure TcGTM.MapToSpace(amatX, amatY: TMatrix);
//Compute the coordinates of aN map locations (amatX) in the original space (amatY) - same reference frame as the initial data
var
  im,ik,id: integer;
  aPhi: TMatrix;
begin
  //matY is supposed to be already set - amatY is an output
  aPhi:=nil;
  DimMatrix(aPhi,K,M);
  // Phi, matrix of basis functions
  for ik := 1 to fK do
    for im := 1 to fM do//exp(-0.5*((x_i-m_i)/sigma)^2)
    begin
      aPhi[ik, im] := exp(-(sqr(matM[im, 1] - amatX[ik, 1]) +
        sqr(matM[im, 2] - amatX[ik, 2]) / sqr(fsigma)) / 2);
    end;
  //
  for ik:=1 to K do
    for id:=1 to D do
    begin
      amatY[ik,id]:=0;
      for im:=1 to M do
        amatY[ik,id]:=amatY[ik,id]+W[id,im]*aPhi[ik,im];
    end;
end;

procedure TcGTM.Generate(Nsmple: integer; var SmpleZ, SmpleX: TMatrix);
//Nsmple: number of sample data points to generate
//SmpleZ: array of the sampled data points in the coordinate frame of the map
//SmpleX: array of the sampled data points in the initial coordinate frame
//ROffset: adjust the acceptation rate of generated data points, must be set to a value comparable to single compounds responsibilities
var
  ik,jk,id,nn: integer;
  aNodeList: TIntVector;
  //aZold,aZ: TMatrix;//Each line is dedicated to a sampled node
  NSel: integer;
  //dLL: double;
  //LLold: TVector;
  //LLnew: TVector;
  //bAccept: boolean;
  //rr: double;
  //nfail: TIntVector;
begin
  //Count selected nodes to generate from and create a list of selected nodes
  NSel:=0;
  aNodeList:=nil;
  jk:=0;
  DimIntVector(aNodeList,K);//aNodeList size is unknown
  for ik:=1 to K do
    if SelNode[ik] then begin
      Inc(jk);
      aNodeList[jk]:=ik;
    end;
  NSel:=jk;
  SetLength(aNodeList,NSel+1);//aNodeList has the right size
  //
  DimMatrix(SmpleZ,Nsmple,D);//Each line is a sample, each column is a dimension
  DimMatrix(SmpleX,Nsmple,D);
  //The GTM distribution is a uniform multivariate gaussian: the covariance matrix is diagonal
  //It is sufficient to generate for each direction, a normal distributed centered on selected nodes with relevant standard dev
  for nn:=1 to Nsmple do
  begin
    if jk<NSel then Inc(jk) else jk:=1;//jk in [1..NSel]
    ik:=aNodeList[jk];//Pick a node on the manifold
    for id:=1 to D do
      SmpleZ[nn,id]:=randg(fmatY[ik,id],sqrt(1/beta));//beta is actually the inverse of the variance of the GTM
  end;
  for nn:=1 to Nsmple do
    for id:=1 to D do
      SmpleX[nn,id]:=Mean[id]+SD[id]*SmpleZ[nn,id];
  {LogLikelyHoodOnSelected(Smple);//DEBUG Compute the LL and responsibilities on selected nodes
  DimVector(LLold,NSel);
  for jk:=1 to High(aNodeList) do//There are as many samples as selected nodes
    LLold[jk]:=fLLM[jk];}
  {//Attempt to do a Monte Carlo walk in the neighborhood of the manifold
  nn:=-fnHeat; //Perform thermalisation for fnHeat steps before recording the generated points
  //Count selected nodes to generate from and create a list of selected nodes
  NSel:=0;
  aNodeList:=nil;
  jk:=0;
  DimIntVector(aNodeList,K);//aNodeList size is unknown
  for ik:=1 to K do
    if SelNode[ik] then begin
      Inc(jk);
      aNodeList[jk]:=ik;
    end;
  NSel:=jk;
  SetLength(aNodeList,NSel+1);//aNodeList has the right size
  DimIntVector(nfail,NSel);//Count the number of consecutive generation fail
  if NSel=0 then begin
    Exception.Create('ERROR cGTM.Generate: no selected node');
    halt;
  end;
  //
  aZ:=nil;
  aZold:=nil;
  LLnew:=nil;
  LLold:=nil;
  DimMatrix(aZ,NSel,D);
  DimMatrix(aZold,NSel,D);
  DimVector(LLnew,NSel);
  DimVector(LLold,NSel);
  //Start exploration from the manifold
  for jk:=1 to High(aNodeList) do
  begin
    ik:=aNodeList[jk]; //Pick a selected node.
    for id:=1 to D do
    begin
      aZ[jk,id]:=fmatY[ik,id];
      aZold[jk,id]:=aZ[jk,id];
    end;
    LLnew[jk]:=0;
    nfail[jk]:=0;
  end;
  LogLikelyHoodOnSelected(aZ);//Compute the LL
  for jk:=1 to High(aNodeList) do//There are as many samples as selected nodes
    LLold[jk]:=fLLM[jk];
  //
  writeln;
  repeat
    for jk:=1 to High(aNodeList) do
    begin
      //id:=random(D)+1;//Pick a random direction.
      //Generate from this previous iteration
      for id:=1 to D do aZ[jk,id]:=aZold[jk,id]+randg(0,beta)/Sqrt(D);
    end;
    LogLikelyHoodOnSelected(aZ);
    {maxLL:=aR[0,1];
    for jk:=1 to NSel do
      if maxLL<aR[0,jk] then maxLL:=aR[0,jk];}
    for jk:=1 to NSel do begin
      LLnew[jk]:=fLLM[jk];
      dLL:=LLnew[jk]-LLold[jk]-ROffset;//improve the acceptation rate and departure from the manifold
      //Metropolis-like condition
      bAccept:=False;
      if dLL>=0 then
        bAccept:=True
      else begin
        rr:=1-random;// rr in ]0,1]
        rr:=ln(rr);
        if rr<=dLL then
          bAccept:=True
        else bAccept:=False;
      end;
      //
      if bAccept then begin
        LLold[jk]:=LLnew[jk];
        for id:=1 to D do
          aZold[jk,id]:=aZ[jk,id];
        Inc(nn);
        write('+'+IntToStr(nn)+'+');
        if (nn>0) and (nn<=Nsmple) then
          for id:=1 to D do
            Smple[nn,id]:=aZ[jk,id]*SD[id]+Mean[id];
      end else then begin
        nfail[jk]:=nfail[jk]+1;
        if nfail[jk]>100 then //to many fail reboot the generation
        begin
          for id:=1 to D do Zold[jk,id]=Zold0[jk,id];
          LLold[jk]:=LLold0[jk]
          write('.');
        end;
      end;
      //
    end;
  until nn>=Nsmple;
  writeln;}
end;

procedure TcGTM.Project();
begin
  inherited Project();
end;

procedure TcGTM.Project(bmatY, bselnode, bdist2, bexpectation: boolean);
begin
  if bmatY then
    UpdateMatY(bselnode);
  if bdist2 then
    CompDist2();
  if bexpectation then
    if not bselnode then
      Expectation()
    else ExpectationOnSelected();
  Project;
end;

procedure TcGTM.Project(ZT: TMatrix; Nmax: integer);
//var
  //i: integer;
begin
  If (N<>Nmax) then
  begin
    N:=Nmax;
    setlength(fZ,0,0);
    setlength(fdist2,0,0);
    setlength(fR,0,0);
    setLength(fLLM,0);
    //Resize matrices according to new value of N
    DimMatrix(fZ,N,D);
    DimMatrix(fdist2,N,K);
    DimMatrix(fR,K,N);
    DimVector(fLLM,N);
  end;
  //Load data to Z, compute Y and update dist2
  LoadZ(ZT);
  UpdateMatY(False); // During a projection all nodes need to be used to compute the manifold position in the D-space
  CompDist2();
  //Update R and Pr
  Expectation();
  //UpdatePr();
  //Compute projection
  inherited Project();
end;

procedure TcGTM.Zremove(LLt: double);
var ii: integer;
begin
  ii:=1;
  repeat
    if LLM[ii]>LLt then inherited Zremove(ii);
    Inc(ii);
  until ii>N;
  //Reshape all matrices
  DimR;
  DimMatPrj;
  DimVector(fLLM,N);
  DimMatrix(fdist2,N,K);
  //Dist2, R, matPrj, LLM are outdated
  CompDist2();
  Expectation();
  Project();
  LogLikelyHood();
end;

procedure TcGTM.SetX;
var
  MeanOld,SDOld: TVector;
  id, ik: integer;
begin
  //Save the previous scaling parameters
  DimVector(MeanOld,fD);
  DimVector(SDOld,fD);
  for id:=1 to fD do begin
    MeanOld[id]:=Mean[id];
    SDOld[id]:=SD[id];
  end;
  inherited SetX;//Rescale the datapoints
  //rescale the manifold accordingly
  for ik:=1 to fK do
    for id:=1 to fD do
      fmatY[ik,id]:=((fmatY[ik,id]*SDold[id]+MeanOld[id])-Mean[id])/SD[id];
  //Warning, W is now invalid!
end;

procedure TcGTM.SetX(aX: TMatrix);
begin
  inherited SetX(aX);
end;

procedure TcGTM.SetW(CX: TMatrix);
var
  ik,id: integer;
begin
  //Set the manifold coordinates as requested
  for ik:=1 to K do
    for id:=1 to D do
      fmatY[ik,id]:=CX[ik,id];
  inherited SetW(CX);
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

