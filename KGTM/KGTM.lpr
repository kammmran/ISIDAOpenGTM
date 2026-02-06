program KGTM;

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}{$IFDEF UseCThreads}
  cthreads,
  {$ENDIF}{$ENDIF}
  Classes, SysUtils, CustApp, TypInfo
  { you can add units after this }, ISIDA_descriptor, ioSVM, UnitGramBase,
  UnitKPCA, utypes, ueigsym,ulinalg,upca,UcGTM,ukgtm_options, UKGTMXML, UnitProc,
  UnitLicence, UnitKGTM, UnitKGTMStream;

const
  ArgLst = 'hi:o:t::m:k:w:l:c:z:j::y:x:b:e:M:G:';
  LngArg = 'help input: type:: output: nSample: nTrait: width: regularization:'+
           'nIter: limit: DoProj:: NewData: xml: blocks: 3D getRmat '+
           'licence: ScaleInit: KPC: ExplainedVar: Metric: Gamma:';

type

  { TKGTMApp }

  TKGTMApp = class(TCustomApplication)
  protected
    procedure DoRun; override;
  public
    constructor Create(TheOwner: TComponent); override;
    destructor Destroy; override;
    procedure WriteHelp; virtual;
  end;

{ TKGTM }

procedure TKGTMApp.DoRun;
var
  GTMOptions: TRKGTMOptions;
  ErrorMsg: String;
  sflnme: string;
  s,sc,st,sk,sl,sn,ss,sy,sz,sscale: string;
  iy,cde,pc: integer;
begin
  //Initialization
  Welcome();
  GTMOptions := TRKGTMOptions.Create;
  // quick check parameters
  ErrorMsg:=CheckOptions(ArgLst, LngArg);
  if ErrorMsg<>'' then begin
    ShowException(Exception.Create(ErrorMsg));
    Terminate;
    Exit;
  end;

  // parse parameters
  if HasOption('licence') then
    CheckLicence(GetOptionValue('licence'))
  else CheckLicence();
  if HasOption('h', 'help') then begin
    WriteHelp;
    Terminate;
    Exit;
  end;
  //
  if HasOption('t','type') then
  begin
    st:=GetOptionValue('t','type');
    GTMOptions.GTMType:=EGTMType(GetEnumValue(Typeinfo(EGTMType), st));
  end;
  if HasOption('i', 'input') then //Input file - SVM format
    GTMOptions.inputFile := GetOptionValue('i', 'input');
  if HasOption('o', 'output') then //Base name for output files
    GTMOptions.outputFile := GetOptionValue('o', 'output');
  if HasOption('x', 'xml') then //XML file name
    GTMOptions.modelFile := GetOptionValue('x', 'xml');
  if HasOption('m','nTrait') then
  begin
    sn := GetOptionValue('m','nTrait');
    //Number of traits of latent probability distribution model (e.g. number of Gaussian distributions).
    GTMOptions.nCenters := StrToInt(sn);
  end;
  if HasOption('k','nSample') then  //Number of samples of the latent probability distribution
  begin
    sk := GetOptionValue('k','nSample');
    GTMOptions.nSamples := StrToInt(sk);
  end;
  if HasOption('w','width') then
  begin
    ss := GetOptionValue('w','width');
    GTMOptions.sigma := StrToFloat(ss);
  end;
  if HasOption('l','regularization') then
  begin
    sl := GetOptionValue('l','regularization');
    GTMOptions.alpha := StrToFloat(sl);
  end;
  if HasOption('c','nIter') then
  begin
    sc := GetOptionValue('c','nIter');
    GTMOptions.nIter := StrToInt(sc);
  end;
  if HasOption('z','limit') then
  begin
    sz := GetOptionValue('z','limit');
    GTMOptions.convCriteria := StrToFloat(sz);
  end;
  if HasOption('j') then
  begin
    GTMOptions.doProjection:=True;
    if HasOption('y') then
    begin
      sy := GetOptionValue('y');
      Val(sy,iy,cde);
      if cde<> 0 then
        GTMOptions.projFile := sy
      else GTMOptions.splitFile:=iy;
    end;
  end;
  if HasOption('b','blocks') then
    GTMOptions.btchSze := StrToInt(GetOptionValue('b','blocks'));
  if HasOption('3D') then
    GTMOptions.p3D:=True;
  if HasOption('getRmat') then
    GTMOptions.Rmat:=True;
  //No pre-processing; the KGTM uses kernels applied to the data as they are provided by the user
  if HasOption('ScaleInit') then
  begin
    sscale:=GetOptionValue('ScaleInit');
    pc:=Pos(':',sscale);
    if (pc<=0) then
      GTMOptions.iScaleInit:=StrToInt(sscale)
    else
    begin
      GTMOptions.iScaleInit:=StrToInt(Copy(sscale,1,pc-1));//int before ";"
      GTMOptions.fScaleInit:=StrToFloat(Copy(sscale,pc+1,Length(sscale)-pc));//float after ";"
    end;
  end;
  if HasOption('KPC') then //KPC file shall store the Kernel PCA coefficients to spare time
    GTMOptions.PCAFile:=GetOptionValue('KPC');
  if HasOption('e','ExplainedVar') then
  begin
    s:=GetOptionValue('e','ExplainedVar');
    GTMOptions.apct:=StrToFloat(s);
    if (GTMOptions.apct<0) or (GTMOptions.apct>1) then
    begin
      raise Exception.Create('KGTM Error. Illegal explained variance threshold: '+s);
      WriteHelp;
      halt;
    end;
  end else GTMOptions.apct:=0.95;
  if HasOption('M','Metric') then
  begin
    s:=GetOptionValue('M','Metric');
    GTMOptions.imetric:=StrToInt(s);
    if (GTMOptions.imetric<2) or (GTMOptions.imetric>4) then
    begin
      raise Exception.Create('KGTM Error. Unsupported kernel value: '+s);
      WriteHelp;
      halt;
    end;
  end;
  if HasOption('G','Gamma') then
  begin
    s:=GetOptionValue('G','Gamma');
    try
      GTMOptions.fgamma:=StrToFloat(s);
    except
      raise Exception.Create('KGTM Error. Unsupported Gamma value: '+s);
      WriteHelp;
      halt;
    end;
  end;
  { add your program here }
  //
  sflnme:=ChangeFileExt(GTMOptions.outputFile,'Prj.mat');
  if FileExists(sflnme) then
  begin
    Writeln('WARNING: flle '+sflnme+ ' exists and will be destroyed');
    DeleteFile(sflnme);
  end;
  sflnme:=ChangeFileExt(GTMOptions.outputFile,'R.svm');
  if FileExists(sflnme) then
  begin
    Writeln('WARNING: flle '+sflnme+ ' exists and will be destroyed');
    DeleteFile(sflnme);
  end;
  sflnme:=ChangeFileExt(GTMOptions.outputFile,'WPhi.mat');
  if FileExists(sflnme) then
  begin
    Writeln('WARNING: flle '+sflnme+ ' exists and will be destroyed');
    DeleteFile(sflnme);
  end;
  sflnme:=ChangeFileExt(GTMOptions.outputFile,'Z.mat');
  if FileExists(sflnme) then
  begin
    Writeln('WARNING: flle '+sflnme+ ' exists and will be destroyed');
    DeleteFile(sflnme);
  end;
  //
  if (GTMOptions.btchSze<=1) then
    DoKGTM(GTMOptions)
  else
    DoKGTMStream(GTMOptions);
  FreeAndNil(GTMOptions);
  Terminate;
end;

constructor TKGTMApp.Create(TheOwner: TComponent);
begin
  inherited Create(TheOwner);
  StopOnException:=True;
end;

destructor TKGTMApp.Destroy;
begin
  inherited Destroy;
end;

procedure TKGTMApp.WriteHelp;
begin
  { add your help code here }
  Writeln('//////////////');
  Writeln('KGTM help');
  Writeln('//////////////');
  Writeln;
  Writeln('-h, --help');
  Writeln(#9 + 'get help');
  Writeln('-i, --input');
  Writeln(#9 + 'svm input file');
  Writeln(#9 + '(-i myfile.svm)');
  Writeln('-o, --output');
  Writeln(#9 + 'output file');
  Writeln('-w');
  Writeln(#9 + 'width factor for radial basis functions');
  Writeln(#9 + '(-w 1.5)');
  Writeln('-m, --nTrait');
  Writeln(#9 + 'number of RBF centers');
  Writeln(#9 + '(-m 5, for 5 RBF)');
  Writeln('-k, --nSample');
  Writeln(#9 + 'number of grid points');
  Writeln(#9 + '(-k 125, for 125 sampling points)');
  Writeln('-l');
  Writeln(#9 + 'regularization coefficient, usually between 0 and 100');
  Writeln(#9 + '(-l 10.0)');
  Writeln('-r');
  Writeln('-c');
  Writeln(#9 + 'number of iterations');
  Writeln(#9 + '(-c 100)');
  Writeln('-b');
  Writeln(#9 + 'number of instances per block for incremental or per block algorithm');
  Writeln(#9 + '(-b 1000)');
  Writeln('-j');
  Writeln(#9 + 'perform projection of training data');
  Writeln(#9 + '(no argument)');
  Writeln(#9 + '(-j -y model_projection.xml)');
  Writeln(#9 + 'dataset to project');
  Writeln(#9 + '(-j -y toproject.svm)');
  Writeln('-x');
  Writeln(#9 + 'input model for projection');
  Writeln(#9 + '(-x model_projection.xml)');
  Writeln('--3D');
  Writeln(#9 + 'compute manifold and data coordinates in PCA 3D space');
  Writeln(#9 + '(no argument)');
  Writeln('-p');
  Writeln(#9 + 'pre-processing');
  Writeln(#9 + '0: no pre-processing; 1: standardization; 2: center; 3: normalization into [-1,1]; 4: normalization into [-1,1] then center');
  Writeln('-z');
  Writeln(#9+'convergence criteria');
  Writeln(#9+'(-z 0.001)');
  Writeln('--ScaleInit [0|1|2]');
  Writeln(#9+'initial geometry of the manifold (0: standard; 1: max extension; 2;<float>: scale the initial geometry by <float>)');
  Writeln(#9+'(--ScaleInit 0)');
  Writeln('--PC123 filePC123.mat'); Writeln(#9+'Use pre-computed three first principal components');
  Writeln(#9+'(File name in .mat format. The first line of data should be the eigenvalues.)');
  Writeln('--licence licence.dat');
  Writeln(#9 + 'licence file if not at usual place.');
  Writeln;
  Writeln('///////////');
  Writeln('Examples');
  Writeln('///////////');
  Writeln;
  Writeln('- Simple GTM: ');
  Writeln('$ GTMapTool -i train.svm -o output -k 15 -m 5 -w 0.5 -l 10');
  Writeln;
  Writeln('- Simple GTM + project train + 3D: ');
  Writeln('$ GTMapTool -i train.svm -o output -k 15 -m 5 -j --3D');
  Writeln;
  Writeln('- Projection of test data on existing model: ');
  Writeln('$ GTMapTool -i mySvm.svm -x myGTM.xml -o output -j -y test.svm');
  Writeln;
end;

var
  Application: TKGTMApp;
begin
  Application:=TKGTMApp.Create(nil);
  Application.Title:='KGTM';
  Application.Run;
  Application.Free;
end.

