unit UnitKGTM;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, ISIDA_descriptor, ioSVM, UnitGramBase,
  UnitKPCA, utypes, ueigsym,ulinalg,upca, UcGTM;

type

  { TKGTM }

  TKGTM = class(TcGTM)
  private
    faKPCA: TKPCA;//kernel PCA
    fmols: LRSMFv2;//molecules used as support to define the feature space
    fmetric: integer;//metric, kernel definition
    fkprm1: float;//exponent, kernel parameter 1
    fpct: float;//percent of explained variance to conserve
    fbKPCAdone: boolean; //Is true if GTM can be loaded with data
    fbGTMready: boolean; //Is true if GTM calculations can be started
    function GetKprm1: float;
    function GetMetric: integer;
    function GetMols: LRSMFv2;
    function GetPct: float;
    procedure SetKprm1(AValue: float);
    procedure SetMetric(AValue: integer);
    procedure SetMols(AValue: LRSMFv2);
    procedure SetPct(AValue: float);
  public
    property aKPCA: TKPCA read faKPCA;
    property mols: LRSMFv2 read GetMols write SetMols;
    property metric: integer read GetMetric write SetMetric;
    property pct: float read GetPct write SetPct;
    property kprm1: float read GetKprm1 write SetKprm1;
    property bKPCAdone: boolean read fbKPCAdone;
    property bGTMready: boolean read fbGTMready;
    procedure ReadSVM(trsvm,trhdr: string);
    procedure ReadSVM(bsnme: string);
    procedure KPCA;
    procedure LoadScores;
    procedure Project; override;
    procedure Project(ZT: TMatrix; Nmax: integer); override;
    constructor Create;
    destructor Destroy; override;
  end;
implementation

{ TKGTM }

function TKGTM.GetMetric: integer;
begin
  Result:=fmetric;
end;

function TKGTM.GetMols: LRSMFv2;
begin
  Result:=fmols;
end;

function TKGTM.GetKprm1: float;
begin
  Result:=fkprm1;
end;

function TKGTM.GetPct: float;
begin
  Result:=fpct;
end;

procedure TKGTM.SetKprm1(AValue: float);
begin
  try
    if (AValue<0) then
    begin
      raise Exception.Create('TKGTM Error. Unsupported kernel parameter value: '+FloatToStr(AValue));
      halt;
    end;
    fkprm1:=AValue;
    mols.sigma:=fkprm1;
  except
    raise Exception.Create('ERROR TKGTM.SetKprm1: no molecule set');
    Halt;
  end;
end;

procedure TKGTM.SetMetric(AValue: integer);
begin
  try
    if (AValue<2) or (AValue>4) then
    begin
      raise Exception.Create('TKGTM Error. Unsupported kernel value: '+IntToStr(AValue));
      halt;
    end;
    fmetric:=AValue;
    mols.metric:=fmetric;
  except
    raise Exception.Create('ERROR TKGTM.SetMetric: no molecule set');
    Halt;
  end;
  end;

procedure TKGTM.SetMols(AValue: LRSMFv2);
begin
  if AValue=nil then
  begin
    raise Exception.Create('TKGTM Error. Undefined molecule dataset.');
    halt;
  end;
  fmols:=AValue;//WARNING: the TLRSMFv2 molecule dataset is now managed by TKGTM
  faKPCA.AttachToMols(mols);
end;

procedure TKGTM.SetPct(AValue: float);
begin
  if (AValue>1) or (AValue<0) then
  begin
    raise Exception.Create('TKGTM Error. Unsupported explained variance value: '+FloatToStr(AValue));
    halt;
  end;
  fpct:=AValue;
end;

procedure TKGTM.ReadSVM(trsvm, trhdr: string);
begin
  fmols.ReadSVM(trsvm,trhdr);
  //faKPCA.AttachToMols(mols);
end;

procedure TKGTM.ReadSVM(bsnme: string);
var
  trsvm,trhdr: string;
begin
  trhdr:=ChangeFileExt(bsnme,'.hdr');
  trsvm:=ChangeFileExt(bsnme,'.svm');
  ReadSVM(trsvm,trhdr);
end;

procedure TKGTM.KPCA;
begin
  if (fmols=nil) then
  begin
    raise Exception.Create('TKGTM Error. No molecule dataset.');
    halt;
  end;
  write('Computing KPCA...');
  faKPCA.EigenVec;
  aKPCA.NPCutOff(fpct);
  N:=aKPCA.Sze;
  D:=aKPCA.NPC; //The number of columns for the GTM is the number of PC kept
  writeln('...Success');
  fbKPCAdone:=True;
end;

procedure TKGTM.LoadScores;
var
  aPC123: TMatrix;//Three firsr KPCA
  aZ: TMatrix; //matrix of KPCA scores
  EV: TVector; //Explained variance per kernel PCA
  i: integer;
  aLog: TStringList;
begin
  //Compute normalized variance for display
  DimVector(EV,aKPCA.NPC);
  for i:=0 to aKPCA.NPC-1 do
    EV[i]:=aKPCA.EigVr[i,0]/aKPCA.vartot;
//  aLog:=TStringList.Create;
//  PrintVec(EV,'Explained Variances',Low(EV),High(EV),aLog);
//  aLog.SaveToFile('EV.mat');
//  FreeAndNil(aLog);
  //
  if aKPCA.NPC<3 then
  begin
    raise Exception.Create('KGTM.LoadScores: feature space dimension is low, NPC='+IntToStr(aKPCA.NPC));
    Halt;
  end;
  write('Compute KPCA scores and load them to GTM...');
  DimMatrix(aPC123,aKPCA.NPC,3);
  for i:=Low(aPC123) to High(aPC123) do
  begin
    aPC123[i,0]:=0;
    aPC123[i,1]:=0;
    aPC123[i,2]:=0;
    aPC123[i,3]:=0;
  end;
  aPC123[0,0]:=0;
  aPC123[0,1]:=aKPCA.EigVr[0,0];//indexing of EigVr is 0 based and aPC123 is 1 based
  aPC123[0,2]:=aKPCA.EigVr[1,0];
  aPC123[0,3]:=aKPCA.EigVr[2,0];
  aPC123[1,1]:=1;
  aPC123[2,2]:=1;
  aPC123[3,3]:=1;
  SetPC123mat(aPC123);
  //Compute KPCA scores
  aZ:=aKPCA.Project2Mat(fmols); // Matrix of KPCA scores
  SetX(aZ); //Load the scores to the GTM
  writeln('...Success');
end;

procedure TKGTM.Project;
begin
  inherited Project;
end;

procedure TKGTM.Project(ZT: TMatrix; Nmax: integer);
begin
  inherited Project(ZT, Nmax);
end;

constructor TKGTM.Create;
begin
  faKPCA:=TKPCA.Create;
  fmetric:=2; //2: Tanimoto; 3: RBF; 4: Cos
  fpct:=0.95; //95% explained variance
  fkprm1:=1;  //default kernel parameter value
  fmols:=nil;
  inherited Create;
  istd:=2; //Always center the scores before attemting a GTM
end;

destructor TKGTM.Destroy;
begin
  FreeAndNil(faKPCA);
  inherited Destroy;
end;

end.

