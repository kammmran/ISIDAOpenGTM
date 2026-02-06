unit uSgGTM;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, contnrs, math,
  utypes, ulinalg,
  UGTMBase, UGTMFull, UcGTM;

type

  { TSgGTM }

  TSgGTM = class(TObject)
  private
    fOLGTM: TObjectList;//Contains GTM objects
    fPP: integer; //Pre-processing. 0: nothing; 1: standardize; 2: center; 3: normalize; 4: normalize+center
    fw: double;//RBF width
    fl: double;//Regularization
    fM: integer;//Number of RBF
    fK: integer;//Number of Nodes
    fN: integer;//Number of instances
    fR: TMatrix;//KxN responsibility matrix
    fVw: TVector;//Vector of mixture model weights
    function GetK: integer;
    function GetL: double;
    function GetM: integer;
    function GetN: integer;
    function GetOLGTM(Index: integer): TcGTM;
    function GetPP: integer;
    function GetVw(index: integer): double;
    function GetW: double;
    procedure SetK(AValue: integer);
    procedure SetL(AValue: double);
    procedure SetM(AValue: integer);
    procedure SetPP(AValue: integer);
    procedure SetVw(index: integer; AValue: double);
    procedure SetW(AValue: double);
  public
    property OLGTM[Index:integer]: TcGTM read GetOLGTM;
    property w: double read GetW write SetW;
    property l: double read GetL write SetL;
    property M: integer read GetM write SetM;
    property K: integer read GetK write SetK;
    property PP: integer read GetPP write SetPP;
    property N: integer read GetN;
    property Vw[index: integer]: double read GetVw write SetVw;
    procedure ReadMols(SLinput: TStringList);//Load data files and initiate GTM calculations
    procedure Init1(kSamples, mTraits: integer; asigma: double=-1.0; aalpha: double=-1.0; aiScaleInit: integer=0; afScaleInit: double=0.0);
    procedure Expectation();
    procedure Maximization();
    function LogLikelyHood(): Double;
    procedure Project(ZT: TMatrix; Nmax: integer);
    constructor Create;
    destructor Destroy; override;
  end;

implementation

{ TSGTM }

function TSgGTM.GetVw(index: integer): double;
begin
  Result:=fVw[index];
end;

function TSgGTM.GetK: integer;
begin
  Result:=fK;
end;

function TSgGTM.GetL: double;
begin
  Result:=fl;
end;

function TSgGTM.GetM: integer;
begin
  Result:=fM;
end;

function TSgGTM.GetN: integer;
begin
  Result:=fN;
end;

function TSgGTM.GetOLGTM(Index: integer): TcGTM;
begin
     Result:=fOLGTM[index] as TcGTM;
end;

function TSgGTM.GetPP: integer;
begin
  Result:=fPP;
end;

function TSgGTM.GetW: double;
begin
  Result:=fw;
end;

procedure TSgGTM.SetK(AValue: integer);
begin
  fK:=AValue;
end;

procedure TSgGTM.SetL(AValue: double);
begin
  fl:=AValue;
end;

procedure TSgGTM.SetM(AValue: integer);
begin
  fM:=AValue;
end;

procedure TSgGTM.SetPP(AValue: integer);
var
  ii, iimax: integer;
  acGTM: TcGTM;
begin
  iimax:=1;
  fPP:=AValue;
  for ii:=0 to iimax do begin
    acGTM:=fOLGTM.Items[ii] as TcGTM;
    acGTM.istd:=fPP;
  end;
end;

procedure TSgGTM.SetVw(index: integer; AValue: double);
begin
  fVw[index]:=AValue;
end;

procedure TSgGTM.SetW(AValue: double);
begin
  fw:=AValue;
end;

procedure TSgGTM.ReadMols(SLinput: TStringList);
var
  ii,iimax: integer;
  sinput: string;
  acGTM:TcGTM;
begin
  iimax:=1;
  //
  for ii:=0 to iimax do begin
    sinput:=SLinput.Strings[ii];
    acGTM:=fOLGTM.Items[ii] as TcGTM;
    acGTM.ReadMols(sinput);
  end;
  //
  fN:=acGTM.N;//This is the same value for any GTM of this mixture model.
end;

procedure TSgGTM.Init1(kSamples, mTraits: integer; asigma: double;
  aalpha: double; aiScaleInit: integer; afScaleInit: double);
var
  ii,iimax: integer;
  acGTM:TcGTM;
begin
  iimax:=1;
  //
  fK:=kSamples;
  fM:=mTraits;
  fw:=asigma;
  fl:=aalpha;
  //
  for ii:=0 to iimax do begin
    acGTM:=fOLGTM.Items[ii] as TcGTM;
    acGTM.Init1(kSamples,mTraits,asigma,aalpha,aiScaleInit,afScaleInit);
  end;
  //
  DimMatrix(fR,fK,fN);
end;

procedure TSgGTM.Expectation();
var
  jj,jjmax: integer;
  ik,ii,iimax,ikmax: integer;
  aw: double;
  acGTM:TcGTM;
begin
  jjmax:=1;
  //Compute expectation step for each GTM
  for jj:=0 to jjmax do begin
    acGTM:=fOLGTM.Items[jj] as TcGTM;
    acGTM.Expectation();
  end;
  //Compute mixed responsibilities - Initialize with GTM0
  jj:=0;
  aw:=fVw[jj];
  acGTM:=fOLGTM.Items[jj] as TcGTM;
  iimax:=fN;
  ikmax:=fK;
  for ii:=1 to iimax do
    for ik:=1 to ikmax do
      fR[ik,ii]:=power(acGTM.R[ik,ii],aw);
  //Compute mixed responsibilities - All others GTM
  for jj:=1 to jjmax do begin
    aw:=fVw[jj];
    acGTM:=fOLGTM.Items[jj] as TcGTM;
    for ii:=1 to iimax do
      for ik:=1 to ikmax do
        fR[ik,ii]:=fR[ik,ii]*power(acGTM.R[ik,ii],aw);
  end;
  NormalizeByColumn(fR,1,fK,1,fN);
  //Replace responsibilities for each GTM with mixed responsibilities
  for jj:=0 to jjmax do begin
    acGTM:=fOLGTM.Items[jj] as TcGTM;
    for ii:=1 to iimax do
      for ik:=1 to ikmax do
        acGTM.R[ik,ii]:=fR[ik,ii];
  end;
end;

procedure TSgGTM.Maximization();
var
  ii,iimax: integer;
  acGTM:TcGTM;
begin
  iimax:=1;
  for ii:=0 to iimax do begin
    acGTM:=fOLGTM.Items[ii] as TcGTM;
    acGTM.Maximization();
  end;
end;

function TSgGTM.LogLikelyHood(): Double;
var
  ii,iimax: integer;
  aw: double;
  acGTM:TcGTM;
  dLL: Double;
begin
  dLL:=0;
  iimax:=1;
  for ii:=0 to iimax do begin
    aw:=fVw[ii];
    acGTM:=fOLGTM.Items[ii] as TcGTM;
    dLL:=dLL+aw*acGTM.LogLikelyHood();
  end;
  //
  Result:=dLL;
end;

procedure TSgGTM.Project(ZT: TMatrix; Nmax: integer);
var
  ii,iimax: integer;
  acGTM:TcGTM;
begin
  iimax:=1;
  for ii:=0 to iimax do begin
    acGTM:=fOLGTM.Items[ii] as TcGTM;
    acGTM.Project(ZT,Nmax);
  end;
end;

constructor TSgGTM.Create;
var
  ii,iimax: integer;
  acGTM:TcGTM;
begin
  iimax:=1;
  fPP:=1;
  fw:=0;
  fl:=0;
  fM:=0;
  fK:=0;
  DimVector(fVw,1);
  fVw[0]:=0; fVw[1]:=0;
  fOLGTM:=TObjectList.Create;
  fOLGTM.OwnsObjects:=True;
  //Currently set two GTM in the mixture
  fOLGTM.Add(TcGTM.Create);
  fOLGTM.Add(TcGTM.Create);
end;

destructor TSgGTM.Destroy;
begin
  FreeAndNil(fOLGTM);
  inherited Destroy;
end;

end.

