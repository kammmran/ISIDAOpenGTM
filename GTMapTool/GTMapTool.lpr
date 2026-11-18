program GTMapTool;

{$mode objfpc}{$H+}

uses {$IFDEF UNIX} {$IFDEF UseCThreads}
  cthreads, {$ENDIF} {$ENDIF}
  Classes, SysUtils, CustApp, UnitProc, ugtm_options, ULinAlgSparse, UGTMXML,
  UiGTM, UGTMMN, ioSVM, UnitLicence, ucholesk;

{,
  ISIDA_descriptor,
  ioSVM,
  utypes,
  ulinalg,
  uclock,
  ureader,
  //incremental_learning,
  ugtm_data, ugtm_manifold, umissing, incremental_learning;}



const
  {ArgLst = 'h::i:o:w:m:k:l:r::f:t::p:c:a::s::d::b::j::v:y:n::q:';
  LngArg =
    'dissimilarity: sparse standardize lambda: bintype: INCRPCA BIN NIPALS COVAR '+
    'reverseProjection: prob combinedGTM: missing meanPCA freezingConstant: freeze gamma: ' +
    'nDim: testVtrain: magnificationFactors kernel: kernelFile computeKernels train: blocks: ' +
    'help input: output: incremental seed: batchL: batchW: batchM: batchK: limit: '+
    'classes: activities: descScores CPF: LPF: supervised initialize: mute inputFiles: '+
    'test: noNormalization scaling: weight: kernelCentering degree: cste: slope: '+
    'dissimilarityFile computeDissimilarities';}
  ArgLst = 'hi:o:t::m:k:w:l:c:z:j::y:x:b:p:';
  LngArg = 'help input: type:: output: nSample: nTrait: width: regularization:'+
           'nIter: limit: DoProj:: NewData: xml: blocks: 3D preprocess getRmat '+
           'licence: ScaleInit: PC123: CfgXml:';

var
  InTerminal: boolean;


type

  { TGTMapTool }

  TGTMapTool = class(TCustomApplication)
  protected
    procedure DoRun; override;
  public
    constructor Create(TheOwner: TComponent); override;
    destructor Destroy; override;
    procedure WriteHelp; virtual;
  end;

  { TGTMapTool }

  procedure TGTMapTool.DoRun;
  var
    //dataMatrix: TMatrix;
    st, ss, sn, sk, sl, sf, sp, sc, sy, sv, sa, sz, sscale, modout, fncfgxml, parentDirPath, sfncfgxml: string;
    it, iy, cde, pc: integer;
    ErrorMsg: string;
    //theStringArray: AAS;
    sbatchW, sbatchL, sBatchK, sBatchM, sInputFiles: string;
    //activities: AD;
    GTMOptions: TRGTMOptions;
    XMLGTM: TGTMXML;
    //GTMData, GTMDataTest, GTMNextData: RGTMData;
    //GTMManifold: RGTMManifold;
  begin
    //Initialization
    Welcome();
    GTMOptions := TRGTMOptions.Create;
    {GTMData := RGTMData.Create;
    ss := '';
    sn := '';
    sk := '';
    sl := '';
    sf := '';
    sp := '';
    sc := '';
    sy := '';
    sv := '';
    sbatchW:= '';
    sbatchL:= '';
    sbatchM:= '';
    sbatchK:= '';
    sbatchW := '0.25:0.25:2';
    sbatchL := '-2:1:2';
    sbatchK := '6:1:10';
    sbatchM := '4:1:6';}
    // quick check parameters
    ErrorMsg := CheckOptions(ArgLst, LngArg);
    if ErrorMsg <> '' then
    begin
      ShowException(Exception.Create(ErrorMsg));
      WriteHelp;
      Terminate;
      Exit;
    end;
    if HasOption('licence') then
      CheckLicence(GetOptionValue('licence'))
    else CheckLicence();
    if HasOption('h', 'help') then
    begin
      WriteHelp;
      Terminate;
      Exit;
    end;
    if HasOption('t','type') then
    begin
      st:=GetOptionValue('t','type');
      if st='BISHOP' then it:=1
      else if st='INCREMENTAL' then it:=2
      else if st='MULTINOMIAL' then it:=3
      else it:=StrToInt(st);
      case it of
        1 : GTMOptions.GTMType:=BISHOP;
        2 : GTMOptions.GTMType:=INCREMENTAL;
        3 : GTMOptions.GTMType:=MULTINOMIAL;
      else GTMOptions.GTMType:=UNKGTM;
      end;
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
    if HasOption('j','DoProj') then
    begin
      GTMOptions.doProjection:=True;
      if HasOption('y','NewData') then
      begin
        sy := GetOptionValue('y','NewData');
        Val(sy,iy,cde);
        if cde<> 0 then
          GTMOptions.projFile := sy
        else GTMOptions.splitFile:=iy;
      end;
    end;
    if HasOption('b','blocks') then
      GTMOptions.nBlocks := StrToInt(GetOptionValue('b','blocks'));
    if HasOption('3D') then
      GTMOptions.p3D:=True;
    if HasOption('p','preprocess') then
      GTMOptions.preprocess:=StrToInt(GetOptionValue('p','preprocess'));
    if HasOption('getRmat') then
      GTMOptions.Rmat:=True;
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
    if HasOption('PC123') then
      GTMOptions.PCAFile:=GetOptionValue('PC123');
    //Validate the combination of input options before doing any work.
    //Without these checks an empty run dereferences unallocated matrices.
    if (GTMOptions.inputFile='') and (GTMOptions.modelFile='') then
    begin
      Writeln('ERROR: nothing to do. Give a training file (-i) or a model file (-x).');
      Writeln('Use -h for help.');
      FreeAndNil(GTMOptions);
      ExitCode:=1;
      Terminate;
      Exit;
    end;
    if (GTMOptions.inputFile='') and (GTMOptions.projFile='') then
    begin
      Writeln('ERROR: a model file (-x) was given without data. Use -j -y <file.svm> to project data,');
      Writeln('or -i <file.svm> to continue training the model.');
      FreeAndNil(GTMOptions);
      ExitCode:=1;
      Terminate;
      Exit;
    end;
    if (GTMOptions.inputFile<>'') and (not FileExists(GTMOptions.inputFile)) then
    begin
      Writeln('ERROR: input file not found: '+GTMOptions.inputFile);
      FreeAndNil(GTMOptions);
      ExitCode:=1;
      Terminate;
      Exit;
    end;
    if (GTMOptions.modelFile<>'') and (not FileExists(GTMOptions.modelFile)) then
    begin
      Writeln('ERROR: model file not found: '+GTMOptions.modelFile);
      FreeAndNil(GTMOptions);
      ExitCode:=1;
      Terminate;
      Exit;
    end;
    if (GTMOptions.projFile<>'') and (not FileExists(GTMOptions.projFile)) then
    begin
      Writeln('ERROR: file to project not found: '+GTMOptions.projFile);
      FreeAndNil(GTMOptions);
      ExitCode:=1;
      Terminate;
      Exit;
    end;
    //
    if GTMOptions.modelFile<>'' then
    begin
      XMLGTM:=TGTMXML.Create;
      XMLGTM.ReadGTMModel(GTMOptions,GTMOptions.modelFile);
      FreeAndNil(XMLGTM);
    end;
    //New - 22-03-2022
    if HasOption('CfgXml') then begin //Option format --CfgXml [1,2]:filename
      sfncfgxml:=GetOptionValue('CfgXml');
      parentDirPath := ExtractFilePath(GTMOptions.outputFile);
      pc:=Pos(':',sfncfgxml);
      if (pc<=0) then begin
        GTMOptions.iCfgXml:=1;
        GTMOptions.CfgXml:=parentDirPath+'GTMConfig.xml';
      end else begin
        GTMOptions.iCfgXml:=StrToInt(Copy(sfncfgxml,1,pc-1));//int before ":"
        GTMOptions.CfgXml:=Copy(sfncfgxml,pc+1,Length(sfncfgxml)-pc);//filename after ":"
      end;
      //fncfgxml:=GetOptionValue('CfgXml');
      //GTMOptions.CfgXml:=fncfgxml;
      //WriteLn('CfgXml option value : '+fncfgxml);
    end else begin
      GTMOptions.CfgXml:=parentDirPath+'GTMConfig.xml';
      //WriteLn('No option CfgXml');
      //WriteLn('parentDirPath : '+parentDirPath);
    end;
    //New - 22-03-2022


    {if GTMOptions.modelFile<>'' then
    begin
//      XMLGTM:=TGTMXML.Create;
//      XMLGTM.ReadGTMModel(GTMOptions,GTMOptions.modelFile);
//      FreeAndNil(XMLGTM);
      if GTMOptions.inputFile<>'' then //Continue training
        writeln('Continue training using the file '+GTMOptions.inputFile)
      else if GTMOptions.doProjection then //Project data using the loaded model
      begin
        writeln('Project data using the loaded model in '+GTMOptions.modelFile);
        if GTMOptions.projFile<>'' then
        begin
          writeln('Project data from file '+GTMOptions.projFile);
        end else
        begin
          writeln('ERROR: no input file to project');
          halt;
        end;
      end;
    end;
    if GTMOptions.inputFile<>'' then //Initialize the GTM with the input file
    begin
      writeln('Initialize and train using file '+GTMOptions.inputFile);
      if GTMOptions.doProjection then
      begin
        writeln('Project on the trained map');
        if GTMOptions.projFile<>'' then
        begin
          writeln('Project data from file '+GTMOptions.projFile);
        end else if GTMOptions.splitFile>0 then
        begin
          writeln('Project the last '+IntToStr(GTMOptions.splitFile)+' instances of the dataset');
        end else
        begin
          writeln('Project the training set');
        end;
      end;
    end;}
    //
    if (GTMOptions.nSamples<=0) then
    begin
      if (GTMOptions.sigma=-1) then //default nSamples and sigma
      begin
        GTMOptions.sigma:=2*sqrt(4/GTMOptions.nCenters);//sigma=2*(spacing between RBF)
        GTMOptions.nSamples := 25*GTMOptions.nCenters;//Round(sqr(5.64 /GTMOptions.sigma));
      end else //default nSample but sigma defined
        GTMOptions.nSamples := 25*GTMOptions.nCenters;//Round(sqr(5.64 /GTMOptions.sigma));
    end else if (GTMOptions.sigma=-1) then //defined nSample but sigma undefined
      GTMOptions.sigma := 5.64 / sqrt(GTMOptions.nSamples); // Recommendation to have O(100) samples within 2 sigma radius
    // nSample and sigma defined: nothing to do
    if (GTMOptions.alpha=-1) then
      GTMOptions.alpha := 1; // Each weight defining the GTM manifold obeys a standard normal distribution
    //


    //Add reading of the GTMConfig.xml here, if it exists

    GTMOptions.WriteOptions;
    //
    case GTMOptions.GTMType of
      BISHOP:
        begin
          if (GTMOptions.nBlocks<1) then DoClassicGTM(GTMOptions)
          else DoClassicGTMb(GTMOptions);
        end;
      INCREMENTAL: DoIncrementalGTM(GTMOptions);
      MULTINOMIAL:
        begin
          if GTMOptions.nBlocks<1 then DoMultinomialGTM(GTMOptions)
          else DoMultinomialGTMb(GTMOptions);
        end
    else begin
      Writeln('ERROR: GTM type not recognized');
      Terminate;
      Exit;
    end;
    end;
    Writeln('************** All Calculations Finished Successfully **************');

    {if HasOption('sparse') then GTMOptions.sparse := TRUE;

    if HasOption('lambda') then GTMOptions.regulation := StrToFloat(getOptionValue('lambda'));

    if HasOption('BIN') then GTMOptions.BIN := TRUE;

    if HasOption('bintype') then GTMOptions.binaryDistribution := getOptionValue('bintype');

    if HasOption('COVAR') then GTMOptions.COVAR := TRUE;

    if HasOption('NIPALS') then GTMOptions.NIPALS := TRUE;

    if HasOption('kernelCentering') then GTMOptions.kernelCentering := TRUE;

    if HasOption('cste') then GTMOptions.cste := StrToFloat(getOptionValue('cste'));

    if HasOption('slope') then GTMOptions.slope := StrToFloat(getOptionValue('slope'));

    if HasOption('degree') then GTMOptions.degree := StrToFloat(getOptionValue('degree'));

    if HasOption('seed') then GTMOptions.seed := GTMOptions.seed*StrToInt(GetOptionValue('seed'));

    if HasOption('mute') then GTMOptions.mute := TRUE;

    if HasOption('meanPCA') then GTMOptions.meanPCA := TRUE;

    if HasOption('missing') then GTMOptions.Missing := TRUE;

    if HasOption('prob') then GTMOptions.probabilisticProjection := TRUE;

    if HasOption('combinedGTM') then begin
    GTMOptions.beginProp := StrToInt(GetOptionValue('combinedGTM'));
    if HasOption('weight') then
    GTMOptions.descweight:= StrToFloat(GetOptionValue('weight')) else
    GTMOptions.descweight:= 0.5;
    end;


    if HasOption('descScores') then
    GTMOptions.computeDescScores := True;

    if HasOption('noNormalization') then
    GTMOptions.normalize := FALSE else GTMOptions.normalize := TRUE;

    if HasOption('standardize') then begin
    GTMOptions.standardize := TRUE;
    GTMOptions.normalize := FALSE;
    end;

    if HasOption('freeze') then begin
    GTMOptions.freeze := TRUE;
    end;

    if HasOption('freezingConstant') then
    begin GTMOptions.freezingConstant := StrToFloat(GetOptionValue('freezingConstant'));
      GTMOptions.freeze := TRUE;
    end;

    if HasOption('gamma') then
    GTMOptions.gamma := StrToFloat(GetOptionValue('gamma')) else
    GTMOptions.gamma := 0.5;

    if HasOption('kernel') then begin
    GTMOptions.kernel := True;
    GTMOptions.kernelType := getOptionValue('kernel');
    end;

    if HasOption('dissimilarity') then begin
    GTMOptions.dissimilarity := True;
    GTMOptions.dissimilarityType := getOptionValue('dissimilarity');
    end;

    if HasOption('initialize') then
    GTMOptions.initialize := StrToInt(GetOptionValue('initialize'));



    if hasOption('nDim') then GTMOptions.featureSpaceDimension := StrToInt(getOptionValue('nDim')) else GTMOptions.featureSpaceDimension := 100;

    if (HasOption('classes'))then begin
      GTMOptions.classify := TRUE;
      if HasOption('v') then begin
      sa :=GetOptionValue('classes');
      activities := loadArray(sa);
      GTMData.ClassModel.activities := TVector(activities);
      DimVector(GTMData.ClassModel.activities, high(GTMData.ClassModel.activities)+1);
      GTMData.ClassModel.numberOfClasses := TRUNC(VectorMax(GTMData.ClassModel.activities));
      if HasOption('CPF') then GTMData.ClassModel.CPF := StrToFloat(GetOptionValue('CPF'));
      if HasOption('LPF') then GTMData.ClassModel.LPF := StrToFloat(GetOptionValue('LPF'));
      if HasOption('supervised') then GTMData.ClassModel.supervised := TRUE;
      end;
      end;

      if HasOption('activities') then begin
      if GTMOptions.classify = FALSE then GTMOptions.regress := TRUE;
      if HasOption('v') then begin
      sa :=GetOptionValue('activities');
      activities := loadArray(sa);
      GTMData.RegModel.activities := TVector(activities);
      DimVector(GTMData.RegModel.activities, high(GTMData.RegModel.activities)+1);
      end;
      end;

    if HasOption('batchW') then
      sbatchW := getOptionValue('batchW');
    Split(':', sbatchW, GTMOptions.lbatchW);

    if HasOption('batchL') then
      sbatchL := getOptionValue('batchL');
    Split(':', sbatchL, GTMOptions.lbatchL);

    if HasOption('batchM') then
      sbatchM := getOptionValue('batchM');
     Split(':', sbatchM, GTMOptions.lbatchM);

    if HasOption('batchK') then
      sbatchK := getOptionValue('batchK');
      Split(':', sbatchK, GTMOptions.lbatchK);

    if HasOption('inputFiles') then begin
      sinputFiles := getOptionValue('inputFiles');
      Split(':', sinputFiles, GTMOptions.linputFiles);
      GTMOptions.numberOfInputFiles := GTMOptions.linputFiles.count;
      GTMOptions.inputFile := GTMOptions.linputFiles[0];
     end;


    if HasOption('b') then
    begin
      GTMOptions.dobatch := True;
      WRITELN;
      WRITELN('****BATCH****');
      Writeln;
    end;

    if (hasOption('m') and (GTMOptions.doBatch=TRUE) and not hasOption('batchM')) then begin
      sbatchM := IntToStr(GTMOptions.sqrtCenters) + ':' + '1' + ':' + IntToStr(GTMOptions.sqrtCenters);
      Split(':', sbatchM, GTMOptions.lbatchM);
    end;

     if (hasOption('k') and (GTMOptions.doBatch=TRUE) and not hasOption('batchK')) then begin
      sbatchK := IntToStr(GTMOptions.sqrtSamples) + ':' + '1' + ':' + IntToStr(GTMOptions.sqrtSamples);
      Split(':', sbatchK, GTMOptions.lbatchK);
    end;

    if HasOption('limit') then
      GTMOptions.convergenceCriterion := StrToFloat(getOptionValue('limit'));

      if HasOption('magnificationFactors') then
      GTMOptions.computeMagnificationFactors := TRUE;

    if HasOption('incremental') then
      GTMOptions.doIncrement := True;

    if ((GTMOptions.inputFile = '') and ( (not HasOption('t')) and (not HasOption('computeKernels')) and (not HasOption('kernel')) and (not HasOption('dissimilarity')) and (not HasOption('computeDissimilarities'))))  then
    begin
      writeln('ERROR: missing input file');
      WriteHelp;
      FreeAndNil(GTMData);
      FreeAndNil(GTMOptions);
      Terminate;
      Exit;
    end;

    if HasOption('t') then
    begin
      theStringArray := convertToSVM(GTMOptions.inputFile);
      GTMOptions.inputFile := GTMOptions.inputFile + '.svm';
      writeStringMatrixToFile(theStringArray, GTMOptions.inputFile);
    end;

    if HasOption('p') then
    begin
      sp := GetOptionValue('p');
      GTMOptions.prop := StrToFloat(sp);
    end else sp := '0.0';





    if HasOption('f') then
    begin
      GTMOptions.nfactors := StrToInt(GetOptionValue('f'));
    end
    else
    begin
      GTMOptions.nfactors := 0;
    end;


    if HasOption('n') then
    begin
      startCounting;
      modout := GTMOptions.outputfile;

      if hasoption('y') then GTMOptions.discardedDescriptors := GetOptionValue('y');
      if hasoption('scaling') then GTMOptions.scaling := GetOptionValue('scaling');
      GTMData.initData(GTMOptions);
      writeln('Number of molecules: ' + IntToStr(GTMData.nMolecules));
      writeln('Number of descriptors: ' + IntToStr(GTMOptions.nDimensions));
      writeln;
      //theStringArray := matrixToSVMFormat(GTMData.matT);
      Writeln;

      If hasOption('p') or hasOption('f') or hasOption('y') then modout += '_cleaned';
      if hasoption('f') then modout += '_pca';
      if GTMOptions.normalize then modout += '_norm';
       modout += '.svm';

     Writeln('Name of output file: ' + modout);

      //writeStringMatrixToFile(theStringArray, GTMOptions.inputFile);
      //writeSVMMatrixToFile(GTMData.matT, GTMOptions.outputfile+'_cleaned.svm');
      stopCounting;
      FreeAndNil(GTMData);
      FreeAndNil(GTMOptions);
      Terminate;
      Exit;
    end;


        if ((HasOption('computeKernels') or HasOption('computeDissimilarities')) and HasOption('train')) then
    begin
      startCounting;
      GTMOptions.inputFile := GetOptionValue('train');
      GTMData.initData(GTMOptions);

      GTMManifold := RGTMManifold.create;
      writeln('Number of molecules in training file: ' + IntToStr(GTMData.nMolecules));
      writeln('Number of descriptors in training file: ' + IntToStr(GTMOptions.nDimensions));
      //matKTrain := FKERNELCreateMatK(GTMData.matT, GTMData.nMolecules, GTMOptions.nDimensions, GTMOptions.kernelType);
      //writeMatrixToFile(matKTrain, GTMOptions.outputfile+'_kernelTrain.txt','training set kernel');

      if HasOption('test') then begin
        GTMOptions.inputFile := getOptionValue('test');
        GTMDataTest := RGTMData.Create;
        GTMDataTest.initData(GTMOptions);
        writeln('Number of molecules in test file: ' + IntToStr(GTMDataTest.nMolecules));
        writeln('Number of descriptors in test file: ' + IntToStr(GTMOptions.nDimensions));

        if(HasOption('computeKernels') ) then begin
        GTMManifold.FKERNELCreateMatKTrainTest(GTMData.matT, GTMDataTest.matT, GTMData.nMolecules, GTMDataTest.nMolecules, GTMOptions.nDimensions, GTMOptions);
        writeMatrixToFile(GTMManifold.matKTestVTrain, GTMOptions.outputfile+'_kernelTestVTrain.txt','test set kernel (rows = test instances, columns = training instances)');
        writeMatrixToFile(GTMManifold.matKTrain, GTMOptions.outputfile+'_kernelTrain.txt','training set kernel');
        writeMatrixToFile(GTMManifold.matKTest, GTMOptions.outputfile+'_kernelTest.txt','test set kernel');
        end
        else if(HasOption('computeDissimilarities')) then begin

        GTMManifold.FDISSIMILARITYCreateMatDissimilarityTrainTest(GTMData.matT, GTMDataTest.matT, GTMData.nMolecules, GTMDataTest.nMolecules, GTMOptions.nDimensions, GTMOptions);
        writeMatrixToFile(GTMManifold.matDissimilarityTestVTrain, GTMOptions.outputfile+'_dissimilarityTestVTrain.txt','test set kernel (rows = test instances, columns = training instances)');
        writeMatrixToFile(GTMManifold.matDissimilarityTrain, GTMOptions.outputfile+'_dissimilarityTrain.txt','training set kernel');

          end;
      end else begin
        if(HasOption('computeKernels') ) then begin
        GTMManifold.matKTrain := FKERNELCreateMatK(GTMData.matT, GTMData.nMolecules, GTMOptions.nDimensions, GTMOptions);
        writeMatrixToFile(GTMManifold.matKTrain, GTMOptions.outputfile+'_kernelTrain.txt','training set kernel');
        end
        else if (HasOption('computeDissimilarities')) then
        begin
        GTMManifold.matDissimilarityTrain := FDISSIMILARITYCreateMatDissimilarity(GTMData.matT, GTMData.nMolecules, GTMOptions.nDimensions, GTMOptions);
        writeMatrixToFile(GTMManifold.matDissimilarityTrain, GTMOptions.outputfile+'_dissimilarityTrain.txt','training set kernel');
          end;
      end;
      stopCounting;
      FreeAndNil(GTMData);
      FreeAndNil(GTMDataTest);
      SetLength(theStringArray,0, 0);
      SetLength(dataMatrix, 0, 0);
      Terminate;
      Exit;
    end;





    if HasOption('r') then
    begin
      GTMOptions.randomize := True;
    end;





    if HasOption('a') then
    begin
      GTMOptions.computeManifold := True;
    end;

    if HasOption('s') then
    begin
      GTMOptions.evalSolidAngles := True;
    end;

    if HasOption('d') then
    begin
      GTMOptions.evalDistances := True;
    end;






    if HasOption('v') then
    begin
      sv := GetOptionValue('v');
      GTMOptions.nfolds := StrToInt(sv);
      GTMOptions.performCV := True;
    end;

    // start time counting
    startCounting;



    if hasOption('kernelFile') then begin
      GTMOptions.kernel := True;
    GTMOptions.kernelFile := getOptionValue('i');
    end;

    if hasOption('dissimilarityFile') then begin
      GTMOptions.dissimilarity := True;
    GTMOptions.dissimilarityFile := getOptionValue('i');
    end;


    if ((GTMOptions.kernel=TRUE)) then begin
    if hasOption('train') then GTMOptions.kernelTrain := getOptionValue('train');
    if hasOption('test') then GTMOptions.kernelTest := getOptionValue('test');
    if hasOption('testVtrain') then GTMOptions.kernelTestVTrain := getOptionValue('testVtrain');
    if hasOption('nDim') then GTMOptions.nDimensions := StrToInt(getOptionValue('nDim'));
    end else if (GTMOptions.dissimilarity) then begin
    if hasOption('train') then GTMOptions.dissimilarityTrain := getOptionValue('train');
    if hasOption('testVtrain') then GTMOptions.dissimilarityTestVTrain := getOptionValue('testVtrain');
    if hasOption('nDim') then GTMOptions.nDimensions := StrToInt(getOptionValue('nDim'));
    end;




    (*END OPTIONS*);


    if ((GTMOptions.doProjection=TRUE) and (GTMOptions.kernel=TRUE) and (GTMOptions.regress=FALSE) and (GTMOptions.classify=FALSE)) then begin
      KERNELperformProjection(GTMOptions);
      Terminate;
      Exit;
    end;


    if (not((GTMOptions.kernel=TRUE) and (GTMOptions.doProjection=TRUE)) and (GTMOptions.kernelFile='') and (GTMOptions.dissimilarityFile='')) then begin



    // Dimensions and number of molecules
    if GTMOptions.doIncrement=FALSE then GTMData.initData(GTMOptions);


    If ((GTMOptions.doIncrement) and (HasOption('inputFiles')=FALSE) and (GTMOptions.sparse))
      then GTMOptions.nDimensions := GTMData.readMolsAndNonNullValues(GTMOptions.inputFile);

    If ((GTMOptions.doIncrement) and (HasOption('inputFiles')=FALSE) and (not GTMOptions.sparse))
      then GTMOptions.nDimensions := GTMData.readMols(GTMOptions.inputFile);

    If ((GTMOptions.doIncrement) and (HasOption('inputFiles')=TRUE) and (GTMOptions.sparse))
      then GTMOptions.nDimensions := GTMData.ReadMolsAndNonNullValues(GTMOptions.linputFiles[0]);

    If ((GTMOptions.doIncrement) and (HasOption('inputFiles')=TRUE) and (not GTMOptions.sparse))
      then GTMOptions.nDimensions := GTMData.ReadMols(GTMOptions.linputFiles[0]);



    GTMData.nMolecules := GTMData.mols.Count;
    writeln('Number of molecules: ' + IntToStr(GTMData.nMolecules));
    writeln('Number of descriptors: ' + IntToStr(GTMOptions.nDimensions));
    writeln;


    end;



    {$IFDEF ShortVersion}
    if (GTMData.nMolecules > 10000) then
    begin
      Writeln;
      Writeln('TOO MANY MOLECULES (> 10000) FOR THIS LIGHT VERSION.');
      Writeln;
      Writeln;

      Terminate;
      Exit;
    end;
    {$ENDIF}


    if (GTMOptions.nfactors > GTMOptions.nDimensions) then
    begin
      Writeln;
      Writeln('ERROR: number of principal components superior to number of dimensions.');
      Terminate;
      Exit;
    end;



    gtmOptions.writeMe := TRUE;


    // external test set classification

    if (((GTMOptions.classify = TRUE) or (GTMOptions.regress= TRUE)) and (GTMOptions.performCV = FALSE)) then begin
       GTMDataTest := RGTMData.Create;
       sy := GTMOptions.inputFile;
       if GTMOptions.kernel=FALSE then begin
       GTMOptions.inputFile := GetOptionValue('test');
       GTMDataTest.initData(GTMOptions);
        end;
       GTMOptions.inputFile := sy;

       if GTMOptions.classify = TRUE then begin
          sa :=GetOptionValue('classes');
          activities := loadArray(sa);
      GTMDataTest.ClassModel.activities := TVector(activities);
      DimVector(GTMDataTest.ClassModel.activities, high(GTMDataTest.ClassModel.activities)+1);
      GTMDataTest.ClassModel.numberOfClasses := TRUNC(VectorMax(GTMDataTest.ClassModel.activities));
       end else begin
       sa :=GetOptionValue('activities');
       activities := loadArray(sa);
      GTMDataTest.RegModel.activities := TVector(activities);
      DimVector(GTMDataTest.RegModel.activities, high(GTMDataTest.RegModel.activities)+1);
   end ;


 sy := GetOptionValue('y');
      GTMOptions.projectionFile := sy;
     if GTMOPtions.kernel = FALSE then performSimplePrediction(GTMData, GTMDataTest, GTMOptions)
     else KERNELperformSimplePrediction(GTMData, GTMDataTest, GTMOptions);
      FreeAndNil(GTMDataTest);


    end else

    begin

    if HasOption('reverseProjection') then
    GTMOptions.reverseProjectionFile := getOptionValue('reverseProjection');


     if (HasOption('INCRPCA')) then begin
        GTMNextData := RGTMData.Create;
        PCAIncrementalWithSeveralFiles(GTMData, GTMNextData,GTMOptions);
     end;


    // run GTM algorithm
    if ((GTMOptions.doProjection = TRUE) and (GTMOptions.kernel=FALSE)) then begin
    if GTMOptions.reverseProjectionFile='' then performProjection(GTMData, GTMOptions) else performReverseProjection(GTMData, GTMOptions)
    end
    else if ((GTMOptions.dobatch = False) and (GTMOptions.performCV = False)) then
    runGTM(GTMData, gtmOptions)
    else if ((GTMOptions.dobatch = True) and (GTMOptions.performCV = False)) then
    runbatchGTM(GTMData, gtmOptions)
    else if ((GTMOptions.dobatch = False) and (GTMOptions.performCV = True)) then
    performCrossValidation(GTMData, GTMOptions)
    else if ((GTMOptions.dobatch = True) and (GTMOptions.performCV = True)) then
    batchCrossValidation(GTMData, GTMOptions);
    end;

    // stop time counting
    stopCounting;

    // stop program loop
    FreeAndNil(GTMOptions);
    FreeAndNil(GTMData);}
    FreeAndNil(GTMOptions);
    Terminate;

  end;

  constructor TGTMapTool.Create(TheOwner: TComponent);
  begin
    inherited Create(TheOwner);
    StopOnException := True;
  end;

  destructor TGTMapTool.Destroy;
  begin
    inherited Destroy;
  end;

  procedure TGTMapTool.WriteHelp;
  begin
    Writeln('//////////////');
    Writeln('GTMapTool help');
    Writeln('//////////////');
    Writeln;
    Writeln('-h, --help');
    Writeln(#9 + 'get help');
    Writeln('-i, --input');
    Writeln(#9 + 'svm input file');
    Writeln(#9 + '(-i myfile.svm)');
    Writeln('-o, --output');
    Writeln(#9 + 'output file');
    Writeln('-w, --width');
    Writeln(#9 + 'width factor for radial basis functions');
    Writeln(#9 + '(-w 1.5)');
    Writeln('-m, --nTrait');
    //Writeln(#9 + 'square root of the number of RBF centers');
    //Writeln(#9 + '(-m 5 for 25 centers)');
    Writeln(#9 + 'number of RBF centers');
    Writeln(#9 + '(-m 5, for 5 RBF)');
    Writeln('-k, --nSample');
    //Writeln(#9 + 'square root of the number of grid points');
    //Writeln(#9 + '(-k 25 for 625 points)');
    Writeln(#9 + 'number of grid points');
    Writeln(#9 + '(-k 125, for 125 sampling points)');
    Writeln('-l, --regularization');
    Writeln(#9 + 'regularization coefficient, usually between 0 and 100');
    Writeln(#9 + '(-l 10.0)');
    //Writeln('-r');
    //Writeln(#9 + 'random initialization of W matrix (GTM parameters)');
    //Writeln(#9 + '(no argument)');
    //Writeln('-f');
    //Writeln(#9 + 'apply PCA before GTM');
    //Writeln(#9 + '(-f 20 for selecting 20 variables)');
    //Writeln('-t');
    //writeln(#9 + 'input .dat instead of .svm with (tab-separated values)');
    //Writeln(#9 + '(no argument)');
    //Writeln('-p');
    //Writeln(#9 + 'clean input file by selecting descriptors with a minimum % of non-null values');
    //Writeln(#9 + '(-p 0.01 for at least 1% of non-null values)');
    Writeln('-c, --nIter');
    Writeln(#9 + 'number of iterations');
    Writeln(#9 + '(-c 100)');
    Writeln('-b, --blocks');
    Writeln(#9 + 'number of instances per block for incremental or per block algorithm');
    Writeln(#9 + '(-b 1000)');
    //Writeln(#9 + 'find best values for -l, -w, -k and -m');
    //Writeln(#9 + '(no argument)');
    //Writeln('-v');
    //Writeln(#9 + 'perform crossvalidation');
    //Writeln(#9 + '(-v 3 for 3 folds)');
    Writeln('-j, --DoProj');
    Writeln('-y, --NewData');
    Writeln(#9 + 'perform projection of training data');
    Writeln(#9 + '(no argument)');
    Writeln(#9 + '(-j -y model_projection.xml)');
    Writeln(#9 + 'dataset to project');
    Writeln(#9 + '(-j -y toproject.svm)');
    Writeln('-x, --xml');
    Writeln(#9 + 'input model for projection');
    Writeln(#9 + '(-x model_projection.xml)');
    Writeln('--3D');
    Writeln(#9 + 'compute manifold and data coordinates in PCA 3D space');
    Writeln(#9 + '(no argument)');
    Writeln('-p, --preprocess');
    Writeln(#9 + 'pre-processing');
    Writeln(#9 + '0: no pre-processing; 1: standardization; 2: center; 3: normalization into [-1,1]; 4: normalization into [-1,1] then center');
    //Writeln('-s'); Writeln(#9+'compute solid angles'); Writeln(#9+'(no argument)');
    Writeln('-z, --limit');
    Writeln(#9+'convergence criteria');
    Writeln(#9+'(-z 0.001)');
    Writeln('--ScaleInit=[0|1|2]');
    Writeln(#9+'initial geometry of the manifold (0: standard; 1: max extension; 2:<float>: scale the initial geometry by <float>)');
    Writeln(#9+'(--ScaleInit=0)');
    Writeln('--PC123 filePC123.mat'); Writeln(#9+'Use pre-computed three first principal components');
    Writeln(#9+'(File name in .mat format. The first line of data should be the eigenvalues.)');
    Writeln('--licence licence.dat');
    Writeln(#9 + 'licence file if not at usual place.');
    Writeln('--getRmat');
    Writeln(#9 + 'If this option is present, the file containing responsibilities in non-sparse format is produced');
    Writeln('--CfgXml=[1|2]:filename');
    Writeln(#9 + 'Create or use XML file of configuration');
    Writeln(#9 + '(--CfgXml=1) : Creates a configuration XML with the default filename (GTMConfig.xml)');
    Writeln(#9 + '(--CfgXml=1:filename) : Creates a configuration XML with the given filename');
    Writeln(#9 + '(--CfgXml=2:filename) : Uses a configuration XML with the given filename');
    //Writeln('--batchW');
    //Writeln(#9 + 'define set of values for k to use with -b or -b -v; syntax: begin:step:end');
    //Writeln(#9 + '(--batchW=0.5:0.5:2)');
    //Writeln('--batchL');
    //Writeln(#9 + 'define set of values for log10(l) to use with -b or -b -v; syntax: begin:step:end');
    //Writeln(#9 + '(--batchL=-2:1:2)');
    //Writeln('--batchM');
    //Writeln(#9 + 'define set of values for m to use with -b or -b -v; syntax: begin:step:end');
    //Writeln(#9 + '(--batchM=4:1:6)');
    //Writeln('--batchK');
    //Writeln(#9 + 'define set of values for k to use with -b or -b -v; syntax: begin:step:end');
    //Writeln(#9 + '(--batchK=10:5:20)');
    //Writeln('--limit');
    //Writeln(#9 + 'convergence criterion');
    //Writeln(#9 + '(--limit=0.001)');
    //Writeln('--classes');
    //Writeln(#9 + 'labels (one value per line, first line is a comment)');
    //Writeln(#9 + '(--classes=labelFilePath.txt)');
    //Writeln('--activities');
    //Writeln(#9 + 'activities (one value per line, first line is a comment)');
    //Writeln(#9 + '(--activities=activityFilePath.txt)');
    //Writeln('--test');
    //Writeln(#9 + 'external test set');
    //Writeln(#9 + '(--test=externalTestSetPath.svm)');
    //Writeln('--magnificationFactors');
    //Writeln(#9 + 'compute magnification factors for classical GTM');
    //Writeln(#9 + '(--magnificationFactors)');
    //Writeln('--noNormalization');
    //Writeln(#9 + 'do not normalize data');
    //Writeln(#9 + '(--noNormalization)');
    //Writeln('--scaling');
    //Writeln(#9 + 'use file with min and max values for normalizing descriptors');
    //Writeln(#9 + '(-n --scaling=myoutput_scaling.txt)');
    //Writeln('-n -y');
    //Writeln(#9 + 'use file for discarding descriptors');
    //Writeln(#9 + '(-n -y myoutput_discarded.txt)');
    //Writeln('--missing');
    //Writeln(#9 + 'computes missing values with attribute value NAN in svm file (format: 1:NAN)');
    //Writeln(#9 + '(no argument)');
    //Writeln('--NIPALS');
    //Writeln(#9 + 'use NIPALS algorithm for PCA: speeds up things for higher dimensions');
    //Writeln(#9 + '(no argument)');
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
    Writeln('$ GTMapTool -x myGTM.xml -o output -j -y test.svm');
    Writeln;
    Writeln('- Continue training an existing model, then project the training data: ');
    Writeln('$ GTMapTool -i train.svm -x myGTM.xml -o output -j');
    Writeln;
  end;

var
  Application: TGTMapTool;

  //{$IFDEF WINDOWS}{$R TGTMapTool.rc}{$ENDIF}

{$R *.res}

begin
  {$IfDef WINDOWS}DefaultFormatSettings.DateSeparator:='-';{$EndIf}
  {$IfDef LOCALES}DefaultFormatSettings.DecimalSeparator:='.';DefaultFormatSettings.ShortDateFormat:='d/m/y';{$EndIf}
  Application := TGTMapTool.Create(nil);
  Application.Run;
  Application.Free;
end.
