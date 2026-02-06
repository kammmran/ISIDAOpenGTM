unit UnitProc;

{$mode objfpc}{$H+}
{$MACRO ON}
{$DEFINE WRITELN:={$IFDEF GUI}SLog.Add{$ELSE}writeln{$ENDIF}}
{$DEFINE APP_PROCESS:={$IFDEF GUI}Application.ProcessMessages{$ENDIF}}

interface

uses
  Classes, SysUtils, streamex, utypes, upca, ISIDA_descriptor, ukgtm_options, UnitKPCA, UnitKPCAStream, UKGTMXML, UKGTMStreamXML, UnitKGTM, UnitKGTMStream, rastream;

procedure Welcome();
procedure DoKGTM(aGTMOpt: TRKGTMOptions);
procedure DoKGTMStream(aGTMOpt: TRKGTMOptions);

implementation

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
  WRITELN('ooooo  WELCOME TO KGTM            ');
  WRITELN('               2023               ');
  WRITELN('                                  ');
  WRITELN(' oooooo      o                    ');
  WRITELN('  ooo o  o   o         oooo       ');
  WRITELN(' ooooo             ooooo          ');
  WRITELN('__________________________________');
  WRITELN('');
  WRITELN('');
  WRITELN('Laboratoire de Chémoinformatique');
  WRITELN('Université de Strasbourg');
  WRITELN('Implementation: G. Marcou, Héléna A. Gaspar, D. Horvath, A. Varnek');
  WRITELN('');APP_PROCESS;
end;

procedure DoKGTM(aGTMOpt: TRKGTMOptions);
var
  bKPCAcompute: boolean;
  mols, molsP: LRSMFv2; // Store the molecules
  trhdr, trsvm: string; // temporary string to manage input files
  //
  aGTMXML: TKGTMXML;
  aKGTM: TKGTM;
  LLt, LLt0, dLL: double;
  iter, iterMax: integer;
  bConv: boolean;
  dConv, convCriteria: double;
  Wold: TMatrix;
  DW,DW0: double;
  sline: string;
  id,ik,im: integer;
  //
  aX,aZ: TMatrix;//aX is typically not scaled and aZ is typically scaled
begin
  aKGTM:=TKGTM.Create;
  mols:=LRSMFv2.Create;
  aKGTM.mols:=mols; //The KGTM does not owns the storage of molecules
  //
  if (aGTMOpt.inputFile<>'') then //Input file -> train a model
  begin
    if aGTMOpt.nSamples<=0 then aGTMOpt.nSamples:=aGTMOpt.nCenters*25;
    if aGTMOpt.sigma<=0 then aGTMOpt.sigma:=2*sqrt(4/aGTMOpt.nCenters);
    if aGTMOpt.alpha<=0 then aGTMOpt.alpha:=1.0;
    //
    bKPCAcompute:=True;
    if FileExists(aGTMOpt.modelFile) then begin //Restart from an existing KPCA
      WRITELN('KPCA loaded from '+aGTMOpt.modelFile);
      aGTMXML:=TKGTMXML.Create;
      aGTMXML.ReadGTMModel(aKGTM,aGTMOpt.modelFile);
      FreeAndNil(aGTMXML);
      //Changing kernel definition is forbidden for a restart
      aGTMOpt.imetric:=aKGTM.metric;//2: Tanimoto; 3: RBF; 4: Cos
      aGTMOpt.fgamma:=aKGTM.kprm1;
      aGTMOpt.apct:=aKGTM.pct;
      //
      bKPCAcompute:=False;//KPCA is loaded from model; do not recompute
      WRITELN(' ...Success');
    end else begin
      aKGTM.metric:=aGTMOpt.imetric;//2: Tanimoto; 3: RBF; 4: Cos
      aKGTM.kprm1:=aGTMOpt.fgamma;
      aKGTM.pct:=aGTMOpt.apct;
    end;
    aGTMOpt.WriteOptions;
    //Other options can be reworked on a restart
    aKGTM.M:=aGTMOpt.nCenters;
    aKGTM.K:=aGTMOpt.nSamples;
    aKGTM.sigma:=aGTMOpt.sigma;
    aKGTM.alpha:=aGTMOpt.alpha;
    iterMax:=aGTMOpt.nIter;
    convCriteria:=aGTMOpt.convCriteria;
    aKGTM.iScaleInit:=aGTMOpt.iScaleInit;
    aKGTM.fScaleInit:=aGTMOpt.fScaleInit;
    //
    if bKPCAcompute then begin // Compute the KPCA
      trhdr:=ChangeFileExt(aGTMOpt.inputFile,'.hdr');
      trsvm:=ChangeFileExt(aGTMOpt.inputFile,'.svm');
      if (not FileExists(trhdr)) or (not FileExists(trsvm)) then
      begin
        raise Exception.Create('ERROR KGTM: file does not exists: '+trhdr+' / '+trsvm);
        halt;
      end;
      aKGTM.ReadSVM(aGTMOpt.inputFile); // Load the SVM in the KPCA machine
      aKGTM.KPCA; // Computer the KPCA
    end;
    aKGTM.LoadScores; // The KPCA is done, ready to start the GTM from the KPCA scores
    //
    aKGTM.Init1(aKGTM.K,aKGTM.M,aKGTM.sigma,aKGTM.alpha,aKGTM.iScaleInit,aKGTM.fScaleInit);
    //myGTM.Init1(GTMOpt.nSamples,GTMOpt.nCenters,GTMOpt.sigma,GTMOpt.alpha,GTMOpt.iScaleInit,GTMOpt.fScaleInit);
    WRITELN('******************Reminder******************');
    WRITELN('Width of rbf: ' + FloatToStr(aKGTM.sigma));
    WRITELN('Regularization coefficient: ' + FloatToStr(aKGTM.alpha));
    WRITELN('********************************************');// APP_PROCESS;
    WRITELN('Number of training instances: '+IntToStr(aKGTM.N));//APP_PROCESS;
    aKGTM.Expectation();
    LLt:=aKGTM.LogLikelyHood();
    WRITELN('First LLt='+FloatToStr(LLt));//APP_PROCESS;
    LLt0:=0;
    iter:=1;
    bConv:=False;
    DimMatrix(Wold,aKGTM.D,aKGTM.M); //Keep track of the previous state of the map
    DW0:=aKGTM.D*aKGTM.M;//scaling factor for W
    //Train the map on the input scores
    repeat
      aKGTM.Maximization();
      aKGTM.Expectation();
      LLt:=aKGTM.LogLikelyHood();
      sline:='Iter.: '+IntToStr(Iter)+' LLmap='+FloatToStrF(LLt,ffFixed,8,5)+' ';
      if iter>1 then
      begin
        dLL:=LLt-LLt0;
        sline:=sline+'DLLmap='+FloatToStrF(dLL,ffFixed,8,5)+' %DLLmap='+FloatToStrF(abs((dLL)*100/LLt0),ffFixed,8,5);
        // How much did the map changed
        DW:=0;
        for id:=1 to aKGTM.D do
          for im:=1 to aKGTM.M do
          begin
            if (DW<abs(Wold[id,im]-aKGTM.W[id,im])) then DW:=abs(Wold[id,im]-aKGTM.W[id,im]);
            Wold[id,im]:=aKGTM.W[id,im];
          end;
        dConv:=DW/DW0;
        sline:=sline+' DW='+FloatToStrF(DW,ffFixed,8,5)+' %DW='+FloatToStrF(dConv*100,ffFixed,8,5);
        If dLL<convCriteria then bConv:=True;
      end;
      WRITELN(sline);//APP_PROCESS;
      //Prepare next iteration
      LLt0:=LLt;
      Inc(iter);
    until (iter>iterMax) or (bConv=True);
    //Save the map
    aGTMXML:=TKGTMXML.Create;
    aGTMXML.WriteGTMModel(aKGTM,ChangeFileExt(aGTMOpt.outputFile,'.xml'));
    FreeAndNil(aGTMXML);
    if (aGTMOpt.doProjection) then //Project data on the map
    begin
      if (aGTMOpt.projFile<>'') then  //Project another data file
      begin
        molsP:=LRSMFv2.Create; // To store the molecules to project
        trhdr:=ChangeFileExt(aGTMOpt.projFile,'.hdr');
        trsvm:=ChangeFileExt(aGTMOpt.projFile,'.svm');
        if (not FileExists(trhdr)) or (not FileExists(trsvm)) then
        begin
          raise Exception.Create('ERROR TKGTM: missing file '+trhdr+' / '+trsvm);
          Halt;
        end;
        molsP.ReadSVM(trsvm,trhdr); //Load the data to project
        aX:=AKGTM.aKPCA.Project2Mat(molsP); // Project the data to the KPCA -> generates the loadings to project on the GTM
        DimMatrix(aZ,High(aX),High(aX[Low(aX)]));
        ScaleVar(aX,1,High(aX),High(aX[Low(aX)]),aKGTM.Mean,aKGTM.SD,aZ,aKGTM.istd); //This shall be part of a GTMFull...
        aKGTM.Init(molsP.Count);
        //Ideally, the new matrix shall be loaded in the GTM object and scaled there
        //The Project method shall be called without parameters based sollely on the loaded matrix
        //aKGTM.SetX(aZ);
        //aKGTM.Project();
        aKGTM.Project(aZ,molsP.Count); // Compute the projections
        FreeAndNil(MolsP);
      end else
      begin
        aKGTM.Project(aKGTM.Z,aKGTM.N); // Project the training data
      end;
      LLt:=aKGTM.LogLikelyHood(); // Get the likelihood of the projected data
      WRITELN('Log likelihood = '+FloatToStr(LLt));
      WriteKGTMMat(aKGTM,aGTMOpt.outputFile,aGTMOpt.p3D,aGTMOpt.Rmat);
    end;
    //
  end else if (aGTMOpt.doProjection) and (aGTMOpt.projFile<>'') then // The KGTM does not need to be train, just project the data
  begin
    aGTMXML:=TKGTMXML.Create; // Load the model
    aGTMXML.ReadGTMModel(aKGTM,aGTMOpt.modelFile);
    FreeAndNil(aGTMXML);
    molsP:=LRSMFv2.Create; // A place to store the molecules
    trhdr:=ChangeFileExt(aGTMOpt.projFile,'.hdr');
    trsvm:=ChangeFileExt(aGTMOpt.projFile,'.svm');
    if (not FileExists(trhdr)) or (not FileExists(trsvm)) then
    begin
      raise Exception.Create('ERROR TKGTM: missing file '+trhdr+' / '+trsvm);
      Halt;
    end;
    molsP.ReadSVM(trsvm,trhdr);  // Load the data
    aX:=AKGTM.aKPCA.Project2Mat(molsP); // Project the data on the KPCA and store the scores
    DimMatrix(aZ,High(aX),High(aX[Low(aX)]));
    ScaleVar(aX,1,High(aX),High(aX[Low(aX)]),aKGTM.Mean,aKGTM.SD,aZ,aKGTM.istd); //This shall be part of a GTMFull...
    aKGTM.Init(molsP.Count);
    aKGTM.Project(aZ,molsP.Count); // Project the scores on the KGTM
    LLt:=aKGTM.LogLikelyHood(); // Get the likelihood of the projected data
    WRITELN('Log likelihood = '+FloatToStr(LLt));
    WriteKGTMMat(aKGTM,aGTMOpt.outputFile,aGTMOpt.p3D,aGTMOpt.Rmat);
    FreeAndNil(MolsP);
  end else
  begin
    raise Exception.Create('ERROR TKGTM: invalid options');
    Halt;
  end;
  FreeAndNil(mols);
  FreeAndNil(aKGTM);
  WRITELN('************** All Calculations Finished Successfully **************');
end;

procedure DoKGTMStream(aGTMOpt: TRKGTMOptions);
var
  bKPCAcompute: boolean;
  mols, molsP: LRSMFv2; // Store the molecules
  amol: LRDsc; // Store one molecule
  trhdr, trsvm: string; // temporary string to manage input files
  il,ilmax: integer; // To use the batch size for projection
  Nmax: integer; // The number of items to project
  //
  aFStream: TFileStream;
  pFStream: TFileReader;
  //pRAStream: TRAStream;
  aGTMXML: TKGTMStreamXML;
  aKGTM: TKGTMStream;
  LLt, LLt0, dLL: double;
  iter, iterMax: integer;
  bConv: boolean;
  dConv, convCriteria: double;
  Wold: TMatrix;
  DW,DW0: double;
  sline: string;
  id,ik,im: integer;
  //
  aX,aZ: TMatrix;//aX is typically not scaled and aZ is typically scaled
begin
  mols:=LRSMFv2.Create; // molecules are managed outside the KGTM class
  aKGTM:=TKGTMStream.Create;
  //
  if (aGTMOpt.inputFile<>'') then //Input file -> train a model
  begin
    {aFStream:=TFileStream.Create(aGTMOpt.inputFile,fmOpenRead); // The file stream is not managed by the KPCA object
    aKGTM.SetKPCA(aFStream);}
    aKGTM.SetMols(mols);
    //
    if aGTMOpt.nSamples<=0 then aGTMOpt.nSamples:=aGTMOpt.nCenters*25;
    if aGTMOpt.sigma<=0 then aGTMOpt.sigma:=2*sqrt(4/aGTMOpt.nCenters);
    if aGTMOpt.alpha<=0 then aGTMOpt.alpha:=1.0;
    //
    bKPCAcompute:=True;
    //
    if FileExists(aGTMOpt.modelFile) then begin //Restart from an existing KPCA
      WRITELN('KPCA loaded from '+aGTMOpt.modelFile);
      aGTMXML:=TKGTMStreamXML.Create;
      aGTMXML.ReadGTMModel(aKGTM,aGTMOpt.modelFile); // this is shall assign the stream in the model file and ignore the user input file
      FreeAndNil(aGTMXML);
      //Changing kernel definition is forbidden for a restart
      aKGTM.aKPCA.OwnStream:=True;// now the KPCA is owning the stream.
      aGTMOpt.imetric:=aKGTM.metric;//2: Tanimoto; 3: RBF; 4: Cos
      aGTMOpt.fgamma:=aKGTM.kprm1;
      aGTMOpt.apct:=aKGTM.pct;
      //
      bKPCAcompute:=False;//KPCA is loaded from model; do not recompute
      WRITELN(' ...Success');
    end else begin // Not restart, prepare the stream and configure the KGTM
      aFStream:=TFileStream.Create(aGTMOpt.inputFile,fmOpenRead); // The file stream is not managed by the KPCA object
      aKGTM.SetKPCA(aFStream);
      //
      aKGTM.metric:=aGTMOpt.imetric;//2: Tanimoto; 3: RBF; 4: Cos
      aKGTM.kprm1:=aGTMOpt.fgamma;
      aKGTM.bWeight:=False;
      aKGTM.pct:=aGTMOpt.apct;
      aKGTM.bSze:=aGTMOpt.btchSze;
    end;
    aGTMOpt.WriteOptions;
    //Other options can be reworked on a restart
    aKGTM.M:=aGTMOpt.nCenters;
    aKGTM.K:=aGTMOpt.nSamples;
    aKGTM.sigma:=aGTMOpt.sigma;
    aKGTM.alpha:=aGTMOpt.alpha;
    iterMax:=aGTMOpt.nIter;
    convCriteria:=aGTMOpt.convCriteria;
    aKGTM.iScaleInit:=aGTMOpt.iScaleInit;
    aKGTM.fScaleInit:=aGTMOpt.fScaleInit;
    //
    if bKPCAcompute then begin // Compute the KPCA
      trhdr:=ChangeFileExt(aGTMOpt.inputFile,'.hdr');
      trsvm:=ChangeFileExt(aGTMOpt.inputFile,'.svm');
      if (not FileExists(trhdr)) or (not FileExists(trsvm)) then
      begin
        raise Exception.Create('ERROR KGTM: file does not exists: '+trhdr+' / '+trsvm);
        halt;
      end;
      aKGTM.KPCA; // Computer the KPCA
    end;
    aKGTM.LoadScores; // The KPCA is done, ready to start the GTM from the KPCA scores
    // Train the GTM part of the KGTM. In stream mode, (quasi-)duplicates are not filtered out
    aKGTM.Init1(aKGTM.K,aKGTM.M,aKGTM.sigma,aKGTM.alpha,aKGTM.iScaleInit,aKGTM.fScaleInit);
    WRITELN('******************Reminder******************');
    WRITELN('Width of rbf: ' + FloatToStr(aKGTM.sigma));
    WRITELN('Regularization coefficient: ' + FloatToStr(aKGTM.alpha));
    WRITELN('********************************************');// APP_PROCESS;
    WRITELN('Number of training instances: '+IntToStr(aKGTM.N));//APP_PROCESS;
    aKGTM.Expectation();
    LLt:=aKGTM.LogLikelyHood();
    WRITELN('First LLt='+FloatToStr(LLt));//APP_PROCESS;
    LLt0:=0;
    iter:=1;
    bConv:=False;
    DimMatrix(Wold,aKGTM.D,aKGTM.M); //Keep track of the previous state of the map
    DW0:=aKGTM.D*aKGTM.M;//scaling factor for W
    //Train the map on the input scores
    repeat
      aKGTM.Maximization();
      aKGTM.Expectation();
      LLt:=aKGTM.LogLikelyHood();
      sline:='Iter.: '+IntToStr(Iter)+' LLmap='+FloatToStrF(LLt,ffFixed,8,5)+' ';
      if iter>1 then
      begin
        dLL:=LLt-LLt0;
        sline:=sline+'DLLmap='+FloatToStrF(dLL,ffFixed,8,5)+' %DLLmap='+FloatToStrF(abs((dLL)*100/LLt0),ffFixed,8,5);
        // How much did the map changed
        DW:=0;
        for id:=1 to aKGTM.D do
          for im:=1 to aKGTM.M do
          begin
            if (DW<abs(Wold[id,im]-aKGTM.W[id,im])) then DW:=abs(Wold[id,im]-aKGTM.W[id,im]);
            Wold[id,im]:=aKGTM.W[id,im];
          end;
        dConv:=DW/DW0;
        sline:=sline+' DW='+FloatToStrF(DW,ffFixed,8,5)+' %DW='+FloatToStrF(dConv*100,ffFixed,8,5);
        If dLL<convCriteria then bConv:=True;
      end;
      WRITELN(sline);//APP_PROCESS;
      //Prepare next iteration
      LLt0:=LLt;
      Inc(iter);
    until (iter>iterMax) or (bConv=True);
    //Save the map
    aGTMXML:=TKGTMStreamXML.Create;
    aGTMXML.WriteGTMModel(aKGTM,ChangeFileExt(aGTMOpt.outputFile,'.xml'));
    FreeAndNil(aGTMXML);
    //
    if (aGTMOpt.doProjection) then //Project data on the map
    begin
      if (aGTMOpt.projFile<>'') then  //Project another data file
      begin
        pFStream:=TFileReader.Create(aGTMOpt.projFile,fmOpenRead);
        molsP:=LRSMFv2.Create;
        ilmax:=aKGTM.bSze;
        while (not pFStream.Eof) do
        begin
          il:=0;
          molsP.Clear;
          While(il<ilmax) and (not pFStream.Eof) do
          begin
            Inc(il);
            sline:=pFStream.ReadLine;
            amol:=LRDsc.Create;
            amol.ReadLNSVM(sline);
            molsP.Add(amol);
          end;
          if (not pFStream.Eof) then
          begin
            Nmax:=molsP.Count; // Count the number of compounds in the current batch to project
            aX:=aKGTM.aKPCA.Project2Mat(molsP); // Get matrix of projections
            DimMatrix(aZ,High(aX),High(aX[Low(aX)])); // Prepare the scaled matrix for the GTM
            ScaleVar(aX,1,High(aX),High(aX[Low(aX)]),aKGTM.Mean,aKGTM.SD,aZ,aKGTM.istd); // Scaling
            aKGTM.Init(molsP.Count); // Send the data to project to the KGTM
            aKGTM.Project(aZ,Nmax); // Do the projections
            //
            LLt:=aKGTM.LogLikelyHood(); // Get the likelihood of the projected data
            WRITELN('Log likelihood = '+FloatToStr(LLt));
            WriteKGTMStreamMat(aKGTM,aGTMOpt.outputFile,aGTMOpt.p3D,aGTMOpt.Rmat); // Save the projections, results are appended
          end;
        end;
        //Release memory
        FreeAndNil(molsP);
        FreeAndNil(pFStream);
      end else
      begin
        aKGTM.Project(aKGTM.Z,aKGTM.N); // Project the training data
        WRITELN('Log likelihood = '+FloatToStr(LLt));
        WriteKGTMStreamMat(aKGTM,aGTMOpt.outputFile,aGTMOpt.p3D,aGTMOpt.Rmat); // Save the projections, results are appended
      end;
    end;
    // Release memory
    if not aKGTM.aKPCA.OwnStream then
      FreeAndNil(aFStream);
    //FreeAndNil(mols);
  end else if (aGTMOpt.doProjection) and (aGTMOpt.projFile<>'') then // The KGTM does not need to be train, just project the data
  begin
    pFStream:=TFileReader.Create(aGTMOpt.projFile,fmOpenRead); // A stream to read projected molecules.
    molsP:=LRSMFv2.Create;
    //
    aGTMXML:=TKGTMStreamXML.Create;
    //
    //aFStream:=TFileStream.Create({the model support molecule file},fmOpenRead); // A stream to read projected molecules.
    aKGTM.SetKPCA(aFStream);
    aKGTM.SetMols(mols); // support molecules to compute the kernel (as specified in the XML file) / mols is attached to a KPCA / KPCA is attached to a stream...
    WRITELN('KPCA loaded from '+aGTMOpt.modelFile);
    aGTMXML.ReadGTMModel(aKGTM,aGTMOpt.modelFile); // Before reading,
    FreeAndNil(aGTMXML);
    //Changing kernel definition is forbidden for a projection
    aGTMOpt.imetric:=aKGTM.metric;//2: Tanimoto; 3: RBF; 4: Cos
    aGTMOpt.fgamma:=aKGTM.kprm1;
    aGTMOpt.apct:=aKGTM.pct;
    //
    bKPCAcompute:=False;//KPCA is loaded from model; do not recompute
    WRITELN(' ...Success');
    //
    ilmax:=aKGTM.bSze;
    while (not pFStream.Eof) do
    begin
      il:=0;
      molsP.Clear;
      While(il<ilmax) and (not pFStream.Eof) do
      begin
        Inc(il);
        sline:=pFStream.ReadLine;
        amol:=LRDsc.Create;
        amol.ReadLNSVM(sline);
        molsP.Add(amol);
      end;
      if (not pFStream.Eof) then
      begin
        Nmax:=molsP.Count; // Count the number of compounds in the current batch to project
        aX:=aKGTM.aKPCA.Project2Mat(molsP); // Get matrix of projections
        DimMatrix(aZ,High(aX),High(aX[Low(aX)])); // Prepare the scaled matrix for the GTM
        ScaleVar(aX,1,High(aX),High(aX[Low(aX)]),aKGTM.Mean,aKGTM.SD,aZ,aKGTM.istd); // Scaling
        aKGTM.Init(Nmax); // Send the data to project to the KGTM
        aKGTM.Project(aZ,Nmax); // Do the projections
        //
        LLt:=aKGTM.LogLikelyHood(); // Get the likelihood of the projected data
        WRITELN('Log likelihood = '+FloatToStr(LLt));
        WriteKGTMStreamMat(aKGTM,aGTMOpt.outputFile,aGTMOpt.p3D,aGTMOpt.Rmat); // Save the projections, results are appended
      end;
    end;
    // Release memory
    FreeAndNil(pFStream);
    FreeAndNil(molsP);
    {aGTMXML:=TKGTMXML.Create; // Load the model
    aGTMXML.ReadGTMModel(aKGTM,aGTMOpt.modelFile);
    FreeAndNil(aGTMXML);
    molsP:=LRSMFv2.Create; // A place to store the molecules
    trhdr:=ChangeFileExt(aGTMOpt.projFile,'.hdr');
    trsvm:=ChangeFileExt(aGTMOpt.projFile,'.svm');
    if (not FileExists(trhdr)) or (not FileExists(trsvm)) then
    begin
      raise Exception.Create('ERROR TKGTM: missing file '+trhdr+' / '+trsvm);
      Halt;
    end;
    molsP.ReadSVM(trsvm,trhdr);  // Load the data
    aX:=AKGTM.aKPCA.Project2Mat(molsP); // Project the data on the KPCA and store the scores
    DimMatrix(aZ,High(aX),High(aX[Low(aX)]));
    ScaleVar(aX,1,High(aX),High(aX[Low(aX)]),aKGTM.Mean,aKGTM.SD,aZ,aKGTM.istd); //This shall be part of a GTMFull...
    aKGTM.Init(molsP.Count);
    aKGTM.Project(aZ,molsP.Count); // Project the scores on the KGTM
    LLt:=aKGTM.LogLikelyHood(); // Get the likelihood of the projected data
    WRITELN('Log likelihood = '+FloatToStr(LLt));
    WriteGTMMat(aKGTM,aGTMOpt.outputFile,aGTMOpt.p3D,aGTMOpt.Rmat);
    FreeAndNil(MolsP);}
  end else
  begin
    raise Exception.Create('ERROR TKGTM: invalid options');
    Halt;
  end;
  FreeAndNil(mols);
  FreeAndNil(aKGTM);
  WRITELN('************** All Calculations Finished Successfully **************');
  FreeAndNil(aKGTM);
end;
  {
  aKGTM:=TKGTM.Create;
  mols:=LRSMFv2.Create;
  aKGTM.mols:=mols; //The KGTM does not owns the storage of molecules
  //
  if (aGTMOpt.inputFile<>'') then //Input file -> train a model
  begin
    if aGTMOpt.nSamples<=0 then aGTMOpt.nSamples:=aGTMOpt.nCenters*25;
    if aGTMOpt.sigma<=0 then aGTMOpt.sigma:=2*sqrt(4/aGTMOpt.nCenters);
    if aGTMOpt.alpha<=0 then aGTMOpt.alpha:=1.0;
    //
    bKPCAcompute:=True;
    if FileExists(aGTMOpt.modelFile) then begin //Restart from an existing KPCA
      WRITELN('KPCA loaded from '+aGTMOpt.modelFile);
      aGTMXML:=TKGTMXML.Create;
      aGTMXML.ReadGTMModel(aKGTM,aGTMOpt.modelFile);
      FreeAndNil(aGTMXML);
      //Changing kernel definition is forbidden for a restart
      aGTMOpt.imetric:=aKGTM.metric;//2: Tanimoto; 3: RBF; 4: Cos
      aGTMOpt.fgamma:=aKGTM.kprm1;
      aGTMOpt.apct:=aKGTM.pct;
      //
      bKPCAcompute:=False;//KPCA is loaded from model; do not recompute
      WRITELN(' ...Success');
    end else begin
      aKGTM.metric:=aGTMOpt.imetric;//2: Tanimoto; 3: RBF; 4: Cos
      aKGTM.kprm1:=aGTMOpt.fgamma;
      aKGTM.pct:=aGTMOpt.apct;
    end;
    aGTMOpt.WriteOptions;
    //Other options can be reworked on a restart
    aKGTM.M:=aGTMOpt.nCenters;
    aKGTM.K:=aGTMOpt.nSamples;
    aKGTM.sigma:=aGTMOpt.sigma;
    aKGTM.alpha:=aGTMOpt.alpha;
    iterMax:=aGTMOpt.nIter;
    convCriteria:=aGTMOpt.convCriteria;
    aKGTM.iScaleInit:=aGTMOpt.iScaleInit;
    aKGTM.fScaleInit:=aGTMOpt.fScaleInit;
    //
    if bKPCAcompute then begin // Compute the KPCA
      trhdr:=ChangeFileExt(aGTMOpt.inputFile,'.hdr');
      trsvm:=ChangeFileExt(aGTMOpt.inputFile,'.svm');
      if (not FileExists(trhdr)) or (not FileExists(trsvm)) then
      begin
        raise Exception.Create('ERROR KGTM: file does not exists: '+trhdr+' / '+trsvm);
        halt;
      end;
      aKGTM.ReadSVM(aGTMOpt.inputFile); // Load the SVM in the KPCA machine
      aKGTM.KPCA; // Computer the KPCA
    end;
    aKGTM.LoadScores; // The KPCA is done, ready to start the GTM from the KPCA scores
    //
    aKGTM.Init1(aKGTM.K,aKGTM.M,aKGTM.sigma,aKGTM.alpha,aKGTM.iScaleInit,aKGTM.fScaleInit);
    //myGTM.Init1(GTMOpt.nSamples,GTMOpt.nCenters,GTMOpt.sigma,GTMOpt.alpha,GTMOpt.iScaleInit,GTMOpt.fScaleInit);
    WRITELN('******************Reminder******************');
    WRITELN('Width of rbf: ' + FloatToStr(aKGTM.sigma));
    WRITELN('Regularization coefficient: ' + FloatToStr(aKGTM.alpha));
    WRITELN('********************************************');// APP_PROCESS;
    WRITELN('Number of training instances: '+IntToStr(aKGTM.N));//APP_PROCESS;
    aKGTM.Expectation();
    LLt:=aKGTM.LogLikelyHood();
    WRITELN('First LLt='+FloatToStr(LLt));//APP_PROCESS;
    LLt0:=0;
    iter:=1;
    bConv:=False;
    DimMatrix(Wold,aKGTM.D,aKGTM.M); //Keep track of the previous state of the map
    DW0:=aKGTM.D*aKGTM.M;//scaling factor for W
    //Train the map on the input scores
    repeat
      aKGTM.Maximization();
      aKGTM.Expectation();
      LLt:=aKGTM.LogLikelyHood();
      sline:='Iter.: '+IntToStr(Iter)+' LLmap='+FloatToStrF(LLt,ffFixed,8,5)+' ';
      if iter>1 then
      begin
        dLL:=LLt-LLt0;
        sline:=sline+'DLLmap='+FloatToStrF(dLL,ffFixed,8,5)+' %DLLmap='+FloatToStrF(abs((dLL)*100/LLt0),ffFixed,8,5);
        // How much did the map changed
        DW:=0;
        for id:=1 to aKGTM.D do
          for im:=1 to aKGTM.M do
          begin
            if (DW<abs(Wold[id,im]-aKGTM.W[id,im])) then DW:=abs(Wold[id,im]-aKGTM.W[id,im]);
            Wold[id,im]:=aKGTM.W[id,im];
          end;
        dConv:=DW/DW0;
        sline:=sline+' DW='+FloatToStrF(DW,ffFixed,8,5)+' %DW='+FloatToStrF(dConv*100,ffFixed,8,5);
        If dLL<convCriteria then bConv:=True;
      end;
      WRITELN(sline);//APP_PROCESS;
      //Prepare next iteration
      LLt0:=LLt;
      Inc(iter);
    until (iter>iterMax) or (bConv=True);
    //Save the map
    aGTMXML:=TKGTMXML.Create;
    aGTMXML.WriteGTMModel(aKGTM,ChangeFileExt(aGTMOpt.outputFile,'.xml'));
    FreeAndNil(aGTMXML);
    if (aGTMOpt.doProjection) then //Project data on the map
    begin
      if (aGTMOpt.projFile<>'') then  //Project another data file
      begin
        molsP:=LRSMFv2.Create; // To store the molecules to project
        trhdr:=ChangeFileExt(aGTMOpt.projFile,'.hdr');
        trsvm:=ChangeFileExt(aGTMOpt.projFile,'.svm');
        if (not FileExists(trhdr)) or (not FileExists(trsvm)) then
        begin
          raise Exception.Create('ERROR TKGTM: missing file '+trhdr+' / '+trsvm);
          Halt;
        end;
        molsP.ReadSVM(trsvm,trhdr); //Load the data to project
        aX:=AKGTM.aKPCA.Project2Mat(molsP); // Project the data to the KPCA -> generates the loadings to project on the GTM
        DimMatrix(aZ,High(aX),High(aX[Low(aX)]));
        ScaleVar(aX,1,High(aX),High(aX[Low(aX)]),aKGTM.Mean,aKGTM.SD,aZ,aKGTM.istd); //This shall be part of a GTMFull...
        aKGTM.Init(molsP.Count);
        //Ideally, the new matrix shall be loaded in the GTM object and scaled there
        //The Project method shall be called without parameters based sollely on the loaded matrix
        //aKGTM.SetX(aZ);
        //aKGTM.Project();
        aKGTM.Project(aZ,molsP.Count); // Compute the projections
        FreeAndNil(MolsP);
      end else
      begin
        aKGTM.Project(aKGTM.Z,aKGTM.N); // Project the training data
      end;
      LLt:=aKGTM.LogLikelyHood(); // Get the likelihood of the projected data
      WRITELN('Log likelihood = '+FloatToStr(LLt));
      WriteGTMMat(aKGTM,aGTMOpt.outputFile,aGTMOpt.p3D,aGTMOpt.Rmat);
    end;
    //
  end else if (aGTMOpt.doProjection) and (aGTMOpt.projFile<>'') then // The KGTM does not need to be train, just project the data
  begin
    aGTMXML:=TKGTMXML.Create; // Load the model
    aGTMXML.ReadGTMModel(aKGTM,aGTMOpt.modelFile);
    FreeAndNil(aGTMXML);
    molsP:=LRSMFv2.Create; // A place to store the molecules
    trhdr:=ChangeFileExt(aGTMOpt.projFile,'.hdr');
    trsvm:=ChangeFileExt(aGTMOpt.projFile,'.svm');
    if (not FileExists(trhdr)) or (not FileExists(trsvm)) then
    begin
      raise Exception.Create('ERROR TKGTM: missing file '+trhdr+' / '+trsvm);
      Halt;
    end;
    molsP.ReadSVM(trsvm,trhdr);  // Load the data
    aX:=AKGTM.aKPCA.Project2Mat(molsP); // Project the data on the KPCA and store the scores
    DimMatrix(aZ,High(aX),High(aX[Low(aX)]));
    ScaleVar(aX,1,High(aX),High(aX[Low(aX)]),aKGTM.Mean,aKGTM.SD,aZ,aKGTM.istd); //This shall be part of a GTMFull...
    aKGTM.Init(molsP.Count);
    aKGTM.Project(aZ,molsP.Count); // Project the scores on the KGTM
    LLt:=aKGTM.LogLikelyHood(); // Get the likelihood of the projected data
    WRITELN('Log likelihood = '+FloatToStr(LLt));
    WriteGTMMat(aKGTM,aGTMOpt.outputFile,aGTMOpt.p3D,aGTMOpt.Rmat);
    FreeAndNil(MolsP);
  end else
  begin
    raise Exception.Create('ERROR TKGTM: invalid options');
    Halt;
  end;
  FreeAndNil(mols);
  FreeAndNil(aKGTM);
  WRITELN('************** All Calculations Finished Successfully **************');
  }

end.

