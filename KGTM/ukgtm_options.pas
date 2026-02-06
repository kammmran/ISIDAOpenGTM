unit ukgtm_options;

{$mode objfpc}{$H+}
//Macro so that at compile time, if GUI is used, writeln will store
//strings into a SLog TStringList and if not, it is directed to stdout.
{$MACRO ON}
{$DEFINE WRITELN:={$IFDEF GUI}SLog.Add{$ELSE}writeln{$ENDIF}}

interface

uses
  Classes, SysUtils, TypInfo, utypes, ISIDA_DESCRIPTOR;//, ueigen_ops;

type

  EGTMType = (BISHOP, INCREMENTAL, MULTINOMIAL, KGTM, KGTMSTREAM, UNK);
  { TRKGTMOptions }

  TRKGTMOptions = class(TPersistent)
  private
    fGTMType: EGTMType;
    finputFile: string; //input file
    foutputFile: string; //output file
    fmodelFile: string; //model file
    fPCAFile: string; //file of precomputed PCA
    fnSamples: integer;
    //number of samples of the latent probability distribution (this a square of an integer)
    fnCenters: integer;
    //number of traits of the latent probability distribution (this a square of an integer, smaller than fnSample)
    fsigma: Float; //Width of RBF; default value = fsqrtSamples/5
    falpha: float; //Regularization coefficient
    fnIter: integer; //max number of EM iteration
    fconvCriteria: Float;
    fsplitFile: integer;
    fbtchSze: integer;
    fprojFile: string;
    fdoProjection: boolean;
    f3D: boolean;
    fRmat: boolean;
    fiScaleInit: integer;
    ffScaleInit: double;
    fimetric: integer; //Kernel choice
    ffgamma: double; // Kernel parameter
    fapct: double; //Explained variance
  public
    property GTMType: EGTMType read fGTMType write fGTMType;
    property inputFile: string read finputFile write finputFile;
    property outputFile: string read foutputFile write foutputFile;
    property modelFile: string read fmodelFile write fmodelFile;
    property PCAFile: string read fPCAFile write fPCAFile;
    property nSamples: integer read fnSamples write fnSamples;
    property nCenters: integer read fnCenters write fnCenters;
    property sigma: float read fsigma write fsigma;
    property alpha: float read falpha write falpha;
    property nIter: integer read fnIter write fnIter;
    property convCriteria: float read fconvCriteria write fconvCriteria;
    property doProjection: boolean read fdoProjection write fdoProjection;
    property projFile: string read fprojFile write fprojFile;
    property splitFile: integer read fsplitFile write fsplitFile;
    property btchSze: integer read fbtchSze write fbtchSze;
    property p3D: boolean read f3D write f3D;//output the 3D projections of data and manifold
    property Rmat: boolean read fRmat write fRmat;
    property iScaleInit: integer read fiScaleInit write fiScaleInit;//scaling manifold initialization (0: original scaling; 1: scale to max data extent; 2: custom)
    property fScaleInit: double read ffScaleInit write ffScaleInit;//scaling factor
    property imetric: integer read fimetric write fimetric;
    property fgamma: double read ffgamma write ffgamma;
    property apct: double read fapct write fapct;
    procedure Reset;
    constructor Create;
    destructor Destroy; override;
    {$IFDEF GUI}
    procedure WriteOptions(var SLog:TStringList);
    {$ELSE}
    procedure WriteOptions;
    {$ENDIF}
  end;
  function GTMTypeToString(aGTMType: EGTMType): string;

implementation

function GTMTypeToString(aGTMType: EGTMType): string;
begin
  Result:=GetEnumName(TypeInfo(EGTMType),Ord(aGTMType));
  {case aGTMType of
    BISHOP: Result:='BISHOP';
    INCREMENTAL: Result:='INCREMENTAL';
    UNK: Result:='UNKNOWN';
  end;}
end;

procedure TRKGTMOptions.Reset;//Reset the object
begin
  fGTMType := BISHOP;
  finputFile := '';
  foutputFile := 'defaultOut';
  fmodelFile:='';
  fPCAFile:='';
  nSamples := 0;//125;
  nCenters := 25;
  fsigma := -1.0;//Guess a default value
  falpha := -1.0;
  fnIter := 100;
  fconvCriteria := 0.001;
  fdoProjection:=False;
  fprojFile:='';
  fsplitFile:=-1;
  fbtchSze:=0;
  f3D:=False;
  fRmat:=False;
  fiScaleInit:=0;
  ffScaleInit:=0.0;
  fimetric:=0;
  ffgamma:=1.0;
  fapct:=0.95;
end;

constructor TRKGTMOptions.Create;
begin
  inherited Create;
  fGTMType := BISHOP;
  finputFile := '';
  foutputFile := 'defaultOut';
  fmodelFile:='';
  fPCAFile:='';
  nSamples := 0;//125;
  nCenters := 25;
  fsigma := -1.0;//Guess a default value
  falpha := -1.0;
  fnIter := 100;
  fconvCriteria := 0.001;
  fdoProjection:=False;
  fprojFile:='';
  fsplitFile:=-1;
  fbtchSze:=0;
  f3D:=False;
  fRmat:=False;
  fiScaleInit:=0;
  ffScaleInit:=0.0;
  fimetric:=0;
  ffgamma:=1.0;
  fapct:=0.95;
end;

destructor TRKGTMOptions.Destroy;
begin
  inherited Destroy;
  finputFile := '';
  foutputFile := '';
end;

(*******************************WRITE OPTIONS**********************************)

{$IFDEF GUI}
procedure TRGtmOptions.WriteOptions(var SLog:TStringList);
{$ELSE}
procedure TRKGTMOptions.WriteOptions;
{$ENDIF}
var
  randomString: string;
  projectionString: string;
  cvString: string;
  batchString: string;
begin
  WRITELN('');
  {$IFDEF GUI}SLog.Add{$ELSE}writeln{$ENDIF}('');
  WRITELN('***************************************************************');
  WRITELN('**************************YOUR OPTIONS*************************');
  WRITELN('***************************************************************');
  WRITELN('');
  WRITELN('***************************************************************');
  if fmodelFile<>'' then WRITELN('Load model file: '+fmodelFile);
  case fGTMType of
    BISHOP: WRITELN('Classical GTM');
    INCREMENTAL: WRITELN('Incremental GTM');
    MULTINOMIAL: WRITELN('Multinomial GTM');
    KGTM: WriteLn('Kernel GTM');
    KGTMSTREAM: Writeln('Stream Kernel GTM');
    UNK: WRITELN('GTM type not recognized');
  end;
  WRITELN('***********INPUT AND OUTPUT PATHS***********');
  WRITELN('Input file: ' + finputFile);
  WRITELN('Output file: ' + foutputFile);
  if (fPCAFile<>'') then WRITELN('Pre-computed PCA: ' + fPCAFile);
  if doProjection = True then
    if projFile<>'' then
      WRITELN('Projection of data from file: ' + projFile)
    else if (splitFile>0) then
      WRITELN('Map first '+IntToStr(splitFile)+' lines, project remaining on map')
    else
      WRITELN('Project input data on generated map');
  WRITELN('********************************************');
  WRITELN('');
  WRITELN('********BASIC ALGORITHM PARAMETERS**********');
  if (fsigma<>-1) then
    WRITELN('Width of rbf: ' + FloatToStr(fsigma))
  else
    WRITELN('Width of rbf: default');
  WRITELN('Number of traits of the latent probability distribution (e.g. rbf centers): '
    + IntToStr(fnCenters));
  WRITELN('Number of samples of the probability distribution: ' + IntToStr(fnSamples));
  WRITELN('Maximum number of iterations: ' + IntToStr(nIter));
  WRITELN('Convergence precision: +/- ' + FloatToStr(convCriteria));
  if (fnCenters>fnSamples) then //Check some consistency of the parameters
  begin
    raise Exception.Create('ERROR: invalid setup. The number of nodes ('+
    IntToStr(fnSamples)+')'+' cannot be larger than the number of traits ('+
    IntToStr(fnCenters)+').');
    Halt;
  end;
  WRITELN('Metric: '+GetEnumName(TypeInfo(EMetric),fimetric));
  WRITELN('Gamma: '+FloatToStr(ffgamma));
  case fiScaleInit of
    0: WRITELN('Standard manifold Initialization.');
    1: WRITELN('Max. extened manifold Initialization.');
    2: WRITELN('Scaling manifold extention initialization = '+FloatToStr(ffScaleInit));
    else begin
      raise Exception.Create('ERROR: Scaling option not recognized.');
      Halt;
    end;
  end;
  WRITELN('Explained variance: '+FloatToStr(fapct));
  WRITELN('********************************************');
  if (GTMType=BISHOP) then
  begin
    WRITELN('********NORMAL ALGORITHM PARAMETERS*********');
    if (falpha<>-1) then
      WRITELN('Regularization coefficient: ' + FloatToStr(falpha))
    else
      WRITELN('Regularization coefficient: default');
    if p3D then
      WRITELN('Output initial space coordinates requested');
    WRITELN('********************************************');
  end;
  if btchSze>0 then
  begin
    WRITELN('*********BLOCK ALGORITHM PARAMETERS*********');
    WRITELN('Number of data/molecules per increment: ' +
      IntToStr(btchSze));
    //WRITELN('Number of initialization molecules: ' + IntToStr(Initialize));
    WRITELN('********************************************');
  end;
  WRITELN('');
  WRITELN('***************************************************************');
  WRITELN('***********************BEGIN COMPUTATIONS**********************');
  WRITELN('***************************************************************');
  WRITELN('');
  WRITELN('');
end;

end.
