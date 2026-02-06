program GTMReg;

{$mode objfpc}{$H+}

uses {$IFDEF UNIX} {$IFDEF UseCThreads}
  cthreads, {$ENDIF} {$ENDIF}
  Classes,
  SysUtils,
  CustApp,
  streamex,
  GTMRegFunctions,
  UGTMBase,
  UGTMXML,
  ugtm_options,
  Math,ulinalg,utypes,
  UGTMReg, UnitCVsvm, UnitClsStat { you can add units after this };

const
  shtOpt = 'hm:r:R:t:p:P:n:d:o:l:x:W';
  lngOpt =
    'help mapFile: trainRsp: testRsp: ADThreshold: trainPrp: testPrp: nodeThreshold: densityThreshold: trustworthinessThreshold: crossValidate: outputFile: author: title: landscapeFile: writeLandscapeOnly propName: comment: tau: alpha: beta:';

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
    tau: double;//Trustworthiness constant - recommended value 0.01
    alpha: double;//Trustworthiness density exponent - recommended value 0.1
    beta: double;//Trustworthiness coherence exponent - recommended value 1.0
    Tthrd: double;//Thrustworthiness threshold AD - recommended value 0.7
  end;

  { TGTMReg }

  TGTMRegCA = class(TCustomApplication)
  protected
    procedure DoRun; override;
  public
    constructor Create(TheOwner: TComponent); override;
    destructor Destroy; override;
    procedure WriteHelp; virtual;
  end;


  { TGTMReg }

  procedure TGTMRegCA.DoRun;
  var
  aGTMReg: TGTMReg;
  aCV: TCVsvm;
  SLtrain,SLtest,SLProp:TStringList;
  kfold,i: integer;
  aClsStat: TClsStat;
  aStat,aStatSum: TAoD;
  pdbl: PDouble;
  Opt: TOpt;
  SLlog: TStringList;//log
  ErrorMsg: string;
  bAddToStat: Boolean;//Add statistic to sum of stat?
  kfold1: integer;//Number of statistics added to the sum
  procedure WriteOptions(Opt: TOpt);
  begin
    writeln('***********************************');
    writeln('*                                 *');
    writeln('*           ISIDA/GTMReg          *');
    writeln('*                                 *');
    writeln('* Marcou G., Lin A.               *');
    writeln('*                                 *');
    writeln('* Université de Strasbourg  2019  *');
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
    writeln('Min. responsibility value for AD        : ' + FloatToStr(Opt.MinRespAD));
    writeln('Min. responsibility value for landscape : ' + FloatToStr(Opt.MinResp));
    writeln('Min. density value for AD               : ' + FloatToStr(Opt.MinDens));
    writeln('Trustwothiness - tau                    : ' + FloatToStr(Opt.tau));
    writeln('Trustwothiness - alpha                  : ' + FloatToStr(Opt.alpha));
    writeln('Trustwothiness - beta                   : ' + FloatToStr(Opt.beta));
    writeln('Trustwothiness - threshold              : ' + FloatToStr(Opt.Tthrd));
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
      tau:=0.0;
      alpha:=0.0;
      beta:=0.0;
      Tthrd:=0.0;;
      Nfolds:=0;
      MapFileNme := '';
      trRspFileNme := '';
      trPrpFileNme := '';
      teRspFileNme := '';
      tePrpFileNme := '';
      OutFileNme := 'default';
      Author:='';
      useLandscape := False;
      writeLSOnly  := False;
      PropName:='default';
      Title:='no title';
      Build    := False;
      Pred     := False;
      Validate := False;
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
      if HasOption('tau') then
        Opt.tau:=StrToFloat(GetOptionValue('tau'));
      if HasOption('alpha') then
        Opt.alpha:=StrToFloat(GetOptionValue('alpha'));
      if HasOption('beta') then
        Opt.beta:=StrToFloat(GetOptionValue('beta'));
      if HasOption('trustworthinessThreshold') then
        Opt.Tthrd:=StrToFloat(GetOptionValue('trustworthinessThreshold'));
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
      aGTMReg:= TGTMReg.Create;
      aGTMReg.ReadGTMModel(Opt.MapFileNme); //Setup the GTM model from the XML file
      aGTMReg.PrpName:=Opt.PropName;
      aGTMReg.MinRspToNode:=Opt.MinResp;
      aGTMReg.MinDensityLS:=Opt.MinDens;
      aGTMReg.MinRspAD:=Opt.MinRespAD;
      aGTMReg.dTtau:=Opt.tau;
      aGTMReg.dTalpha:=Opt.alpha;
      aGTMReg.dTbeta:=Opt.beta;
      aGTMReg.dTT:=Opt.Tthrd;
      TrainLandscape(aGTMReg,Opt.trRspFileNme,Opt.trPrpFileNme,Opt.OutFileNme,Opt.Author,Opt.Title,Opt.PropComment,SLlog);
      writeln(SLlog.Text); SLlog.Clear;
      //
      if (Opt.Pred=True) and (FileExists(Opt.tePrpFileNme)) then
      begin
        SLlog.Add('---- Predictions - Responsibilities: '+Opt.teRspFileNme+ ' / Properties: '+Opt.tePrpFileNme+' ----');
        Writeln(SLlog.Text); SLlog.Clear;
        if (aGTMReg=nil) then exit;
        SLlog.Add('Min. responsibility on labeled nodes for AD: '+ FloatToStr(aGTMReg.MinRspAD)+
          ', Min. responsiblity value to contribute landscape: '+ FloatToStr(aGTMReg.MinRspToNode)+
          ', Min. density value to contribute landscape: '+ FloatToStr(aGTMReg.MinDensityLS)+
          ', Number of nodes: '+ IntToStr(aGTMReg.K));
        Writeln(SLlog.Text); SLlog.Clear;
        aClsStat:=TClsStat.Create;
        SLtest:=TStringList.Create;
        SLProp:=TStringList.Create;
        SLtest.LoadFromFile(Opt.teRspFileNme);
        SLProp.LoadFromFile(Opt.tePrpFileNme);
        for i:=1 to SLProp.Count-1 do //Ignore line 1: a comment
        begin
          new(pdbl);
          pdbl^:=StrToFloat(SLProp[i]);
          SLtest.Objects[i-1]:=TObject(pdbl);
        end;
        UseLandscape(aGTMReg,SLtest,Opt.OutFileNme,aClsStat,SLlog);
        Writeln(SLlog.Text); SLlog.Clear;
        for i:=0 to SLtest.Count-1 do
        begin
          pdbl:=Pdouble(SLtest.Objects[i]);
          if pdbl<>nil then dispose(pdbl);
        end;
        FreeAndNil(SLProp);
        FreeAndNil(SLtest);
        //
        SLlog.Add('/------------ Performances ------------\');
        SLlog.Add('RMSE          = '+FloatToStrF(aClsStat.RMSE(),ffFixed,3,4));
        SLlog.Add('MAE           = '+FloatToStrF(aClsStat.MAE(),ffFixed,3,4));
        SLlog.Add('Relative RMSE = '+FloatToStrF(aClsStat.RelRMSE(),ffFixed,3,4));
        SLlog.Add('Relative MAE  = '+FloatToStrF(aClsStat.RelMAE(),ffFixed,3,4));
        SLlog.Add('R2det         = '+FloatToStrF(aClsStat.R2det(),ffFixed,3,4));
        SLlog.Add('CCC           = '+FloatToStrF(aClsStat.CCC(),ffFixed,3,4));
        SLlog.Add('R2cor         = '+FloatToStrF(aClsStat.R2cor(),ffFixed,3,4));
        Writeln(SLlog.Text); SLlog.Clear;
        FreeAndNil(aClsStat);
      end;
      //
      FreeAndNil(aGTMReg);
      FreeAndNil(SLlog);
    end else if Opt.Pred=True then
    begin
      SLlog:=TStringList.Create;
      aGTMReg:= TGTMReg.Create;
      SLlog.Add('Begin to read specified landscape and projected responsibilities.');
      Writeln(SLlog.Text); SLlog.Clear;
      readLandscape(Opt.MdlFileNme,aGTMReg);
      if (aGTMReg=nil) then exit;
      SLlog.Add('Min. responsibility on labeled nodes for AD: '+ FloatToStr(aGTMReg.MinRspAD)+
        ', Min. responsiblity value to contribute landscape: '+ FloatToStr(aGTMReg.MinRspToNode)+
        ', Min. density value to contribute landscape: '+ FloatToStr(aGTMReg.MinDensityLS)+
        ', Number of nodes: '+ IntToStr(aGTMReg.K));
      Writeln(SLlog.Text); SLlog.Clear;
      if (Opt.tePrpFileNme='') or (not FileExists(Opt.tePrpFileNme)) then begin
        UseLandscape(aGTMReg,Opt.teRspFileNme,Opt.OutFileNme,SLlog);
        Writeln(SLlog.Text); SLlog.Clear;
      end
      else
      begin
       aClsStat:=TClsStat.Create;
       SLtest:=TStringList.Create;
       SLProp:=TStringList.Create;
       SLtest.LoadFromFile(Opt.teRspFileNme);
       SLProp.LoadFromFile(Opt.tePrpFileNme);
       for i:=1 to SLProp.Count-1 do //Ignore line 1: a comment
       begin
         new(pdbl);
         pdbl^:=StrToFloat(SLProp[i]);
         SLtest.Objects[i-1]:=TObject(pdbl);
       end;
       UseLandscape(aGTMReg,SLtest,Opt.OutFileNme,aClsStat,SLlog);
       Writeln(SLlog.Text); SLlog.Clear;
       for i:=0 to SLtest.Count-1 do
       begin
         pdbl:=Pdouble(SLtest.Objects[i]);
         if pdbl<>nil then dispose(pdbl);
       end;
       FreeAndNil(SLProp);
       FreeAndNil(SLtest);
       //
       SLlog.Add('/------------ Performances ------------\');
       SLlog.Add('RMSE          = '+FloatToStrF(aClsStat.RMSE(),ffFixed,3,4));
       SLlog.Add('MAE           = '+FloatToStrF(aClsStat.MAE(),ffFixed,3,4));
       SLlog.Add('Relative RMSE = '+FloatToStrF(aClsStat.RelRMSE(),ffFixed,3,4));
       SLlog.Add('Relative MAE  = '+FloatToStrF(aClsStat.RelMAE(),ffFixed,3,4));
       SLlog.Add('R2det         = '+FloatToStrF(aClsStat.R2det(),ffFixed,3,4));
       SLlog.Add('CCC           = '+FloatToStrF(aClsStat.CCC(),ffFixed,3,4));
       SLlog.Add('R2cor         = '+FloatToStrF(aClsStat.R2cor(),ffFixed,3,4));
       Writeln(SLlog.Text); SLlog.Clear;
       FreeAndNil(aClsStat);
      end;
      FreeAndNil(aGTMReg);
      FreeAndNil(SLlog);
    end else if Opt.Validate=True then
    begin
      SLlog:=TStringList.Create;
      //Setup cross validation
      aClsStat:=TClsStat.Create; //A place to store exp and pred values and compute statistics
      SLtrain:=TStringList.Create;
      SLtest:= TStringList.Create;
      aCV:=TCVsvm.Create;
      aCV.Nfolds:=Opt.Nfolds;
      aCV.SetSLSVMFromFileAndPropP(Opt.trRspFileNme,Opt.trPrpFileNme);//Property values are attached to the responsibilities via a pointer
      //Do CV
      SetLength(aStat,7);
      SetLength(aStatSum,7);
      for i:=Low(aStatSum) to high(aStatSum) do aStatSum[i]:=0;
      kfold1:=0; //For some fold the statistics are not computed -> effective number of folds can be lower than expected
      for kfold:=1 to aCV.Nfolds do
      begin
        aCV.GenerateFold(kfold,SLtrain,SLtest);
        aGTMReg:= TGTMReg.Create;
        aGTMReg.ReadGTMModel(Opt.MapFileNme); //Setup the GTM model from the XML file
        aGTMReg.PrpName:=Opt.PropName;
        aGTMReg.MinRspToNode:=Opt.MinRespAD;
        aGTMReg.MinDensityLS:=Opt.MinDens;
        aGTMReg.MinRspAD:=Opt.MinRespAD;
        aGTMReg.dTtau:=Opt.tau;
        aGTMReg.dTalpha:=Opt.alpha;
        aGTMReg.dTbeta:=Opt.beta;
        aGTMReg.dTT:=Opt.Tthrd;
        TrainLandscape(aGTMReg,SLtrain,Opt.OutFileNme+'_train-fold'+IntToStr(kfold),Opt.Author,Opt.Title,Opt.PropComment,SLlog);
        Writeln(SLlog.Text); SLlog.Clear;
        UseLandscape(aGTMReg,SLtest,Opt.OutFileNme+'_test-fold'+IntToStr(kfold),aClsStat,SLlog);
        Writeln(SLlog.Text); SLlog.Clear;
        //Output results
        aStat[0]:=aClsStat.RMSE();
        aStat[1]:=aClsStat.MAE();
        aStat[2]:=aClsStat.RelRMSE();
        aStat[3]:=aClsStat.RelMAE();
        aStat[4]:=aClsStat.CCC();
        aStat[5]:=aClsStat.R2det();
        aStat[6]:=aClsStat.R2cor();
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
        SLlog.Add('RMSE          = '+FloatToStrF(aStat[0],ffFixed,3,4));
        SLlog.Add('MAE           = '+FloatToStrF(aStat[1],ffFixed,3,4));
        SLlog.Add('Relative RMSE = '+FloatToStrF(aStat[2],ffFixed,3,4));
        SLlog.Add('Relative MAE  = '+FloatToStrF(aStat[3],ffFixed,3,4));
        SLlog.Add('CCC           = '+FloatToStrF(aStat[4],ffFixed,3,4));
        SLlog.Add('R2det         = '+FloatToStrF(aStat[5],ffFixed,3,4));
        SLlog.Add('R2cor         = '+FloatToStrF(aStat[6],ffFixed,3,4));
        Writeln(SLlog.Text); SLlog.Clear;
        //
        FreeAndNil(aGTMReg);
      end;
      // Averaged performances
      for i:=Low(aStatSum) to High(aStatSum) do
        aStatSum[i]:=aStatSum[i]/kfold1;
      SLlog.Add('************** Averaged performances **************');
      SLlog.Add('RMSE          = '+FloatToStrF(aStatSum[0],ffFixed,3,4));
      SLlog.Add('MAE           = '+FloatToStrF(aStatSum[1],ffFixed,3,4));
      SLlog.Add('Relative RMSE = '+FloatToStrF(aStatSum[2],ffFixed,3,4));
      SLlog.Add('Relative MAE  = '+FloatToStrF(aStatSum[3],ffFixed,3,4));
      SLlog.Add('CCC           = '+FloatToStrF(aStatSum[4],ffFixed,3,4));
      SLlog.Add('R2det         = '+FloatToStrF(aStatSum[5],ffFixed,3,4));
      SLlog.Add('R2cor         = '+FloatToStrF(aStatSum[6],ffFixed,3,4));
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




{
  var

    aGTMReg: TGTMReg;

    Opt: TOpt;
    XML: XMLData;
    nNodes: integer;
    nMol0, nMol1: integer;
    StreamRsp, StreamPrp: TFileReader;
    FSOut: TFileStream;
    SLout: TStringList;//Short output files as TStringList
    sl1, sl2: string; //temporary strings
    ii, jj, kk: integer; //ii: words in stringlist; jj: lines; kk: node index
    SLRspM: TStringList; // String list of responsiblities of molecule
    SLRspN: TStringList; // String list tuple node:responsibility
    bInAD: boolean; //In or out of applicability domain
    dResVal: double; //a responsibility value
    aResMol: array of double; //Array of responsibilities for a molecule
    dprp: double; // a property value
    dprd: double; // a prediction value
    sout: string;//output string
    sComment: string; //Comment from property file
    aLandscapeXYZ: TMatrix;//A landscape in XYZ format
    aDensityXYZ: TMatrix;//A density in XYZ format

    procedure WriteOptions(Opt: TOpt);
    begin
      writeln('***********************************');
      writeln('*                                 *');
      writeln('*           ISIDA/GTMReg          *');
      writeln('*                                 *');
      writeln('* Marcou G., Lin A.               *');
      writeln('*                                 *');
      writeln('* Université de Strasbourg  2019  *');
      writeln('***********************************');
      writeln;
      writeln('GTM model                               : ' + Opt.MapFileNme);
      if Opt.useLandscape = False then
      begin
        writeln('Input training responsibilities         : ' + Opt.trRspFileNme);
        writeln('Input training property                 : ' + Opt.trPrpFileNme);
        writeln('Property short name                     : ' + Opt.PropName);
        writeln('Title                                   : ' + Opt.Title);
      end
      else
        writeln('Input landscape                         : ' + Opt.MdlFileNme);
      writeln('Input query responsibilities            : ' + Opt.teRspFileNme);
      writeln('Min. responsibility value for AD        : ' + FloatToStr(Opt.MinRspAD));
      writeln('Min. responsibility value for landscape : ' + FloatToStr(Opt.MinRspLd));
      writeln('Base of output file names               : ' + Opt.OutFileNme);
      writeln;
      writeln('***********************************');
    end;

  begin




    { add your program here }
    WriteOptions(Opt);
    //Initialization
    SLout:=TStringList.Create;
    sComment:='';
    aGTMReg:=TGTMReg.Create;
    aGTMReg.ReadGTMModel(Opt.MapFileNme); //Setup the GTM model from the XML file
    aGTMReg.PrpName:=Opt.PropName;
    nNodes := aGTMReg.K;
    SetLength(aResMol, aGTMReg.K + 1);//Array of responsibilities for a molecule, 1-indexed
    if Opt.useLandscape = False then //Compute the landscape
    begin

      writeln('Begin to read responsibilities.');
      { reading the responsibility file }
      try  //Use streams to deal with potentially very large amount of data
        StreamRsp := TFileReader.Create(Opt.trRspFileNme, fmOpenRead);
        StreamPrp := TFileReader.Create(Opt.trPrpFileNme, fmOpenRead);
        try
          StreamRsp.Reset;
          StreamPrp.Reset;
          //Prepare to read responsibilies and properties
          SLRspM := TStringList.Create;
          SLRspN := TStringList.Create;
          SLRspM.Delimiter := ' ';
          SLRspM.StrictDelimiter := False;
          SLRspN.Delimiter := ':';
          SLRspN.StrictDelimiter := True;
          sl2 := StreamPrp.ReadLine;
          sComment := sl2;
          while not StreamRsp.EOF do
          begin
            sl1 := StreamRsp.ReadLine; //Read one line of responsibilities
            sl2 := StreamPrp.ReadLine; //Read one line of properties
            if (sl1 <> '') and (sl2 <> '') then
            begin
              //Interpret responsibilities text line
              dprp := StrToFloat(sl2);//Get the associated responsibility
              SLRspM.DelimitedText := sl1;
              //Check the integrity of the responsibility file
              SLRspN.DelimitedText := SLRspM.Strings[SLRspM.Count - 1];
              if (nNodes <> 0) and (nNodes <> StrToInt(SLRspN[0])) then
              begin
                writeln('ERROR readRespFile: Unexpected number of nodes reading training file '
                  + Opt.trRspFileNme);
                halt;
              end;
              for kk := 0 to nNodes do
                aResMol[kk] := 0; //Reset the array of responsibilities
              for ii := 1 to SLRspM.Count - 1 do
              begin
                SLRspN.DelimitedText := SLRspM[ii];
                kk := StrToInt(SLRspN[0]);
                dResVal := StrToFloat(SLRspN[1]);
                aResMol[kk] := dResVal;
              end;
              aGTMReg.AddMolecule(aResMol,dprp);//Add molecule to landscape
            end;
          end;
          FreeAndNil(SLRspM);
          FreeAndNil(SLRspN);
          StreamRsp.Close;
          StreamPrp.Close;
        except
          writeln('ERROR: reading responsibility/property file while computing landscape.');
        end;
      finally
        FreeAndNil(StreamRsp);
        FreeAndNil(StreamPrp);
      end; //End of Landscape computing
      writeln('Number of molecules processed ', aGTMReg.nMol0);
      writeln('Number of molecules used for landscape ', aGTMReg.nMol1);
      writeln('--------------------------------------');
      //Finalize Landscape
      aGTMReg.DoFinalize;
      { Saving the landscape if it was created here }
      saveLandscape(ChangeFileExt(Opt.OutFileNme,'.xml'),Opt.Author, aGTMReg,Opt.Title,sComment);
      aDensityXYZ:=aGTMReg.GetDensityXYZ();
      aLandscapeXYZ:=aGTMReg.GetLandscapeXYZ();
      SLOut.Clear;
      PrintMat(aDensityXYZ,'Density',1,aGTMReg.K,1,3,SLout);
      SLout.SaveToFile(ChangeFileExt(Opt.OutFileNme,'Dens.mat'));
      SLOut.Clear;
      PrintMat(aLandscapeXYZ,'Landscape',1,aGTMReg.K,1,3,SLout);
      SLout.SaveToFile(ChangeFileExt(Opt.OutFileNme,'LS.mat'));
    end
    else
    begin
      { reading landscape file }
      writeln('Begin to read specified landscape and projected responsibilities.');
      //XML := readLandscape(Opt.MdlFileNme);
      readLandscape(opt.MdlFileNme,aGTMReg);
      {if aGTMReg.K<>XML.nNode then
      begin
        writeln('ERROR: reading landscape file. Inconsistent number of nodes between landscape and manifold');
        halt;
      end;
      aGTMReg.MinRspAD:=XML.MinRespAD;
      aGTMReg.MinRspLS:=XML.MinRespLS;
      aGTMReg.PrpMean := XML.PrpMean;
      for kk:=1 to aGTMReg.K do
      begin
        aGTMReg.Density[kk] := XML.Density[kk];
        aGTMReg.Landscape[kk]:=XML.Landscape[kk];
      end;}
      writeln('Min. responsibility value for AD: ', FloatToStr(aGTMReg.MinRspAD),
        ', Min. responsiblity value to contribute landscape: ', FloatToStr(aGTMReg.MinRspLS),
        ', Number of nodes: ', IntToStr(aGTMReg.K));
    end;
    { reading of File with Responsibilities for the projection set }
    if Opt.writeLSOnly = False then  {if not just to write the landscape}
    begin
      try
        StreamRsp := TFileReader.Create(Opt.teRspFileNme);
        StreamRsp.Reset;
        if FileExists(ChangeFileExt(Opt.OutFileNme,'.tsv')) then
        begin
          writeln('WARNING: File '+ChangeFileExt(Opt.OutFileNme,'.tsv')+' is overwritten.');
        end;
        FSOut := TFileStream.Create(ChangeFileExt(Opt.OutFileNme,'.tsv'), fmCreate);
        FSOut.Size := 0;
        SetLength(aResMol, aGTMReg.K + 1);//Array of responsibilities for a molecule, 1-indexed
        sout := 'ID' + #9 + 'Prediction' + #9 + 'In/Out_of_AD'+LineEnding;
        FSOut.Write(sout[1],length(sout));//WriteAnsiString(sout+LineEnding);
        try
          //Prepare to read responsibilies and properties
          SLRspM := TStringList.Create;
          SLRspN := TStringList.Create;
          SLRspM.Delimiter := ' ';
          SLRspM.StrictDelimiter := False;
          SLRspN.Delimiter := ':';
          SLRspN.StrictDelimiter := True;
          nMol0:=0; //Molecules out of AD
          nMol1:=0; //Molecules inside AD
          jj:=0; //Count lines
          while not StreamRsp.EOF do
          begin
            Inc(jj);//Count lines
            sl1 := StreamRsp.ReadLine; //Read one line of responsibilities
            if (sl1 <> '') then
            begin
              SLRspM.DelimitedText := sl1;
              //Check the integrity of the responsibility file
              SLRspN.DelimitedText := SLRspM.Strings[SLRspM.Count - 1];
              if (nNodes <> 0) and (nNodes <> StrToInt(SLRspN[0])) then
              begin
                writeln('ERROR readRespFile: Unexpected number of nodes reading test file '
                  + Opt.teRspFileNme);
                halt;
              end;
              for kk:=0 to aGTMReg.K do aResMol[kk]:=0;
              bInAD:=False;
              for ii:=1 to SLRspM.Count-1 do
              begin
                SLRspN.DelimitedText:=SLRspM[ii];
                kk:=StrToInt(SLRspN[0]);
                dResVal:=StrToFloat(SLRspN[1]);
                aResMol[kk]:=dResVal;
              end;
              dprd:=aGTMReg.PredMol(aResMol,bInAD);
              sout := IntToStr(nMol0) + #9 + FloatToStrF(dprd,ffFixed,6,2) + #9;
              //sout := IntToStr(nMol0) + #9 + FloatToStr(SimpleRoundTo(dprd, -2)) + #9;
              if bInAD then
              begin
                Inc(nMol1);
                sout:=sout+'1';
              end else
              begin
                Inc(nMol0);
                sout:=sout+ '0';
              end;
              sout:=sout+LineEnding;
              FSOut.Write(sout[1],length(sout));//AnsiString(sout+LineEnding);
            end;
          end;
          FreeAndNil(SLRspM);
          FreeAndNil(SLRspN);
        except
          writeln('ERROR: computing prediction using the landscape for the test set');
        end;
      finally
        FreeAndNil(StreamRsp);
        FreeAndNil(FSOut);
      end;
      writeln('--------------------------------------');
      writeln('Number of molecules processed ', jj);
      writeln('Number of molecules in AD ', nMol1);
      writeln('Number of molecules out AD ', nMol0);
      writeln('--------------------------------------');

    end;
    FreeAndNil(SLout);
    FreeAndNil(aGTMReg);
    // stop program loop
    Terminate;
  end;
}
  constructor TGTMRegCA.Create(TheOwner: TComponent);
  begin
    inherited Create(TheOwner);
    StopOnException := True;
  end;

  destructor TGTMRegCA.Destroy;
  begin
    inherited Destroy;
  end;

  procedure TGTMRegCA.WriteHelp;
  begin
    { add your help code here }
    writeln();
    writeln('USAGE: GTMReg [-h] [-m] <manifold.xml> [-R] <testR.svm> '+
            '[-o] <output> [-l] <Landscape.xml> [-r] <trainR.svm> '+
            '[-p] <properties.prp>  [-t] <AD Threshold> [-n] <Node Threshold> '+
            '[-d] <Density Threshold> [-x] <CV nFolds> [-W]');
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
    writeln('--tau                                   ',
      ' -the trustworthiness offset (default value 0.0)');
    writeln('--alpha                                 ',
      ' -the trustworthiness density exponent (default value 0.0)');
    writeln('--beta                                  ',
      ' -the trustworthiness coherence exponent (default value 0.0)');
    writeln('--trustworthinessThreshold              ',
      ' -the trustworthiness threshold (default value 0.0)');
    writeln('-l, --landscapeFile                     ',
      ' -an input existing landscape file, for prediction;');
    writeln('-o, --outputFile                        ',
      ' -the base name for output files;');
    writeln('-W, --writeLandscapeOnly                ',
      ' -compute and save a landscape, do not apply the model;');
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
  Application: TGTMRegCA;
begin
  {$IfDef WINDOWS}DefaultFormatSettings.DateSeparator:='-';{$EndIf}
  {$IfDef LOCALES}DefaultFormatSettings.DecimalSeparator:='.';DefaultFormatSettings.ShortDateFormat:='d/m/y';{$EndIf}
  Application := TGTMRegCA.Create(nil);
  Application.Run;
  Application.Free;
end.
