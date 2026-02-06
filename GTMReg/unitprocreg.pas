unit UnitProcReg;

interface

uses
  {$IFDEF UNIX} {$IFDEF UseCThreads}
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
  UGTMReg, UnitCVsvm, UnitClsStat { you can add units after this },
  gtmr_option;
type
  DoubleArray = array of Double;

function RunGTMReg(Opt: TGTMROpt): DoubleArray;

implementation

function RunGTMReg(Opt: TGTMROpt): DoubleArray;
  var
  aGTMReg: TGTMReg;
  aCV: TCVsvm;
  SLtrain,SLtest,SLProp:TStringList;
  kfold,i: integer;
  aClsStat: TClsStat;
  aStat,aStatSum: TAoD;
  pdbl: PDouble;
  SLlog: TStringList;//log
  ErrorMsg: string;
  bAddToStat: Boolean;//Add statistic to sum of stat?
  kfold1: integer;//Number of statistics added to the sum
  begin

    if Opt.MapFileNme='' then
    begin
      raise Exception.Create('ERROR: missing GTM XML model. GTM model is mandatory for a landscape.');
      halt;
    end;

    if Opt.MdlFileNme<>'' then //Use a pre-computed landscape
    begin
      Opt.useLandscape:=true;
    end;

    //AD options
    if (Opt.MinRespAD <>0.0) and (Opt.useLandscape = True) then
    begin
      Opt.MinRespAD := 0.0;
    end;

    if (Opt.MinResp <>0.0) and (Opt.useLandscape = True) then
    begin
      Opt.MinResp := 0.0;
    end;

    if (Opt.MinDens <>0.0) and (Opt.useLandscape = True) then
    begin
      Opt.MinDens := 0.0;
    end;
    //
    if (Opt.trRspFileNme<>'') and (Opt.useLandscape = False) then
    begin
      if Opt.trPrpFileNme='' then
      begin
        raise Exception.Create('ERROR: training a landscape. A property file is mandatory.');
        halt;
      end;
      if Opt.Nfolds<>0 then
      begin
        Opt.Build:=False;
        Opt.Validate:=True;
        Opt.Pred:=False;
      end;
      {if HasOption('tau') then
        Opt.tau:=StrToFloat(GetOptionValue('tau'));
      if HasOption('alpha') then
        Opt.alpha:=StrToFloat(GetOptionValue('alpha'));
      if HasOption('beta') then
        Opt.beta:=StrToFloat(GetOptionValue('beta'));
      if HasOption('trustworthinessThreshold') then
        Opt.Tthrd:=StrToFloat(GetOptionValue('trustworthinessThreshold'));}
      If not Opt.Validate then Opt.Build:=True;
    end
    else if (Opt.trRspFileNme<>'') and (Opt.useLandscape = True) then
    begin
      raise Exception.Create('ERROR: Using existing model. No training responsibilities needed.');
      halt;
    end;
    if Opt.writeLSOnly then
    begin
      Opt.Build:=True;
      Opt.Validate:=False;
      Opt.Pred:=False;
    end;
    //
    if (Opt.teRspFileNme<>'') and (Opt.writeLSOnly = False) then
    begin
      Opt.Validate:=False;
      Opt.Pred:=True;
      {if HasOption('P', 'testPrp') then
      begin
        Opt.tePrpFileNme := GetOptionValue('P', 'testPrp');
      end}
    end
    else if (Opt.teRspFileNme<>'') and (Opt.writeLSOnly = True) then
    begin
      raise Exception.Create('ERROR: Using an existing landscape on test set responsibilities is incompatible with saving the command to save the landscape only.');
      halt;
    end
    else if (not ((Opt.teRspFileNme<>'') or (Opt.Nfolds<>0))) and (Opt.writeLSOnly = False) then
    begin
      raise Exception.Create('ERROR: do you wish to predict (where is -R?) or do you wish to create landscape only (where is -W?)');
      halt;
    end;
    //
    //Opt.WriteOptions();
    //

    SetLength(Result, 7);
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
      //writeln(SLlog.Text);
      SLlog.Clear;
      //
      if (Opt.Pred=True) and (FileExists(Opt.tePrpFileNme)) then
      begin
        //SLlog.Add('---- Predictions - Responsibilities: '+Opt.teRspFileNme+ ' / Properties: '+Opt.tePrpFileNme+' ----');
        //Writeln(SLlog.Text);
        SLlog.Clear;
        if (aGTMReg=nil) then exit;
        {SLlog.Add('Min. responsibility on labeled nodes for AD: '+ FloatToStr(aGTMReg.MinRspAD)+
          ', Min. responsiblity value to contribute landscape: '+ FloatToStr(aGTMReg.MinRspToNode)+
          ', Min. density value to contribute landscape: '+ FloatToStr(aGTMReg.MinDensityLS)+
          ', Number of nodes: '+ IntToStr(aGTMReg.K));}
        //Writeln(SLlog.Text);
        SLlog.Clear;
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
        //Writeln(SLlog.Text);
        SLlog.Clear;
        for i:=0 to SLtest.Count-1 do
        begin
          pdbl:=Pdouble(SLtest.Objects[i]);
          if pdbl<>nil then dispose(pdbl);
        end;
        FreeAndNil(SLProp);
        FreeAndNil(SLtest);
        //
        {SLlog.Add('/------------ Performances ------------\');
        SLlog.Add('RMSE          = '+FloatToStrF(aClsStat.RMSE(),ffFixed,3,4));
        SLlog.Add('MAE           = '+FloatToStrF(aClsStat.MAE(),ffFixed,3,4));
        SLlog.Add('Relative RMSE = '+FloatToStrF(aClsStat.RelRMSE(),ffFixed,3,4));
        SLlog.Add('Relative MAE  = '+FloatToStrF(aClsStat.RelMAE(),ffFixed,3,4));
        SLlog.Add('R2det         = '+FloatToStrF(aClsStat.R2det(),ffFixed,3,4));
        SLlog.Add('CCC           = '+FloatToStrF(aClsStat.CCC(),ffFixed,3,4));
        SLlog.Add('R2cor         = '+FloatToStrF(aClsStat.R2cor(),ffFixed,3,4));
        //Writeln(SLlog.Text);
        SLlog.Clear;}

        Result[0] := aClsStat.RMSE();
        Result[1] := aClsStat.MAE();
        Result[2] := aClsStat.RelRMSE();
        Result[3] := aClsStat.RelMAE();
        Result[4] := aClsStat.CCC();
        Result[5] := aClsStat.R2det();
        Result[6] := aClsStat.R2cor();

        FreeAndNil(aClsStat);
      end;
      //
      FreeAndNil(aGTMReg);
      FreeAndNil(SLlog);
    end else if Opt.Pred=True then
    begin
      SLlog:=TStringList.Create;
      aGTMReg:= TGTMReg.Create;
      //SLlog.Add('Begin to read specified landscape and projected responsibilities.');
      //Writeln(SLlog.Text);
      SLlog.Clear;
      readLandscape(Opt.MdlFileNme,aGTMReg);
      if (aGTMReg=nil) then exit;
      {SLlog.Add('Min. responsibility on labeled nodes for AD: '+ FloatToStr(aGTMReg.MinRspAD)+
        ', Min. responsiblity value to contribute landscape: '+ FloatToStr(aGTMReg.MinRspToNode)+
        ', Min. density value to contribute landscape: '+ FloatToStr(aGTMReg.MinDensityLS)+
        ', Number of nodes: '+ IntToStr(aGTMReg.K));}
      //Writeln(SLlog.Text);
      SLlog.Clear;
      if (Opt.tePrpFileNme='') or (not FileExists(Opt.tePrpFileNme)) then begin
        UseLandscape(aGTMReg,Opt.teRspFileNme,Opt.OutFileNme,SLlog);
        //Writeln(SLlog.Text);
        SLlog.Clear;
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
        //Writeln(SLlog.Text);
        SLlog.Clear;
        for i:=0 to SLtest.Count-1 do
        begin
         pdbl:=Pdouble(SLtest.Objects[i]);
         if pdbl<>nil then dispose(pdbl);
        end;
        FreeAndNil(SLProp);
        FreeAndNil(SLtest);
        //
        {SLlog.Add('/------------ Performances ------------\');
        SLlog.Add('RMSE          = '+FloatToStrF(aClsStat.RMSE(),ffFixed,3,4));
        SLlog.Add('MAE           = '+FloatToStrF(aClsStat.MAE(),ffFixed,3,4));
        SLlog.Add('Relative RMSE = '+FloatToStrF(aClsStat.RelRMSE(),ffFixed,3,4));
        SLlog.Add('Relative MAE  = '+FloatToStrF(aClsStat.RelMAE(),ffFixed,3,4));
        SLlog.Add('R2det         = '+FloatToStrF(aClsStat.R2det(),ffFixed,3,4));
        SLlog.Add('CCC           = '+FloatToStrF(aClsStat.CCC(),ffFixed,3,4));
        SLlog.Add('R2cor         = '+FloatToStrF(aClsStat.R2cor(),ffFixed,3,4));
        Writeln(SLlog.Text);}
        SLlog.Clear;

        Result[0] := aClsStat.RMSE();
        Result[1] := aClsStat.MAE();
        Result[2] := aClsStat.RelRMSE();
        Result[3] := aClsStat.RelMAE();
        Result[4] := aClsStat.CCC();
        Result[5] := aClsStat.R2det();
        Result[6] := aClsStat.R2cor();

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
        //Writeln(SLlog.Text);
        //SLlog.Clear;
        UseLandscape(aGTMReg,SLtest,Opt.OutFileNme+'_test-fold'+IntToStr(kfold),aClsStat,SLlog);
        //Writeln(SLlog.Text);
        //SLlog.Clear;
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
        {SLlog.Add('*------------- fold '+IntToStr(kfold)+' -------------*');
        SLlog.Add('RMSE          = '+FloatToStrF(aStat[0],ffFixed,3,4));
        SLlog.Add('MAE           = '+FloatToStrF(aStat[1],ffFixed,3,4));
        SLlog.Add('Relative RMSE = '+FloatToStrF(aStat[2],ffFixed,3,4));
        SLlog.Add('Relative MAE  = '+FloatToStrF(aStat[3],ffFixed,3,4));
        SLlog.Add('R2det         = '+FloatToStrF(aStat[4],ffFixed,3,4));
        SLlog.Add('CCC           = '+FloatToStrF(aStat[5],ffFixed,3,4));
        SLlog.Add('R2cor         = '+FloatToStrF(aStat[6],ffFixed,3,4));
        //Writeln(SLlog.Text);
        SLlog.Clear;                                                 }
        //
        FreeAndNil(aGTMReg);
      end;
      // Averaged performances
      for i:=Low(aStatSum) to High(aStatSum) do
        aStatSum[i]:=aStatSum[i]/kfold1;
      {SLlog.Add('************** Averaged performances **************');
      SLlog.Add('RMSE          = '+FloatToStrF(aStatSum[0],ffFixed,3,4));
      SLlog.Add('MAE           = '+FloatToStrF(aStatSum[1],ffFixed,3,4));
      SLlog.Add('Relative RMSE = '+FloatToStrF(aStatSum[2],ffFixed,3,4));
      SLlog.Add('Relative MAE  = '+FloatToStrF(aStatSum[3],ffFixed,3,4));
      SLlog.Add('R2det         = '+FloatToStrF(aStatSum[4],ffFixed,3,4));
      SLlog.Add('CCC           = '+FloatToStrF(aStatSum[5],ffFixed,3,4));
      SLlog.Add('R2cor         = '+FloatToStrF(aStatSum[6],ffFixed,3,4));
      //Writeln(SLlog.Text);
      SLlog.Clear;                                                       }

       Result[0] := aStatSum[0];
       Result[1] := aStatSum[1];
       Result[2] := aStatSum[2];
       Result[3] := aStatSum[3];
       Result[4] := aStatSum[4];
       Result[5] := aStatSum[5];
       Result[6] := aStatSum[6];

      //
      FreeAndNil(aClsStat);
      FreeAndNil(aCV);
      FreeAndNil(SLtrain);
      FreeAndNil(SLtest);
      FreeAndNil(SLlog);
      SetLength(aStat, 0);
      SetLength(aStatSum, 0);
    end;
    //Writeln('.............. Calculations complete ..............');
  end;

end.

