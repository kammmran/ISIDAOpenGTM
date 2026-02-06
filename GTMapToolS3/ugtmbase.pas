unit UGTMBase;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, ULinAlgSparse, utypes, ulinalg, math;

type

  { TGTMBase }

  TGTMBase = class(TObject)
  private
    fmatM, fmatX: TMatrix; //2D latent space positions of RBF centers and sample points
  protected
    fPhi: TMatrix;//Phi: KxM latent to traits space transfer function;
    fN, fD, fK, fM: integer; { N, Number of instances;
                               D, dimension of initial space;
                               K, number of latent space samples;
                               M, number of traits }
    fnIter: integer; //Count the number of EM iterations
    fsigma: double; // Width of the latent space RBF: Phi_i(x)=exp(-((x-u_i)/sigma)^2)
    fW, fR: TMatrix; { W: DxM model parameters matrix;
                       R: KxN, responsabilities; }
    fmatPrj: TMatrix;//Nx2 matrix Projected data on the theta/phi plane manifold
    fmatPrj3: TMatrix;//Nx3 matrix of projected datat on the sphere manifold
    fRestart: boolean;//True: the manifold is initialized externally to start EM
  public
    property N: integer read fN write fN;
    property D: integer read fD write fD;
    property K: integer read fK write fK;
    property M: integer read fM write fM;
    property W: TMatrix read fW write fW;
    property Phi: TMatrix read fPhi;
    property matM: TMatrix read fmatM;
    property matX: TMatrix read fmatX;
    property R: TMatrix read fR;
    property matPrj: TMatrix read fmatPrj;
    property matPrj3: TMatrix read fmatPrj3;
    property sigma: double read fsigma write fsigma;
    property nIter: integer read fnIter write fnIter;
    property Restart: boolean read fRestart write fRestart;
    procedure DimR(Ub1,Ub2: integer);
    procedure DimR;
    procedure DimW(Ub1,Ub2: integer);
    procedure DimW;
    procedure Init(kSamples, mTraits: integer; asigma: double = -1.0); virtual;
    procedure Init(); virtual;
    function LogLikelyHood(): double; virtual; abstract;
    procedure Project(); virtual;
    constructor Create; virtual;
    destructor Destroy; override;
  published
  end;

function createMMatrix(numM: integer): TMatrix;
//Uniform grid of numM points on a [-1,1]x[-1,1] range

implementation

function createMMatrix(numM: integer): TMatrix;
var
  GR: double;//golden ratio
  ii: integer;
  theta, phi: double;
  mSphere: TMatrix;
  slog: TStringList;
begin
  Result:=nil;
  DimMatrix(Result, numM, 2);
  //Nodes on Fibonacci generalized spiral on a sphere
  GR:=(Sqrt(5)+1)/2;
  for ii:=1 to numM do
  begin
    theta:=arccos(1-2*ii/numM);
    phi:=2*Pi*frac(GR*ii);
    Result[ii,1]:=theta;
    Result[ii,2]:=phi;
  end;
  {slog:=TStringList.Create;
  PrintMat(Result,'theta_phi.mat',1,numM,1,2,slog);
  slog.SaveToFile('theta_phi.mat');}
  mSphere:=nil;
  DimMatrix(mSphere,numM,3);
  for ii:=1 to numM do
  begin
    mSphere[ii,1]:=sin(Result[ii,1])*cos(Result[ii,2]);//sin(theta)*cos(phi)
    mSphere[ii,2]:=sin(Result[ii,1])*sin(Result[ii,2]);//sin(theta)*sin(phi)
    mSphere[ii,3]:=cos(Result[ii,1]);//cos(theta)
  end;
  slog:=TStringList.Create;
  PrintMat(mSphere,'Sphere'+IntToStr(numM),1,numM,1,3,slog);
  slog.SaveToFile('Sphere'+IntToStr(numM));
  FreeAndNil(slog);
end;

{function createMMatrix(numM: integer): TMatrix;
const
  P6: array [1..6] of integer = (2,3,5,7,11,13);
var
  i,j,ii,ii0: integer;
  k1,k2,k3: integer;
  kdepth,r,theta,phi: double;
  dtmp: double;
  xmin, ymin: double;
  xmax, ymax: double;
  numMdiv,numMmod: integer;
  aiCube: array [1..6] of integer;
  mCube{,mSphere}: TMatrix;
  //slog: TStringList;
begin
  k1:=-1; k2:=-1; k3:=-1; kdepth:=0;
  mCube:=nil; Result:=nil;
  //Store the sampling of the 6 faces of the cube
  numMdiv:=numM div 6;
  numMmod:=numM mod 6;
  for i:=1 to 6 do
    aiCube[i]:=numMdiv;
  for i:=1 to numMmod do
    aiCube[i]:=aiCube[i]+1;
  DimMatrix(mCube,numM,3); // XYZ coordinates of a cube sampling
  //Store the sampling of the sphere (theta,phi)
  DimMatrix(Result, numM, 2);
  //Sample the 6 faces of the cube
  ii:=0;
  for j:=1 to 6 do
  begin
    if j=1 then //Set the face of the cube to process
    begin
      k1:=1; k2:=2; k3:=3; kdepth:=-1/sqrt(3); //xy plane bottom
    end else
    if j=2 then
    begin
      k1:=1; k2:=2; k3:=3; kdepth:=1/sqrt(3); //xy plane top
    end;
    if j=3 then
    begin
      k1:=3; k2:=1; k3:=2; kdepth:=-1/sqrt(3); //zx plane bottom
    end;
    if j=4 then
    begin
      k1:=3; k2:=1; k3:=2; kdepth:=1/sqrt(3); //zx plane top
    end;
    if j=5 then
    begin
      k1:=2; k2:=3; k3:=1; kdepth:=-1/sqrt(3); //yz plane bottom
    end;
    if j=6 then
    begin
      k1:=2; k2:=3; k3:=1; kdepth:=1/sqrt(3); //yz top
    end;
    if aiCube[j]>1 then
    begin
      xmin:=1/aiCube[j];
      xmax:=1;
      ymin:=1;
      ymax:=0;
      ii0:=ii;//remember sample index
      for i:=1 to aiCube[j] do // i is an index on the face of the cube
      begin
        Inc(ii); //ii is the index of the sample, whatever the face
        mCube[ii,k1]:=i/aiCube[j];
        dtmp:=i*(sqrt(P6[j])+1)/2;
        mCube[ii,k2]:=dtmp-int(dtmp);
        mCube[ii,k3]:=kdepth;
        if mCube[ii,k2]<ymin then ymin:=mCube[ii,k2];
        if mCube[ii,k2]>ymax then ymax:=mCube[ii,k2];
      end;
      ii:=ii0; //Re-enumerate the samples of the cube face
      for i:=1 to aiCube[j] do //rescale the samples in -sqrt(3)..sqrt(3)
      begin                    //so the cube is inscribed in the unit sphere
        Inc(ii);
        mCube[ii,k1]:=(2*(mCube[ii,k1]-xmin)/(xmax-xmin)-1)/sqrt(3);
        mCube[ii,k2]:=(2*(mCube[ii,k2]-ymin)/(ymax-ymin)-1)/sqrt(3);
      end;
    end else
    begin
      Inc(ii);
      mCube[ii,k1]:=0;
      mCube[ii,k2]:=0;
      mCube[ii,k3]:=kdepth;
    end;
  end;
  //Compute the theta-phi angles: lift the sampling of the cube to the sphere
  for ii:=1 to numM do
  begin
    r:=sqrt(sqr(mCube[ii,1])+sqr(mCube[ii,2])+sqr(mCube[ii,3]));
    theta:=arccos(mCube[ii,3]/r);
    phi:=arctan2(mCube[ii,2],mCube[ii,1]);
    Result[ii,1]:=theta;
    Result[ii,2]:=phi;
  end;
  {slog:=TStringList.Create;
  PrintMat(Result,'theta_phi.mat',1,numM,1,2,slog);
  slog.SaveToFile('theta_phi.mat');}
  {DimMatrix(mSphere,numM,3);
  for ii:=1 to numM do
  begin
    mSphere[ii,1]:=sin(Result[ii,1])*cos(Result[ii,2]);//sin(theta)*cos(phi)
    mSphere[ii,2]:=sin(Result[ii,1])*sin(Result[ii,2]);//sin(theta)*sin(phi)
    mSphere[ii,3]:=cos(Result[ii,1]);//cos(theta)
  end;
  slog:=TStringList.Create;
  PrintMat(mSphere,'Sphere'+IntToStr(numM),1,numM,1,3,slog);
  slog.SaveToFile('Spere'+IntToStr(numM));
  FreeAndNil(slog);}
end;
}

{ TGTMBase }

procedure TGTMBase.DimR(Ub1, Ub2: integer);
begin
  DimMatrix(fR,Ub1,Ub2);
end;

procedure TGTMBase.DimR;
begin
  if (fK<>0) and (fN<>0) then DimMatrix(fR,fK,fN)
  else begin
    writeln('ERROR TGTMBase.DimR: number of samples K and/or number of instances N not set.');
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
    writeln('ERROR TGTMBase.DimW: input space dimension D and/or number of traits M not set.');
    Exception.Create('ERROR TGTMBase.DimW: input space dimension D and/or number of traits M not set.');
    Halt;
  end;
end;

procedure TGTMBase.Init(kSamples, mTraits: integer; asigma: double);
begin
  M := mTraits;
  K := kSamples;
  if asigma <= 0 then
    fsigma:=15.7/M//M RBF in 4*Pi surface. sigma=5*Pi/M. The RBF allways overlap
    //fsigma := 5.64 / sqrt(fK) // Recommendation to have O(100) samples within 2 sigma radius
  else
    fsigma := asigma;
  Init;
  writeln('sigma='+FloatToStr(fsigma));
end;

procedure TGTMBase.Init;
var
  ik, im: integer;
  x1,y1,z1: double;
  x2,y2,z2: double;
  dist: double;
  darc: double;
begin
  DimMatrix(fPhi, fK, fM);
  if (not fRestart) then DimMatrix(fW, fD, fM);
  // Samples and RBF centers
  fmatM := createMMatrix(fM);
  fmatX := createMMatrix(fK);
  // Phi, matrix of basis functions
  for ik := 1 to fK do
    for im := 1 to fM do//exp(-0.5*((x_i-m_i)/sigma)^2)
    begin
      x1:=sin(fmatM[im,1])*cos(fmatM[im,2]);//sin(theta)*cos(phi)
      y1:=sin(fmatM[im,1])*sin(fmatM[im,2]);//sin(theta)*sin(phi)
      z1:=cos(fmatM[im,1]);//cos(theta)
      x2:=sin(fmatX[ik,1])*cos(fmatX[ik,2]);//sin(theta)*cos(phi)
      y2:=sin(fmatX[ik,1])*sin(fmatX[ik,2]);//sin(theta)*sin(phi)
      z2:=cos(fmatX[ik,1]);//cos(theta)
      dist:=sqrt(sqr(x1-x2)+sqr(y1-y2)+sqr(z1-z2));
      darc:=2*arcsin(dist/2);
      fPhi[ik, im] := exp(-(sqr(darc) / sqr(fsigma)) / 2);
    end;
  //for ik := 1 to fK do
  //  fPhi[ik, 0] := 1;//Add a constant to the model, the associated weight is W[0]
  //
end;

procedure TGTMBase.Project;
var
  ii, ik: integer;
  as1, as2, ac1, ac2: double;
  //slog: TStringList;
begin
  //Projections on theta/phi plane
  DimMatrix(fmatPrj, fN, 2);
  for ii := 1 to N do
  begin
    fmatPrj[ii, 1] := 0;
    fmatPrj[ii, 2] := 0;
    as1:=0; as2:=0; ac1:=0; ac2:=0;
    for ik := 1 to K do // Averaging of angles is computed using the complex plane
    begin
      as1:=as1+fR[ik, ii] * sin(fmatX[ik, 1]);
      as2:=as2+fR[ik, ii] * sin(fmatX[ik, 2]);
      ac1:=ac1+fR[ik, ii] * cos(fmatX[ik, 1]);
      ac2:=ac2+fR[ik, ii] * cos(fmatX[ik, 2]);
      //fmatPrj[ii, 1] := fmatPrj[ii, 1] + fR[ik, ii] * fmatX[ik, 1];
      //fmatPrj[ii, 2] := fmatPrj[ii, 2] + fR[ik, ii] * fmatX[ik, 2];
    end;
    fmatPrj[ii, 1] := arctan2(as1,ac1);
    fmatPrj[ii, 2] := arctan2(as2,ac2);
  end;
  //Projections on the sphere manifold
  DimMatrix(fmatPrj3,fN,3);
  for ii:=1 to fN do
  begin
    fmatPrj3[ii,1]:=sin(fmatPrj[ii,1])*cos(fmatPrj[ii,2]);//sin(theta)*cos(phi)
    fmatPrj3[ii,2]:=sin(fmatPrj[ii,1])*sin(fmatPrj[ii,2]);//sin(theta)*sin(phi)
    fmatPrj3[ii,3]:=cos(fmatPrj[ii,1]);//cos(theta)
  end;
  {slog:=TStringList.create;
  PrintMat(fmatPrj3,'Prj3',1,N,1,3,slog);
  slog.SaveToFile('Proj3.mat');
  FreeAndNil(slog);}
end;

constructor TGTMBase.Create;
begin
  fM := 0;
  fK := 0;
  fN := 0;
  fD := 0;
  fsigma := 1.0;
  fnIter:=0;
  fRestart:=False;
  //Initialize matrices to nil
  fPhi:=nil;
  fmatM:=nil;
  fmatX:=nil;
  //fY:=nil;
  fW:=nil;
  fR:=nil;
  fmatPrj:=nil;
  fmatPrj3:=nil;
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
