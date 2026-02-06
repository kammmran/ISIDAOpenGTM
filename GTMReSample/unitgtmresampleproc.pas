unit UnitGTMReSampleProc;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, unit_GTMReSample_option, UGTMXML, ugtm_options,
  UcGTM, UGTMMN, UGTMFull, UGTMBase;

procedure DoReSampling(GTMRSopt: TGTMReSample_option; SLog: TStrings);
implementation

procedure DoReSampling(GTMRSopt: TGTMReSample_option; SLog: TStrings);
var
  GTMXML: TGTMXML;
  GTMopt: TRGtmOptions;
  GTMc: TcGTM;
  GTMs: TuGTMMN;
  aGTM: TGTMBase;
  GTMf: TGTMFull;
  LL: double;
begin
  GTMXML:=nil;
  GTMopt:=nil;
  GTMc:=nil;
  GTMs:=nil;
  aGTM:=nil;
  GTMf:=nil;
  LL:=0;
  //
  if FileExists(ChangeFileExt(GTMRSopt.output,'.xml')) then
    DeleteFile(ChangeFileExt(GTMRSopt.output,'.xml'));
  if FileExists(ChangeFileExt(GTMRSopt.output,'Prj.mat')) then
    DeleteFile(ChangeFileExt(GTMRSopt.output,'Prj.mat'));
  if FileExists(ChangeFileExt(GTMRSopt.output,'R.svm')) then
    DeleteFile(ChangeFileExt(GTMRSopt.output,'R.svm'));
  if FileExists(ChangeFileExt(GTMRSopt.output,'R.mat')) then
    DeleteFile(ChangeFileExt(GTMRSopt.output,'R.mat'));
  if FileExists(ChangeFileExt(GTMRSopt.output,'PC123.mat')) then
    DeleteFile(ChangeFileExt(GTMRSopt.output,'PC123.mat'));
  if FileExists(ChangeFileExt(GTMRSopt.output,'WPhi.mat')) then
    DeleteFile(ChangeFileExt(GTMRSopt.output,'WPhi.mat'));
  if FileExists(ChangeFileExt(GTMRSopt.output,'WPhi3D.mat')) then
    DeleteFile(ChangeFileExt(GTMRSopt.output,'WPhi3D.mat'));
  //DON'T FORGET TO REMOVE EXISTING OUTPUT FILES

  Slog.add('');
  Slog.add('***************************************************************');
  Slog.add('***********************BEGIN COMPUTATIONS**********************');
  Slog.add('***************************************************************');
  Slog.add('');

  GTMXML:=TGTMXML.Create;
  GTMopt:=TRGtmOptions.Create;
  GTMXML.ReadGTMModel(GTMopt,GTMRSopt.model);
  FreeAndNil(GTMXML);
  //
  GTMXML:=TGTMXML.Create;
  case GTMOpt.GTMType of
    BISHOP:
      begin
        GTMc:=TcGTM.Create;
        GTMXML.ReadGTMModel(TGTMFull(GTMc),GTMRSopt.model);
        GTMc.Restart:=True;
        aGTM:=GTMc as TGTMBase;
      end;
    INCREMENTAL: raise Exception.Create('Not Supported');
    MULTINOMIAL:
      begin
        GTMs:=TuGTMMN.Create;
        GTMXML.ReadGTMModel(GTMs,GTMRSopt.model);
        GTMs.Restart:=True;
        aGTM:=GTMs as TGTMBase;
      end
  else begin
    raise Exception.Create('ERROR: GTM type not recognized');
    Exit;
  end;
  end;
  FreeAndNil(GTMXML);
  //
  if (GTMRSopt.input<>'') then
  begin
    case GTMOpt.GTMType of
      BISHOP:
        begin
          GTMc.ReadMols(GTMRSopt.input);
          if (GTMRSopt.width<>0) and (GTMRSopt.height<>0) then
            GTMc.ResizeMatX(GTMRSopt.height,GTMRSopt.width )
          else if (GTMRSopt.newK<>0) then
            GTMc.ResizeMatX(GTMRSopt.newK)
          else
          begin
            raise Exception.Create('Invalid new geometry; width='+IntToStr(GTMRSopt.width)+' height='+IntToStr(GTMRSopt.height)+' resolution='+IntToStr(GTMRSopt.newK));
            halt;
          end;
          GTMc.Project(GTMc.Z,GTMc.N);
          LL:=GTMc.LogLikelyHood();
        end;
      INCREMENTAL: raise Exception.Create('Not Supported');
      MULTINOMIAL:
        begin
          GTMs.ReadMols(GTMRSopt.input);
          if (GTMRSopt.width<>0) and (GTMRSopt.height<>0) then
            GTMs.ResizeMatX(GTMRSopt.height,GTMRSopt.width )
          else if (GTMRSopt.newK<>0) then
            GTMs.ResizeMatX(GTMRSopt.newK)
          else
          begin
            raise Exception.Create('Invalid new geometry; width='+IntToStr(GTMRSopt.width)+' height='+IntToStr(GTMRSopt.height)+' resolution='+IntToStr(GTMRSopt.newK));
            halt;
          end;
          GTMs.Project();
          LL:=GTMc.LogLikelyHood();
        end
    else begin
      raise Exception.Create('ERROR: GTM type not recognized');
      Exit;
    end;
    end;
    WriteGTMMat(aGTM,GTMRSopt.output,GTMRSopt.b3D,True);//GTMRSopt.bRmat);
    SLog.Add('LogLikelihood: '+FloatToStrF(LL,ffFixed,10,5));
  end else
  begin
    aGTM.K:=GTMRSopt.height*GTMRSopt.width;
    if (GTMRSopt.width<>0) and (GTMRSopt.height<>0) then
      aGTM.ResizeMatX(GTMRSopt.height,GTMRSopt.width )
    else if (GTMRSopt.newK<>0) then
      aGTM.ResizeMatX(GTMRSopt.newK)
    else
    begin
      raise Exception.Create('Invalid new geometry; width='+IntToStr(GTMRSopt.width)+' height='+IntToStr(GTMRSopt.height)+' resolution='+IntToStr(GTMRSopt.newK));
      halt;
    end;
  end;
  //
  GTMXML:=TGTMXML.Create;
  GTMXML.WriteGTMModel(aGTM,ChangeFileExt(GTMRSopt.output,'.xml'));
  FreeAndNil(GTMXML);
  // stop program loop
  if (GTMc<>nil) then FreeAndNil(GTMc);
  if (GTMs<>nil) then FreeAndNil(GTMs);
  FreeAndNil(GTMopt);
  Slog.add('***********End of Run************');
end;

end.

