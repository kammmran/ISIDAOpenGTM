program GTMClass;

{$mode objfpc}{$H+}

uses {$IFDEF UNIX} {$IFDEF UseCThreads}
  cthreads, {$ENDIF} {$ENDIF}
  Classes, SysUtils, CustApp, streamex, GTMClassFunctions, UGTMBase, UGTMXML,
  ugtm_options, Math, gtmc_option, UGTMClass, UnitCVsvm,
  UnitClsStats { you can add units after this };

const
  shtOpt = 'hm:r:R:t:p:P:n:d:o:l:x:WN';
  lngOpt =
    'help mapFile: trainRsp: testRsp: ADThreshold: trainPrp: testPrp: nodeThreshold: densityThreshold: crossValidate: outputFile: author: title: landscapeFile: writeLandscapeOnly propName: comment: PRatio: classNormalization';

type

  {Options}
  TOpt = record
    MinRespAD: double;//Min responsability value to be in applicability domain
    MinResp: double; //Min responsability value to count for landscape
    MinDens: double; //Min density
    Nfolds: integer; //Number of folds in cross-validation
    MapFileNme: string; //The GTM file
    trRspFileNme: string; // training Responsibilities file name
    trPrpFileNme: string; // training Properties file name
    teRspFileNme: string; // test Responsibilities file name
    tePrpFileNme: string; // test Properties file name
    OutFileNme: string; //Output base name
    MdlFileNme: string; //Landscape file name
    Author: string; //Author of the landscape
    useLandscape: boolean; //Use landscape
    PropComment: string; //Comments for property file
    PropName: shortstring; //short property name (max 255 char)
    Title: string; // A title for the map
    writeLSOnly: boolean; //Write the landscape
    Build: boolean; //Building mode
    Pred: boolean; //Prediction mode
    Validate: boolean; // Validation mode
    classNormalization: boolean; // Class normalization
    PRatio: double; // Prevalence ratio - recommended value 0.5?
  end;

  { TGTMClass }

  TGTMClassCA = class(TCustomApplication)
  protected
    procedure DoRun; override;
  public
    constructor Create(TheOwner: TComponent); override;
    destructor Destroy; override;
    procedure WriteHelp; virtual;
  end;


  { TGTMClass }

  procedure TGTMClassCA.DoRun;
  var
  aGTMClass: TGTMClass;
  aCV: TCVsvm;
  SLtrain,SLtest,SLProp:TStringList;
  kfold,i,ii: integer;
  kfold1: integer;//Number of statistics added to the sum
  aClsStat: TClsStats;
  aStat,aStatSum: TAoD;
  pdbl: PDouble;
  Opt: TOpt;
  SLlog: TStringList;//log
  ipos: integer;//position in string
  sres: string; // temporary string variable
  ErrorMsg: string;
  bAddToStat: Boolean;//Add statistic to sum of stat?
  procedure WriteOptions(Opt: TOpt);
  begin
    writeln('***********************************');
    writeln('*                                 *');
    writeln('*           ISIDA/GTMClass        *');
    writeln('*                                 *');
    writeln('* Marcou G.                       *');
    writeln('*                                 *');
    writeln('* Université de Strasbourg  2024  *');
    writeln('***********************************');
    writeln;
    writeln('GTM model                               : ' + Opt.MapFileNme);
    if not Opt.useLandscape then
    begin
      writeln('Input training responsibilities         : ' + Opt.trRspFileNme);
      writeln('Input training properties               : ' + Opt.trPrpFileNme);
      writeln('Property short name                     : ' + Opt.PropName);
      writeln('Title                                   : ' + Opt.Title);
      writeln('Author                                  : ' + Opt.Author);
      writeln('Comment                                 : ' + Opt.PropComment);
    end
    else
    begin
      writeln('Input landscape                         : ' + Opt.MdlFileNme);
      writeln('Input test responsibilities             : ' + Opt.teRspFileNme);
      writeln('Input test properties                   : ' + Opt.tePrpFileNme);
    end;
    if Opt.classNormalization=true then
      writeln('Used class normalization                : '+BoolToStr(Opt.classNormalization));
    writeln('Min. responsibility value for AD        : ' + FloatToStr(Opt.MinRespAD));
    writeln('Min. responsibility value for landscape : ' + FloatToStr(Opt.MinResp));
    writeln('Min. density value for AD               : ' + FloatToStr(Opt.MinDens));
    writeln('Prevalence Ratio - PRatio               : ' + FloatToStr(Opt.PRatio));
    writeln('Base of output file names               : ' + Opt.OutFileNme);
    writeln;
    if Opt.Build then writeln('Building a landscape');
    if Opt.Pred then begin
      if FileExists(Opt.tePrpFileNme) then begin
        writeln('Model validation on new data');
        writeln('Input test responsibilities         : ' + Opt.teRspFileNme);
        writeln('Input test properties               : ' + Opt.tePrpFileNme);
      end else begin
        writeln('Using landscape for predictions');
        writeln('Responsibilities                    : ' + Opt.teRspFileNme);
      end;
    end;
    if Opt.Validate then begin
      writeln('Validation of landscape');
      Writeln('Cross-validation, number of folds     : ' + IntToStr(Opt.Nfolds));
    end;
    writeln('***********************************');
  end;
  begin
    //Default Opt values
    with Opt do
    begin
      MinRespAD := 0.0;//Min responsability value to be in applicability domain
      MinResp := 0.0; //Min responsability value to count for landscape
      MinDens := 0.0; //Min density
      Nfolds:=0;      // Cross-validation
      MapFileNme := '';
      trRspFileNme := '';
      trPrpFileNme := '';
      teRspFileNme := '';
      tePrpFileNme := '';
      OutFileNme := 'default';
      MdlFileNme:= 'default';
      Author:='';
      useLandscape := False;
      PropComment:='';
      PropName:='default';
      Title:='no title';
      writeLSOnly  := False;
      Build    := False;
      Pred     := False;
      Validate := False;
      classNormalization:= False;
      PRatio:=1.0; // Prevalence ratio
    end;
    //
    // quick check parameters
    ErrorMsg := CheckOptions(shtOpt, lngOpt);
    if ErrorMsg <> '' then
    begin
      ShowException(Exception.Create(ErrorMsg));
      Terminate;
      Exit;
    end;
    // parse parameters
    if HasOption('h', 'help') then
    begin
      WriteHelp;
      Terminate;
      Exit;
    end;
    //
    if HasOption('m', 'mapFile') then
    begin
      Opt.MapFileNme := GetOptionValue('m', 'mapFile');
    end else
    begin
      writeln('ERROR: missing GTM XML model. GTM model is mandatory for a landscape.');
      Terminate;
      Exit;
    end;
    //
    if HasOption('l', 'landscapeFile') then
    begin
      Opt.MdlFileNme := GetOptionValue('l', 'landscapeFile');
      Opt.useLandscape := True;
    end;
    //AD options
    if HasOption('t', 'ADThreshold') and
      (Opt.useLandscape = False) then
    begin
      Opt.MinRespAD := StrToFloat(GetOptionValue('t', 'ADThreshold'));
    end;
    if HasOption('n', 'nodeThreshold') and (Opt.useLandscape = False) then
    begin
      Opt.MinResp := StrToFloat(GetOptionValue('n', 'nodeThreshold'));
    end;
    if HasOption('d', 'densityThreshold') and (Opt.useLandscape = False) then
    begin
      Opt.MinDens := StrToFloat(GetOptionValue('d', 'densityThreshold'));
    end;
    //
    if HasOption('r', 'trainMatR') and (Opt.useLandscape = False) then
    begin
      Opt.trRspFileNme := GetOptionValue('r', 'trainMatR');
      if HasOption('p', 'trainPrp') then
      begin
        Opt.trPrpFileNme := GetOptionValue('p', 'trainPrp');
      end
      else
      begin
        writeln('ERROR: training a landscape. A property file is mandatory.');
        Terminate;
        Exit;
      end;
      if HasOption('author') then
        Opt.Author := GetOptionValue('author');
      if HasOption('propName') then
        Opt.PropName:=GetOptionValue('propName');
      if HasOption('title') then
        Opt.Title:=GetOptionValue('title');
      if HasOption('comment') then
        Opt.PropComment:=GetOptionValue('comment');
      if HasOption('x','crossValidate') then
      begin
        Opt.Nfolds:=StrToInt(GetOptionValue('x','crossValidate'));
        Opt.Build:=False;
        Opt.Validate:=True;
        Opt.Pred:=False;
      end;
      if HasOption('PRatio') then
        Opt.PRatio:=StrToFloat(GetOptionValue('PRatio'));
      If not Opt.Validate then Opt.Build:=True;
    end
    else if HasOption('r', 'trainMatR') and (Opt.useLandscape = True) then
    begin
      writeln('ERROR: Using existing model. No training responsibilities needed.');
      Terminate;
      Exit;
    end;
    if HasOption('W', 'writeLandscapeOnly') then
    begin
      Opt.writeLSOnly := True;
      Opt.Build:=True;
      Opt.Validate:=False;
      Opt.Pred:=False;
    end;
    if HasOption('N','classNormalization') then
    begin
      Opt.classNormalization:=True;
    end;
    //
    if HasOption('R', 'testMatR') and (Opt.writeLSOnly = False) then
    begin
      Opt.teRspFileNme := GetOptionValue('R', 'testMatR');
      //Opt.Build:=False;
      Opt.Validate:=False;
      Opt.Pred:=True;
      if HasOption('P', 'testPrp') then
      begin
        Opt.tePrpFileNme := GetOptionValue('P', 'testPrp');
      end
    end
    else if HasOption('R', 'testMatR') and (Opt.writeLSOnly = True) then
    begin
      writeln('ERROR: Using an existing landscape on test set responsibilities is incompatible with saving the command to save the landscape only.');
      Terminate;
      Exit;
    end
    else if (not (HasOption('R', 'testMatR') or HasOption('x','crossValidate'))) and (Opt.writeLSOnly = False) then
    begin
      writeln('ERROR: do you wish to predict (where is -R?) or do you wish to create landscape only (where is -W?)');
      Terminate;
      Exit;
    end;
    //
    if HasOption('o', 'outputFile') then
      Opt.OutFileNme:= GetOptionValue('o', 'outputFile');
    //
    WriteOptions(Opt);
    //
    if Opt.Build=True then
    begin
      SLlog:=TStringList.Create;
      aGTMClass:= TGTMClass.Create;
      aGTMClass.ReadGTMModel(Opt.MapFileNme); //Setup the GTM model from the XML file
      aGTMClass.PrpName:=Opt.PropName;
      aGTMClass.MinRspToNode:=Opt.MinResp;
      aGTMClass.MinDensityLS:=Opt.MinDens;
      aGTMClass.bClassNormalize:=Opt.classNormalization;
      aGTMClass.rClsThrd:=Opt.PRatio; // PRatio - seems to have been deactivated. To check.
      TrainLandscape(aGTMClass,Opt.trRspFileNme,Opt.trPrpFileNme,Opt.OutFileNme,Opt.Author,Opt.Title,Opt.PropComment,SLlog);
      writeln(SLlog.Text); SLlog.Clear;
      //
      if (Opt.Pred=True) and (FileExists(Opt.tePrpFileNme)) then
      begin
        SLlog.Add('---- Predictions - Responsibilities: '+Opt.teRspFileNme+ ' / Properties: '+Opt.tePrpFileNme+' ----');
        Writeln(SLlog.Text); SLlog.Clear;
        if (aGTMClass=nil) then exit;
        SLlog.Add('Min. responsibility value for AD: '+ FloatToStr(aGTMClass.MinRspToNode)+
          ', Min. density value to contribute landscape: '+ FloatToStr(aGTMClass.MinDensityLS)+
          ', Number of nodes: '+ IntToStr(aGTMClass.K));
        Writeln(SLlog.Text); SLlog.Clear;
        aClsStat:=TClsStats.Create;
        SLtest:=TStringList.Create;
        SLProp:=TStringList.Create;
        SLtest.LoadFromFile(Opt.teRspFileNme);
        SLProp.LoadFromFile(Opt.tePrpFileNme);
        for i:=1 to SLProp.Count-1 do //Ignore line 1: a comment
        begin
          ii:=i-1;
          sres:=SLProp[i];
          ipos:=pos(' ',SLtest[ii]);
          sres:=sres+copy(SLtest[ii],ipos,Length(SLtest[ii]));
          SLtest[ii]:=sres;
        end;
        UseLandscape(aGTMClass,SLtest,Opt.OutFileNme,aClsStat,SLlog);
        Writeln(SLlog.Text); SLlog.Clear;
        //
        SLlog.Add('/------------ Performances ------------\');
        SLlog.Add('Accuracy          ='+FloatToStrF(aClsStat.Accuracy,ffFixed,3,4));
        SLlog.Add('Balanced Accuracy ='+FloatToStrF(aClsStat.BalancedAccuracy,ffFixed,3,4));
        for i:=1 to aGTMClass.classSL.Count-1 do
        begin
          SLlog.Add('Precision('+aGTMClass.classSL[i]+')='+FloatToStrF(aClsStat.Precision(i-1),ffFixed,3,4));
          SLlog.Add('Recall('+aGTMClass.classSL[i]+')   ='+FloatToStrF(aClsStat.Recall(i-1),ffFixed,3,4));
          SLlog.Add('F('+aGTMClass.classSL[i]+')        ='+FloatToStrF(aClsStat.Fmeasure(i-1),ffFixed,3,4));
          SLlog.Add('MCC('+aGTMClass.classSL[i]+')      ='+FloatToStrF(aClsStat.MCC(i-1),ffFixed,3,4));
        end;
        Writeln(SLlog.Text); SLlog.Clear;
        FreeAndNil(SLProp);
        FreeAndNil(SLtest);
        FreeAndNil(aClsStat);
      end;
      FreeAndNil(SLlog);
      FreeAndNil(aGTMClass);
    end else if Opt.Pred=True then
    begin
      SLlog:=TStringList.Create;
      aGTMClass:= TGTMClass.Create;
      SLlog.Add('Begin to read specified landscape and projected responsibilities.');
      readLandscape(Opt.MdlFileNme,aGTMClass);
      SLlog.Add('---- Predictions - Responsibilities: '+Opt.teRspFileNme+ ' / Properties: '+Opt.tePrpFileNme+' ----');
      Writeln(SLlog.Text); SLlog.Clear;
      if (aGTMClass=nil) then exit;
      SLlog.Add('Min. responsibility value for AD: '+ FloatToStr(aGTMClass.MinRspToNode)+
        ', Min. density value to contribute landscape: '+ FloatToStr(aGTMClass.MinDensityLS)+
        ', Number of nodes: '+ IntToStr(aGTMClass.K));
      Writeln(SLlog.Text); SLlog.Clear;
      if (Opt.tePrpFileNme='') or (not FileExists(Opt.tePrpFileNme)) then begin
        UseLandscape(aGTMClass,Opt.teRspFileNme,Opt.OutFileNme,SLlog);
        Writeln(SLlog.Text); SLlog.Clear;
      end
      else
      begin
        aClsStat:=TClsStats.Create;
        SLtest:=TStringList.Create;
        SLProp:=TStringList.Create;
        SLtest.LoadFromFile(Opt.teRspFileNme);
        SLProp.LoadFromFile(Opt.tePrpFileNme);
        for i:=1 to SLProp.Count-1 do //Ignore line 1: a comment
        begin
          ii:=i-1;
          sres:=SLProp[i];
          ipos:=pos(' ',SLtest[ii]);
          sres:=sres+copy(SLtest[ii],ipos,Length(SLtest[ii]));
          SLtest[ii]:=sres;
        end;
        UseLandscape(aGTMClass,SLtest,Opt.OutFileNme,aClsStat,SLlog);
        Writeln(SLlog.Text); SLlog.Clear;
        //
        SLlog.Add('/------------ Performances ------------\');
        SLlog.Add('Accuracy          ='+FloatToStrF(aClsStat.Accuracy,ffFixed,3,4));
        SLlog.Add('Balanced Accuracy ='+FloatToStrF(aClsStat.BalancedAccuracy,ffFixed,3,4));
        for i:=1 to aGTMClass.classSL.Count-1 do
        begin
          SLlog.Add('Precision('+aGTMClass.classSL[i]+')='+FloatToStrF(aClsStat.Precision(i-1),ffFixed,3,4));
          SLlog.Add('Recall('+aGTMClass.classSL[i]+')   ='+FloatToStrF(aClsStat.Recall(i-1),ffFixed,3,4));
          SLlog.Add('F('+aGTMClass.classSL[i]+')        ='+FloatToStrF(aClsStat.Fmeasure(i-1),ffFixed,3,4));
          SLlog.Add('MCC('+aGTMClass.classSL[i]+')      ='+FloatToStrF(aClsStat.MCC(i-1),ffFixed,3,4));
        end;
        Writeln(SLlog.Text); SLlog.Clear;
        FreeAndNil(SLProp);
        FreeAndNil(SLtest);
        FreeAndNil(aClsStat);
      end;
      FreeAndNil(aGTMClass);
      FreeAndNil(SLlog);
    end else if Opt.Validate=True then
    begin
      SLlog:=TStringList.Create;      //Setup cross validation
      aClsStat:=TClsStats.Create; //A place to store exp and pred values and compute statistics
      SLtrain:=TStringList.Create;
      SLtest:= TStringList.Create;
      aCV:=TCVsvm.Create;
      aCV.Nfolds:=Opt.Nfolds;
      aCV.SetSLSVMFromFileAndProp(Opt.trRspFileNme,Opt.trPrpFileNme);//Property values are attached in column 1
      //Do CV
      SetLength(aStat,2);
      SetLength(aStatSum,2);
      for i:=Low(aStatSum) to high(aStatSum) do aStatSum[i]:=0;
      kfold1:=0; //For some fold the statistics are not computed -> effective number of folds can be lower than expected
      for kfold:=1 to aCV.Nfolds do
      begin
        aCV.GenerateFold(kfold,SLtrain,SLtest);
        aGTMClass:= TGTMClass.Create;
        aGTMClass.ReadGTMModel(Opt.MapFileNme); //Setup the GTM model from the XML file
        aGTMClass.PrpName:=Opt.PropName;
        aGTMClass.MinRspToNode:=Opt.MinRespAD;
        aGTMClass.MinDensityLS:=Opt.MinDens;
        aGTMClass.rClsThrd:=Opt.PRatio;
        if Opt.classNormalization then
          aGTMClass.bClassNormalize:=True
        else
          aGTMClass.bClassNormalize:=False;
        TrainLandscape(aGTMClass,SLtrain,Opt.OutFileNme+'_train-fold'+IntToStr(kfold),Opt.Author,Opt.Title,Opt.PropComment,SLlog);
        Writeln(SLlog.Text); SLlog.Clear;
        aGTMClass.SetMolCountToZero;
        UseLandscape(aGTMClass,SLtest,Opt.OutFileNme+'_test-fold'+IntToStr(kfold),aClsStat,SLlog);
        Writeln(SLlog.Text); SLlog.Clear;
        //Output results
        aStat[0]:=aClsStat.Accuracy();
        aStat[1]:=aClsStat.BalancedAccuracy();
        bAddToStat:=True;
        i:=Low(aStatSum);
        while(bAddToStat=True) and (i<=High(aStatSum)) do
        begin
         if (IsNan(aStat[i])) then bAddToStat:=False;
          Inc(i);
        end;
        if bAddToStat then
        begin
          Inc(kfold1);
          for i:=Low(aStatSum) to High(aStatSum) do
            aStatSum[i]:=aStatSum[i]+aStat[i];
        end;
        SLlog.Add('*------------- fold '+IntToStr(kfold)+' -------------*');
        SLlog.Add('Accuracy         ='+FloatToStrF(aStat[0],ffFixed,3,4));
        SLlog.Add('Balanced Accuracy ='+FloatToStrF(aStat[1],ffFixed,3,4));
        Writeln(SLlog.Text); SLlog.Clear;
        //
        FreeAndNil(aGTMClass);
      end;
      // Averaged performances
      for i:=Low(aStatSum) to High(aStatSum) do
        aStatSum[i]:=aStatSum[i]/kfold1;
      SLlog.Add('************** Averaged performances **************');
      SLlog.Add('Accuracy          ='+FloatToStrF(aStatSum[0],ffFixed,3,4));
      SLlog.Add('Balanced Accuracy ='+FloatToStrF(aStatSum[1],ffFixed,3,4));
      Writeln(SLlog.Text); SLlog.Clear;
      //
      FreeAndNil(aClsStat);
      FreeAndNil(aCV);
      FreeAndNil(SLtrain);
      FreeAndNil(SLtest);
      FreeAndNil(SLlog);
    end;
    Writeln('.............. Calculations complete ..............');
    //
    Terminate;
  end;

constructor TGTMClassCA.Create(TheOwner: TComponent);
  begin
    inherited Create(TheOwner);
    StopOnException := True;
  end;

  destructor TGTMClassCA.Destroy;
  begin
    inherited Destroy;
  end;

  procedure TGTMClassCA.WriteHelp;
  begin
    { add your help code here }
    writeln();
    writeln('USAGE: GTMClass [-h] [-m] <manifold.xml> [-R] <testR.svm> '+
            '[-o] <output> [-l] <Landscape.xml> [-r] <trainR.svm> '+
            '[-p] <train_properties.prp>  [-P] <test_properties.prp>'+
            '[-t] <AD Threshold> [-n] <Node Threshold> '+
            '[-d] <Density Threshold> [-x] <CV nFolds> [-W] [-N]');
    writeln();
    writeln('-h, --help                              ', ' -get Help;');
    writeln('-r, --trainRsp                          ',
      ' -a training set responsibility (*R.svm) file');
    writeln('-p, --trainPrp                          ',
      ' -the training set property file, one compound per line; the first line of this file is a comment');
    writeln('-R, --testRsp                           ',
      ' -a test set responsibility (*R.svm) file;');
    writeln('-P, --testPrp                          ',
      ' -the test set property file, one compound per line; the first line of this file is a comment');
    writeln('-m, --mapFile                           ',
      ' -a GTM manifold used to locate the (x,y) coordinates of each node;');
    writeln('-t, --ADThreshold                       ',
      ' -a molecule''s maximal responsibility must be larger than this '+
      'threshold to be inside the applicability domain (default value: 0.0)');
    writeln('-n, --nodeThreshold                     ',
      ' -nodes which cumulated responsibilities are below this threshold are '+
      'no model regions; they are out of applicability domain '+
      '(default value: 0.0)');
    writeln('-d, --densityThreshold                     ',
      ' -nodes which cumulated responsibilities are below this threshold are '+
      'no model regions; they are out of applicability domain '+
      '(default value: 0.0)');
    writeln('--PRatio                                ',
      ' -Prevalence ratio (default value 1.0).');
    writeln('-l, --landscapeFile                     ',
      ' -an input existing landscape file, for prediction;');
    writeln('-o, --outputFile                        ',
      ' -the base name for output files;');
    writeln('-W, --writeLandscapeOnly                ',
      ' -compute and save a landscape, do not apply the model;');
    writeln('-N, --classNormalization                ',
      ' -Normalize the classes, simulating balanced classes;');
    writeln('-x, --crossValidate                     ',
      ' -the number of folds to use for cross-validation;');
    writeln('--author                                ',
      ' -input the name of the author of the landscape.');
    writeln('--title                                 ',
      ' -input the title of the landscape.');
    writeln('--propName                              ',
      ' -a short name for the property.');
    writeln('--comment                               ',
      ' -a comment to add to the model.');
  end;

var
  Application: TGTMClassCA;
begin
  {$IfDef WINDOWS}DefaultFormatSettings.DateSeparator:='-';{$EndIf}
  {$IfDef LOCALES}DefaultFormatSettings.DecimalSeparator:='.';DefaultFormatSettings.ShortDateFormat:='d/m/y';{$EndIf}
  Application := TGTMClassCA.Create(nil);
  Application.Run;
  Application.Free;
end.
