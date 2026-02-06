program SGTM;

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}{$IFDEF UseCThreads}
  cthreads,
  {$ENDIF}{$ENDIF}
  Classes, SysUtils, CustApp, utypes, uProc, uSgGTM, UcGTM,  UGTMXML,
  UnitLicence;

const
  ShortArg='hi:o:p:k:m:w:l:v:c:z:';
  LongArg='help input: output: preprocess: nTrait: nSample: width: regularization: weights: nIter: limit: licence:';

type

  { TSGTM }

  TSGTM = class(TCustomApplication)
  protected
    procedure DoRun; override;
  public
    constructor Create(TheOwner: TComponent); override;
    destructor Destroy; override;
    procedure WriteHelp; virtual;
  end;

{ TSGTM }

procedure TSGTM.DoRun;
var
  ErrorMsg: String;
  sinput,soutput,svalue,sline: string;
  SLaVw,SLinput,SLErr: TStringList;
  i: integer;
  am, ak,app: integer; // traits, nodes, preprocessing
  aw, al: double; // width, regularization
  LLt,LLt0,dLL,LLeps: double; // a likelihood
  iter,itermax: integer; // training loop iterator
  bConv: boolean; // training converged yes or no?
  aVw: TVector; // Map weighting
  Vwnrm: double;
  aSgGTM: TSgGTM;
  acGTM: TcGTM;
  aGTMXML: TGTMXML;
begin
  sinput:='';
  soutput:='default';
  SLErr:=nil;
  SLinput:=TStringList.Create;
  SLaVw:=TStringList.Create;
  DimVector(aVw,1);//Only two maps for now
  aVw[0]:=0.;
  aVw[1]:=0.;
  Vwnrm:=0.;
  acGTM:=nil;
  aGTMXML:=nil;
  // Default parameters
  app:=1;
  ak:=-1;
  am:=-1;
  aw:=-1;
  al:=-1;
  itermax:=100;
  LLeps:=0.001;
  //
  Welcome();
  // quick check parameters
  ErrorMsg:=CheckOptions(ShortArg, LongArg);
  if ErrorMsg<>'' then begin
    ShowException(Exception.Create(ErrorMsg));
    Terminate;
    Exit;
  end;

  // parse parameters
  if HasOption('h', 'help') then begin
    WriteHelp;
    Terminate;
    Exit;
  end;

  if HasOption('o', 'output') then begin
    soutput:=GetOptionValue('o','output');
  end;
  if HasOption('i','input') then begin
    sinput:=GetOptionValue('i','input');
    SLinput.DelimitedText:=sinput;
    if SLinput.Count<>2 then begin
      SLErr:=TStringList.Create;
      SLErr.Add('ERROR: SGTM needs exactly two input files. Your actual inputs are:');
      for i:=0 to SLinput.Count-1 do SLErr.Add(SLinput[i]);
      raise Exception.Create(SLErr.Text);
      WriteHelp;
      Terminate;
      Exit;
    end;
  end;
  //Get GTM options
  if HasOption('p','preprocess') then begin
    svalue:=GetOptionValue('p','preprocess');
    try
      app:=StrToInt(svalue);
    except
      raise Exception.Create('ERROR, p/preprocess, invalud preprocessing option');
      Terminate;
      Exit;
    end;
  end;
  if HasOption('m','traits') then begin
    svalue:=GetOptionValue('m','traits');
    try
      am:=StrToInt(svalue);
    except
      raise Exception.Create('ERROR, invalid m/traits value: '+svalue);
      Terminate;
      Exit;
    end;
  end;
  if HasOption('k','nodes') then begin
    svalue:=GetOptionValue('k','nodes');
    try
      ak:=StrToInt(svalue);
    except
      raise Exception.Create('ERROR, invalid k/nodes value: '+svalue);
      Terminate;
      Exit;
    end;
  end;
  if HasOption('w','width') then begin
    svalue:=GetOptionValue('w','width');
    try
      aw:=StrToFloat(svalue);
    except
      raise Exception.Create('ERROR, invalid (w/width) value: '+svalue);
      Terminate;
      Exit;
    end;
  end;
  if HasOption('l','regularization') then begin
    svalue:=GetOptionValue('l','regularization');
    try
      al:=StrToFloat(svalue);
    except
      raise Exception.Create('ERROR, invalid (l/regularization) value: '+svalue);
      Terminate;
      Exit;
    end;
  end;
  //
  if HasOption('c','nIter') then begin
    svalue:=GetOptionValue('c','nIter');
    try
      itermax:=StrToInt(svalue);
    except
      raise Exception.Create('ERROR, invalid (c/nIter) value: '+svalue);
      Terminate;
      Exit;
    end;
  end;
  if HasOption('z','limit') then begin
    svalue:=GetOptionValue('z','limit');
    try
      LLeps:=StrToFloat(svalue);
    except
      raise Exception.Create('ERROR, invalid (z/limit) value: '+svalue);
      Terminate;
      Exit;
    end;
  end;
  //
  if HasOption('v','weights') then begin
    svalue:=GetOptionValue('v','weights');
    SLaVw.DelimitedText:=svalue;
    try
      for i:=0 to SLaVw.Count-1 do begin
        aVw[i]:=StrToFloat(SLaVw[i]);
      end;
    except
      raise Exception.Create('ERROR, invalid (v/weights) values: '+svalue);
      Terminate;
      Exit;
    end;
    if (aVw[0]+aVw[1]<>1) then aVw[1]:=1-aVw[0];
  end;
  //
  if HasOption('licence') then begin
    svalue:=GetOptionValue('licence');
    CheckLicence(svalue);
  end else CheckLicence();
  { add your program here }

  //Build a consistent set of parameters
  if (aK<=0) then
  begin
    if (aw=-1) then //default nSamples and sigma
    begin
      aw:=2*sqrt(4/aM);//sigma=2*(spacing between RBF)
      aK := 25*aM;//Round(sqr(5.64 /GTMOptions.sigma));
    end else //default nSample but sigma defined
      aK := 25*aM;//Round(sqr(5.64 /GTMOptions.sigma));
  end else if (aw=-1) then //defined nSample but sigma undefined
    aw := 5.64 / sqrt(aK); // Recommendation to have O(100) samples within 2 sigma radius
  // nSample and sigma defined: nothing to do
  if (al=-1) then
    al := 1; // Each weight defining the GTM manifold obeys a standard normal distribution
  //
  PrintParameters(soutput,app, aK,aM,aw,al,SLaVw,SLinput);
  // Create SGTM
  aSgGTM:=TSgGTM.Create();
  // Load Data
  write('Loading data...');
  aSgGTM.PP:=app;//Set the pre-processing procedure before reading the data
  aSgGTM.ReadMols(SLinput);
  Writeln('...OK');
  if (aVw[0]=0) and (aVw[1]=0) then begin
    aVw[0]:=(aSgGTM.OLGTM[0] as TcGTM).D;
    aVw[1]:=(aSgGTM.OLGTM[1] as TcGTM).D;
    Vwnrm:=aVw[0]+aVw[1];
    aVw[0]:=aVw[0]/Vwnrm;
    aVw[1]:=aVw[1]/Vwnrm;
    Writeln('Weights - update: ');
    for i:=0 to 1 do
      Writeln('                 map['+IntToStr(i)+']='+FloatToStr(aVw[i]));
  end;
  aSgGTM.Vw[0]:=aVw[0];
  aSgGTM.Vw[1]:=aVw[1];
  //
  Writeln('Number of training instances: ',aSgGTM.N);
  write('Initializing maps...');
  aSgGTM.Init1(aK,aM,aw,al);
  Writeln('...OK');
  // Initializing training loop
  aSgGTM.Expectation();
  LLt:=aSgGTM.LogLikelyHood();
  sline:='';
  LLt0:=0;
  writeln('LLt=',LLt);
  iter:=0;
  bConv:=False;
  // Training loop
  repeat
    Inc(iter);
    LLt0:=LLt;
    aSgGTM.Maximization();
    aSgGTM.Expectation();
    LLt:=aSgGTM.LogLikelyHood();
    sline:='Iter.: '+IntToStr(Iter)+' LLmap='+FloatToStrF(LLt,ffFixed,8,5)+' ';
    dLL:=LLt-LLt0;
    sline:=sline+'DLLmap='+FloatToStrF(dLL,ffFixed,8,5)+' %DLLmap='+FloatToStrF(abs((dLL)*100/LLt0),ffFixed,8,5);
    writeln(sline);
    if (abs(dLL)<LLeps) or (iter>=itermax) then
      bConv:=True;
  until bConv;
  Writeln('...Successfull training');
  //Finishing
  Writeln('Finalizing...');
  for i:=0 to 1 do begin
    acGTM:=aSgGTM.OLGTM[i];
    aGTMXML:=TGTMXML.Create;
    aGTMXML.WriteGTMModel(acGTM,ChangeFileExt(soutput,'_map'+IntToStr(i)+'.xml'));
    FreeAndNil(aGTMXML);
  end;
  Writeln('...OK');
{
myGTM.Init1(GTMOpt.nSamples,GTMOpt.nCenters,GTMOpt.sigma,GTMOpt.alpha,GTMOpt.iScaleInit,GTMOpt.fScaleInit);
WRITELN('******************Reminder******************');
WRITELN('Width of rbf: ' + FloatToStr(myGTM.sigma));
WRITELN('Regularization coefficient: ' + FloatToStr(myGTM.alpha));
WRITELN('********************************************'); APP_PROCESS;
WRITELN('Number of training instances: '+IntToStr(myGTM.N));APP_PROCESS;
myGTM.Expectation();
LLt:=myGTM.LogLikelyHood();
WRITELN('First LLt='+FloatToStr(LLt));APP_PROCESS;
LLt0:=0;
iter:=1;
bConv:=False;
DimMatrix(Wold,myGTM.D,myGTM.M); //Keep track of the previous state of the map
DW0:=myGTM.D*myGTM.M;//scaling factor for W
//Train the map on the input file
repeat
  myGTM.Maximization();
  myGTM.Expectation();
  LLt:=myGTM.LogLikelyHood();
  sline:='Iter.: '+IntToStr(Iter)+' LLmap='+FloatToStrF(LLt,ffFixed,8,5)+' ';
  if iter>1 then
  begin
    dLL:=LLt-LLt0;
    sline:=sline+'DLLmap='+FloatToStrF(dLL,ffFixed,8,5)+' %DLLmap='+FloatToStrF(abs((dLL)*100/LLt0),ffFixed,8,5);
    // How much did the map changed
    DW:=0;
    for id:=1 to myGTM.D do
      for im:=1 to myGTM.M do
      begin
        if (DW<abs(Wold[id,im]-myGTM.W[id,im])) then DW:=abs(Wold[id,im]-myGTM.W[id,im]);
        Wold[id,im]:=myGTM.W[id,im];
      end;
    dConv:=DW/DW0;
    sline:=sline+' DW='+FloatToStrF(DW,ffFixed,8,5)+' %DW='+FloatToStrF(dConv*100,ffFixed,8,5);
    If dLL<GTMOpt.convCriteria then bConv:=True;
  end;
  WRITELN(sline);APP_PROCESS;
  //Prepare next iteration
  LLt0:=LLt;
  Inc(iter);
until (iter>GTMOpt.nIter) or (bConv=True);
//Save the map
GTM_XML:=TGTMXML.Create;
GTM_XML.WriteGTMModel(myGTM,ChangeFileExt(GTMOpt.outputFile,'.xml'));
FreeAndNil(GTM_XML);

}



  // stop program loop
  FreeAndNil(aSgGTM);
  FreeAndNil(SLinput);
  FreeAndNil(SLaVw);
  Terminate;
end;

constructor TSGTM.Create(TheOwner: TComponent);
begin
  inherited Create(TheOwner);
  StopOnException:=True;
end;

destructor TSGTM.Destroy;
begin
  inherited Destroy;
end;

procedure TSGTM.WriteHelp;
begin
  { add your help code here }
  writeln('Usage: ', ExeName, ' -h -o <output> -i <input1>,<input2> '+
          '-v <double>,<double> -m <integer> -k <integer> -w <double> '+
          '-l <double> -c <integer> -z <double>');
  writeln('-o, --output: base name of output files');
  writeln('-i, --input: comma separated list of input files in SVM format. No blanks are allowed');
  writeln('-p, --preprocess: pre-processing option. 0: nothing, 1 (default): center, 2: standardize, 3: normalize, 4: normalize+center');
  writeln('-v, --weights: comma separated weights of each spaces');
  writeln('-m, --nTrait: number of RBF (traits)');
  writeln('-k, --nSample: number of nodes (sampling points)');
  writeln('-w, --width: RBF width');
  writeln('-l, --regularization: regularization parameter');
  writeln('-c, nIter: number of optimization iteration (default=100)');
  writeln('-z, --limit: convergence criteria (default=0.001)');
end;

var
  Application: TSGTM;
begin
  {$IfDef WINDOWS}DefaultFormatSettings.DateSeparator:='-';{$EndIf}
  {$IfDef LOCALES}DefaultFormatSettings.DecimalSeparator:='.';DefaultFormatSettings.ShortDateFormat:='d/m/y';{$EndIf}
  Application:=TSGTM.Create(nil);
  Application.Title:='SGTM';
  Application.Run;
  Application.Free;
end.

