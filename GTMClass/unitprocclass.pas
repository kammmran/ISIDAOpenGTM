unit UnitProcClass;

interface
{$mode objfpc}{$H+}
 uses
  {$IFDEF UNIX}{$IFDEF UseCThreads}
  cthreads,
  {$ENDIF}{$ENDIF}
  Classes,
  SysUtils,
  CustApp,
  streamex,
  GTMClassFunctions,
  UGTMBase,
  UGTMXML,
  ugtm_options,
  Math,
  gtmc_option,
  UGTMClass,
  UnitCVsvm,
  UnitClsStats
  { you can add units after this };
 type
  DoubleArray = array of Double;

function RunGTMClass(Opt: TGTMCOpt): DoubleArray;

implementation

function RunGTMClass(Opt: TGTMCOpt): DoubleArray;
var
  aGTMClass: TGTMClass;
  aCV: TCVsvm;
  SLtrain,SLtest,SLProp:TStringList;
  kfold,i,ii: integer;
  kfold1: integer;//Number of statistics added to the sum
  aClsStat: TClsStats;
  aStat,aStatSum: TAoD;
  pdbl: PDouble;
  SLlog: TStringList;//log
  ipos: integer;//position in string
  sres: string; // temporary string variable
  ErrorMsg: string;
  bAddToStat: Boolean;//Add statistic to sum of stat?
begin
  if Opt.MapFileNme='' then
  begin
    raise Exception.Create('ERROR: No GTM model (XML file) specified!');
    halt;
  end;
  if Opt.MdlFileNme<>'' then //Use a pre-computed landscape
  begin
    Opt.useLandscape:=true;
  end else // train a new one
  begin
    if Opt.trRspFileNme='' then
    begin
     raise Exception.Create('ERROR: No projection file for training set specified!');
     halt;
    end;
    if Opt.trPrpFileNme='' then
    begin
     raise Exception.Create('ERROR: No property file for training set specified!');
     halt;
    end;
    if Opt.writeLSOnly then
    begin
      if Opt.teRspFileNme='' then begin
        raise Exception.Create('ERROR: No need of a test file if you want to only output the model');
        halt;
      end;
    end;
  end;

  //AD options
  if (Opt.useLandscape = True) then
  begin
    Opt.MinRespAD := 0.0;
    Opt.MinResp   := 0.0;
    Opt.MinDens   := 0.0;
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

  SetLength(Result, 2);
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
    //writeln(SLlog.Text);
    SLlog.Clear;
    //
    if (Opt.Pred=True) and (FileExists(Opt.tePrpFileNme)) then
    begin
      //SLlog.Add('---- Predictions - Responsibilities: '+Opt.teRspFileNme+ ' / Properties: '+Opt.tePrpFileNme+' ----');
      ///Writeln(SLlog.Text);
      SLlog.Clear;
      if (aGTMClass=nil) then exit;
      {SLlog.Add('Min. responsibility value for AD: '+ FloatToStr(aGTMClass.MinRspToNode)+
        ', Min. density value to contribute landscape: '+ FloatToStr(aGTMClass.MinDensityLS)+
        ', Number of nodes: '+ IntToStr(aGTMClass.K));
      Writeln(SLlog.Text); }
      SLlog.Clear;
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
      //Writeln(SLlog.Text);
      SLlog.Clear;
      //
      {SLlog.Add('/------------ Performances ------------\');
      SLlog.Add('Accuracy          ='+FloatToStrF(aClsStat.Accuracy,ffFixed,3,4));
      SLlog.Add('Balanced Accuracy ='+FloatToStrF(aClsStat.BalancedAccuracy,ffFixed,3,4));
      for i:=1 to aGTMClass.classSL.Count-1 do
      begin
        SLlog.Add('Precision('+aGTMClass.classSL[i]+')='+FloatToStrF(aClsStat.Precision(i-1),ffFixed,3,4));
        SLlog.Add('Recall('+aGTMClass.classSL[i]+')   ='+FloatToStrF(aClsStat.Recall(i-1),ffFixed,3,4));
        SLlog.Add('F('+aGTMClass.classSL[i]+')        ='+FloatToStrF(aClsStat.Fmeasure(i-1),ffFixed,3,4));
        SLlog.Add('MCC('+aGTMClass.classSL[i]+')      ='+FloatToStrF(aClsStat.MCC(i-1),ffFixed,3,4));
      end;
      Writeln(SLlog.Text);}
      SLlog.Clear;

      Result[0] := aClsStat.Accuracy;
      Result[1] := aClsStat.BalancedAccuracy;

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
    //SLlog.Add('Begin to read specified landscape and projected responsibilities.');
    readLandscape(Opt.MdlFileNme,aGTMClass);
    //SLlog.Add('---- Predictions - Responsibilities: '+Opt.teRspFileNme+ ' / Properties: '+Opt.tePrpFileNme+' ----');
    //Writeln(SLlog.Text);
    SLlog.Clear;
    if (aGTMClass=nil) then exit;
    {SLlog.Add('Min. responsibility value for AD: '+ FloatToStr(aGTMClass.MinRspToNode)+
      ', Min. density value to contribute landscape: '+ FloatToStr(aGTMClass.MinDensityLS)+
      ', Number of nodes: '+ IntToStr(aGTMClass.K));
    Writeln(SLlog.Text);}
    SLlog.Clear;
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
      {SLlog.Add('/------------ Performances ------------\');
      SLlog.Add('Accuracy          ='+FloatToStrF(aClsStat.Accuracy,ffFixed,3,4));
      SLlog.Add('Balanced Accuracy ='+FloatToStrF(aClsStat.BalancedAccuracy,ffFixed,3,4));
      for i:=1 to aGTMClass.classSL.Count-1 do
      begin
        SLlog.Add('Precision('+aGTMClass.classSL[i]+')='+FloatToStrF(aClsStat.Precision(i-1),ffFixed,3,4));
        SLlog.Add('Recall('+aGTMClass.classSL[i]+')   ='+FloatToStrF(aClsStat.Recall(i-1),ffFixed,3,4));
        SLlog.Add('F('+aGTMClass.classSL[i]+')        ='+FloatToStrF(aClsStat.Fmeasure(i-1),ffFixed,3,4));
        SLlog.Add('MCC('+aGTMClass.classSL[i]+')      ='+FloatToStrF(aClsStat.MCC(i-1),ffFixed,3,4));
      end;
      Writeln(SLlog.Text);}
      SLlog.Clear;

      Result[0] := aClsStat.Accuracy;
      Result[1] := aClsStat.BalancedAccuracy;

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
      //Writeln(SLlog.Text);
      SLlog.Clear;
      aGTMClass.SetMolCountToZero;
      UseLandscape(aGTMClass,SLtest,Opt.OutFileNme+'_test-fold'+IntToStr(kfold),aClsStat,SLlog);
      //Writeln(SLlog.Text);
      SLlog.Clear;
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
      {SLlog.Add('*------------- fold '+IntToStr(kfold)+' -------------*');
      SLlog.Add('Accuracy         ='+FloatToStrF(aStat[0],ffFixed,3,4));
      SLlog.Add('Balanced Accuracy ='+FloatToStrF(aStat[1],ffFixed,3,4));
      Writeln(SLlog.Text);}
      SLlog.Clear;
      //
      FreeAndNil(aGTMClass);
    end;
    // Averaged performances
    for i:=Low(aStatSum) to High(aStatSum) do
      aStatSum[i]:=aStatSum[i]/kfold1;
    {SLlog.Add('************** Averaged performances **************');
    SLlog.Add('Accuracy          ='+FloatToStrF(aStatSum[0],ffFixed,3,4));
    SLlog.Add('Balanced Accuracy ='+FloatToStrF(aStatSum[1],ffFixed,3,4));
    Writeln(SLlog.Text);}
    SLlog.Clear;

    Result[0] := aStatSum[0];
    Result[1] := aStatSum[1];
    //
    FreeAndNil(aClsStat);
    FreeAndNil(aCV);
    FreeAndNil(SLtrain);
    FreeAndNil(SLtest);
    FreeAndNil(SLlog);
  end;
  //Writeln('.............. Calculations complete ..............');
  //
end;

end.

