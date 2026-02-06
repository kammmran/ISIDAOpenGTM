unit UnitProc;

{$mode objfpc}{$H+}
//Macro so that at compile time, if GUI is used, writeln will store
//strings into a SLog TStringList and if not, it is directed to stdout.
{$MACRO ON}
{$DEFINE WRITELN:={$IFDEF GUI}SLog.Add{$ELSE}writeln{$ENDIF}}
{$DEFINE APP_PROCESS:={$IFDEF GUI}Application.ProcessMessages{$ENDIF}}

(******************************************************************************)
(*************************************INTERFACE********************************)
(******************************************************************************)
interface

uses
  Classes, SysUtils, streamex, utypes,
  {$IFDEF GUI}
  Forms,
  {$ENDIF}
  ULinAlgSparse, ulinalg,
  ISIDA_descriptor, ioSVM,
  ugtm_options, UcGTM, UiGTM, UGTMMN, UGTMBase, UGTMFull, UGTMSparse, UGTMXML;
{, utypes,
  ugtm_EM, incremental_learning, ulinalg, DOM, XMLRead, ureader,
  umath, ugtm_options, ugtm_manifold, ugtm_data, ugtm_model, ustatistics;}

//scripts (normal, batch, crossval, batch crossval)
//Procedures to parse an input file. L1, L2 are the lower and upper values of the lines to read
procedure ReadMols(RF: TFileReader; out X: TSMatrix; out Y:TVector; const L:integer=-1);
procedure ReadMols(const flenme: string; var X : TSMatrix; out Y : TVector; L1: integer=0; L2:integer=-1);
procedure ReadMols(const flenme: string; var X : TSMatrix; L1: integer=0; L2:integer=-1);
procedure ReadGTMModel(var myGTM: TGTMBase; xmlfile: string; brestart: boolean);
procedure SetGTMMols(var myGTM: TGTMFull; var ZT: TMatrix; var NMax: integer; trainfile, projfile: string; isplit: integer;
  bproj: boolean; istd: integer);
procedure SetGTMMols(var myGTM: TGTMSparse; var ZT: TSMatrix; var NMax: integer; trainfile, projfile: string; isplit: integer;
  bproj: boolean);
function ProjectData(myGTM: TGTMFull; TZ: TMatrix; Nmax: integer; var LLt: double; b3D, bproj: boolean; s3Dfile: string): double;
function ProjectData(myGTM: TGTMSparse; TZ: TSMatrix; Nmax: integer; bproj: boolean): double;
{$IFDEF GUI}
procedure Welcome(SLog: TStringList);
procedure DoClassicGTM(GTMOpt: TRGtmOptions; SLog: TStringList); //Bishop GTM
procedure DoClassicGTMb(GTMOpt: TRGtmOptions; SLog: TStringList); //Bishop GTM on blocks
procedure DoIncrementalGTM(GTMOpt: TRGtmOptions; SLog: TStringList); //Incremental GTM
procedure DoMultinomialGTM(GTMOpt: TRGtmOptions; SLog: TStringList); //Incremental GTM
procedure DoMultinomialGTMb(GTMOpt: TRGtmOptions; SLog: TStringList); //Incremental GTM on blocks
procedure FileCleanUp(flename: string; SLog: TStringList); //Clean up files of previous runs
{$ELSE}
procedure Welcome();
procedure DoClassicGTM(GTMOpt: TRGtmOptions); //Bishop GTM
procedure DoClassicGTMb(GTMOpt: TRGtmOptions); //Bishop GTM on blocks
procedure DoIncrementalGTM(GTMOpt: TRGtmOptions); //Incremental GTM
procedure DoMultinomialGTM(GTMOpt: TRGtmOptions); //Incremental GTM
procedure DoMultinomialGTMb(GTMOpt: TRGtmOptions); //Incremental GTM on blocks
procedure FileCleanUp(flename: string); //Clean up files of previous runs
{$ENDIF}
{procedure runGTM(var GTMData: RGTMData; var GTMoptions: RGTMOptions);
procedure runCommonGTM(var GTMData: RGTMData; var GTMoptions: RGTMOptions;
  var GTMModel: RGTMModel);
procedure runbatchGTM(var GTMData: RGTMData; var GTMoptions: RGTMOptions);
procedure performProjection(var GTMData: RGTMData; var GTMOptions: RGTMOptions);
procedure performReverseProjection(var GTMData: RGTMData; var GTMOptions: RGTMOptions);
function performCrossValidation(var GTMData: RGTMData;
  var GTMoptions: RGTMOptions): TVector;
procedure performSimplePrediction(var GTMData, GTMDataTest: RGTMData; var GTMOptions: RGTMOptions);
procedure KERNELperformSimplePrediction(var GTMData, GTMDataTest: RGTMData; var GTMOptions: RGTMOptions);
procedure KERNELperformProjection(var GTMOptions: RGTMOptions);
procedure DISSIMILARITYperformSimplePrediction(var GTMData, GTMDataTest: RGTMData; var GTMOptions: RGTMOptions);
procedure DISSIMILARITYperformProjection(var GTMOptions: RGTMOptions);
procedure batchCrossValidation(var GTMData: RGTMData; var GTMoptions: RGTMOptions);
procedure runCombinedGTM(var GTMData: RGTMData; var GTMoptions: RGTMOptions; var GTMModel: RGTMModel);}


// make indices for cross-validation
{function makesIndices(nFolds, numInfold, numInLastFold: integer): TVector;
procedure computeScore(GTMData: RGTMData; GTMModel: RGTMModel; GTMOptions: RGTMOptions);}



(******************************************************************************)
(*******************************IMPLEMENTATION*********************************)
(******************************************************************************)
implementation


(*******************************WELCOME****************************************)

{$IFDEF GUI}
procedure Welcome(SLog: TStringList);
{$ELSE}
procedure Welcome();
{$ENDIF}
begin
  WRITELN('');
  WRITELN('__________________________________');
  WRITELN('                                  ');
  WRITELN('oooo                ooooo         ');
  WRITELN('            o      o   ooooooooo  ');
  WRITELN('ooo    o      o                   ');
  WRITELN('                                  ');
  WRITELN('ooooo  WELCOME TO GTMAPTOOL       ');
  WRITELN('               2016               ');
  WRITELN('                                  ');
  WRITELN(' oooooo      o                    ');
  WRITELN('  ooo o  o   o         oooo       ');
  WRITELN(' ooooo             ooooo          ');
  WRITELN('__________________________________');
  WRITELN('');
  WRITELN('');
  WRITELN('Laboratoire de Chémoinformatique');
  WRITELN('Université de Strasbourg');
  WRITELN('Implementation: Héléna A. Gaspar, G. Marcou, D. Horvath, A. Varnek');
  WRITELN('');APP_PROCESS;
end;

procedure ReadMols(RF: TFileReader; out X: TSMatrix; out Y: TVector;
  const L: integer);
var
  il, id, ic, ir, N: integer;
  sline: string;
  pitem: PRDsc;
  mol: LRDsc;
  mols: LRSMFv2;
  bstop: boolean;
begin
  bstop:=False;
  il:=0;
  N:=0;
  mols:=LRSMFv2.Create;
  repeat
    RF.ReadLine(sline);
    inc(il);
    mol:=ReadLNSVM(sline);
    mols.Add(mol);
    pitem:=mol.Last;
    if (L<0) then
       bstop:=RF.Eof
    else
      bstop:=(il>=L);
  until bstop;
  //
  N:=mols.Count; //Get the number of molecules
  DimVector(Y,N);
  for il:=0 to mols.Count-1 do
  begin
    mol:=mols.Items[il] as LRDsc;
    ir:=il+1;
    Y[ir]:=mol.prp;
    for id:=0 to mol.Count-1 do
    begin
      pitem:=PRDsc(mol.Items[id]);
      ic:=pitem^.Idx;
      X.AddElement(ir,ic,pitem^.Cnt);
    end;
  end;
  FreeAndNil(mols);
end;

procedure ReadMols(const flenme: string; var X: TSMatrix; out Y: TVector;
  L1: integer; L2: integer);
var
  RF: TFileReader;
  il, Lmax: integer;
begin
  RF:=TFileReader.Create(flenme);
  X.Clear;
  il:=0;
  while (il<L1) and (not RF.Eof) do
  begin
    RF.ReadLine;
    inc(il);
  end;
  if (L2>0) then
     Lmax:=L2-L1
  else Lmax:=-1;
  ReadMols(RF,X,Y,Lmax);
  FreeAndNil(RF);
end;

procedure ReadMols(const flenme: string; var X: TSMatrix; L1: integer;
  L2: integer);
begin
  ReadMols(flenme,X,L1,L2);
end;

procedure ReadGTMModel(var myGTM: TGTMBase; xmlfile: string; brestart: boolean);
//Read the file xmlfile to set myGTM. If brestart, continue training.
var
  GTM_XML: TGTMXML;
begin
  GTM_XML:=TGTMXML.Create;
  if (myGTM is TGTMFull) then
    GTM_XML.ReadGTMModel(TGTMFull(myGTM),xmlfile)
  else if (myGTM is TGTMSparse) then
    GTM_XML.ReadGTMModel(TGTMSparse(myGTM),xmlfile)
  else
  begin
    raise Exception.Create('ERROR: requested GTM is neither sparse of full. Reading the XML is not possible.');
    halt;
  end;
  FreeAndNil(GTM_XML); //GTM_XML is linked to the document: it cannot survive its use
  myGTM.Restart:=brestart; //Continue training
end;

procedure SetGTMMols(var myGTM: TGTMFull; var ZT: TMatrix; var NMax: integer; trainfile, projfile: string; isplit: integer;
  bproj: boolean; istd: integer);
//Set the training set and the projection set according to user's options
var
  RF: TFileReader;
begin
  NMax:=0;
  if myGTM.istd=1 then myGTM.istd:=istd; //do not overwrite the pre-process option unless it is default
  if trainfile<>'' then
  begin
    RF:=TFileReader.Create(trainfile);
    if isplit>0 then // TZ and TY from the last lines of the input file
    begin
      myGTM.ReadMols(RF,isplit);
      if bproj then //Get a TZ and TY as last lines of input file
        myGTM.ReadMols(RF,ZT,Nmax,-1);
    end else myGTM.ReadMols(RF); // Use whole input file
    FreeAndNil(RF);
  end;
  //Initialize the calculation
  if bproj and (projfile<>'') then // TZ and TY from another file
    myGTM.ReadMols(projfile,ZT,Nmax);
end;

procedure SetGTMMols(var myGTM: TGTMSparse; var ZT: TSMatrix; var NMax: integer;
  trainfile, projfile: string; isplit: integer; bproj: boolean);
var
  RF: TFileReader;
begin
  if trainfile<>'' then //Initialize the GTM with the input file
  begin
    RF:=TFileReader.Create(trainfile);
    if isplit>0 then // TZ and TY from the last lines of the input file
    begin
      myGTM.ReadMols(RF,isplit);
      if bproj then //Get a TZ and TY as last lines of input file
        myGTM.ReadMols(RF,ZT,Nmax,-1);
    end else myGTM.ReadMols(RF); // Use whole input file
    FreeAndNil(RF);
  end;
  //Initialize the calculation
  if bproj and (projfile<>'') then // TZ and TY from another file
    myGTM.ReadMols(projfile,ZT,Nmax);
end;

function ProjectData(myGTM: TGTMFull; TZ: TMatrix; Nmax: integer; var LLt: double; b3D, bproj: boolean; s3Dfile: string): double;
var
  sl: TStringList;
  Z3D: TMatrix;
  jj,ii,id: integer;
  fsOut: TFileStream;
begin
  sl:=TStringList.Create;
  if (b3D) and (myGTM.Z<>nil) then
  begin
    Z3D:=nil;
    sl.Clear;
    PrintMat(myGTM.Z,'Ztrain',1,myGTM.N,1,myGTM.D,sl);
    if not FileExists(s3Dfile+'Ztrain.mat') then
       sl.SaveToFile(s3Dfile+'Ztrain.mat')
    else
    begin
      fsOut:=TFileStream.Create(s3Dfile+'Ztrain.mat',fmOpenReadWrite);
      fsOut.Seek(0,soFromEnd);
      sl.SaveToStream(fsOut);
      FreeAndNil(fsOut);
    end;
    DimMatrix(Z3D,High(myGTM.Z),3);
    for ii:=1 to High(Z3D) do
      for jj:=1 to 3 do
      begin
        Z3D[ii,jj]:=0;
        for id:=1 to myGTM.D do
          Z3D[ii,jj]:=Z3D[ii,jj]+myGTM.Z[ii,id]*myGTM.PC123[id,jj];
      end;
    sl.Clear;
    PrintMat(Z3D,'Z3Dtrain',1,myGTM.N,1,3,sl);
    SetLength(Z3D,0); Z3D:=nil;
    if not FileExists(s3Dfile+'Z3Dtrain.mat') then
      sl.SaveToFile(s3Dfile+'Z3Dtrain.mat')
    else
    begin
      fsOut:=TFileStream.Create(s3Dfile+'Z3Dtrain.mat',fmOpenReadWrite);
      fsOut.Seek(0,soFromEnd);
      sl.SaveToStream(fsOut);
      FreeAndNil(fsOut);
    end;
  end;
  if bproj then
  begin
    if (Nmax>0) then
    begin
      myGTM.Project(TZ,Nmax);
      LLt:=myGTM.LogLikelyHood();
      if b3D then
      begin
        sl.Clear;
        PrintMat(myGTM.Z,'Ztest',1,myGTM.N,1,myGTM.D,sl);
        if not FileExists(s3Dfile+'Ztest.mat') then
          sl.SaveToFile(s3Dfile+'Ztest.mat')
        else
        begin
          fsOut:=TFileStream.Create(s3Dfile+'Ztest.mat',fmOpenReadWrite);
          fsOut.Seek(0,soFromEnd);
          sl.SaveToStream(fsOut);
          FreeAndNil(fsOut);
        end;
        DimMatrix(Z3D,High(myGTM.Z),3);
        for ii:=1 to High(Z3D) do
          for jj:=1 to 3 do
          begin
            Z3D[ii,jj]:=0;
            for id:=1 to myGTM.D do
              Z3D[ii,jj]:=Z3D[ii,jj]+myGTM.Z[ii,id]*myGTM.PC123[id,jj];
          end;
        sl.Clear;
        PrintMat(Z3D,'Z3Dtest',1,myGTM.N,1,3,sl);
        SetLength(Z3D,0); Z3D:=nil;
        if not FileExists(s3Dfile+'Z3Dtest.mat') then
          sl.SaveToFile(s3Dfile+'Z3Dtest.mat')
        else
        begin
          fsOut:=TFileStream.Create(s3Dfile+'Z3Dtest.mat',fmOpenReadWrite);
          fsOut.Seek(0,soFromEnd);
          sl.SaveToStream(fsOut);
          FreeAndNil(fsOut);
        end;
      end;
    end else
    begin
      (myGTM as TGTMBase).Project();
      LLt:=myGTM.LogLikelyHood();
    end;
    Result:=LLt
  end;
  sl.Clear;
  FreeAndNil(sl);
end;

function ProjectData(myGTM: TGTMSparse; TZ: TSMatrix; Nmax: integer; bproj: boolean): double;
begin
  Result:=0;
  if bproj then
  begin
    if (Nmax>0) then
    begin
      myGTM.Project(TZ);
    end else
    begin
      (myGTM as TGTMBase).Project();
    end;
  end;
end;

{$IFDEF GUI}
procedure DoClassicGTM(GTMOpt: TRGtmOptions; SLog: TStringList); //Bishop GTM
{$ELSE}
procedure DoClassicGTM(GTMOpt: TRGtmOptions); //Bishop GTM
{$ENDIF}
var
  myGTM: TcGTM;
  LLt0, LLt: double;
  iter: integer;
  Wold: TMatrix;
  id, im: integer;
  DW,DW0, dconv, dLL: double;
  bConv: boolean;
  TZ: TMatrix;
  Nmax: integer;
  GTM_XML: TGTMXML;
  sline: string;
begin
  {$IFDEF GUI}
  FileCleanUp(GTMOpt.outputFile,SLog);

  {$ELSE}
  FileCleanUp(GTMOpt.outputFile);
  {$ENDIF}
  myGTM:=TcGTM.Create;
  TZ:=nil;
  Wold:=nil;
  Nmax:=0;
  LLt:=0;
  DW0:=1;
  sline:='';
  //Read a model file
  if GTMOpt.modelFile<>'' then
  begin
    ReadGTMModel(TGTMbase(myGTM),GTMOpt.modelFile,True);
  end;
  SetGTMMols(TGTMFull(myGTM),TZ,NMax,GTMOpt.inputFile,GTMOpt.projFile,GTMOpt.splitFile,GTMOpt.doProjection,GTMOpt.preprocess);
  if GTMOpt.inputFile<>'' then
  begin
    myGTM.Init1(GTMOpt.nSamples,GTMOpt.nCenters,GTMOpt.sigma,GTMOpt.alpha);
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
  end else
  begin
    myGTM.Init(NMax);
  end;
  //Project data
  LLt:=ProjectData(TGTMFull(myGTM),TZ,Nmax,LLt,GTMOpt.p3D,GTMOpt.doProjection,GTMOpt.outputFile);
  WRITELN('Likelyhood of projected data: '+FloatToStrF(LLt,ffGeneral,8,5));APP_PROCESS;
  //Save responsabilities and projections
  WriteGTMMat(myGTM,GTMOpt.outputFile, GTMOpt.p3D,GTMOpt.Rmat);
  FreeAndNil(myGTM);
end;

{$IFDEF GUI}
procedure DoClassicGTMb(GTMOpt: TRGtmOptions; SLog: TStringList); //Bishop block GTM
{$ELSE}
procedure DoClassicGTMb(GTMOpt: TRGtmOptions);
{$ENDIF}
//If the dataset is treated by blocks of data projection functionalities
//are disabled. This is because, the dataset to analyze are likely to be
//very large. Thus projection becomes a separated task.
var
  myGTM: TcGTM;
  LLt0, LLt, dLL: double;
  iter: integer;
  Wold: TMatrix;
  id, im: integer;
  DW,DW0, dconv: double;
  bConv: boolean;
  RF: TFileReader;
  GTM_XML: TGTMXML;
  ZT: TMatrix;
  Nmax: integer;
  sline: string;
begin
  WRITELN('block classical');APP_PROCESS;
  {$IFDEF GUI}
  FileCleanUp(GTMOpt.outputFile,SLog);
  {$ELSE}
  FileCleanUp(GTMOpt.outputFile);
  {$ENDIF}
  myGTM:=TcGTM.Create;
  Wold:=nil;
  DW0:=1;
  sline:='';
  //Read a model file
  myGTM.istd:=GTMOpt.preprocess;
  if GTMOpt.modelFile<>'' then
  begin
    ReadGTMModel(TGTMbase(myGTM),GTMOpt.modelFile,True);
  end;
  if GTMOpt.inputFile<>'' then
  begin
    RF:=TFileReader.Create(GTMOpt.inputFile);
    myGTM.ReadMols(RF,GTMOpt.nBlocks); //Read the first block in advance to initialize the GTM
    myGTM.Init1(GTMOpt.nSamples,GTMOpt.nCenters,GTMOpt.sigma,GTMOpt.alpha);
    DimMatrix(Wold,myGTM.D,myGTM.M); //Keep track of the previous state of the map
    DW0:=myGTM.D*myGTM.M;
    RF.Reset;
    repeat
      myGTM.ReadMols(RF,ZT,Nmax,GTMOpt.nBlocks);
      myGTM.Initb(ZT,Nmax);
      myGTM.Expectation();
      LLt:=myGTM.LogLikelyHood();
      WRITELN('New block. Likelyhood of new block: '+FloatToStrF(LLt,ffGeneral,8,5));APP_PROCESS;
      LLt0:=0;
      iter:=1;
      bConv:=False;
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
              if (DW<abs(Wold[id,im]-myGTM.W[id,im])) then DW:=abs(Wold[id,im]-myGTM.W[id,im]);
          dConv:=DW/DW0;
          sline:=sline+' DW='+FloatToStrF(DW,ffFixed,8,5)+' %DW='+FloatToStrF(dConv*100,ffFixed,8,5);
          If dLL<GTMOpt.convCriteria then bConv:=True;
        end;
        WRITELN(sline);APP_PROCESS;
        //Prepare next iteration
        LLt0:=LLt;
        Inc(iter);
      until (iter>GTMOpt.nIter) or (bConv=True);
      WRITELN('End block');APP_PROCESS;
    until (RF.Eof);
    //Save the map
    GTM_XML:=TGTMXML.Create;
    GTM_XML.WriteGTMModel(myGTM,ChangeFileExt(GTMOpt.outputFile,'.xml'));
    FreeAndNil(GTM_XML);
  end;
  if GTMOpt.projFile<>'' then
  begin
    RF:=TFileReader.Create(GTMOpt.projFile);
    myGTM.ReadMols(RF,ZT,Nmax,GTMOpt.nBlocks); //Read the first block in advance to initialize the GTM
    myGTM.Init(Nmax);
    if not RF.Eof then
    begin
      repeat
        LLt:=ProjectData(TGTMFull(myGTM),ZT,Nmax,LLt,GTMOpt.p3D,GTMOpt.doProjection,GTMOpt.outputFile);
        WRITELN('Likelyhood of projected data: '+FloatToStrF(LLt,ffGeneral,8,5));APP_PROCESS;
        WriteGTMMat(myGTM,GTMOpt.outputFile, GTMOpt.p3D,GTMOpt.Rmat);
        myGTM.ReadMols(RF,ZT,Nmax,GTMOpt.nBlocks);
        WRITELN('End block');APP_PROCESS;
      until (RF.Eof);
      LLt:=ProjectData(TGTMFull(myGTM),ZT,Nmax,LLt,GTMOpt.p3D,GTMOpt.doProjection,GTMOpt.outputFile);
      WRITELN('Likelyhood of projected data: '+FloatToStrF(LLt,ffGeneral,8,5));APP_PROCESS;
      WriteGTMMat(myGTM,GTMOpt.outputFile, GTMOpt.p3D,GTMOpt.Rmat);
    end else //in case the buffer size is larger than the file
    begin
      LLt:=ProjectData(TGTMFull(myGTM),ZT,Nmax,LLt,GTMOpt.p3D,GTMOpt.doProjection,GTMOpt.outputFile);
      WRITELN('Likelyhood of projected data: '+FloatToStrF(LLt,ffGeneral,8,5));APP_PROCESS;
      WriteGTMMat(myGTM,GTMOpt.outputFile, GTMOpt.p3D,GTMOpt.Rmat);
    end;
    FreeAndNil(RF);
  end else if (GTMOpt.doProjection) then
    WRITELN('WARNING: Projection ignored. You need to specify a datafile to project if using block mode.');APP_PROCESS;
  FreeAndNil(myGTM);
end;

{$IFDEF GUI}
procedure DoIncrementalGTM(GTMOpt: TRGtmOptions; SLog: TStringList); //Incremental algorithm
{$ELSE}
procedure DoIncrementalGTM(GTMOpt: TRGtmOptions);
{$ENDIF}
var
  myGTM: TiGTM;
  LLt0, LLt, dLL: double;
  iter: integer;
  Wold: TMatrix;
  ZT: TMatrix;
  id, im: integer;
  DW,DW0, dconv: double;
  bConv, bInc: boolean;
  Nmax: integer;
  GTM_XML: TGTMXML;
  iimin, iimax,incr: integer;
  sline: string;
begin
  if (GTMOpt.nBlocks<=0) then
  begin
    WRITELN('ERROR: invalid number of blocks value: '+IntToStr(GTMOpt.nBlocks));APP_PROCESS;
    Exit;
  end;
  {$IFDEF GUI}
  FileCleanUp(GTMOpt.outputFile,SLog);
  {$ELSE}
  FileCleanUp(GTMOpt.outputFile);
  {$ENDIF}
  myGTM:=TiGTM.Create;
  Nmax:=0;
  DW0:=1;
  Wold:=nil;
  ZT:=nil;
  sline:='';
  SetGTMMols(TGTMFull(myGTM),ZT,Nmax,GTMOpt.inputFile,'',0,False,GTMOpt.preprocess);
  //Initialize the calculation
  if GTMOpt.inputFile<>'' then
  begin
    myGTM.Init1(GTMOpt.nSamples,GTMOpt.nCenters,GTMOpt.nBlocks,GTMOpt.sigma,GTMOpt.alpha);
    TcGTM(myGTM).Expectation();
    LLt:=TcGTM(myGTM).LogLikelyHood();
    myGTM.LL:=LLt*myGTM.N;
    TcGTM(myGTM).Maximization();
    WRITELN('LLt='+FloatToStr(LLt));APP_PROCESS;
    LLt0:=0;
    iter:=1;
    bConv:=False;
    DimMatrix(Wold,myGTM.D,myGTM.M); //Keep track of the previous state of the map
    DW0:=myGTM.D*myGTM.M;
    repeat
      incr:=1;
      bInc:=True;
      iimin:=1;
      iimax:=myGTM.Nblk;
      while(bInc) do begin
        myGTM.Expectation(iimin,iimax);
        myGTM.Maximization(iimin,iimax);
        LLt:=myGTM.LogLikelyHood(iimin,iimax);
        WRITELN('*Iter.: '+IntToStr(Iter)+' Increment:'+IntToStr(incr)+' LLmap='+FloatToStrF(LLt,ffFixed,8,5)+' ');APP_PROCESS;
        iimin:=iimax+1;
        iimax:=iimax+myGTM.Nblk;
        if iimax>=myGTM.N then
        begin
          iimax:=myGTM.N;
          bInc:=False;
        end;
        Inc(incr);
      end;
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
  end;
  FreeAndNil(myGTM);
end;

{$IFDEF GUI}
procedure DoMultinomialGTM(GTMOpt: TRGtmOptions; SLog: TStringList); //Multinomial algorithm
{$ELSE}
procedure DoMultinomialGTM(GTMOpt: TRGtmOptions); //Multinomial algorithm
{$ENDIF}
var
  myGTM: TuGTMMN;
  LLt0, LLt, dLL: double;
  iter: integer;
  Wold: TMatrix;
  id, im: integer;
  DW,DW0, dconv: double;
  bConv: boolean;
  TZ: TSMatrix;
  Nmax: integer;
  GTM_XML: TGTMXML;
  sline: string;
begin
  WRITELN('batch multinomial');
  {$IFDEF GUI}
  FileCleanUp(GTMOpt.outputFile,SLog);
  {$ELSE}
  FileCleanUp(GTMOpt.outputFile);
  {$ENDIF}
  myGTM:=TuGTMMN.Create;
  TZ:=TSMatrix.Create;
  Wold:=nil;
  Nmax:=0;
  DW0:=1;
  sline:='';
  //Read a model file
  if GTMOpt.modelFile<>'' then
  begin
    ReadGTMModel(TGTMbase(myGTM),GTMOpt.modelFile,True);
  end;
  SetGTMMols(TGTMSparse(myGTM),TZ,NMax,GTMOpt.inputFile,GTMOpt.projFile,GTMOpt.splitFile,GTMOpt.doProjection);
  if GTMOpt.inputFile<>'' then
  begin
    myGTM.Init(GTMOpt.nSamples,GTMOpt.nCenters,GTMOpt.sigma);
    myGTM.Expectation();
    LLt0:=0;
    iter:=1;
    bConv:=False;
    DimMatrix(Wold,myGTM.D,myGTM.M); //Keep track of the previous state of the map
    DW0:=myGTM.D*myGTM.M;
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
        If dConv<GTMOpt.convCriteria then bConv:=True;
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
  end else
  begin
    myGTM.Init(Nmax);
  end;
  //Project data
  ProjectData(TGTMSparse(myGTM),TZ,Nmax,GTMOpt.doProjection);
  LLt:=myGTM.LogLikelyhood();
  WRITELN('Likelyhood of projected data: '+FloatToStrF(LLt,ffGeneral,8,5));APP_PROCESS;
  //Save responsabilities and projections
  WriteGTMMat(myGTM,GTMOpt.outputFile, GTMOpt.p3D,GTMOpt.Rmat);
  FreeAndNil(TZ);
  FreeAndNil(GTM_XML);
  FreeAndNil(myGTM);
end;

{$IFDEF GUI}
procedure DoMultinomialGTMb(GTMOpt: TRGtmOptions; SLog: TStringList); // Block multinomial algorithm
{$ELSE}
procedure DoMultinomialGTMb(GTMOpt: TRGtmOptions); // Block multinomial algorithm
{$ENDIF}
//If the dataset is treated by blocks of data projection functionalities
//are disabled. This is because, the dataset to analyze are likely to be
//very large. Thus projection becomes a separated task.
var
  myGTM: TuGTMMN;
  LLt0, LLt, dLL: double;
  iter: integer;
  Wold: TMatrix;
  id, im: integer;
  DW,DW0, dconv: double;
  bConv: boolean;
  RF: TFileReader;
  GTM_XML: TGTMXML;
  sline: string;
begin
  WRITELN('block multinomial');
  {$IFDEF GUI}
  FileCleanUp(GTMOpt.outputFile,SLog);
  {$ELSE}
  FileCleanUp(GTMOpt.outputFile);
  {$ENDIF}
  myGTM:=TuGTMMN.Create;
  Wold:=nil;
  DW0:=1;
  sline:='';
  //Read a model file
  if GTMOpt.modelFile<>'' then
  begin
    ReadGTMModel(TGTMbase(myGTM),GTMOpt.modelFile,True);
  end;
  if GTMOpt.inputFile<>'' then
  begin
    RF:=TFileReader.Create(GTMOpt.inputFile);
    myGTM.ReadMols(RF,GTMOpt.nBlocks); //Read the first block in advance to initialize the GTM
    myGTM.Init(GTMOpt.nSamples,GTMOpt.nCenters,GTMOpt.sigma,GTMOpt.nBlocks);
    DimMatrix(Wold,myGTM.D,myGTM.M); //Keep track of the previous state of the map
    DW0:=myGTM.D*myGTM.M;
    RF.Reset;
    repeat
      myGTM.ResetZ;
      myGTM.ReadMols(RF,GTMOpt.nBlocks);
      myGTM.RedimR(myGTM.N,myGTM.K);
      myGTM.Expectation();
      LLt0:=0;
      iter:=1;
      bConv:=False;
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
              if (DW<abs(Wold[id,im]-myGTM.W[id,im])) then DW:=abs(Wold[id,im]-myGTM.W[id,im]);
          dConv:=DW/DW0;
          sline:=sline+' DW='+FloatToStrF(DW,ffFixed,8,5)+' %DW='+FloatToStrF(dConv*100,ffFixed,8,5);
          If dLL<GTMOpt.convCriteria then bConv:=True;
        end;
        WRITELN(sline);APP_PROCESS;
        //Prepare next iteration
        LLt0:=LLt;
        Inc(iter);
      until (iter>GTMOpt.nIter) or (bConv=True);
    until (RF.Eof);
    //Save the map
    GTM_XML:=TGTMXML.Create;
    GTM_XML.WriteGTMModel(myGTM,ChangeFileExt(GTMOpt.outputFile,'.xml'));
    FreeAndNil(GTM_XML);
  end;
  FreeAndNil(GTM_XML);
  FreeAndNil(myGTM);
end;

{$IFDEF GUI}
procedure FileCleanUp(flename: string; SLog: TStringList); //Remove files from previous runs
{$ELSE}
procedure FileCleanUp(flename: string); //Remove files from previous runs
{$ENDIF}
begin
  if FileExists(ChangeFileExt(flename,'R.mat')) then
  begin
    WRITELN('WARNING: File '+ChangeFileExt(flename,'R.mat')+' is deleted');APP_PROCESS;
    DeleteFile(ChangeFileExt(flename,'R.mat'));
  end;
  if FileExists(ChangeFileExt(flename,'R.svm')) then
  begin
    WRITELN('WARNING: File '+ChangeFileExt(flename,'R.svm')+' is deleted');APP_PROCESS;
    DeleteFile(ChangeFileExt(flename,'R.svm'));
  end;
  if FileExists(ChangeFileExt(flename,'Prj.mat')) then
  begin
    WRITELN('WARNING: File '+ChangeFileExt(flename,'Prj.mat')+' is deleted');APP_PROCESS;
    DeleteFile(ChangeFileExt(flename,'Prj.mat'));
  end;
  if FileExists(ChangeFileExt(flename,'Prj3.mat')) then
  begin
    WRITELN('WARNING: File '+ChangeFileExt(flename,'Prj3.mat')+' is deleted');APP_PROCESS;
    DeleteFile(ChangeFileExt(flename,'Prj3.mat'));
  end;
  if FileExists(ChangeFileExt(flename,'WPhi.mat')) then
  begin
    WRITELN('WARNING: File '+ChangeFileExt(flename,'WPhi.mat')+' is deleted');APP_PROCESS;
    DeleteFile(ChangeFileExt(flename,'WPhi.mat'));
  end;
  if FileExists(ChangeFileExt(flename,'PC123.mat')) then
  begin
    WRITELN('WARNING: File '+ChangeFileExt(flename,'PC123.mat')+' is deleted');APP_PROCESS;
    DeleteFile(ChangeFileExt(flename,'PC123.mat'));
  end;
  if FileExists(ChangeFileExt(flename,'WPhi3D.mat')) then
  begin
    WRITELN('WARNING: File '+ChangeFileExt(flename,'WPhi3D.mat')+' is deleted');APP_PROCESS;
    DeleteFile(ChangeFileExt(flename,'WPhi3D.mat'));
  end;

  if FileExists(ChangeFileExt(flename,'Ztrain.mat')) then
  begin
    WRITELN('WARNING: File '+ChangeFileExt(flename,'Ztrain.mat')+' is deleted');APP_PROCESS;
    DeleteFile(ChangeFileExt(flename,'Ztrain.mat'));
  end;
  if FileExists(ChangeFileExt(flename,'Z3Dtrain.mat')) then
  begin
    WRITELN('WARNING: File '+ChangeFileExt(flename,'Z3Dtrain.mat')+' is deleted');APP_PROCESS;
    DeleteFile(ChangeFileExt(flename,'Z3Dtrain.mat'));
  end;
  if FileExists(ChangeFileExt(flename,'Ztest.mat')) then
  begin
    WRITELN('WARNING: File '+ChangeFileExt(flename,'Ztest.mat')+' is deleted');APP_PROCESS;
    DeleteFile(ChangeFileExt(flename,'Ztest.mat'));
  end;
  if FileExists(ChangeFileExt(flename,'Z3Dtest.mat')) then
  begin
    WRITELN('WARNING: File '+ChangeFileExt(flename,'Z3Dtest.mat')+' is deleted');APP_PROCESS;
    DeleteFile(ChangeFileExt(flename,'Z3Dtest.mat'));
  end;
end;



{
(*********************************RUN REGULAR GTM******************************)
procedure runGTM(var GTMData: RGTMData; var GTMoptions: RGTMOptions);
var
  GTMModel: RGTMModel; /////////////////////////////////////////////////////
begin
  // create MODEL object
  GTMModel := RGTMModel.Create; /////////////////////////////////////////////////////

  // run algorithm and fill GTMModel
  if GTMOptions.beginProp = 0 then
  runCommonGTM(GTMData, GTMOptions, GTMModel)
  else
  runCombinedGTM(GTMData, GTMOptions, GTMModel);

  // free DATA and MODEL objects
  FreeAndNil(GTMModel); /////////////////////////////////////////////////////
end;



(*********************************GTM ALGORITHM********************************)
procedure runCommonGTM(var GTMData: RGTMData; var GTMoptions: RGTMOptions;
  var GTMModel: RGTMModel);
var
  GTMManifold: RGTMManifold;
  GTMINITIALDATA, GTMNextData: RGTMData;
  GTMInitialModel, GTMNextModel: RGTMModel;
begin
  // create MANIFOLD object
  GTMManifold := RGTMManifold.Create;
  GTMManifold.missing := GTMOptions.missing;
  GTMManifold.sparse := GTMOptions.sparse;
  /////////////////////////////////////////////////////

  //initialize GTM (matM, matPhi, matX, matU, matW, matY, matD, matW, betaInv)
  if GTMOptions.doIncrement=FALSE then begin

  GTMManifold.initManifold(GTMOptions, GTMData);

  GTMModel.initModel(GTMOptions, GTMData, GTMManifold);
  end else begin
  GTMInitialData := RGTMData.Create;
  GTMNextData := RGTMData.Create;
  GTMInitialModel := RGTMModel.Create;
  GTMNextModel := RGTMModel.Create;
  end;

  // EM algorithm
  if ((GTMOptions.doIncrement = False) or (GTMOptions.doBatch = True)) then
  begin
    EM(GTMData, GTMManifold, GTMModel, GTMOptions);
  end
  else if (GTMOptions.numberOfInputFiles<2)  then
    GTMModel.matR := EMIncremental(GTMInitialData, GTMData, GTMNextData, GTMManifold, GTMInitialModel, GTMModel, GTMNextModel, GTMOptions)
    else  begin

     GTMModel.matR := EMIncrementalWithSeveralFiles(GTMInitialData, GTMData, GTMNextData, GTMManifold, GTMInitialModel, GTMModel, GTMNextModel, GTMOptions);
    end;



  // free MANIFOLD object
  FreeAndNil(GTMManifold); /////////////////////////////////////////////////////

  if GTMOptions.missing then  writeMatrixToFile(GTMData.matT, GTMOptions.outputFile + '_matTCompleted' + '.txt','completed matrix');

  if ((GTMOptions.doBatch = False) and (GTMOptions.mute = FALSE) and (GTMOptions.numberOfInputFiles<2)) then
  begin
    // compute means, modes and descriptors
    GTMModel.compute2DCoordinates(GTMOptions.nSamples, GTMData.nMolecules);
    //   if GTMData.nMolecules < 10000 then DisplayMatrix(GTMModel.matMeans);

    //optionnal fit
    //   if ((GTMOptions.classify = TRUE) and (GTMOptions.perFormCV = FALSE)) then begin
  // GTMData.ClassModel.makeFit(GTMOptions.nSamples,
  // GTMData.nMolecules, GTMModel.matR, GTMModel.matMeans, GTMModel.matX, GTMModel.moleculeLikelihood,
  // GTMOptions.outputfile);
   //end;

    GTMModel.writeGTMModel(GTMOptions);

  end;

 if GTMOptions.computeDescScores = TRUE then computeScore(GTMData, GTMModel, GTMOptions);

 if GTMOptions.doBatch = FALSE then begin
 writeln;
 write('SCORE: '); writeln(FormatFloat('0.000000000', GTMModel.loglikelihood));

 end;

end;



(*********************************GTM ALGORITHM********************************)
procedure runCombinedGTM(var GTMData: RGTMData; var GTMoptions: RGTMOptions;
  var GTMModel: RGTMModel);
var
  GTMManifoldDesc, GTMManifoldProp, GTMManifold: RGTMManifold;
  GTMDataDesc, GTMDataProp: RGTMData;
  GTMModelDesc, GTMModelProp: RGTMModel;
  GTMOptionsDesc,GTMOptionsProp: RGTMOptions;
begin

  GTMDataDesc := RGTMData.create;
  GTMDataProp := RGTMData.create;
  GTMModelDesc := RGTMModel.Create;
  GTMModelProp := RGTMModel.Create;
  GTMManifoldProp := RGTMManifold.Create;
  GTMManifoldDesc := RGTMManifold.Create;
  GTMManifold := RGTMManifold.Create;
  GTMOptionsDesc := RGTMOptions.Create;
  GTMOptionsProp := RGTMOptions.Create;
  GTMOptionsDesc.clone(GTMOptions);
  GTMOptionsProp.clone(GTMOptions);
  GTMManifoldDesc.missing := GTMOptionsDesc.missing;
  GTMManifoldProp.missing := GTMOptionsProp.missing;
  GTMManifold.missing := GTMOptions.missing;
  GTMDataDesc.matT := matrixSubMatrix(GTMData.matT,0,GTMData.nMolecules-1,0,GTMOptions.beginProp-2);
  GTMDataDesc.nMolecules := GTMData.nMolecules;
  GTMDataProp.matT := matrixSubMatrix(GTMData.matT,0,GTMData.nMolecules-1,GTMOptions.beginProp-1,GTMOptions.nDimensions-1);
  GTMDataProp.nMolecules := GTMData.nMolecules;

  GTMDataDesc.theMeans := matrixColMeans(GTMDataDesc.matT);
  GTMDataProp.theMeans := matrixColMeans(GTMDataProp.matT);
  GTMDataDesc.allMissingValues := GTMData.allMissingValues;
  GTMDataProp.allMissingValues := GTMData.allMissingValues;
  GTMOptionsDesc.nDimensions := GTMOptions.beginProp-1;
  GTMOptionsProp.nDimensions := GTMOptions.nDimensions-GTMOptions.beginProp + 1;
  GTMOptionsDesc.outputFile := GTMOptions.outputFile + '_desc';
  GTMOptionsProp.outputFile := GTMOptions.outputFile + '_prop';


  //initialize GTM (matM, matPhi, matX, matU, matW, matY, matD, matW, betaInv)

  GTMManifoldDesc.initManifold(GTMOptionsDesc, GTMDataDesc);

  GTMManifoldProp.initManifold(GTMOptionsProp, GTMDataProp);
  GTMManifold.initManifold(GTMOptions, GTMData);

  GTMModelDesc.initModel(GTMOptionsDesc, GTMDataDesc, GTMManifoldDesc);
  GTMModelProp.initModel(GTMOptionsProp, GTMDataProp, GTMManifoldProp);
  GTMModel.initModel(GTMOptions, GTMData, GTMManifold);



  // EM algorithm
  EMCombined(GTMDataDesc, GTMDataProp, GTMManifoldDesc, GTMManifoldProp, GTMModelDesc,GTMModelProp,GTMModel, GTMOptions,GTMOptionsDesc,GTMOptionsProp);


  // free MANIFOLD object
  FreeAndNil(GTMManifoldDesc); /////////////////////////////////////////////////////
  FreeAndNil(GTMManifoldProp); /////////////////////////////////////////////////////
  FreeAndNil(GTMManifold); /////////////////////////////////////////////////////

  if GTMOptions.missing then writeMatrixToFile(GTMDataDesc.matT, GTMOptionsDesc.outputFile + '_matT' + '.txt','descriptors matrix');
 if GTMOptions.missing then writeMatrixToFile(GTMDataProp.matT, GTMOptionsProp.outputFile + '_matT' + '.txt','properties matrix');

  if ((GTMOptions.doBatch = False) and (GTMOptions.mute = FALSE) and (GTMOptions.numberOfInputFiles<2)) then
  begin
    // compute means, modes and descriptors
    GTMModelDesc.compute2DCoordinates(GTMOptionsDesc.nSamples, GTMDataDesc.nMolecules);
    GTMModelProp.compute2DCoordinates(GTMOptionsProp.nSamples, GTMDataProp.nMolecules);
    GTMModel.compute2DCoordinates(GTMOptions.nSamples, GTMData.nMolecules);
    GTMModelDesc.writeGTMModel(GTMOptionsDesc);
    GTMModelProp.writeGTMModel(GTMOptionsProp);
    GTMModel.writeGTMModel(GTMOptions);
  end;

 //if GTMOptions.computeDescScores = TRUE then computeScore(GTMData, GTMModel, GTMOptions);

 if GTMOptions.doBatch = FALSE then begin
 writeln;
 write('SCORE: '); writeln(FormatFloat('0.000000000', GTMModel.loglikelihood));

 end;

end;




(*********************************RUN GTM**************************************)
procedure runbatchGTM(var GTMData: RGTMData; var GTMoptions: RGTMOptions);
var
  parameters, params: string;
  retainValue: Float;
  doBatch: boolean;
  doOnline, doIncrement: boolean;
  GTMModel: RGTMModel; /////////////////////////////////////////////////////
begin
  doBatch := True;
  doOnline := False;
  doIncrement := False;
  GTMOptions.doBatch := doBatch;
  GTMOptions.doIncrement := doIncrement;

  RetainValue := -MaxNum;
  Parameters := '';
  Params := '';
  writeln('#nodes' + #9 + '#rbf' + #9 + 'width' + #9 + 'alpha' +
    #9 + 'log likelihood');


  GTMOptions.sigma := StrToFloat(GTMOptions.lbatchW.Strings[0]);
  GTMOptions.alpha := Power(10, StrToFloat(GTMOptions.lbatchL.Strings[0]));
  GTMOptions.sqrtSamples := StrToInt(GTMOptions.lbatchK.Strings[0]);
  GTMOptions.sqrtCenters := StrToInt(GTMOptions.lbatchM.Strings[0]);
  GTMOptions.nSamples := GTMOptions.sqrtSamples * GTMOptions.sqrtSamples;
  GTMOptions.nCenters := GTMOptions.sqrtCenters * GTMOptions.sqrtCenters;

  while GTMOptions.sqrtSamples <= StrToInt(GTMOptions.lbatchK.Strings[2]) do
  begin
    while GTMOptions.sqrtCenters <= StrToInt(GTMOptions.lbatchM.Strings[2]) do
    begin
      while GTMOptions.sigma <= StrToFloat(GTMOptions.lbatchW.Strings[2]) do
      begin
        while GTMOptions.alpha <=
          Power(10, StrToFloat(GTMOptions.lbatchL.Strings[2]) + 1) do
        begin

          GTMModel := RGTMModel.Create;

          runCommonGTM(GTMData, GTMOptions, GTMModel);

          Params := IntToStr(GTMOptions.sqrtSamples) + #9 +
            IntToStr(GTMOptions.sqrtCenters) + #9 + FloatToStr(GTMOptions.sigma) +
            #9 + FloatToStr(GTMOptions.alpha) + #9 +
            FormatFloat('0.000000000', GTMModel.loglikelihood);
          Writeln(params);



          if RetainValue < GTMModel.loglikelihood then
          begin
            RetainValue := GTMModel.loglikelihood;
            Parameters := Params;
          end;

          FreeAndNil(GTMModel);

          GTMOptions.alpha *= Power(10, StrToFloat(GTMOptions.lbatchL.Strings[1]));
        end;
        GTMOptions.alpha := Power(10, StrToFloat(GTMOptions.lbatchL.Strings[0]));
        GTMOptions.sigma += StrToFloat(GTMOptions.lbatchW.Strings[1]);
      end;
      GTMOptions.sigma := StrToFloat(GTMOptions.lbatchW.Strings[0]);
      GTMOptions.sqrtCenters += StrToInt(GTMOptions.lbatchM.Strings[1]);
      GTMOptions.nCenters := GTMOptions.sqrtCenters * GTMOptions.sqrtCenters;
    end;
    GTMOptions.sqrtCenters := StrToInt(GTMOptions.lbatchM.Strings[0]);
    GTMOptions.nCenters := GTMOptions.sqrtCenters * GTMOptions.sqrtCenters;
    GTMOptions.sqrtSamples += StrToInt(GTMOptions.lbatchK.Strings[1]);
    GTMOptions.nSamples := GTMOptions.sqrtSamples * GTMOptions.sqrtSamples;

  end;


  FreeAndNil(GTMModel); /////////////////////////////////////////////////////
  writeln;
  writeln;
  writeln('***************BATCH RESULTS****************');
  Write('Best loglikelihood: ');
  writeln(#9 + FloatToStr(Retainvalue));
  writeln('Best Parameters: ');
  writeln('#nodes' + #9 + '#rbf' + #9 + 'width' + #9 + 'alpha');
  writeln(Parameters);
  writeln('********************************************');

end;



(*******************************PERFORM PROJECTION*****************************)
procedure performProjection(var GTMData: RGTMData; var GTMOptions: RGTMOptions);
var
  i, j: integer;
  Doc: TXMLDocument;/////////////////////////////////////////////////////
  InverseBetaNode, MappingMatrixNode: TDOMNode;
  /////////////////////////////////////////////////////
  invBetaMatAAD: AAD;/////////////////////////////////////////////////////
  GTMManifold: RGTMManifold; /////////////////////////////////////////////////////
  GTMModel: RGTMModel;/////////////////////////////////////////////////////
begin


  GTMManifold := RGTMManifold.Create;
  GTMModel := RGTMModel.Create;

  GTMOptions.evaldistances := False;


  ReadXMLFile(Doc, GTMOptions.projectionFile);



  InverseBetaNode := Doc.DocumentElement.FindNode('inverseBeta');

  MappingMatrixNode := Doc.DocumentElement.FindNode('mappingMatrix');

  invBetaMatAAD := loadData(inverseBetaNode.FirstChild.NodeValue);

  GTMManifold.matY := loadDataMatrix(MappingMatrixNode.FirstChild.NodeValue);


  GTMManifold.betaInv := invBetaMatAAD[0][0];

  SetLength(invBetaMatAAD, 0, 0); /////////////////////////////////////////////////////


  if high(GTMManifold.matY) = high(GTMData.matT[0]) then
  begin
    GTMOptions.nSamples := ROUND(high(GTMManifold.matY[0]));
    GTMOptions.sqrtSamples := ROUND(sqrt(GTMOptions.nSamples));
    GTMModel.matX := GTMManifold.createMMatrix(GTMOptions.sqrtSamples);

    writeln('creating distance matrix...');
    GTMModel.createDistanceMatrix(GTMManifold,
      GTMData.matT, GTMOptions.nSamples, GTMData.nMolecules,
      GTMOptions.nDimensions);
    writeln('computing probabilities...');
    GTMModel.createPMatrix(GTMManifold.betaInv,
      GTMOptions.nSamples, GTMData.nMolecules, GTMOptions.nDimensions);
    writeln('computing responsibilities...');
    GTMModel.createRMatrix(GTMOptions.nSamples, GTMData.nMolecules);
    writeln('computing likelihood...');
    GTMModel.computemoleculeLikelihood(GTMManifold.betaInv, GTMOptions.nDimensions,GTMOptions.nSamples, GTMData.nMolecules);
    if GTMOptions.BIN=FALSE then begin
    GTMModel.computelogLikelihood(GTMManifold.betaInv,GTMOptions.nDimensions,GTMOptions.nSamples, GTMData.nMolecules);
    GTMModel.computemoleculeLikelihood(GTMManifold.betaInv, GTMOptions.nDimensions,GTMOptions.nSamples, GTMData.nMolecules);
    end else begin
      GTMModel.computelogLikelihoodClassical(GTMOptions.nDimensions,GTMOptions.nSamples, GTMData.nMolecules);
      GTMModel.computemoleculeLikelihoodClassical(GTMOptions.nDimensions,GTMOptions.nSamples, GTMData.nMolecules);
      end;

    writeln('computing means and modes...');
    GTMModel.compute2DCoordinates(GTMOptions.nSamples, GTMData.nMolecules);
    DisplayMatrix(GTMModel.matMeans);
    Writeln;
    writeln('writing files...');
    GTMModel.writeGTMModel(GTMOptions);
    writeln;
    Writeln('Log Likelihood: ' + FloatToStr(GTMModel.logLikelihood));
  end
  else
    writeln('ERROR: the projection matrix dimension does not match input data dimension');

  FreeAndNil(GTMManifold); /////////////////////////////////////////////////////
  FreeAndNil(GTMModel); /////////////////////////////////////////////////////


end;



(*******************************PERFORM PROJECTION*****************************)
procedure performReverseProjection(var GTMData: RGTMData; var GTMOptions: RGTMOptions);
var
  i, j,k: integer;
  Doc, DocReverse: TXMLDocument;/////////////////////////////////////////////////////
  InverseBetaNode, MappingMatrixNode: TDOMNode;
  wNode, sigmaNode, mNode: TDOMNode;
  /////////////////////////////////////////////////////
  invBetaMatAAD, mAAD, sigmaAAD: AAD;/////////////////////////////////////////////////////
  GTMManifold, GTMManifoldReverse: RGTMManifold; /////////////////////////////////////////////////////
  GTMModel, GTMModelReverse: RGTMModel;/////////////////////////////////////////////////////
  matRPrime : TMatrix;
  YTemp: TVector;
  datasd, datamean: TMatrix;
  saveYMat: TMatrix;
  dataDistrib: TMatrix;
begin


  GTMManifold := RGTMManifold.Create;
  GTMModel := RGTMModel.Create;
  GTMOptions.evaldistances := False;
  ReadXMLFile(Doc, GTMOptions.projectionFile);
  InverseBetaNode := Doc.DocumentElement.FindNode('inverseBeta');
  MappingMatrixNode := Doc.DocumentElement.FindNode('mappingMatrix');
  invBetaMatAAD := loadData(inverseBetaNode.FirstChild.NodeValue);
  GTMManifold.matY := loadDataMatrix(MappingMatrixNode.FirstChild.NodeValue);
  GTMManifold.betaInv := invBetaMatAAD[0][0];

  SetLength(invBetaMatAAD, 0, 0); /////////////////////////////////////////////////////


  if high(GTMManifold.matY) = high(GTMData.matT[0]) then
  begin
    GTMOptions.nSamples := ROUND(high(GTMManifold.matY[0]));
    GTMOptions.sqrtSamples := ROUND(sqrt(GTMOptions.nSamples));
    GTMModel.matX := GTMManifold.createMMatrix(GTMOptions.sqrtSamples);

    writeln('creating distance matrix...');
    GTMModel.createDistanceMatrix(GTMManifold,
      GTMData.matT, GTMOptions.nSamples, GTMData.nMolecules,
      GTMOptions.nDimensions);
    writeln('computing probabilities...');
    GTMModel.createPMatrix(GTMManifold.betaInv,
      GTMOptions.nSamples, GTMData.nMolecules, GTMOptions.nDimensions);
    writeln('computing responsibilities...');
    GTMModel.createRMatrix(GTMOptions.nSamples, GTMData.nMolecules);
    writeln('computing likelihood...');

    if GTMOptions.BIN=FALSE then begin
    GTMModel.computemoleculeLikelihood(GTMManifold.betaInv, GTMOptions.nDimensions,GTMOptions.nSamples, GTMData.nMolecules);
    GTMModel.computelogLikelihood(GTMManifold.betaInv,GTMOptions.nDimensions,GTMOptions.nSamples, GTMData.nMolecules);
     end else begin
      GTMModel.computemoleculeLikelihoodClassical(GTMOptions.nDimensions,GTMOptions.nSamples, GTMData.nMolecules);
    GTMModel.computelogLikelihoodClassical(GTMOptions.nDimensions,GTMOptions.nSamples, GTMData.nMolecules);
     end;
    writeln('computing means and modes...');
    GTMModel.compute2DCoordinates(GTMOptions.nSamples, GTMData.nMolecules);
    DisplayMatrix(GTMModel.matMeans);
    Writeln;
    writeln('writing files...');
    GTMModel.writeGTMModel(GTMOptions);
    writeln;
    Writeln('Log Likelihood: ' + FloatToStr(GTMModel.logLikelihood));
  end
  else
    writeln('ERROR: the projection matrix dimension does not match input data dimension');



  //then, open second file



  GTMManifoldReverse := RGTMManifold.Create;
  ReadXMLFile(DocReverse, GTMOptions.reverseProjectionFile);
  sigmaNode := DocReverse.DocumentElement.FindNode('rbfWidth');
  mNode := DocReverse.DocumentElement.FindNode('numberOfRbfCenters');
  wNode := DocReverse.DocumentElement.FindNode('WParameterMatrix');
  InverseBetaNode := Doc.DocumentElement.FindNode('inverseBeta');
  sigmaAAD := loadData(sigmaNode.FirstChild.NodeValue);

  mAAD := loadData(mNode.FirstChild.NodeValue);

  GTMManifoldReverse.matW := loadDataMatrix(wNode.FirstChild.NodeValue);


  GTMManifoldReverse.rbfWidth := sigmaAAD[0][0];
  GTMOptions.nCenters := TRUNC(mAAD[0][0]);



  GTMManifoldReverse.matM := GTMManifold.createMMatrix(trunc(sqrt(GTMOptions.nCenters)));

    GTMManifoldReverse.createPhiMatrixFromMatrix(GTMModel.matX, GTMOptions.nSamples, GTMOptions.nCenters, GTMManifoldReverse.rbfWidth);
  GTMManifoldReverse.createYMatrix;
  writeMatrixToFile(matrixTranspose(GTMManifoldReverse.matY),GTMOptions.outputfile+'_manifoldInPropertySpace.txt');
    GTMManifoldReverse.createPhiMatrixFromMatrix(GTMModel.matMeans, GTMData.nMolecules, GTMOptions.nCenters, GTMManifoldReverse.rbfWidth);
  GTMManifoldReverse.createYMatrix;
  writeSVMMatrixToFile(matrixTranspose(GTMManifoldReverse.matY),GTMOptions.outputfile+'_dataInPropertySpace.svm');


  if GTMOptions.probabilisticProjection = TRUE then begin

  GTMOptions.nDimensions := high(GTMManifoldReverse.matY);
  saveYMat := matrixTranspose(GTMManifoldReverse.matY);
  GTMManifoldReverse.createPhiMatrixFromMatrix(GTMModel.matX, GTMOptions.nSamples, GTMOptions.nCenters, GTMManifoldReverse.rbfWidth);
  GTMManifoldReverse.createYMatrix;

  invBetaMatAAD := loadData(inverseBetaNode.FirstChild.NodeValue);
  GTMManifoldReverse.betaInv := invBetaMatAAD[0][0];

  GTMModelReverse := RGTMModel.Create;



  GTMModelReverse.createDistanceMatrix(GTMManifoldReverse,
      saveYMat, GTMOptions.nSamples, GTMData.nMolecules,
      GTMOptions.nDimensions);



  GTMModelReverse.createPMatrix(GTMManifoldReverse.betaInv,
      GTMOptions.nSamples, GTMData.nMolecules, GTMOptions.nDimensions);



   DimMatrix(dataDistrib, GTMData.nMolecules,  GTMData.nMolecules);


   for i:= 0 to GTMData.nMolecules-1 do
       for j := 0 to GTMData.nMolecules-1 do
           for k := 0 to GTMOptions.nSamples-1 do
         dataDistrib[i][j] += GTMModelReverse.matP[k][j]*GTMModel.matR[k][i];
        //    dataDistrib[j] += GTMModelReverse.matP[i][j];



 writeMatrixToFile(dataDistrib,GTMOptions.outputfile+'_prop_dataDistrib.txt', 'data distribution in property space knowing descriptor information');
 writeMatrixToFile(matrixTranspose(GTMModelReverse.matP), GTMOptions.outputfile+'_desc_PDF.txt', 'descriptor PDF');
 writeMatrixToFile(saveYMat, GTMOptions.outputfile+'_dataInPropSpace.txt', 'all data distribution');
 writeMatrixToFile(GTMManifoldReverse.matY, GTMOptions.outputfile+'_matY.txt', 'all data distribution');

    {
  matRPrime := matrixTranspose(GTMModel.matR);
 dimVector(YTemp, GTMOptions.nSamples);
 dimMatrix(datasd, GTMData.nMolecules, high(GTMManifoldReverse.matY));
 dimMatrix(datamean, GTMData.nMolecules, high(GTMManifoldReverse.matY));
  for i := 0 to GTMData.nMolecules-1 do
  begin
        for k := 0 to high(GTMManifoldReverse.matY)-1 do begin
            for j := 0 to GTMOptions.nSamples-1 do begin
                 datamean[i,k] += GTMManifoldReverse.matY[k][j]*matRPrime[i][j];
                  YTemp[j] := GTMManifoldReverse.matY[k][j]*matRPrime[i][j];
            end;

         if((i=0) and (k=0)) then begin
         writeVectorToFile(GTMManifoldReverse.matY[0],GTMOptions.outputfile+'_yx.txt', 'ff');
         writeVectorToFile(YTemp, GTMOptions.outputfile+'_yf.txt', 'ff');
         end;
          datasd[i,k] := standardDeviationTVector(YTemp,GTMOptions.nSamples);
          //datamean[i,k] := meanTVector(YTemp,GTMOptions.nSamples);
        end;
  end;




  writeMatrixToFile(datasd,GTMOptions.outputfile+'_predSTD.txt', 'standard deviation for each dimension');
  //writeMatrixToFile(datamean,GTMOptions.outputfile+'_predMEAN.txt', 'mean for each dimension');
  writeSVMMatrixToFile(datamean,GTMOptions.outputfile+'_dataInPropertySpace.svm');
 }
  end;








   FreeAndNil(GTMManifold); /////////////////////////////////////////////////////
  FreeAndNil(GTMModel); /////////////////////////////////////////////////////
  FreeAndNil(GTMManifoldReverse); /////////////////////////////////////////////////////







end;




(*******************************PERFORM PROJECTION*****************************)
procedure KERNELperformProjection(var GTMOptions: RGTMOptions);
var
  i, j: integer;
  Doc: TXMLDocument;/////////////////////////////////////////////////////
  InverseBetaNode, MappingMatrixNode, rbfNode, kernelNode: TDOMNode;
  invBetaMatAAD: AAD;
  /////////////////////////////////////////////////////
  GTMManifold: RGTMManifold; /////////////////////////////////////////////////////
  GTMModel: RGTMModel;/////////////////////////////////////////////////////
  nMoleculesTest, nMoleculesTrain: Integer;
begin

  //writeln('this function is not yet available, sorry');


  GTMManifold := RGTMManifold.Create;
  GTMModel := RGTMModel.Create;
  GTMOptions.evaldistances := False;

  ReadXMLFile(Doc, GTMOptions.projectionFile);

  InverseBetaNode := Doc.DocumentElement.FindNode('inverseBeta');
  MappingMatrixNode := Doc.DocumentElement.FindNode('mappingMatrix');
  rbfNode := Doc.DocumentElement.FindNode('rbf');


  GTMManifold.matL := loadDataMatrix(MappingMatrixNode.FirstChild.NodeValue);
  invBetaMatAAD := loadData(inverseBetaNode.FirstChild.NodeValue);
  GTMManifold.matPhiMPlusOne := loadDataMatrix(rbfNode.FirstChild.NodeValue);

  GTMManifold.matKTrain := loadMatrix(GTMOptions.kernelTrain);
  GTMManifold.matKTest := loadMatrix(GTMOptions.kernelTest);
  GTMManifold.matKTestVTrain := loadMatrix(GTMOptions.kernelTestVTrain);

  nMoleculesTest := high(GTMManifold.matKTest);
  nMoleculesTrain := high(GTMManifold.matKTrain);


  write('Number of molecules in test set: ');
  writeln(nMoleculesTest);
  write('Number of molecules in training set: ');
  writeln(nMoleculesTrain);
  writeln;

  GTMManifold.betaInv := invBetaMatAAD[0][0];


      GTMOptions.nSamples := ROUND(high(GTMManifold.matPhiMPlusOne));
    GTMOptions.sqrtSamples := ROUND(sqrt(GTMOptions.nSamples));
    GTMModel.matX := GTMManifold.createMMatrix(GTMOptions.sqrtSamples);


   GTMModel.KERNELcreateDistanceMatrixForProjection(GTMManifold, GTMOptions.nSamples, nMoleculesTrain, nMoleculesTest);     //init both mat Y and matD

  GTMModel.createPMatrix(GTMManifold.betaInv,
       GTMOptions.nSamples, nMoleculesTest, GTMOptions.nDimensions);
      writeln('computing likelihood...');
     GTMModel.computemoleculeLikelihood(GTMManifold.betaInv, GTMOptions.nDimensions,GTMOptions.nSamples, nMoleculesTest);
     writeln('computing responsibilities...');
     GTMModel.createRMatrix(GTMOptions.nSamples, nMoleculesTest);
     if GTMOptions.BIN=FALSE then
     GTMModel.computelogLikelihood(GTMManifold.betaInv,GTMOptions.nDimensions,GTMOptions.nSamples, nMoleculesTest) else
     GTMModel.computelogLikelihoodClassical(GTMOptions.nDimensions,GTMOptions.nSamples, nMoleculesTest);
     writeln('computing means and modes...');
     GTMModel.compute2DCoordinates(GTMOptions.nSamples, nMoleculesTest);

     DisplayMatrix(GTMModel.matMeans);
     Writeln;
     writeln('writing files...');
     GTMModel.writeGTMModel(GTMOptions);
     writeln;
     Writeln('Log Likelihood: ' + FloatToStr(GTMModel.logLikelihood));

  FreeAndNil(GTMManifold); /////////////////////////////////////////////////////
  FreeAndNil(GTMModel); /////////////////////////////////////////////////////



end;

(*******************************PERFORM PROJECTION*****************************)
procedure DISSIMILARITYperformProjection(var GTMOptions: RGTMOptions);
var
  i, j: integer;
  Doc: TXMLDocument;/////////////////////////////////////////////////////
  InverseBetaNode, MappingMatrixNode, rbfNode, kernelNode: TDOMNode;
  invBetaMatAAD: AAD;
  /////////////////////////////////////////////////////
  GTMManifold: RGTMManifold; /////////////////////////////////////////////////////
  GTMModel: RGTMModel;/////////////////////////////////////////////////////
  nMoleculesTest, nMoleculesTrain: Integer;
begin

  //writeln('this function is not yet available, sorry');


  GTMManifold := RGTMManifold.Create;
  GTMModel := RGTMModel.Create;
  GTMOptions.evaldistances := False;

  ReadXMLFile(Doc, GTMOptions.projectionFile);

  InverseBetaNode := Doc.DocumentElement.FindNode('inverseBeta');
  MappingMatrixNode := Doc.DocumentElement.FindNode('mappingMatrix');
  rbfNode := Doc.DocumentElement.FindNode('rbf');


  GTMManifold.matL := loadDataMatrix(MappingMatrixNode.FirstChild.NodeValue);
  invBetaMatAAD := loadData(inverseBetaNode.FirstChild.NodeValue);
  GTMManifold.matPhiMPlusOne := loadDataMatrix(rbfNode.FirstChild.NodeValue);

  GTMManifold.matDissimilarityTrain := loadMatrix(GTMOptions.dissimilarityTrain);
  GTMManifold.matDissimilarityTestVTrain := loadMatrix(GTMOptions.dissimilarityTestVTrain);


  nMoleculesTrain := high(GTMManifold.matDissimilarityTrain);
  nMoleculesTest := high(GTMManifold.matDissimilarityTestVTrain);

  write('Number of molecules in test set: ');
  writeln(nMoleculesTest);
  write('Number of molecules in training set: ');
  writeln(nMoleculesTrain);
  writeln;

  GTMManifold.betaInv := invBetaMatAAD[0][0];


    GTMOptions.nSamples := ROUND(high(GTMManifold.matPhiMPlusOne));
    GTMOptions.sqrtSamples := ROUND(sqrt(GTMOptions.nSamples));
    GTMModel.matX := GTMManifold.createMMatrix(GTMOptions.sqrtSamples);


   GTMModel.DISSIMILARITYcreateDistanceMatrixForProjection(GTMManifold, GTMOptions.nSamples, nMoleculesTrain, nMoleculesTest, GTMOptions.randomize);     //init both mat Y and matD

  GTMModel.createPMatrix(GTMManifold.betaInv,
       GTMOptions.nSamples, nMoleculesTest, GTMOptions.nDimensions);
      writeln('computing likelihood...');
     GTMModel.computemoleculeLikelihood(GTMManifold.betaInv, GTMOptions.nDimensions,GTMOptions.nSamples, nMoleculesTest);
     writeln('computing responsibilities...');
     GTMModel.createRMatrix(GTMOptions.nSamples, nMoleculesTest);
     if GTMOptions.BIN=FALSE then
     GTMModel.computelogLikelihood(GTMManifold.betaInv,GTMOptions.nDimensions,GTMOptions.nSamples, nMoleculesTest) else
     GTMModel.computelogLikelihoodClassical(GTMOptions.nDimensions,GTMOptions.nSamples, nMoleculesTest);
     writeln('computing means and modes...');
     GTMModel.compute2DCoordinates(GTMOptions.nSamples, nMoleculesTest);

     DisplayMatrix(GTMModel.matMeans);
     Writeln;
     writeln('writing files...');
     GTMModel.writeGTMModel(GTMOptions);
     writeln;
     Writeln('Log Likelihood: ' + FloatToStr(GTMModel.logLikelihood));

  FreeAndNil(GTMManifold); /////////////////////////////////////////////////////
  FreeAndNil(GTMModel); /////////////////////////////////////////////////////



end;


(*******************************PERFORM PROJECTION*****************************)
procedure performSimplePrediction(var GTMData, GTMDataTest: RGTMData; var GTMOptions: RGTMOptions);
var
  i, j: integer;
  Doc: TXMLDocument;/////////////////////////////////////////////////////
  InverseBetaNode, MappingMatrixNode: TDOMNode;
  /////////////////////////////////////////////////////
  invBetaMatAAD: AAD;/////////////////////////////////////////////////////
  GTMManifold: RGTMManifold; /////////////////////////////////////////////////////
  GTMModel: RGTMModel;/////////////////////////////////////////////////////
  GTMModelTest: RGTMModel;/////////////////////////////////////////////////////
  outputFile: String;
begin

  outputFile := GTMOptions.outputFile;
  GTMManifold := RGTMManifold.Create;
  GTMModel := RGTMModel.Create;
  GTMModelTest := RGTMModel.Create;

  //Doc := TXMLDocument.Create;
  //InverseBetaNode := TDOMNode.Create(Doc);
  //MappingMatrixNode := TDOMNode.Create(Doc);


  GTMOptions.evaldistances := False;

  writeln('reading xml file...');
  ReadXMLFile(Doc, GTMOptions.projectionFile);



  InverseBetaNode := Doc.DocumentElement.FindNode('inverseBeta');
  MappingMatrixNode := Doc.DocumentElement.FindNode('mappingMatrix');



  invBetaMatAAD := loadData(inverseBetaNode.FirstChild.NodeValue);

  GTMManifold.matY := loadDataMatrix(MappingMatrixNode.FirstChild.NodeValue);
  GTMManifold.betaInv := invBetaMatAAD[0][0];

  SetLength(invBetaMatAAD, 0, 0); /////////////////////////////////////////////////////


  if ((high(GTMManifold.matY) = high(GTMData.matT[0])) and (high(GTMDataTest.matT[0]) = high(GTMManifold.matY))) then
  begin

    GTMOptions.nSamples := ROUND(high(GTMManifold.matY[0]));
    GTMOptions.sqrtSamples := ROUND(sqrt(GTMOptions.nSamples));
    GTMModel.matX := GTMManifold.createMMatrix(GTMOptions.sqrtSamples);
    GTMModelTest.matX := GTMManifold.createMMatrix(GTMOptions.sqrtSamples);


    writeln('creating distance matrices...');

    GTMModel.createDistanceMatrix(GTMManifold,
      GTMData.matT, GTMOptions.nSamples, GTMData.nMolecules,
      GTMOptions.nDimensions);

    GTMModelTest.createDistanceMatrix(GTMManifold,
      GTMDataTest.matT, GTMOptions.nSamples, GTMDataTest.nMolecules,
      GTMOptions.nDimensions);

    writeln('computing probabilities...');
    GTMModel.createPMatrix(GTMManifold.betaInv,
      GTMOptions.nSamples, GTMData.nMolecules, GTMOptions.nDimensions);

    GTMModelTest.createPMatrix(GTMManifold.betaInv,
      GTMOptions.nSamples, GTMDataTest.nMolecules, GTMOptions.nDimensions);

    writeln('computing responsibilities...');
    GTMModel.createRMatrix(GTMOptions.nSamples, GTMData.nMolecules);
    GTMModelTest.createRMatrix(GTMOptions.nSamples, GTMDataTest.nMolecules);

    writeln('computing likelihood...');

    if GTMOptions.BIN=FALSE then begin
    GTMModel.computemoleculeLikelihood(GTMManifold.betaInv, GTMOptions.nDimensions,GTMOptions.nSamples, GTMData.nMolecules);
    GTMModelTest.computemoleculeLikelihood(GTMManifold.betaInv, GTMOptions.nDimensions,GTMOptions.nSamples, GTMDataTest.nMolecules);
    GTMModel.computelogLikelihood(GTMManifold.betaInv,GTMOptions.nDimensions,GTMOptions.nSamples, GTMData.nMolecules);
    GTMModelTest.computelogLikelihood(GTMManifold.betaInv,GTMOptions.nDimensions,GTMOptions.nSamples, GTMDataTest.nMolecules);
    end else begin
          GTMModel.computemoleculeLikelihoodClassical(GTMOptions.nDimensions,GTMOptions.nSamples, GTMData.nMolecules);
    GTMModelTest.computemoleculeLikelihoodClassical(GTMOptions.nDimensions,GTMOptions.nSamples, GTMDataTest.nMolecules);
    GTMModel.computelogLikelihoodClassical(GTMOptions.nDimensions,GTMOptions.nSamples, GTMData.nMolecules);
    GTMModelTest.computelogLikelihoodClassical(GTMOptions.nDimensions,GTMOptions.nSamples, GTMDataTest.nMolecules);

    end;


    writeln('writing vectors to file...');
    writeVectorToFile(GTMModel.moleculeLikelihood, GTMOptions.outputfile +
      '_moleculeLoglikelihoodTrain.txt',
      'log likelihood for each molecule');
  {      writeVectorToFile(GTMModelTest.moleculeLikelihood, GTMOptions.outputfile +
      '_moleculeLoglikelihoodTest.txt',
      'log likelihood for each molecule');   }
    writeln('computing means and modes...');
   GTMModel.compute2DCoordinates(GTMOptions.nSamples, GTMData.nMolecules);

   // DisplayMatrix(GTMModel.matMeans);
   GTMModelTest.compute2DCoordinates(GTMOptions.nSamples, GTMDataTest.nMolecules);

  //  Writeln;
  // writeln('writing files...');
   // GTMModel.writeGTMModel(GTMOptions);
    GTMModelTest.writeGTMModel(GTMOptions);
    writeln;
    Writeln('Log Likelihood of training set: ' + FloatToStr(GTMModel.logLikelihood));
    Writeln('Log Likelihood of external test set: ' + FloatToStr(GTMModelTest.logLikelihood));
  end
  else
    writeln('ERROR: the projection matrix dimension does not match input data dimension');

   if (GTMOptions.classify) then begin
    GTMDataTest.ClassModel.makeSimplePrediction(GTMData.nMolecules, GTMDataTest.nMolecules, GTMOptions.nSamples, GTMModel.matR, GTMModelTest.matR,GTMModelTest.matMeans,GTMModel.matX ,GTMOptions.outputfile);
    writeln;
    Writeln('Pred. activity: ' + outputFile + '_external_predictedActivity.txt');
    Writeln('Confidence: ' + outputFile + '_external_confidence.txt');
    Writeln;
    //Writeln('Predicted activity :');
   // DisplayVectorAsIntVector(GTMDataTest.ClassModel.predictedActivity);
    Writeln;
    Writeln;
   end else begin
    GTMDataTest.Regmodel.makeSimplePrediction(GTMData.nMolecules, GTMDataTest.nMolecules, GTMOptions.nSamples, GTMModel.matR, GTMModelTest.matR, GTMModel.matX, GTMModel.matMeans, GTMModelTest.matMeans);
    writeln;
    Writeln('Pred. activity: ' + outputFile + '_external_predictedActivity.txt');
    writeln;
    Writeln('Predicted activity :');
    DisplayVectorWithPrecision(GTMDataTest.RegModel.activityPredGlobalActivityLandscape,'0.000000');
    WriteVectorToFile(GTMDataTest.RegModel.activityPredGlobalActivityLandscape, outputFile + '_external_predictedActivityGlobalMethod.txt', 'external test set prediction using all nodes');
    WriteVectorToFile(GTMDataTest.RegModel.activityPredLocalActivityLandscape, outputFile + '_external_predictedActivityLocalMethod.txt', 'external test set prediction using neighbour nodes');
    WriteVectorToFile(GTMDataTest.RegModel.activityPredkNN, outputFile + '_external_predictedActivitykNNMethod.txt', 'external test set prediction using neighbour molecules');
    WriteVectorToFile(GTMDataTest.RegModel.activityPredkNNResp, outputFile + '_external_predictedActivitykNNRespMethod.txt', 'external test set prediction using responsibility correlations');
    WriteVectorToFile(GTMDataTest.RegModel.activityModel, outputFile + '_activityLandscape.txt', 'activity landscape');
    Writeln;
    Writeln;


   end;



  FreeAndNil(GTMManifold); /////////////////////////////////////////////////////
  FreeAndNil(GTMModel); /////////////////////////////////////////////////////
  FreeAndNil(GTMModelTest); /////////////////////////////////////////////////////


end;


(*******************************PERFORM PROJECTION*****************************)
procedure KERNELperformSimplePrediction(var GTMData, GTMDataTest: RGTMData; var GTMOptions: RGTMOptions);
var
  i, j: integer;
  Doc: TXMLDocument;/////////////////////////////////////////////////////
  InverseBetaNode, MappingMatrixNode, rbfNode, kernelNode: TDOMNode;
  /////////////////////////////////////////////////////
  invBetaMatAAD: AAD;/////////////////////////////////////////////////////
  GTMManifold: RGTMManifold; /////////////////////////////////////////////////////
  GTMModel: RGTMModel;/////////////////////////////////////////////////////
  GTMModelTest: RGTMModel;/////////////////////////////////////////////////////
  outputFile: String;
begin

  outputFile := GTMOptions.outputFile;
  GTMManifold := RGTMManifold.Create;
  GTMModel := RGTMModel.Create;
  GTMModelTest := RGTMModel.Create;

  //Doc := TXMLDocument.Create;
  //InverseBetaNode := TDOMNode.Create(Doc);
  //MappingMatrixNode := TDOMNode.Create(Doc);


  GTMOptions.evaldistances := False;

  writeln('reading xml file...');
  ReadXMLFile(Doc, GTMOptions.projectionFile);


  InverseBetaNode := Doc.DocumentElement.FindNode('inverseBeta');
  MappingMatrixNode := Doc.DocumentElement.FindNode('mappingMatrix');
  rbfNode := Doc.DocumentElement.FindNode('rbf');



  GTMManifold.matL := loadDataMatrix(MappingMatrixNode.FirstChild.NodeValue);
  invBetaMatAAD := loadData(inverseBetaNode.FirstChild.NodeValue);
  GTMManifold.matPhiMPlusOne := loadDataMatrix(rbfNode.FirstChild.NodeValue);

  GTMManifold.matKTrain := loadMatrix(GTMOptions.kernelTrain);
  GTMManifold.matKTest := loadMatrix(GTMOptions.kernelTest);
  GTMManifold.matKTestVTrain := loadMatrix(GTMOptions.kernelTestVTrain);

  GTMDataTest.nMolecules := high(GTMManifold.matKTest);
  GTMData.nMolecules := high(GTMManifold.matKTrain);


  write('Number of molecules in test set: ');
  writeln(GTMDataTest.nMolecules);
  write('Number of molecules in training set: ');
  writeln(GTMData.nMolecules);
  writeln;

  GTMManifold.betaInv := invBetaMatAAD[0][0];
  GTMOptions.nSamples := ROUND(high(GTMManifold.matPhiMPlusOne));
  GTMOptions.sqrtSamples := ROUND(sqrt(GTMOptions.nSamples));
  GTMModel.matX := GTMManifold.createMMatrix(GTMOptions.sqrtSamples);
  GTMModelTest.matX := GTMManifold.createMMatrix(GTMOptions.sqrtSamples);


  GTMModel.KERNELcreateDistanceMatrix(GTMManifold, GTMOptions.nSamples, GTMData.nMolecules);     //init both mat Y and matD
  GTMModelTest.KERNELcreateDistanceMatrixForProjection(GTMManifold, GTMOptions.nSamples, GTMData.nMolecules, GTMDataTest.nMolecules);     //init both mat Y and matD

  SetLength(GTMManifold.matL,0,0);
  SetLength(GTMManifold.matPhiMPlusOne,0,0);
  SetLength(GTMManifold.matKTrain,0,0);
  SetLength(GTMManifold.matKTest,0,0);
  SetLength(GTMManifold.matKTestVTrain,0,0);

  writeln('computing probabilities...');
    GTMModel.createPMatrix(GTMManifold.betaInv,
      GTMOptions.nSamples, GTMData.nMolecules, GTMOptions.nDimensions);

    GTMModelTest.createPMatrix(GTMManifold.betaInv,
      GTMOptions.nSamples, GTMDataTest.nMolecules, GTMOptions.nDimensions);

    writeln('computing responsibilities...');
    GTMModel.createRMatrix(GTMOptions.nSamples, GTMData.nMolecules);
    GTMModelTest.createRMatrix(GTMOptions.nSamples, GTMDataTest.nMolecules);

    writeln('computing likelihood...');
    if GTMOPtions.BIN = FALSE then begin
    GTMModel.computemoleculeLikelihood(GTMManifold.betaInv, GTMOptions.nDimensions,GTMOptions.nSamples, GTMData.nMolecules);
    GTMModelTest.computemoleculeLikelihood(GTMManifold.betaInv, GTMOptions.nDimensions,GTMOptions.nSamples, GTMDataTest.nMolecules);
    GTMModel.computelogLikelihood(GTMManifold.betaInv,GTMOptions.nDimensions,GTMOptions.nSamples, GTMData.nMolecules);
    GTMModelTest.computelogLikelihood(GTMManifold.betaInv,GTMOptions.nDimensions,GTMOptions.nSamples, GTMDataTest.nMolecules);
     end else begin
    GTMModel.computemoleculeLikelihoodClassical(GTMOptions.nDimensions,GTMOptions.nSamples, GTMData.nMolecules);
    GTMModelTest.computemoleculeLikelihoodClassical(GTMOptions.nDimensions,GTMOptions.nSamples, GTMDataTest.nMolecules);
    GTMModel.computelogLikelihoodClassical(GTMOptions.nDimensions,GTMOptions.nSamples, GTMData.nMolecules);
    GTMModelTest.computelogLikelihoodClassical(GTMOptions.nDimensions,GTMOptions.nSamples, GTMDataTest.nMolecules);
     end;


    writeln('writing vectors to file...');
    writeVectorToFile(GTMModel.moleculeLikelihood, GTMOptions.outputfile +
      '_moleculeLoglikelihoodTrain.txt',
      'log likelihood for each molecule');
        writeVectorToFile(GTMModelTest.moleculeLikelihood, GTMOptions.outputfile +
      '_moleculeLoglikelihoodTest.txt',
      'log likelihood for each molecule');
    writeln('computing means and modes...');
   GTMModel.compute2DCoordinates(GTMOptions.nSamples, GTMData.nMolecules);

   // DisplayMatrix(GTMModel.matMeans);
   GTMModelTest.compute2DCoordinates(GTMOptions.nSamples, GTMDataTest.nMolecules);

  //  Writeln;
  // writeln('writing files...');
   // GTMModel.writeGTMModel(GTMOptions);
   // GTMModelTest.writeGTMModel(GTMOptions);
    writeln;
    Writeln('Log Likelihood of training set: ' + FloatToStr(GTMModel.logLikelihood));
    Writeln('Log Likelihood of external test set: ' + FloatToStr(GTMModelTest.logLikelihood));



   if (GTMOptions.classify) then begin
    GTMDataTest.ClassModel.makeSimplePrediction(GTMData.nMolecules, GTMDataTest.nMolecules, GTMOptions.nSamples, GTMModel.matR, GTMModelTest.matR, GTMModelTest.matMeans, GTMModel.matX,GTMOptions.outputfile);
    writeln;
    Writeln('Pred. activity: ' + outputFile + '_external_predictedActivity.txt');
    Writeln('Confidence: ' + outputFile + '_external_confidence.txt');
    Writeln;
    Writeln('Predicted activity :');
    DisplayVectorAsIntVector(GTMDataTest.ClassModel.predictedActivity);
    Writeln;
    Writeln;
   end else begin
    GTMDataTest.Regmodel.makeSimplePrediction(GTMData.nMolecules, GTMDataTest.nMolecules, GTMOptions.nSamples, GTMModel.matR, GTMModelTest.matR, GTMModel.matX, GTMModel.matMeans, GTMModelTest.matMeans);
    writeln;
    Writeln('Pred. activity: ' + outputFile + '_external_predictedActivityGlobalMethod.txt');
    writeln;
    Writeln('Predicted activity :');
    DisplayVectorWithPrecision(GTMDataTest.RegModel.activityPredGlobalActivityLandscape,'0.000000');
    WriteVectorToFile(GTMDataTest.RegModel.activityPredGlobalActivityLandscape, outputFile + '_external_predictedActivityGlobalMethod.txt', 'external test set prediction');
    WriteVectorToFile(GTMDataTest.RegModel.activityPredLocalActivityLandscape, outputFile + '_external_predictedActivityLocalMethod.txt', 'external test set prediction');
    WriteVectorToFile(GTMDataTest.RegModel.activityPredkNN, outputFile + '_external_predictedActivitykNNMethod.txt', 'external test set prediction');
    WriteVectorToFile(GTMDataTest.RegModel.activityModel, outputFile + '_activityLandscape.txt', 'training set activity landscape');
    Writeln;
    Writeln;
   end;

  FreeAndNil(GTMManifold); /////////////////////////////////////////////////////
  FreeAndNil(GTMModel); /////////////////////////////////////////////////////
  FreeAndNil(GTMModelTest); /////////////////////////////////////////////////////

end;





(*******************************PERFORM PROJECTION*****************************)
procedure DISSIMILARITYperformSimplePrediction(var GTMData, GTMDataTest: RGTMData; var GTMOptions: RGTMOptions);
var
  i, j: integer;
  Doc: TXMLDocument;/////////////////////////////////////////////////////
  InverseBetaNode, MappingMatrixNode, rbfNode, kernelNode: TDOMNode;
  /////////////////////////////////////////////////////
  invBetaMatAAD: AAD;/////////////////////////////////////////////////////
  GTMManifold: RGTMManifold; /////////////////////////////////////////////////////
  GTMModel: RGTMModel;/////////////////////////////////////////////////////
  GTMModelTest: RGTMModel;/////////////////////////////////////////////////////
  outputFile: String;
begin

  outputFile := GTMOptions.outputFile;
  GTMManifold := RGTMManifold.Create;
  GTMModel := RGTMModel.Create;
  GTMModelTest := RGTMModel.Create;

  //Doc := TXMLDocument.Create;
  //InverseBetaNode := TDOMNode.Create(Doc);
  //MappingMatrixNode := TDOMNode.Create(Doc);


  GTMOptions.evaldistances := False;

  writeln('reading xml file...');
  ReadXMLFile(Doc, GTMOptions.projectionFile);

  InverseBetaNode := Doc.DocumentElement.FindNode('inverseBeta');
  MappingMatrixNode := Doc.DocumentElement.FindNode('mappingMatrix');
  rbfNode := Doc.DocumentElement.FindNode('rbf');

  GTMManifold.matL := loadDataMatrix(MappingMatrixNode.FirstChild.NodeValue);
  invBetaMatAAD := loadData(inverseBetaNode.FirstChild.NodeValue);
  GTMManifold.matPhiMPlusOne := loadDataMatrix(rbfNode.FirstChild.NodeValue);

  GTMManifold.matDissimilarityTrain := loadMatrix(GTMOptions.dissimilarityTrain);
  GTMManifold.matDissimilarityTestVTrain := loadMatrix(GTMOptions.dissimilarityTestVTrain);

  GTMData.nMolecules := high(GTMManifold.matKTrain);
  GTMDataTest.nMolecules := high(GTMManifold.matDissimilarityTestVTrain);

  write('Number of molecules in test set: ');
  writeln(GTMDataTest.nMolecules);
  write('Number of molecules in training set: ');
  writeln(GTMData.nMolecules);
  writeln;

  GTMManifold.betaInv := invBetaMatAAD[0][0];
  GTMOptions.nSamples := ROUND(high(GTMManifold.matPhiMPlusOne));
  GTMOptions.sqrtSamples := ROUND(sqrt(GTMOptions.nSamples));
  GTMModel.matX := GTMManifold.createMMatrix(GTMOptions.sqrtSamples);
  GTMModelTest.matX := GTMManifold.createMMatrix(GTMOptions.sqrtSamples);


  GTMModel.DissimilaritycreateDistanceMatrix(GTMManifold, GTMOptions.nSamples, GTMData.nMolecules, GTMOptions.randomize);     //init both mat Y and matD
  GTMModelTest.DissimilaritycreateDistanceMatrixForProjection(GTMManifold, GTMOptions.nSamples, GTMData.nMolecules, GTMDataTest.nMolecules, GTMOptions.randomize);     //init both mat Y and matD

  SetLength(GTMManifold.matL,0,0);
  SetLength(GTMManifold.matPhiMPlusOne,0,0);
  SetLength(GTMManifold.matDissimilarityTrain,0,0);
  SetLength(GTMManifold.matDissimilarityTestVTrain,0,0);

  writeln('computing probabilities...');
    GTMModel.createPMatrix(GTMManifold.betaInv,
      GTMOptions.nSamples, GTMData.nMolecules, GTMOptions.nDimensions);

    GTMModelTest.createPMatrix(GTMManifold.betaInv,
      GTMOptions.nSamples, GTMDataTest.nMolecules, GTMOptions.nDimensions);

    writeln('computing responsibilities...');
    GTMModel.createRMatrix(GTMOptions.nSamples, GTMData.nMolecules);
    GTMModelTest.createRMatrix(GTMOptions.nSamples, GTMDataTest.nMolecules);

    writeln('computing likelihood...');

    if GTMOptions.BIN = FALSE then begin
    GTMModel.computemoleculeLikelihood(GTMManifold.betaInv, GTMOptions.nDimensions,GTMOptions.nSamples, GTMData.nMolecules);
    GTMModelTest.computemoleculeLikelihood(GTMManifold.betaInv, GTMOptions.nDimensions,GTMOptions.nSamples, GTMDataTest.nMolecules);
    GTMModel.computelogLikelihood(GTMManifold.betaInv,GTMOptions.nDimensions,GTMOptions.nSamples, GTMData.nMolecules);
    GTMModelTest.computelogLikelihood(GTMManifold.betaInv,GTMOptions.nDimensions,GTMOptions.nSamples, GTMDataTest.nMolecules);
     end else begin
     GTMModel.computemoleculeLikelihoodClassical(GTMOptions.nDimensions,GTMOptions.nSamples, GTMData.nMolecules);
    GTMModelTest.computemoleculeLikelihoodClassical(GTMOptions.nDimensions,GTMOptions.nSamples, GTMDataTest.nMolecules);
    GTMModel.computelogLikelihoodClassical(GTMOptions.nDimensions,GTMOptions.nSamples, GTMData.nMolecules);
    GTMModelTest.computelogLikelihoodClassical(GTMOptions.nDimensions,GTMOptions.nSamples, GTMDataTest.nMolecules);
     end;


    writeln('writing vectors to file...');
    writeVectorToFile(GTMModel.moleculeLikelihood, GTMOptions.outputfile +
      '_moleculeLoglikelihoodTrain.txt',
      'log likelihood for each molecule');
        writeVectorToFile(GTMModelTest.moleculeLikelihood, GTMOptions.outputfile +
      '_moleculeLoglikelihoodTest.txt',
      'log likelihood for each molecule');
    writeln('computing means and modes...');
   GTMModel.compute2DCoordinates(GTMOptions.nSamples, GTMData.nMolecules);

   // DisplayMatrix(GTMModel.matMeans);
   GTMModelTest.compute2DCoordinates(GTMOptions.nSamples, GTMDataTest.nMolecules);

  //  Writeln;
  // writeln('writing files...');
   // GTMModel.writeGTMModel(GTMOptions);
   // GTMModelTest.writeGTMModel(GTMOptions);
    writeln;
    Writeln('Log Likelihood of training set: ' + FloatToStr(GTMModel.logLikelihood));
    Writeln('Log Likelihood of external test set: ' + FloatToStr(GTMModelTest.logLikelihood));



   if (GTMOptions.classify) then begin
    GTMDataTest.ClassModel.makeSimplePrediction(GTMData.nMolecules, GTMDataTest.nMolecules, GTMOptions.nSamples, GTMModel.matR, GTMModelTest.matR, GTMModelTest.matMeans, GTMModel.matX,GTMOptions.outputfile);
    writeln;
    Writeln('Pred. activity: ' + outputFile + '_external_predictedActivity.txt');
    Writeln('Confidence: ' + outputFile + '_external_confidence.txt');
    Writeln;
    Writeln('Predicted activity :');
    DisplayVectorAsIntVector(GTMDataTest.ClassModel.predictedActivity);
    Writeln;
    Writeln;
   end else begin
    GTMDataTest.Regmodel.makeSimplePrediction(GTMData.nMolecules, GTMDataTest.nMolecules, GTMOptions.nSamples, GTMModel.matR, GTMModelTest.matR, GTMModel.matX, GTMModel.matMeans, GTMModelTest.matMeans);
    writeln;
    Writeln('Pred. activity: ' + outputFile + '_external_predictedActivityGlobalMethod.txt');
    writeln;
    Writeln('Predicted activity :');
    DisplayVectorWithPrecision(GTMDataTest.RegModel.activityPredGlobalActivityLandscape,'0.000000');
    WriteVectorToFile(GTMDataTest.RegModel.activityPredGlobalActivityLandscape, outputFile + '_external_predictedActivityGlobalMethod.txt', 'external test set prediction');
    WriteVectorToFile(GTMDataTest.RegModel.activityPredLocalActivityLandscape, outputFile + '_external_predictedActivityLocalMethod.txt', 'external test set prediction');
    WriteVectorToFile(GTMDataTest.RegModel.activityPredkNN, outputFile + '_external_predictedActivitykNNMethod.txt', 'external test set prediction');
    WriteVectorToFile(GTMDataTest.RegModel.activityModel, outputFile + '_activityLandscape.txt', 'training set activity landscape');
    Writeln;
    Writeln;
   end;

  FreeAndNil(GTMManifold); /////////////////////////////////////////////////////
  FreeAndNil(GTMModel); /////////////////////////////////////////////////////
  FreeAndNil(GTMModelTest); /////////////////////////////////////////////////////

end;





function makesIndices(nFolds, numInfold, numInLastFold: integer): TVector;
var
  step, i, j: integer;
begin
  //writeln;
  //writeln;
  step := 0;
  DimVector(Result, (numInfold * (nFolds - 1) + numInLastFold));

  for i := 1 to nFolds - 1 do
  begin
    for j := 0 to numInfold - 1 do
    begin
      Result[j + step] := i;
    end;
    step += numInFold;
    //  writeln('Fold ' + IntToStr(i) + ' : ' + IntToStr(numInFold) + ' molecules');
  end;

  // Write('Fold ' + IntToStr(nFolds) + ' : ' + IntToStr(numInLastFold) + ' molecules');
  for j := 0 to numInLastFold - 1 do
  begin
    Result[j + step] := nFolds;
  end;

  //writeln;
  //writeln;

end;


(*********************************PERFORM CROSS-VALIDATION*********************)
function performCrossValidation(var GTMData: RGTMData;
  var GTMoptions: RGTMOptions): TVector;
var
  matMeans: AOM; /////////////////////////////////////////////////////
  filename: string; /////////////////////////////////////////////////////
  i, j, k, w: integer;
  nodes: AOS;/////////////////////////////////////////////////////
  arrayofMatrices: AOM;/////////////////////////////////////////////////////
  indices: TVector;/////////////////////////////////////////////////////
  arrayOfIndices: TMatrix; /////////////////////////////////////////////////////
  Count, CountTest: integer;
  matLikelihood: TMatrix;/////////////////////////////////////////////////////
  numInFold, numInLastFold: integer;
  GTMManifold: RGTMManifold;/////////////////////////////////////////////////////
  GTMDataTest, GTMDataTrain: RGTMData;
  /////////////////////////////////////////////////////
  GTMModelTest, GTMModelTrain: RGTMModel;
  /////////////////////////////////////////////////////
  iteract: Integer;
  totMoleculesInApplicabilityDomain : TBoolVector;
  totactInitialSpace : TVector;
  totActLatentSpaceBayes: TVector;
  totActLatentSpaceNearestNode: TVector;
  totProbInitialSPace: TMatrix;
  totProbLatentSpaceBayes: TMatrix;
  totProbLatentSpaceNearestNode: TMatrix;
  keepMatT: TMatrix;
  keepActivities:TVector;
  meanDeterminationGlobal, meanFScore:Float;
  conserveOutput: String;
begin

  conserveOutput := GTMOptions.outputfile;
  keepMatT := matrixCopy(GTMData.matT);

  if GTMOptions.regress = TRUE then begin
   keepActivities := vectorCopy(GTMData.RegModel.activities);
  meanDeterminationGlobal := 0.0;


  end else if GTMOptions.classify = TRUE then begin
    keepActivities := vectorCopy(GTMData.ClassModel.activities);
    meanFScore := 0.0;
  end;

  //shortcut for output file
  filename := GTMOptions.outputFile;

  // matLikelihood will contain train/test likelihood of all folds
  DimMatrix(matLikelihood, GTMOptions.nfolds, 2);

  //init Result (mean of all train and test scores)
  DimVector(Result, 2);

  //means contain the concatenated coordinates of all (projected) test molecules
  SetLength(MatMeans, GTMOptions.nfolds);

  // never compute manifold or solid angles (too long for cross-validation)
  GTMOptions.computeManifold := False;
  GTMOptions.evalSolidAngles := False;

  //number of molecules in each fold
  numInFold := TRUNC(GTMData.nMolecules / GTMOptions.nFolds);
  numInLastFold := numInFold + (GTMData.nMolecules mod GTMOptions.nFolds);

  // reassign number of molecules if the last fold is too big
  while numInLastFold > (numInFold * 3 / 2) do
  begin
    numInFold := TRUNC(GTMData.nMolecules / GTMOptions.nFolds);
    numInLastFold := (GTMData.nMolecules mod GTMOptions.nFolds);
    GTMOptions.nFolds := GTMOptions.nFolds + 1;
    DimMatrix(matLikelihood, GTMOptions.nfolds, 2);
    SetLength(MatMeans, GTMOptions.nfolds);
  end;

  // shuffle initial data (will be written only if it's not batch)
 if ((GTMOptions.Classify = FALSE) and (GTMOptions.regress = FALSE)) then GTMData.matT := shuffleSVM(GTMOptions.outputfile, GTMData.matT,
    GTMData.nMolecules, GTMOptions.nDimensions, GTMOptions.seed, GTMOptions.writeMe) else if GTMOptions.classify then
     GTMData.matT := shuffleSVMAndActivities(GTMOptions.outputFile, GTMData.matT,
    GTMData.nMolecules, GTMOptions.nDimensions, GTMData.ClassModel.activities, GTMOptions.seed, GTMOptions.writeMe) else if GTMOptions.regress then
       GTMData.matT := shuffleSVMAndActivities(GTMOptions.outputFile, GTMData.matT,
    GTMData.nMolecules, GTMOptions.nDimensions, GTMData.RegModel.activities, GTMOptions.seed, GTMOptions.writeMe);

  // distribute fold indices
  indices := makesIndices(GTMOptions.nFolds, numInfold, numInLastFold);

  //if not batch, write indices to file
  if GTMOptions.writeMe = True then
  begin
    writeVectorToFile(indices, filename + '_foldIndices' + '.txt', 'indices');
  end;


 iterAct := 0;
  {"""""""""""""""""""""""""""""""""""}
  for k := 1 to GTMOptions.nFolds do
  begin { begin fold iteration }

    // create one MANIFOLD object, DATATEST, DATATRAIN, MODELTEST, MODELTRAIN
    GTMManifold := RGTMManifold.Create;
    GTMDataTest := RGTMData.Create;
    GTMDataTrain := RGTMData.Create;
    GTMModelTest := RGTMModel.Create;
    GTMModelTrain := RGTMModel.Create;
    Count := 0;
    countTest := 0;

    // training matrix : fill DATATRAIN
    for i := 0 to GTMData.nMolecules - 1 do
    begin
      // if the data is not in fold k, take it
      if indices[i] <> k then
      begin
        DimMatrix(GTMDataTrain.matT, Count + 1, GTMOptions.nDimensions);
        for j := 0 to GTMOptions.nDimensions - 1 do
        begin
          GTMDataTrain.matT[Count][j] := GTMData.matT[i][j];
        end;
        Count += 1;
      end;
    end;

    //test Matrix : fill DATATEST
    for i := 0 to GTMData.nMolecules - 1 do
    begin
      // if the data is in fold k, take it
      if indices[i] = k then
      begin
        DimMatrix(GTMDataTest.matT, countTest + 1, GTMOptions.nDimensions);
        for j := 0 to GTMOptions.nDimensions - 1 do
        begin
          GTMDataTest.matT[countTest][j] := GTMData.MatT[i][j];
        end;
        countTest += 1;
      end;
    end;


    // write number of molecules in each fold only if it's not batch
    if GTMOptions.writeMe = True then
    begin
      Writeln;
      Writeln;
      writeln('Fold ' + IntToStr(k) + ' : Training Set : ' + IntToStr(Count) +
        ' molecules; Test set : ' + IntToStr(GTMData.nMolecules - Count) +
        ' molecules');
    end;

    // let GTMMODELTRAIN and GTMMODELTEST know how many molecules they have
    GTMDataTrain.nMolecules := Count;
    GTMDataTest.nMolecules := countTest;

    // compute matT column means
    GTMDataTrain.initDataFromT;
    GTMDataTest.initDataFromT;

    // init GTM with training data, fill MANIFOLD and MODELTRAIN
    GTMManifold.initManifold(GTMOptions, GTMDataTrain);
    GTMModelTest.initModel(GTMOptions, GTMDataTest, GTMManifold);
    GTMModelTrain.initModel(GTMOptions, GTMDataTrain, GTMManifold);

    // register fold number to use with projectMatrix() function
    GTMOptions.foldIter := k;

    // train GTM with training data (EM alg) and project test data
    GTMModelTest.matR := projectMatrix(GTMDataTrain, GTMDataTest,
      GTMManifold, GTMModelTrain, GTMModelTest, GTMOptions, matLikelihood);


    GTMModelTrain.compute2DCoordinates(GTMOptions.nSamples, GTMDataTest.nMolecules);
    GTMModelTest.compute2DCoordinates(GTMOptions.nSamples, GTMDataTest.nMolecules);

    GTMModelTrain.computeMoleculeLikelihood(GTMManifold.betaInv, GTMOptions.nDimensions,GTMOptions.nSamples, GTMDataTrain.nMolecules);


    if GTMOptions.doBatch = FALSE then begin
     WriteVectorToFile(GTMModelTest.moleculeLikelihood,  GTMOptions.outputFile+'_fold'+IntToStr(k)+'_moleculeLikelihood_test.txt', 'test molecules likelihood');
     WriteVectorToFile(GTMModelTrain.moleculeLikelihood,  GTMOptions.outputFile+'_fold'+IntToStr(k)+'_moleculeLikelihood_train.txt', 'train molecules likelihood');
     writeSVMMatrixToFile(GTMDataTest.matT, GTMOptions.outputFile+'_fold'+IntToStr(k)+'_test'+'.svm');
     writeSVMMatrixToFile(GTMDataTrain.matT, GTMOptions.outputFile+'_fold'+IntToStr(k)+'_train'+'.svm');
    end;



    if GTMoptions.classify then begin

      dimVector(totactInitialSpace, GTMDatatest.nMolecules);
    dimVector(totactLatentSpaceBayes, GTMDatatest.nMolecules);
    dimVector(totactLatentSpaceNearestNode, GTMDatatest.nMolecules);
    dimBoolVector(totMoleculesInApplicabilityDomain, GTMDatatest.nMolecules);
    dimMatrix(totProbInitialSpace, GTMDatatest.nMolecules, GTMData.ClassModel.numberOfClasses);
    dimMatrix(totProbLatentSpaceNearestNode, GTMDatatest.nMolecules, GTMData.ClassModel.numberOfClasses);
    dimMatrix(totProbLatentSpaceBayes, GTMDatatest.nMolecules, GTMData.ClassModel.numberOfClasses);

     GTMData.classModel.fillAllCVPredictions(totMoleculesInApplicabilityDomain,
     totActInitialSpace, totActLatentSpaceBayes, totActLatentSpaceNearestNode,
     totProbInitialSpace, totProbLatentSpaceBayes, totProbLatentSpaceNearestNode,
     indices, k, 0, GTMDataTrain.nMolecules, GTMDataTest.nMolecules, GTMOptions.nSamples,
     GTMModelTrain.matR, GTMModelTest.matR, GTMModelTest.matMeans, GTMModelTrain.matX, GTMModelTrain.matP,
     GTMModelTest.matP, GTMModelTrain.moleculelikelihood, GTMModelTest.moleculeLikelihood);

     GTMData.ClassModel.makeAllCVPredictions(GTMOptions.doBatch, GTMDataTest.nMolecules,
     totMoleculesInApplicabilityDomain, totActInitialSpace, totActLatentSpaceBayes,
       totActLatentSpaceNearestNode, totProbInitialSpace, totProbLatentSpaceBayes, totProbLatentSpaceNearestNode,
       GTMOptions.outputFile+'_fold'+IntToStr(k));


       GTMData.classModel.nMoleculesTestInCPFApplicabilityDomain := 0;
       GTMData.classModel.nMoleculesTestInLPFApplicabilityDomain := 0;

       meanFScore += GTMData.classModel.FScore;


    end else if GTMOptions.regress then begin

       GTMData.RegModel.makeCrossVal(GTMDataTrain.nMolecules, GTMDataTest.nMolecules,GTMOptions.nSamples,k,
       GTMModelTrain.matR, GTMModelTest.matR, GTMModelTrain.matMeans, GTMModelTest.matMeans, GTMManifold.matX, indices);

      meanDeterminationGlobal += GTMData.regModel.determinationGlobal;
      WriteVectorToFile(GTMData.RegModel.activityPredGlobalActivityLandscape, GTMOptions.outputFile + '_fold'+IntToStr(k) + '_'+ 'predictedActivityGlobalMethod.txt', 'predicted activity');
      WriteVectorToFile(GTMData.RegModel.activityTest, GTMOptions.outputFile + '_fold'+IntToStr(k) + '_'+ 'testActivity.txt', 'actual activity');
      WriteVectorToFile(GTMData.RegModel.activityTrain, GTMOptions.outputFile + '_fold'+IntToStr(k) + '_'+ 'trainActivity.txt', 'actual activity');
      WriteVectorToFile(GTMData.RegModel.activityPredLocalActivityLandscape, GTMOptions.outputFile + '_fold'+IntToStr(k) + '_'+ 'predictedActivityLocalMethod.txt', 'predicted activity');
      WriteVectorToFile(GTMData.RegModel.activityPredkNN, GTMOptions.outputFile + '_fold'+IntToStr(k) + '_'+ 'predictedActivitykNNMethod.txt', 'predicted activity');



    end;




           if GTMOptions.doBatch = False then begin
          if (GTMOptions.classify) then begin
          writeln;
        for w:=0 to GTMData.ClassModel.numberOfClasses-1 do
        Writeln('Fold ' + IntToStr(k) + ' FScore class '+ IntToStr(w+1) + ': ' + FloatToStr(GTMData.ClassModel.FScorePerClass[w]));
        Writeln('Fold ' + IntToStr(k) + ' Average: ' + FloatToStr(GTMData.ClassModel.FScore));
        writeln;  end else if (GTMOptions.regress) then begin
        writeln;
           Writeln('Fold ' + IntToStr(k) + ' R squared: ' + FloatToStr(GTMData.RegModel.determinationGlobal));
          end;
        end;



  // sensitivity += GTMData.ClassModel.sensitivity;

      if GTMOptions.WriteMe = True then
      matMeans[k - 1] := GTMModelTest.matMeans;

      if(GTMOptions.doBatch = FALSE) then
      begin
      GTMOptions.outputfile := conserveOutput+'_train_'+IntToStr(k);
      GTMModelTrain.writeGTMModel(GTMOptions);
      GTMOptions.outputfile := conserveOutput+'_test_'+IntToStr(k);
      GTMModelTest.writeGTMModel(GTMOptions);
      GTMOptions.outputfile := conserveOutput;
      end;

      iterAct += GTMDataTest.nMolecules;
    // train/test garbage
    FreeAndNil(GTMModelTrain); /////////////////////////////////////////////////////
    FreeAndNil(GTMModelTest); /////////////////////////////////////////////////////
    FreeAndNil(GTMManifold); /////////////////////////////////////////////////////
    FreeAndNil(GTMDataTest); /////////////////////////////////////////////////////
    FreeAndNil(GTMDataTrain); /////////////////////////////////////////////////////
   end;  { end fold iteration }



  {"""""""""""""""""""""""""""""""""""}


  // write matMeans and scores only if it's not batch
  if GTMOptions.writeMe = True then { begin condition }
  begin
    writeMatrixToFile(matLikelihood, filename + '_trainTestLikelihood.txt',
      'likelihood of train (col 1) and test (col 2) sets');

    setlength(nodes, GTMOptions.nfolds + 1);
    setLength(arrayOfMatrices, GTMOptions.nfolds + 1);
    DimMatrix(arrayOfIndices, GTMData.nMolecules, 1);
    for i := 2 to GTMOptions.nfolds + 1 do
    begin
      nodes[i - 1] := 'means_fold' + IntToStr(i - 1);
      arrayOfMatrices[i - 1] := matMeans[i - 2];
    end;
    for i := 0 to GTMData.nMolecules - 1 do
      arrayOfIndices[i][0] := indices[i];
    nodes[0] := 'moleculeFoldIndices';
    arrayOfMatrices[0] := arrayOfIndices;
    writeMatricesToXML(GTMOptions.outputfile + '_allFolds_means' + '.xml',
      arrayOfMatrices, 'gtmmeans', nodes);
  end; { end condition }


  Result[0] := VectorMean(matrixTranspose(matLikelihood)[0]);
  Result[1] := VectorMean(matrixTranspose(matLikelihood)[1]);


  GTMData.matT := matrixCopy(keepMatT);
  setLength(keepMatT, 0, 0);

  if GTMOptions.classify=TRUE then begin

  GTMData.classModel.allDet;

  writeVectorToFile(GTMData.ClassModel.activities, filename+'_shuffAllAct' + '.txt', 'shuffled activities');
  writeVectorToFile(GTMData.ClassModel.allLatent, filename+'_shuffAllPredLatent' + '.txt', 'predicted activities');
  GTMData.classModel.activities := vectorCopy(keepActivities);
  setLength(keepActivities,0);
  GTMData.ClassModel.meanFScore := 0.0;
  GTMData.ClassModel.meanFScore := meanFScore/GTMOptions.nFolds;

  end else if GTMOptions.regress then begin
  writeVectorToFile(GTMData.RegModel.activities, filename+'_shuffAllAct' + '.txt', 'shuffled activities');
  writeVectorToFile(GTMData.RegModel.allGlobal, filename+'_shuffAllPredGlobal' + '.txt', 'predicted activities');
  GTMData.RegModel.nMoleculesTot := GTMData.nMolecules;
  GTMData.RegModel.allDet;
  GTMData.regModel.activities := vectorCopy(keepActivities);
  setLength(keepActivities,0);
      GTMData.RegModel.MeandeterminationGlobal := 0.0;
    GTMData.RegModel.MeandeterminationGlobal := meanDeterminationGlobal/GTMOptions.nFolds;
    GTMData.RegModel.pClear;
  end ;


  if GTMOptions.doBatch = FALSE then begin


  writeln;
  writeln('Cross-validation results');
  writeln('*************************************');
  write('SCORE TRAIN:' + #9); Writeln(FormatFloat('0.000000000', Result[0]));
  write('SCORE TEST:' + #9); Writeln(FormatFloat('0.000000000', Result[1]));


  if GTMOptions.Classify then begin write('AVERAGED FSCORE ( % ):' + #9 + FormatFloat('0.000000000', GTMData.classModel.meanFScore*100)); writeln; end;
  if GTMOptions.regress then  begin write('AVERAGED R2  ( % ):' + #9 + FormatFloat('0.000000000', GTMData.RegModel.meanDeterminationGlobal*100)); writeln; end;



  writeln('*************************************');
  Writeln;
  if(GTMOptions.regress = TRUE) then GTMData.RegModel.printAllDet;
  if(GTMOptions.classify = TRUE) then GTMData.ClassModel.printAllDet;




 // write('InvDelta:'); Writeln(FormatFloat('0.0000', (Result[0]/(Result[0]-Result[1]))));
 // write('ScorePlusDelta:'); Writeln(FormatFloat('0.0000', Result[1]+(Result[0]/(Result[0]-Result[1]))));
  end;

  // garbage
  SetLength(matMeans, 0);/////////////////////////////////////////////////////
  filename := '';   /////////////////////////////////////////////////////
  SetLength(nodes, 0); /////////////////////////////////////////////////////
  setLength(arrayOfMatrices, 0); /////////////////////////////////////////////////////
  setLength(indices, 0); /////////////////////////////////////////////////////
  setLength(matLikelihood, 0, 0); /////////////////////////////////////////////////////
  setLength(arrayOfIndices, 0, 0); /////////////////////////////////////////////////////
  setLength(totProbInitialSpace, 0, 0);
  setLength(totActInitialSpace, 0);
  setLength(totProbLatentSpaceBayes, 0, 0);
  setLength(totActLatentSpaceBayes, 0);
  setLength(totProbLatentSpaceNearestNode, 0, 0);
  setLength(totActLatentSpaceNearestNode, 0);
  GTMData.ClassModel.pClear;
end;


(**************SELECTION OF PARAMETERS BY CROSS VALIDATION*********************)
procedure batchCrossValidation(var GTMData: RGTMData; var GTMoptions: RGTMOptions);
var
  k: integer;
  parameters, params,parameters2,provisoire: string;/////////////////////////////////////////////////////
  retainValue, retainValue2: Float;
  trainTestLikelihood: TVector; /////////////////////////////////////////////////////
  numInFold, numInlastFold: integer;
begin
  GTMOptions.writeMe := False;
  GTMOptions.sigma := StrToFloat(GTMOptions.lbatchW.Strings[0]);
  GTMOptions.alpha := Power(10, StrToFloat(GTMOptions.lbatchL.Strings[0]));
  GTMOptions.sqrtSamples := StrToInt(GTMOptions.lbatchK.Strings[0]);
  GTMOptions.sqrtCenters := StrToInt(GTMOptions.lbatchM.Strings[0]);
  GTMOptions.nSamples := GTMOptions.sqrtSamples * GTMOptions.sqrtSamples;
  GTMOptions.nCenters := GTMOptions.sqrtCenters * GTMOptions.sqrtCenters;
  RetainValue := -maxNum;
  RetainValue2 := -maxNum;

  numInFold := TRUNC(GTMData.nMolecules / GTMOptions.nFolds);
  numInLastFold := numInFold + (GTMData.nMolecules mod GTMOptions.nFolds);

  while numInLastFold > (numInFold * 3 / 2) do
  begin
    numInFold := TRUNC(GTMData.nMolecules / GTMOptions.nFolds);
    numInLastFold := (GTMData.nMolecules mod GTMOptions.nFolds);
    GTMOptions.nFolds := GTMOptions.nFolds + 1;
  end;

  for k := 1 to GTMOptions.nFolds - 1 do
    writeln('Fold ' + IntToStr(k) + ': ' + IntToStr(numInfold) + ' molecules');
  Writeln('Fold ' + IntToStr(GTMOptions.nFolds) + ': ' + IntToStr(numInLastFold) +
    ' molecules');
  writeln;


  Write('nodes' + #9 + 'rbf' + #9 + 'width' + #9 + 'alpha' + #9 +
    'score train' + #9 + 'score test');
  if GTMOptions.Classify then write(#9 + 'FScore-Bayes(%)'+ #9 + 'BAC-Bayes(%)'+#9 + 'FScore-kNNode(%)'+ #9 + 'BAC-kNNode(%)') else if GTMOptions.Regress then
  write(
  #9 + 'R2-Global(%)'+ #9 + 'R2-Local(%)' + #9 + 'R2-kNN(%)'+ #9 + 'R2-kNNResp(%)' +
  #9 + 'RMSE-Global'+ #9 + 'RMSE-Local' + #9 + 'RMSE-kNN'+ #9 + 'RMSE-kNNResp');
  writeln;

  while GTMOptions.sqrtSamples <= StrToInt(GTMOptions.lbatchK.Strings[2]) do
  begin
    while GTMOptions.sqrtCenters <= StrToInt(GTMOptions.lbatchM.Strings[2]) do
    begin
      while GTMOptions.sigma <= StrToFloat(GTMOptions.lbatchW.Strings[2]) do
      begin
        while GTMOptions.alpha <= Power(10, StrToFloat(GTMOptions.lbatchL.Strings[2]) + 1) do
        begin

          Params := IntToStr(GTMOptions.sqrtSamples) + #9 +
            IntToStr(GTMOptions.sqrtCenters) + #9 + FloatToStr(GTMOptions.sigma) +
            #9 + FloatToStr(GTMOptions.alpha);

          Write(params);
          provisoire := GTMOptions.outputFile;

          GTMOptions.outputFile :=
            GTMOptions.outputFile + '_' + IntToStr(GTMOptions.sqrtSamples) +
            '_' + IntToStr(GTMOptions.sqrtCenters) + '_' +
            FloatToStr(GTMOptions.sigma) + '_' + FloatToStr(GTMOptions.alpha);


          trainTestLikelihood := performCrossValidation(GTMData, GTMOptions);


          GTMOptions.outputFile :=provisoire;
          Write(#9 + FormatFloat('0.00000000', trainTestLikelihood[0]));
          Write(#9 + FormatFloat('0.00000000', trainTestLikelihood[1]));
         // Write(#9 + FormatFloat('0.000000000', (trainTestLikelihood[0] -
         //   trainTestLikelihood[1]) / trainTestLikelihood[0] * 100));
          if GTMOptions.Classify=TRUE then
          begin write(#9); GTMData.ClassModel.printAllDetShort;end

          else if GTMOptions.regress then
          write(#9 + FormatFloat('0.000', GTMData.RegModel.detGlobal*100)+
          #9 + FormatFloat('0.000', GTMData.RegModel.detLocal*100) +
          #9 + FormatFloat('0.000', GTMData.RegModel.detkNN*100)+
          #9 + FormatFloat('0.000', GTMData.RegModel.detkNNResp*100) +
          #9 + FormatFloat('0.000', GTMData.RegModel.rmseGlobal)+
          #9 + FormatFloat('0.000', GTMData.RegModel.rmseLocal) +
          #9 + FormatFloat('0.000', GTMData.RegModel.rmsekNN)+
          #9 + FormatFloat('0.000', GTMData.RegModel.rmsekNNResp)
          );
          Writeln;

           if GTMOptions.classify then begin
                 if RetainValue2 < GTMData.classModel.classificationObjectLatent.sensitivity then
          begin
            RetainValue2 := GTMData.classModel.classificationObjectLatent.sensitivity;
            Parameters2 := Params;
          end;
               end;

             if GTMOptions.regress then begin
                 if RetainValue2 < GTMData.RegModel.detGlobal then
          begin
            RetainValue2 := GTMData.RegModel.detGlobal;
            Parameters2 := Params;
          end;
               end;

          //writeMe := False;
          if RetainValue < trainTestLikelihood[1] then
          begin
            RetainValue := trainTestLikelihood[1];
            Parameters := Params;
          end;

          GtmOptions.alpha *= Power(10, StrToFloat(GTMOptions.lbatchL.Strings[1]));
        end;
        GTMOptions.alpha := Power(10, StrToFloat(GTMOptions.lbatchL.Strings[0]));
        GTMOptions.sigma += StrToFloat(GTMOptions.lbatchW.Strings[1]);
      end;
      GTMOptions.sigma := StrToFloat(GTMOptions.lbatchW.Strings[0]);
      GTMOptions.sqrtCenters += StrToInt(GTMOptions.lbatchM.Strings[1]);
      GTMOptions.nCenters := GTMOptions.sqrtCenters * GTMOptions.sqrtCenters;
    end;
    GTMOptions.sqrtCenters := StrToInt(GTMOptions.lbatchM.Strings[0]);
    GTMOptions.nCenters := GTMOptions.sqrtCenters * GTMOptions.sqrtCenters;
    GTMOptions.sqrtSamples += StrToInt(GTMOptions.lbatchK.Strings[1]);
    GTMOptions.nSamples := GTMOptions.sqrtSamples * GTMOptions.sqrtSamples;

  end;


  writeln;
  writeln('***************BATCH RESULTS****************');
  writeln('********************************************');
  Write('Best average test loglikelihood: ');
  writeln(#9 + FloatToStr(Retainvalue));
  writeln('Associated Parameters: ');
  writeln('#nodes' + #9 + '#rbf' + #9 + 'width' + #9 + 'alpha');
  writeln(Parameters);
  writeln('********************************************');
  writeln;
  if GTMOptions.classify or GTMOptions.regress then begin
  writeln('********************************************');
  if GTMOptions.classify then Write('Best averaged test BAC: ') else if GTMOptions.regress then  Write('Best averaged test R2: ');
  writeln(#9 + FloatToStr(Retainvalue2));
  writeln('Associated Parameters: ');
  writeln('#nodes' + #9 + '#rbf' + #9 + 'width' + #9 + 'alpha');
  writeln(Parameters2);
  writeln('********************************************');
  end;
  parameters := ''; /////////////////////////////////////////////////////
  params := ''; /////////////////////////////////////////////////////
  parameters2 := ''; /////////////////////////////////////////////////////
  setLength(trainTestLikelihood, 0);
  /////////////////////////////////////////////////////

end;

procedure computeScore(GTMData: RGTMData; GTMModel: RGTMModel; GTMOptions: RGTMOptions);
var
  j,k,n,m: Integer;
  score : TMatrix;
  scores, scores2, scores3: TIntVector;
begin
  { DimMatrix(Score, GTMOptions.nDimensions, GTMOptions.nSamples);
   DimIntVector(scores, GTMOptions.nSamples);
   DimIntVector(scores2, GTMOptions.nSamples);
   DimIntVector(scores3, GTMOptions.nSamples);
   DimIntVector(countNonZero, GTMOptions.nDimensions);
   DimBoolVector(doCount, GTMOptions.nDimensions);
   Writeln;

   for i := 0 to GTMOptions.nDimensions - 1 do
   begin
     for j := 0 to GTMData.nMolecules - 1 do
     begin
       if GTMData.matT[j][i] <> 0 then
         countNonZero[i] += 1;
     end;
   end;

   for i := 0 to GTMOptions.nDimensions - 1 do
     if countNonZero[i] / GTMData.nMolecules <= 0.1 then
        doCount[i] := FALSE else
          doCount[i] := TRUE;


 Writeln('Computing similarity score of descriptor :');
for j:=0 to GTMOptions.nDimensions-1 do begin
  write(' ' + IntToStr(j+1));
for k:=0 to GTMOptions.nSamples-1 do
   for n:=0 to GTMData.nMolecules-1 do
       for m:=0 to GTMData.nMolecules-1 do
      // if doCount[j] = TRUE then
        Score[j,k]+= GTMModel.matR[k,n]*GTMModel.matR[k,m]*(1-abs(GTMData.matT[n,j]-GTMData.matT[m,j]));
       end;

      score := matrixmaxminnorm1(Score);
        writeMatrixToFile(score, GTMOptions.outputFile+'_majSimScore.txt', 'descriptor (line) similarity score for each node (column)');
        Score := matrixTranspose(Score);

      for k:=0 to GTMOptions.nSamples-1 do
        scores[k] := findMaxIndex(score[k])+1;

      writeIntVectorToFile(scores, GTMOptions.outputFile+'_majSimDescriptors.txt', 'best similarity descriptor on each node');

      for k:=0 to GTMOptions.nSamples-1 do
        scores2[k] := findMaxIndex2(score[k])+1;

      writeIntVectorToFile(scores2, GTMOptions.outputFile+'_majSimDescriptors2.txt', 'second best similarity descriptor on each node');


         for k:=0 to GTMOptions.nSamples-1 do
        scores3[k] := findMaxIndex3(score[k])+1;

      writeIntVectorToFile(scores3, GTMOptions.outputFile+'_majSimDescriptors3.txt', 'third best similarity descriptor on each node');


       SetLength(Score, 0, 0);
  setLength(scores2,0);
  setLength(scores,0);
  setLength(scores3,0);   }

  DimMatrix(Score, GTMOptions.nDimensions, GTMOptions.nSamples);
   DimIntVector(scores, GTMOptions.nSamples);
   DimIntVector(scores2, GTMOptions.nSamples);
   DimIntVector(scores3, GTMOptions.nSamples);
Writeln;
Writeln('HighDesc :');
for j:=0 to GTMOptions.nDimensions-1 do begin
  write(' ' + IntToStr(j+1));
for k:=0 to GTMOptions.nSamples-1 do
   for n:=0 to GTMData.nMolecules-1 do
      // if doCount[j] = TRUE then
        Score[j,k]+= GTMModel.matR[k,n]*(GTMData.matT[n,j]);
       end;


score := matrixmaxminnorm1(Score);
        writeMatrixToFile(score, GTMOptions.outputFile+'_majScore.txt', 'descriptor (line) score for each node (column)');
        Score := matrixTranspose(Score);

      for k:=0 to GTMOptions.nSamples-1 do
        scores[k] := findMaxIndex(score[k])+1;

      writeIntVectorToFile(scores, GTMOptions.outputFile+'_majDescriptors.txt', 'major descriptor on each node');

      for k:=0 to GTMOptions.nSamples-1 do
        scores2[k] := findMaxIndex2(score[k])+1;

      writeIntVectorToFile(scores2, GTMOptions.outputFile+'_majDescriptors2.txt', 'major descriptor on each node');

         for k:=0 to GTMOptions.nSamples-1 do
        scores3[k] := findMaxIndex3(score[k])+1;

      writeIntVectorToFile(scores3, GTMOptions.outputFile+'_majDescriptors3.txt', 'major descriptor on each node');

      SetLength(Score, 0, 0);
  setLength(scores2,0);
  setLength(scores,0);
  setLength(scores3,0);

    DimMatrix(Score, GTMOptions.nDimensions, GTMOptions.nSamples);
   DimIntVector(scores, GTMOptions.nSamples);
   DimIntVector(scores2, GTMOptions.nSamples);
   DimIntVector(scores3, GTMOptions.nSamples);


Writeln;
Writeln('LowDesc :');
for j:=0 to GTMOptions.nDimensions-1 do begin
  write(' ' + IntToStr(j+1));
for k:=0 to GTMOptions.nSamples-1 do
   for n:=0 to GTMData.nMolecules-1 do
      // if doCount[j] = TRUE then
        Score[j,k]+= GTMModel.matR[k,n]*(1-GTMData.matT[n,j]);
       end;


score := matrixmaxminnorm1(Score);
        writeMatrixToFile(score, GTMOptions.outputFile+'_minScore.txt', 'descriptor (line) score for each node (column)');
        Score := matrixTranspose(Score);

      for k:=0 to GTMOptions.nSamples-1 do
        scores[k] := findMaxIndex(score[k])+1;

      writeIntVectorToFile(scores, GTMOptions.outputFile+'_minDescriptors.txt', 'min descriptor on each node');

      for k:=0 to GTMOptions.nSamples-1 do
        scores2[k] := findMaxIndex2(score[k])+1;

      writeIntVectorToFile(scores2, GTMOptions.outputFile+'_minDescriptors2.txt', 'min descriptor on each node');

         for k:=0 to GTMOptions.nSamples-1 do
        scores3[k] := findMaxIndex3(score[k])+1;

      writeIntVectorToFile(scores3, GTMOptions.outputFile+'_minDescriptors3.txt', 'min descriptor on each node');


       SetLength(Score, 0, 0);
  setLength(scores2,0);
  setLength(scores,0);
  setLength(scores3,0);

   DimMatrix(Score, GTMOptions.nDimensions, GTMOptions.nSamples);
   DimIntVector(scores, GTMOptions.nSamples);
   DimIntVector(scores2, GTMOptions.nSamples);
   DimIntVector(scores3, GTMOptions.nSamples);

Writeln;
Writeln('SimDesc :');
for j:=0 to GTMOptions.nDimensions-1 do begin
  write(' ' + IntToStr(j+1));
for k:=0 to GTMOptions.nSamples-1 do
   for n:=0 to GTMData.nMolecules-1 do
    for m:=0 to GTMData.nMolecules-1 do
      // if doCount[j] = TRUE then
        Score[j,k] += abs((GTMModel.matR[k,n]*GTMData.matT[n,j])-(GTMModel.matR[k,m]*GTMData.matT[m,j]));
       end;



score := matrixmaxminnorm1(Score);
        writeMatrixToFile(score, GTMOptions.outputFile+'_simScore.txt', 'descriptor (line) score for each node (column)');
        Score := matrixTranspose(Score);

      for k:=0 to GTMOptions.nSamples-1 do
        scores[k] := findMinIndex(score[k])+1;

      writeIntVectorToFile(scores, GTMOptions.outputFile+'_simDescriptors.txt', 'similar descriptor on each node');

      for k:=0 to GTMOptions.nSamples-1 do
        scores2[k] := findMinIndex2(score[k])+1;

      writeIntVectorToFile(scores2, GTMOptions.outputFile+'_simDescriptors2.txt', 'similar descriptor on each node');

         for k:=0 to GTMOptions.nSamples-1 do
        scores3[k] := findMinIndex3(score[k])+1;

      writeIntVectorToFile(scores3, GTMOptions.outputFile+'_simDescriptors3.txt', 'similar descriptor on each node');


 end;
}

end.


