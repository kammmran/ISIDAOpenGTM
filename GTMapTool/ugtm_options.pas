unit ugtm_options;

{$mode objfpc}{$H+}
//Macro so that at compile time, if GUI is used, writeln will store
//strings into a SLog TStringList and if not, it is directed to stdout.
{$MACRO ON}
{$DEFINE WRITELN:={$IFDEF GUI}SLog.Add{$ELSE}writeln{$ENDIF}}

interface

uses
  Classes, SysUtils, utypes, ISIDA_DESCRIPTOR;//, ueigen_ops;

type

  EGTMType = (BISHOP, INCREMENTAL, MULTINOMIAL, KGTM, UNKGTM);
  { TRGtmOptions }

  TRGtmOptions = class(TPersistent)
  private
    fGTMType: EGTMType;
    finputFile: string; //input file
    foutputFile: string; //output file
    fmodelFile: string; //model file
    fPCAFile: string; //file of precomputed PCA
    fCfgXml: string; //file of GTM Configuration file
    fiCfgXml: integer; //What to do with the GTM Configuration file
    fnSamples: integer;
    //number of samples of the latent probability distribution (this a square of an integer)
    fnCenters: integer;
    //number of traits of the latent probability distribution (this a square of an integer, smaller than fnSample)
    fsigma: Float; //Width of RBF; default value = fsqrtSamples/5
    falpha: float; //Regularization coefficient
    fnIter: integer; //max number of EM iteration
    fconvCriteria: Float;
    fsplitFile: integer;
    fnBlocks: integer;
    fprojFile: string;
    fdoProjection: boolean;
    fpreprocess: integer; //0: no preprocessing; 1: standardize; 2: center
    f3D: boolean;
    fRmat: boolean;
    fiScaleInit: integer;
    ffScaleInit: double;
    fMatX, fMatM: TMatrix; //To store the traits and samples
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
    property nBlocks: integer read fnBlocks write fnBlocks;
    property p3D: boolean read f3D write f3D;//output the 3D projections of data and manifold
    property CfgXml: string read fCfgXml write fCfgXml;//the GTMConfig.xml file
    property iCfgXml: integer read fiCfgXml write fiCfgXml;//what to do with the GTMConfig.xml file
    property preprocess: integer read fpreprocess write fpreprocess;
    property Rmat: boolean read fRmat write fRmat;
    property iScaleInit: integer read fiScaleInit write fiScaleInit;//scaling manifold initialization (0: original scaling; 1: scale to max data extent; 2: custom)
    property fScaleInit: double read ffScaleInit write ffScaleInit;//scaling factor
    {degree: Float;
    cste: Float;
    slope: Float;
    kernelCentering: boolean;
    beginProp: integer;
    mute: boolean;
    computeDescScores: boolean;
    CPF: Float;
    kernelType: string;
    dissimilarityType: string;
    alpha: Float;
    descWeight: Float;
    nDimensions: integer;
    nfactors: integer;
    nFolds: integer;
    featureSpaceDimension: integer;
    distanceType: integer;
    seed: integer;
    foldIter: integer;
    prop: Float;
    Initialize: integer;
    numberOfInputFiles: integer;
    convergenceCriterion: Float;
    freezingConstant: Float;
    regulation: Float;
    gamma: Float;
    sparse: boolean;
    BIN: boolean;
    COVAR: boolean;
    probabilisticProjection: boolean;
    computeMagnificationFactors: boolean;
    normalize: boolean;
    FromCovariance: boolean;
    computeManifold: boolean;
    evalSolidAngles: boolean;
    evalDistances: boolean;
    doIncrement: boolean;
    doBatch: boolean;
    performCV: boolean;
    randomize: boolean;
    writeMe: boolean;
    classify: boolean;
    regress: boolean;
    kernel: boolean;
    dissimilarity: boolean;
    freeze: boolean;
    meanPCA: boolean;
    missing: boolean;
    NIPALS: boolean;
    beware0: boolean;
    prior: boolean;
    binaryDistribution: string;
    kernelTrain: string;
    kernelTest: string;
    kernelTestVTrain: string;
    kernelFile: string;
    dissimilarityFile: string;
    dissimilarityTrain: string;
    dissimilarityTestVTrain: string;
    discardedDescriptors: string;
    reverseProjectionFile: string;
    scaling: string;
    lbatchW: TStringList;
    lbatchL: TStringList;
    lbatchK: TStringList;
    lbatchM: TStringList;
    linputFiles: TStringList;}
    procedure Reset;
    constructor Create;
    destructor Destroy; override;
    {$IFDEF GUI}
    procedure WriteOptions(var SLog:TStringList);
    {$ELSE}
    procedure WriteOptions;
    {$ENDIF}
    procedure Assign(Source: TPersistent); override;
  end;
  function GTMTypeToString(aGTMType: EGTMType): string;

implementation

function GTMTypeToString(aGTMType: EGTMType): string;
begin
  case aGTMType of
    BISHOP: Result:='BISHOP';
    INCREMENTAL: Result:='INCREMENTAL';
    MULTINOMIAL: Result:='MULTINOMIAL';
    UNKGTM: Result:='UNKNOWN';
  end;
end;

procedure TRGtmOptions.Reset;//Reset the object
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
  fnBlocks:=0;
  f3D:=False;
  fCfgXml:='GTMConfig.xml';
  fpreprocess:=1;
  fRmat:=False;
  fiScaleInit:=0;
  ffScaleInit:=0.0;
end;

constructor TRGtmOptions.Create;
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
  fnBlocks:=0;
  f3D:=False;
  fCfgXml:='GTMConfig.xml';
  fpreprocess:=1;
  fRmat:=False;
  fiScaleInit:=0;
  ffScaleInit:=0.0;
  {degree := 2;
  cste := 0;
  slope := 1;
  regulation := 0.001;
  BIN := False;
  kernelCentering := False;
  computeDescScores := False;
  beginProp := 0;
  lbatchW := TStringList.Create;
  lbatchL := TStringList.Create;
  lbatchK := TStringList.Create;
  lbatchM := TStringList.Create;
  linputFiles := TStringList.Create;
  numberOfInputFiles := 1;
  Initialize := 50;
  CPF := 0.0;
  nDimensions := 0;
  nfactors := 0;
  nFolds := 5;
  distanceType := 0;
  seed := 118105245;
  foldIter := 0;
  prop := 0.0;
  nBlocks := 0;
  freezingConstant := 10E-100;
  sparse := False;
  standardize := False;
  probabilisticprojection := False;
  computeManifold := False;
  computeMagnificationFactors := False;
  evalSolidAngles := False;
  evalDistances := False;
  performCV := False;
  doIncrement := False;
  doBatch := False;
  doProjection := False;
  randomize := False;
  writeMe := False;
  classify := False;
  regress := False;
  MUTE := False;
  kernel := False;
  normalize := False;
  freeze := False;
  meanPCA := False;
  NIPALS := False;
  COVAR := False;
  dissimilarity := False;
  beware0 := False;
  kernelType := 'gauss';
  binarydistribution := 'bernoulli';
  projectionFile := '';
  discardedDescriptors := '';
  scaling := '';
  kernelFile := '';
  reverseProjectionFile := '';
  dissimilarityFile := '';
  dissimilarityTrain := '';
  dissimilarityTestVTrain := '';}
end;

destructor TRGtmOptions.Destroy;
begin
  inherited Destroy;
  finputFile := '';
  foutputFile := '';
  {projectionFile := '';
  kernelFile := '';
  FreeAndNil(lbatchW);
  FreeAndNil(lbatchL);
  FreeAndNil(lbatchK);
  FreeAndNil(lbatchM);}
end;

(*******************************WRITE OPTIONS**********************************)

{$IFDEF GUI}
procedure TRGtmOptions.WriteOptions(var SLog:TStringList);
{$ELSE}
procedure TRGtmOptions.WriteOptions;
{$ENDIF}
var
  randomString: string;
  projectionString: string;
  cvString: string;
  batchString: string;
begin
  WRITELN('');
  {if randomize = True then
    randomString := 'TRUE'
  else
    randomString := 'FALSE';
  if performCV = True then
    cvString := 'TRUE'
  else
    cvString := 'FALSE';
  if doBATCH = True then
    batchString := 'TRUE'
  else
    batchString := 'FALSE';
  if doProjection = True then
    projectionString := 'TRUE'
  else
    projectionString := 'FALSE';}
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
    UNKGTM: WRITELN('GTM type not recognized');
  end;
  WRITELN('***********INPUT AND OUTPUT PATHS***********');
  WRITELN('Input file: ' + finputFile);
  WRITELN('Output file: ' + foutputFile);
  WRITELN('GTM configuration file: ' + fCfgXml);
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
    WRITELN('ERROR: invalid setup. The number of nodes ('+
    IntToStr(fnSamples)+')'+' cannot be larger than the number of traits ('+
    IntToStr(fnCenters)+').');
    Halt;
  end;
  case fiScaleInit of
    0: WRITELN('Standard manifold Initialization.');
    1: WRITELN('Max. extened manifold Initialization.');
    2: WRITELN('Scaling manifold extention initialization = '+FloatToStr(ffScaleInit));
    else begin
      WRITELN('ERROR: Scaling option not recognized.');
      Halt;
    end;
  end;
  WRITELN('********************************************');
  if (GTMType=BISHOP) or (GTMType=INCREMENTAL) then
  begin
    WRITELN('********NORMAL ALGORITHM PARAMETERS*********');
    if (falpha<>-1) then
      WRITELN('Regularization coefficient: ' + FloatToStr(falpha))
    else
      WRITELN('Regularization coefficient: default');
    if p3D then
      WRITELN('Output initial space coordinates requested');
    if p3D then
      WRITELN('Output Configuration XML requested');
    case preprocess of
      0: WRITELN('Input attributes are NOT transformed.');
      1: WRITELN('Input attributes are standardized.');
      2: WRITELN('Input attributes are centered.');
      3: WRITELN('Input attributes are normalized into [-1,1]');
      4: WRITELN('Input attributes are normalized into [-1,1] then centered');
      else begin
        WRITELN('ERROR: unsupported value for the preprocess option: '+IntToStr(preprocess));
        halt;
      end;
    end;
    WRITELN('********************************************');
  end;
  if nBlocks>0 then
  begin
    WRITELN('*********BLOCK ALGORITHM PARAMETERS*********');
    WRITELN('Number of data/molecules per increment: ' +
      IntToStr(nBlocks));
    //WRITELN('Number of initialization molecules: ' + IntToStr(Initialize));
    WRITELN('********************************************');
  end;
  if GTMType=MULTINOMIAL then
  begin
    WRITELN('*****MULTINOMIAL ALGORITHM PARAMETERS*****');
    if (fsigma<=0) then
      WRITELN('RBF width automatic setting. width='+FloatToStr(1/(2*sqrt((2*2/(fnCenters-1))))));
    WRITELN('Number of data/molecules per block: ' +
      IntToStr(nBlocks));
    WRITELN('********************************************');
  end;
  {WRITELN('Random initialization of W: ' + RandomString);
  if nfactors <> 0 then
    WRITELN('Number of principal components for pca pre-processing: ' + IntToStr(nfactors));
  WRITELN('Minimum proportion of descriptor values not equal to zero: ' +
    FloatToSTr(prop));
}
  {WRITELN;
  WRITELN('************OPTIONAL COMPUTATIONS***********');
  Write('Compute score of descriptors: ');
  Write(computedescscores);
  WRITELN;
  Write('Compute points and manifold coordinates in 3D PCA space : ');
  Write(computeManifold);
  WRITELN;
  // Write('Compute solid angles : '); write(evalSolidAngles); WRITELN;
  // Write('Compute distance matrix : '); write(evalDistances); WRITELN;
  WRITELN('********************************************');
  WRITELN;
  WRITELN('********************MODE********************');
  WRITELN('Do cross-validation: ' + cvString);
  WRITELN('Do batch: ' + batchString);
  Write('Do incremental learning: ');
  Write(doIncrement);
  WRITELN;
  Write('Do kernel: ');
  Write(kernel);
  WRITELN;
  Write('Write files: ');
  Write(not mute);
  WRITELN;
  Write('Latent trait: ');
  Write(bin);
  WRITELN;
  Write('Sparse data: ');
  Write(sparse);
  WRITELN;
  WRITELN('********************************************');
  WRITELN;}

  {if BIN then
  begin
    WRITELN('*****LATENT TRAIT ALGORITHM PARAMETERS*****');
    WRITELN('Type of distribution: ' + binaryDistribution);
    WRITELN('Regularization: ' + FloatToStr(regulation));
    WRITELN('********************************************');
  end;


  if kernelFile <> '' then
    kernelType := 'external';

  if kernel = True then
  begin
    WRITELN('*******KERNEL ALGORITHM PARAMETERS*******');
    WRITELN('Type of kernel: ' + kernelType);
    WRITELN('Number of feature space dimensions: ' + IntToStr(featureSpaceDimension));
    if kernelType = 'poly' then
    begin
      WRITELN('Degree: ' + FloatToStr(degree));
      WRITELN('Slope: ' + FloatToStr(slope));
      WRITELN('Constant: ' + FloatToStr(cste));
    end;
    if kernelType = 'linear' then
      WRITELN('Constant: ' + FloatToStr(cste));
    if kernelType = 'gauss' then
      WRITELN('Gamma: ' + FloatToStr(gamma));
    if kernelType = 'anova' then
    begin
      WRITELN('Degree: ' + FloatToStr(degree));
      WRITELN('Gamma: ' + FloatToStr(gamma));
    end;
    WRITELN('********************************************');
  end;
  WRITELN;

  if performCV then
  begin
    WRITELN('*******CROSS VALIDATION OPTIONS********');
    WRITELN('Number of folds: ' + IntToStr(nFolds));
    WRITELN('Seed: ' + IntToStr(seed));
    WRITELN('********************************************');
  end;
  WRITELN;}

  WRITELN('');
  WRITELN('***************************************************************');
  WRITELN('***********************BEGIN COMPUTATIONS**********************');
  WRITELN('***************************************************************');
  WRITELN('');
  WRITELN('');

end;

procedure TRGtmOptions.Assign(Source: TPersistent);
var
  S: TRGtmOptions;
begin
  S := (Source as TRGtmOptions);

  finputFile := S.inputFile;
  foutputFile := S.outputFile;
  nSamples := S.nSamples;
  nCenters := S.nCenters;
  {bin := otherOptions.BIN;
  degree := otherOptions.degree;
  slope := otherOptions.slope;
  cste := otherOptions.cste;
  kernelCentering := otherOptions.kernelCentering;
  beginProp := otherOptions.beginProp;
  mute := otherOptions.mute;
  computeDescScores := otherOptions.computeDescScores;
  CPF := otherOptions.CPF;
  nSamples := otherOptions.nSamples;
  kernelType := otherOptions.kernelType;
  nCenters := otherOptions.nCenters;
  sqrtSamples := otherOptions.sqrtSamples;
  sqrtCenters := otherOptions.sqrtCenters;
  nBlocks := otherOptions.nBlocks;
  sigma := otherOptions.sigma;
  alpha := otherOptions.alpha;
  nDimensions := otherOptions.nDimensions;
  nfactors := otherOptions.nfactors;
  nFolds := otherOptions.nfolds;
  nIter := otherOptions.nIter;
  featureSpaceDimension := otherOptions.featureSpaceDimension;
  distanceType := otherOptions.distanceType;
  seed := otherOptions.seed;
  foldIter := otherOptions.foldIter;
  prop := otherOptions.prop;
  Initialize := otherOptions.Initialize;
  numberOfInputFiles := otherOptions.numberOfInputFiles;
  convergenceCriterion := otherOptions.convergenceCriterion;
  freezingConstant := otherOptions.freezingConstant;
  gamma := otherOptions.gamma;
  computeMagnificationFactors := otherOptions.computeMagnificationFactors;
  normalize := otherOptions.normalize;
  computeManifold := otherOptions.computeManifold;
  evalSolidAngles := otherOptions.evalSolidAngles;
  evalDistances := otherOptions.evalDistances;
  doIncrement := otherOptions.doIncrement;
  doBatch := otherOptions.doBatch;
  doProjection := otherOptions.doProjection;
  performCV := otherOptions.performCV;
  randomize := otherOptions.randomize;
  writeMe := otherOptions.writeMe;
  classify := otherOptions.classify;
  regress := otherOptions.regress;
  kernel := otherOptions.kernel;
  freeze := otherOptions.freeze;
  meanPCA := otherOptions.meanPCA;
  missing := otherOptions.missing;
  inputFile := otherOptions.inputFile;
  outputFile := otherOptions.outputFile;
  kernelTrain := otherOptions.kernelTrain;
  kernelTest := otherOptions.kernelTest;
  kernelTestVTrain := otherOptions.kernelTestVTrain;
  kernelFile := otherOptions.kernelFile;
  discardedDescriptors := otherOptions.discardedDescriptors;
  scaling := otherOptions.scaling;
  projectionFile := otherOptions.projectionFile;
 (* lbatchW := otherOptions.lbatchW;
  lbatchL := otherOptions.lbatchL;
  lbatchK := otherOptions.lbatchK;
  lbatchM := otherOptions.lbatchM;
  linputFiles := otherOptions.linputFiles; *)
  }
end;



end.
