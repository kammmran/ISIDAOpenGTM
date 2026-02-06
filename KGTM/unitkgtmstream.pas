unit UnitKGTMStream;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, streamex, rastream, ISIDA_descriptor, ioSVM, UnitGramBase,
  UnitKPCAStream, utypes, ueigsym,ulinalg,upca, UcGTM;

type

  { TKGTMStream }

  TKGTMStream = class(TcGTM)
  private
    faKPCA: TKPCAStream;//kernel PCA
    fbKPCAdone: boolean; //Is true if GTM can be loaded with data
    fbGTMready: boolean; //Is true if GTM calculations can be started
    function GetKprm1: float;
    function GetMetric: integer;
    function GetFileStream: TRAStream;
    function GetPct: float;
    function GetbWeight: boolean;
    function GetbSze: integer;
    procedure SetbWeight(AValue: boolean);
    procedure SetKprm1(AValue: float);
    procedure SetMetric(AValue: integer);
    procedure SetPct(AValue: float);
    procedure SetbSze(AValue: integer);
  public
    property aKPCA: TKPCAStream read faKPCA;
    property bWeight: boolean read GetbWeight write SetbWeight;
    property metric: integer read GetMetric write SetMetric; //metric, kernel definition
    property pct: float read GetPct write SetPct; //percent of explained variance to conserve
    property kprm1: float read GetKprm1 write SetKprm1; //exponent, kernel parameter 1
    property bSze: integer read GetbSze write SetbSze; //batch size
    property bKPCAdone: boolean read fbKPCAdone;
    property bGTMready: boolean read fbGTMready;
    procedure SetKPCA(AStream: TStream; ABufferSize: integer;AOwnStream: boolean);
    procedure SetKPCA(AStream: TStream);
    procedure SetMols(mols: LRSMFv2);
    procedure KPCA;
    procedure LoadScores;
    procedure LoadScores(aStr: TStream);
    procedure LoadScores(mols: LRSMFv2);
    procedure Project; override;
    procedure Project(ZT: TMatrix; Nmax: integer); override;
    constructor Create(AStream: TStream; ABufferSize: integer;AOwnStream: boolean);
    constructor Create(AStream: TStream);
    constructor Create;
    destructor Destroy; override;
  end;
implementation

{ TKGTMStream }

function TKGTMStream.GetMetric: integer;
begin
  Result:=faKPCA.metric;
end;

function TKGTMStream.GetFileStream: TRAStream; //Not sure it is of any good...
begin
  Result:=faKPCA.aRAStream;
end;

function TKGTMStream.GetKprm1: float;
begin
  Result:=faKPCA.sigma;
end;

function TKGTMStream.GetPct: float;
begin
  Result:=faKPCA.thr;
end;

function TKGTMStream.GetbWeight: boolean;
begin
  Result:=faKPCA.bWeight;
end;

function TKGTMStream.GetbSze: integer;
begin
  Result:=faKPCA.bsze;
end;

procedure TKGTMStream.SetbWeight(AValue: boolean);
begin
  faKPCA.bWeight:=AValue;
end;

procedure TKGTMStream.SetKprm1(AValue: float);
begin
  try
    if (AValue<0) then
    begin
      raise Exception.Create('TKGTM Error. Unsupported kernel parameter value: '+FloatToStr(AValue));
      halt;
    end;
    faKPCA.sigma:=AValue;
  except
    raise Exception.Create('ERROR TKGTM.SetKprm1: no molecule set');
    Halt;
  end;
end;

procedure TKGTMStream.SetMetric(AValue: integer);
begin
  try
    if (AValue<2) or (AValue>4) then
    begin
      raise Exception.Create('TKGTM Error. Unsupported kernel value: '+IntToStr(AValue));
      halt;
    end;
    faKPCA.metric:=AValue;
  except
    raise Exception.Create('ERROR TKGTM.SetMetric: no molecule set');
    Halt;
  end;
  end;

procedure TKGTMStream.SetPct(AValue: float);
begin
  if (AValue>1) or (AValue<0) then
  begin
    raise Exception.Create('TKGTM Error. Unsupported explained variance value: '+FloatToStr(AValue));
    halt;
  end;
  faKPCA.thr:=AValue;
end;

procedure TKGTMStream.SetbSze(AValue: integer);
begin
  if (AValue>0) then
    faKPCA.bsze:=AValue
  else begin
    raise Exception.Create('ERROR SetbSze: invalid batch size: '+IntToStr(AValue));
    Halt;
  end;
end;

procedure TKGTMStream.SetKPCA(AStream: TStream; ABufferSize: integer;
  AOwnStream: boolean);
begin
  if (faKPCA=nil) then
    faKPCA:=TKPCAStream.Create(AStream,ABufferSize,AOwnStream)
  else begin
    faKPCA.SetRAStream(AStream,ABufferSize,AOwnStream);
    //raise Exception.Create('ERROR SetKPCA: a KPCA is already set.');
    //Halt;
  end;
end;

procedure TKGTMStream.SetKPCA(AStream: TStream);
begin
    SetKPCA(AStream, BUFFER_SIZE, False)
end;

procedure TKGTMStream.SetMols(mols: LRSMFv2);
begin
  if Assigned(faKPCA) then
    faKPCA.AttachToMols(mols)
  else begin
    raise Exception.Create('ERROR TKGTMStream.SetKPCA: KPCA object does not exist.');
    Halt;
  end;
end;

procedure TKGTMStream.KPCA;
begin
  if (faKPCA.aRAStream=nil) then
  begin
    raise Exception.Create('TKGTM Error. No stream has been set.');
    halt;
  end;
  write('Computing stream KPCA...');
  faKPCA.FillSim;
  faKPCA.EigenVec;  // The selection KPC is done as a final step of this method
  //faKPCA.NPCutOff(pct);
  N:=faKPCA.Sze;
  D:=faKPCA.NPC; //The number of columns for the GTM is the number of PC kept
  writeln('...Success');
  fbKPCAdone:=True;
end;

procedure TKGTMStream.LoadScores;
var
  aPC123: TMatrix;//Three firsr KPCA
  aZ: TMatrix; //matrix of KPCA scores
  EV: TVector; //Explained variance per kernel PCA
  i: integer;
  aLog: TStringList;
  scores: LRSMFv2;
begin
  scores:=nil;
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
  AZ:=aKPCA.Project2Mat;
  {scores:=LRSMFv2.Create;
  aKPCA.Project2SMF(scores); // Matrix of KPCA scores
  scores.WriteSVM('tutu.svm','tutu.hdr');
  FreeAndNil(scores);}
  //Halt;
  SetX(aZ); //Load the scores to the GTM
  //PrintMat(AZ,0,10,0,10);
  writeln('...Success');
end;

procedure TKGTMStream.LoadScores(aStr: TStream);
begin

end;

procedure TKGTMStream.LoadScores(mols: LRSMFv2);
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
  aZ:=aKPCA.Project2Mat(mols); // Matrix of KPCA scores
  SetX(aZ); //Load the scores to the GTM
  writeln('...Success');
end;

procedure TKGTMStream.Project;
begin
  inherited Project;
end;

procedure TKGTMStream.Project(ZT: TMatrix; Nmax: integer);
begin
  inherited Project(ZT, Nmax);
end;

constructor TKGTMStream.Create(AStream: TStream; ABufferSize: integer;
  AOwnStream: boolean);
begin
  Create;
  faKPCA.Create(AStream,ABufferSize,AOwnStream);
end;

constructor TKGTMStream.Create(AStream: TStream);
begin
  Create(AStream,BUFFER_SIZE, False);
end;

constructor TKGTMStream.Create;
begin
  faKPCA:=TKPCAStream.Create;//nil;
  //metric:=2; //2: Tanimoto; 3: RBF; 4: Cos
  //pct:=0.95; //95% explained variance
  //kprm1:=1;  //default kernel parameter value
  inherited Create;
  istd:=2; //Always center the scores before attemting a GTM
end;

destructor TKGTMStream.Destroy;
begin
  FreeAndNil(faKPCA);
  inherited Destroy;
end;

end.

