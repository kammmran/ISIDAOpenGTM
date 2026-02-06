program GTMReSample;

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}{$IFDEF UseCThreads}
  cthreads,
  {$ENDIF}{$ENDIF}
  Classes, SysUtils, CustApp, unit_GTMReSample_option, UGTMXML, ugtm_options,
  UcGTM, UGTMMN, UGTMFull, UGTMBase, ulinalg
  { you can add units after this };

const
  ArgLst = 'hi:o:x:k:w:e:';
  LngArg = 'help input: xml: sampling: width: height: 3D getRmat';


type

  { TGTMReSample }

  TGTMReSample = class(TCustomApplication)
  protected
    procedure DoRun; override;
  public
    constructor Create(TheOwner: TComponent); override;
    destructor Destroy; override;
    procedure WriteHelp; virtual;
  end;

{ TGTMReSample }

procedure TGTMReSample.DoRun;
var
  ErrorMsg: String;
  GTMRSopt: TGTMReSample_option;
  GTMXML: TGTMXML;
  GTMopt: TRGtmOptions;
  GTMc: TcGTM;
  GTMs: TuGTMMN;
  aGTM: TGTMBase;
  GTMf: TGTMFull;
  LL: double;
begin
  // quick check parameters
  ErrorMsg:=CheckOptions(ArgLst, LngArg);
  if ErrorMsg<>'' then begin
    ShowException(Exception.Create(ErrorMsg));
    Terminate;
    Exit;
  end;

  GTMc:=nil;
  GTMs:=nil;
  aGTM:=nil;
  GTMRSopt:=TGTMReSample_option.Create;
  // parse parameters
  if HasOption('h', 'help') then begin
    WriteHelp;
    Terminate;
    Exit;
  end;

  if HasOption('i', 'input') then begin
    GTMRSopt.input:=GetOptionValue('i','input');
  end;

  if HasOption('o', 'output') then begin
    GTMRSopt.output:=GetOptionValue('o','output');
  end else GTMRSopt.output:='default';

  if HasOption('x', 'xml') then begin
    GTMRSopt.model:=GetOptionValue('x','xml');
  end else
  begin
    writeln('ERROR: No model provided.');
    WriteHelp;
    Terminate;
    Exit;
  end;

  if HasOption('k', 'sampling') then begin
    GTMRSopt.newK:=StrToInt(GetOptionValue('k', 'sampling'));
  end else
  begin
    writeln('INFO: No resolution provided.');
    if HasOption('w', 'width') then begin
      GTMRSopt.width:=StrToInt(GetOptionValue('w', 'width'));
    end else
    begin
      writeln('ERROR: No width provided.');
      WriteHelp;
      Terminate;
      Exit;
    end;

    if HasOption('e', 'height') then begin
      GTMRSopt.height:=StrToInt(GetOptionValue('e', 'height'));
    end else GTMRSopt.height:=GTMRSopt.width;
  end;

  GTMRSopt.b3D:=False;
  if HasOption('3D') then GTMRSopt.b3D:=True;

  GTMRSopt.bRmat:=False;
  if HasOption('getRmat') then GTMRSopt.bRmat:=True;

  { add your program here }

  GTMRSopt.Welcome();
  GTMRSopt.DisplayParameters();
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
    INCREMENTAL: writeln('Not Supported');
    MULTINOMIAL:
      begin
        GTMs:=TuGTMMN.Create;
        GTMXML.ReadGTMModel(GTMs,GTMRSopt.model);
        GTMs.Restart:=True;
        aGTM:=GTMs as TGTMBase;
      end
  else begin
    Writeln('ERROR: GTM type not recognized');
    Terminate;
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
      INCREMENTAL: writeln('Not Supported');
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
      Writeln('ERROR: GTM type not recognized');
      Terminate;
      Exit;
    end;
    end;
    WriteGTMMat(aGTM,GTMRSopt.output,GTMRSopt.b3D,True);//GTMRSopt.bRmat);
    Writeln('LogLikelihood: '+FloatToStrF(LL,ffFixed,10,5));
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
  FreeAndNil(GTMRSopt);
  writeln('***********End of Run************');
  Terminate;
end;

constructor TGTMReSample.Create(TheOwner: TComponent);
begin
  inherited Create(TheOwner);
  StopOnException:=True;
end;

destructor TGTMReSample.Destroy;
begin
  inherited Destroy;
end;

procedure TGTMReSample.WriteHelp;
begin
  { add your help code here }
  writeln('Usage: ', ExeName, ' -h -i <molecules.svm> -x <model.xml> -o <output> -k <sampling(int) -w <width(int)> -e <height(int)>');
  writeln('This software resample a GTM manifold with a rectangular grid.');
  writeln('-i <molecules.svm>: the molecules that need to be projected.');
  writeln('-x <model.xml>: the GTM model XML file that needs to be resampled.');
  writeln('-o <output>: the base name of output files names.');
  writeln('-k <sampling(int)>: the total number of nodes of the map. Pseudo-regular grid.');
  writeln('-w <width(int)>: the number of nodes on the width of the map. Rectangular grid.');
  writeln('-e <heigth(int)>: the number of nodes on the height of the map. Rectangular grid.');
  writeln('--3D: output also 3D information files');
  writeln('--getRmat: output also responsability matrices');
end;

var
  Application: TGTMReSample;
begin
  {$IfDef WINDOWS}DefaultFormatSettings.DateSeparator:='-';{$EndIf}
  {$IfDef LOCALES}DefaultFormatSettings.DecimalSeparator:='.';DefaultFormatSettings.ShortDateFormat:='d/m/y';{$EndIf}
  Application:=TGTMReSample.Create(nil);
  Application.Run;
  Application.Free;
end.

