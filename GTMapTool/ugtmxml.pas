unit UGTMXML;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, XMLRead, XMLWrite, DOM, ugtm_options, UGTMBase, UGTMFull,
  UGTMSparse, UcGTM, UiGTM, UGTMMN, utypes, ulinalg, typinfo;

type

  { TGTMXML }

  TGTMXML = class(TObject)
  private
    frootnode, fnode, fchildnode: TDOMElement;
    fdoc: TXMLDocument;
  public
    procedure WriteGTMModel(aGTM: TGTMBase; xmlnme: string);
    procedure WriteGTMConfig(aGTMOpt: TRGtmOptions; xmlnme: string);
    procedure ReadGTMModel(aGTMBase: TGTMBase; xmlnme: string);
    procedure ReadGTMModel(aGTMFull: TGTMFull; xmlnme: string);
    procedure ReadGTMModel(aGTMSparse: TGTMSparse; xmlnme: string);
    procedure ReadGTMModel(aGTMOpt: TRGtmOptions; xmlnme: string);
    procedure ReadGTMConfig(aGTMOpt: TRGtmOptions; xmlnme: string);
    procedure ReadNode(aGTMBase: TGTMBase);
    procedure ReadNode(aGTMFull: TGTMFull);
    procedure ReadNode(aGTMSparse: TGTMSparse);
    constructor Create;
    destructor Destroy; override;
  end;

procedure WriteGTMMat(aGTM: TGTMBase; flename: string; b3D, bRmat: boolean);

implementation

{ TGTMXML }

procedure WriteGTMMat(aGTM: TGTMBase; flename: string; b3D, bRmat: boolean);
var
  sl: TStringList;
  WPhi3D: TMatrix;
  ik, ii, id: integer;
  cGTM: TcGTM;
  s: string;
  fsOut: TFileStream;
begin
  WPhi3D := nil;
  sl := TStringList.Create;
  if aGTM.R <> nil then
  begin
    if bRmat then
    begin
      sl.Clear;
      PrintMatT(aGTM.R, 'R', 1, aGTM.K, 1, aGTM.N, sl);
      if not FileExists(ChangeFileExt(flename, 'R.mat')) then
        sl.SaveToFile(ChangeFileExt(flename, 'R.mat'))
      else
      begin
        fsOut := TFileStream.Create(ChangeFileExt(flename, 'R.mat'), fmOpenReadWrite);
        fsOut.Seek(0, soFromEnd);
        sl.SaveToStream(fsOut);
        FreeAndNil(fsOut);
      end;
      sl.Clear;
    end;
    //Save responsibilities as SVM, the first column are loglikelyhood contribution of the compound
    for ii := 1 to aGTM.N do
    begin
      if (aGTM is TcGTM) then
        s := FloatToStrF(TcGTM(aGTM).LLM[ii], ffGeneral, 8, 5)
      else
        s := '?';
      for ik := 1 to aGTM.K - 1 do
        if aGTM.R[ik, ii] > 1E-5 then
          s := s + ' ' + IntToStr(ik) + ':' + FloatToStrF(aGTM.R[ik, ii], ffGeneral, 8, 5);
      ik := aGTM.K;
      if aGTM.R[ik, ii] > 1E-5 then
        s := s + ' ' + IntToStr(ik) + ':' + FloatToStrF(aGTM.R[ik, ii], ffGeneral, 8, 5)
      else
        s := s + ' ' + IntToStr(ik) + ':0';
      sl.Add(s);
    end;
    if not FileExists(ChangeFileExt(flename, 'R.svm')) then
      sl.SaveToFile(ChangeFileExt(flename, 'R.svm'))
    else
    begin
      fsOut := TFileStream.Create(ChangeFileExt(flename, 'R.svm'), fmOpenReadWrite);
      fsOut.Seek(0, soFromEnd);
      sl.SaveToStream(fsOut);
      FreeAndNil(fsOut);
    end;
    sl.Clear;
  end;
  if aGTM.matPrj <> nil then
  begin
    sl.Clear;
    PrintMat(aGTM.matPrj, 'Proj', 1, aGTM.N, 1, 2, sl);
    if not FileExists(ChangeFileExt(flename, 'Prj.mat')) then
      sl.SaveToFile(ChangeFileExt(flename, 'Prj.mat'))
    else
    begin
      fsOut := TFileStream.Create(ChangeFileExt(flename, 'Prj.mat'), fmOpenReadWrite);
      fsOut.Seek(0, soFromEnd);
      sl.SaveToStream(fsOut);
      FreeAndNil(fsOut);
    end;
    sl.Clear;
  end;
  if (aGTM is TcGTM) and (b3D = True) then
  begin
    cGTM := aGTM as TcGTM;
    sl.Clear;
    PrintMat(cGTM.matY, 'WPhi', 1, cGTM.K, 1, cGTM.D, sl);
    sl.SaveToFile(ChangeFileExt(flename, 'WPhi.mat'));
    sl.Clear;
    EuclideanNormalizeByColumn(cGTM.PC123,1,cGTM.D,1,3);
    PrintMat(cGTM.PC123, 'PC123', 0, cGTM.D, 1, 3, sl); //Dim 0 are eigenvalues
    sl.SaveToFile(ChangeFileExt(flename, 'PC123.mat'));
    sl.Clear;
    DimMatrix(WPhi3D, cGTM.K, 3);
    for ik := 1 to cGTM.K do
      for ii := 1 to 3 do
      begin
        WPhi3D[ik, ii] := 0;
        for id := 1 to cGTM.D do
        begin
          WPhi3D[ik, ii] := WPhi3D[ik, ii] + cGTM.matY[ik, id] * cGTM.PC123[id, ii];
        end;
      end;
    sl.Clear;
    PrintMat(WPhi3D, 'WPhi3D', 1, cGTM.K, 1, 3, sl);
    sl.SaveToFile(ChangeFileExt(flename, 'WPhi3D.mat'));
    sl.Clear;
  end;
  FreeAndNil(sl);
end;

procedure TGTMXML.WriteGTMModel(aGTM: TGTMBase; xmlnme: string);
var
  sl: TStringList;
  aGTMFull: TGTMFull;
  aGTMSparse: TGTMSparse;
  lPC123: TMatrix;
  id,im,ik: integer;
  stmp: string;
begin
  sl := TStringList.Create;
  if (fdoc = nil) then
    fdoc := TXMLDocument.Create;
  frootnode := fdoc.CreateElement('GTM');
  fdoc.AppendChild(frootnode);
  if (aGTM is TcGTM) then
    frootnode.SetAttribute('Type', 'BISHOP');
  if (aGTM is TiGTM) then
    frootnode.SetAttribute('Type', 'BISHOP');
  if (aGTM is TuGTMMN) then
    frootnode.SetAttribute('Type', 'MULTINOMIAL');
  frootnode.SetAttribute('N', IntToStr(aGTM.N));
  frootnode.SetAttribute('D', IntToStr(aGTM.D));
  frootnode.SetAttribute('nIter', IntToStr(aGTM.nIter));
  if aGTM is TGTMFull then
  begin
    aGTMFull := (aGTM as TGTMFull);
    frootnode.SetAttribute('Preprocess', IntToStr(aGTMFull.istd));
    if (aGTM is TcGTM) or (aGTM is TiGTM) then
    begin
      //Mean
      fnode := fdoc.CreateElement('Mean');
      frootnode.AppendChild(fnode);
      sl.Clear;
      fnode.SetAttribute('D', IntToStr(aGTMFull.D));
      PrintVec(aGTMFull.Mean, 1, aGTMFull.D, sl);
      fnode.AppendChild(fdoc.CreateTextNode(sl.Text));
      //SD
      fnode := fdoc.CreateElement('SD');
      frootnode.AppendChild(fnode);
      sl.Clear;
      fnode.SetAttribute('D', IntToStr(aGTMFull.D));
      PrintVec(aGTMFull.SD, 1, aGTMFull.D, sl);
      fnode.AppendChild(fdoc.CreateTextNode(sl.Text));
      //PC123 - 3 first principal components
      fnode := fdoc.CreateElement('PC123');
      frootnode.AppendChild(fnode);
      sl.Clear;
      fnode.SetAttribute('D', IntToStr(aGTMFull.D));
      fnode.SetAttribute('EV1',FloatToStr(aGTMFull.PC123[0,1]));
      fnode.SetAttribute('EV2',FloatToStr(aGTMFull.PC123[0,2]));
      fnode.SetAttribute('EV3',FloatToStr(aGTMFull.PC123[0,3]));
      lPC123:=aGTMFull.PC123;
      EuclideanNormalizeByColumn(aGTMFull.PC123,1,aGTMFull.D,1,3);
      PrintMatFullPrec(aGTMFull.PC123, 1, aGTMFull.D, 1, 3, sl);
      fnode.AppendChild(fdoc.CreateTextNode(sl.Text));
    end;
    //Manifold distribution
    fnode := fdoc.CreateElement('Manifold');
    frootnode.AppendChild(fnode);
    fnode.SetAttribute('K', IntToStr(aGTMFull.K));
    fnode.SetAttribute('M', IntToStr(aGTMFull.M));
    fnode.SetAttribute('D', IntToStr(aGTMFull.D));
    fnode.SetAttribute('sigma', FloatToStrF(aGTMFull.sigma, ffFixed, 8, 5));
    if (aGTM is TcGTM) or (aGTM is TiGTM) then
    begin
      fnode.SetAttribute('beta', FloatToStrF(aGTMFull.beta, ffFixed, 8, 5));
      fnode.SetAttribute('alpha', FloatToStrF(TcGTM(aGTM).alpha, ffFixed, 8, 5));
    end;
    sl.Clear;
    {To test the effect of the floating point precision of W
    for id:=1 to aGTM.D do
    begin
      stmp:=FloatToStr(aGTM.W[id,0]);
      for im:=1 to aGTM.M do
      begin
        stmp:=stmp+','+FloatToStr(aGTM.W[id,im]);
      end;
      sl.Add(stmp);
    end;}
    PrintMat(aGTM.W, 1, aGTM.D, 0, aGTM.M, sl); //Write nodes coordinates
    fnode.AppendChild(fdoc.CreateTextNode(sl.Text));
  end;
  if aGTM is TGTMSparse then
  begin
    aGTMSparse := (aGTM as TGTMSparse);
    //Manifold distribution
    fnode := fdoc.CreateElement('Manifold');
    frootnode.AppendChild(fnode);
    fnode.SetAttribute('K', IntToStr(aGTMSparse.K));
    fnode.SetAttribute('M', IntToStr(aGTMSparse.M));
    fnode.SetAttribute('D', IntToStr(aGTMSparse.D));
    fnode.SetAttribute('sigma', FloatToStrF(aGTMSparse.sigma, ffFixed, 8, 5));
    sl.Clear;
    PrintMat(aGTM.W, 1, aGTM.D, 0, aGTM.M, sl);
    fnode.AppendChild(fdoc.CreateTextNode(sl.Text));
  end;
  //Save latent space samples
  fnode := fdoc.CreateElement('LatentSamples');
  frootnode.AppendChild(fnode);
  sl.Clear;
  PrintMat(aGTM.matX, 1, aGTM.K, 1, 2, sl);
  fnode.AppendChild(fdoc.CreateTextNode(sl.Text));
  //--Selected nodes
  fchildnode := fdoc.CreateElement('SelectedNodes');
  fnode.AppendChild(fchildnode);//child of LatentSamples
  sl.Clear;
  for ik:=1 to aGTM.K do
    if aGTM.SelNode[ik] then sl.Add('1') else sl.Add('0');
  fchildnode.AppendChild(fdoc.CreateTextNode(sl.Text));
  //Save latent space RBF centers
  fnode := fdoc.CreateElement('LatentTraits');
  frootnode.AppendChild(fnode);
  sl.Clear;
  PrintMat(aGTM.matM, 1, aGTM.M, 1, 2, sl);
  fnode.AppendChild(fdoc.CreateTextNode(sl.Text));
  //Write file
  WriteXMLFile(fdoc, xmlnme);
  FreeAndNil(sl);
end;


procedure TGTMXML.WriteGTMConfig(aGTMOpt: TRGtmOptions; xmlnme: string);
var
  sl: TStringList;
  aGTMFull: TGTMFull;
  aGTMSparse: TGTMSparse;
  lPC123: TMatrix;
  ik: integer;
  s: string;
  gtype: EGTMType;
begin
  sl := TStringList.Create;
  if (fdoc = nil) then
    fdoc := TXMLDocument.Create;
  frootnode := fdoc.CreateElement('GTMOptions');
  //Option by option
  //input: type:: output: nSample: nTrait: width: regularization: nIter: limit: DoProj:: NewData: xml: blocks: 3D preprocess getRmat licence: ScaleInit: PC123: CfgXml:
  //Input
  fnode := fdoc.CreateElement('Input');
  fnode.AppendChild(fdoc.CreateTextNode(aGTMOpt.inputFile));
  frootnode.AppendChild(fnode);

  //Type
  fnode := fdoc.CreateElement('Type');
  fnode.AppendChild(fdoc.CreateTextNode(GetEnumName(TypeInfo(aGTMOpt.GTMType),ord(gtype))));
  frootnode.AppendChild(fnode);

  //Output
  fnode := fdoc.CreateElement('Output');
  fnode.AppendChild(fdoc.CreateTextNode(aGTMOpt.outputFile));
  frootnode.AppendChild(fnode);

  //nSample
  fnode := fdoc.CreateElement('nSample');
  fnode.AppendChild(fdoc.CreateTextNode(IntToStr(aGTMOpt.nSamples)));
  frootnode.AppendChild(fnode);

  //nTrait
  fnode := fdoc.CreateElement('nTrait');
  fnode.AppendChild(fdoc.CreateTextNode(IntToStr(aGTMOpt.nCenters)));
  frootnode.AppendChild(fnode);

  //width
  fnode := fdoc.CreateElement('width');
  fnode.AppendChild(fdoc.CreateTextNode(FloatToStr(aGTMOpt.sigma)));
  frootnode.AppendChild(fnode);

  //regularization
  fnode := fdoc.CreateElement('regularization');
  fnode.AppendChild(fdoc.CreateTextNode(FloatToStr(aGTMOpt.alpha)));
  frootnode.AppendChild(fnode);

  //nIter
  fnode := fdoc.CreateElement('nIter');
  fnode.AppendChild(fdoc.CreateTextNode(IntToStr(aGTMOpt.nIter)));
  frootnode.AppendChild(fnode);

  //limit
  fnode := fdoc.CreateElement('limit');
  fnode.AppendChild(fdoc.CreateTextNode(FloatToStr(aGTMOpt.convCriteria)));
  frootnode.AppendChild(fnode);

  //DoProj
  fnode := fdoc.CreateElement('DoProj');
  fnode.AppendChild(fdoc.CreateTextNode(BoolToStr(aGTMOpt.doProjection, True)));
  frootnode.AppendChild(fnode);

  //NewData
  fnode := fdoc.CreateElement('NewData');
  fnode.AppendChild(fdoc.CreateTextNode(aGTMOpt.projFile));
  frootnode.AppendChild(fnode);

  //xml
  fnode := fdoc.CreateElement('xml');
  fnode.AppendChild(fdoc.CreateTextNode(ChangeFileExt(aGTMOpt.outputFile,'.xml')));
  frootnode.AppendChild(fnode);

  //blocks
  fnode := fdoc.CreateElement('blocks');
  fnode.AppendChild(fdoc.CreateTextNode(IntToStr(aGTMOpt.nBlocks)));
  frootnode.AppendChild(fnode);

  //3D
  fnode := fdoc.CreateElement('p3D');
  fnode.AppendChild(fdoc.CreateTextNode(BoolToStr(aGTMOpt.p3D, True)));
  frootnode.AppendChild(fnode);

  //preprocess
  fnode := fdoc.CreateElement('preprocess');
  fnode.AppendChild(fdoc.CreateTextNode(IntToStr(aGTMOpt.preprocess)));
  frootnode.AppendChild(fnode);

  //getRmat
  fnode := fdoc.CreateElement('getRmat');
  fnode.AppendChild(fdoc.CreateTextNode(BoolToStr(aGTMOpt.Rmat, True)));
  frootnode.AppendChild(fnode);

  //iScaleInit
  fnode := fdoc.CreateElement('iScaleInit');
  fnode.AppendChild(fdoc.CreateTextNode(IntToStr(aGTMOpt.iScaleInit)));
  frootnode.AppendChild(fnode);

  //fScaleInit
  fnode := fdoc.CreateElement('fScaleInit');
  fnode.AppendChild(fdoc.CreateTextNode(FloatToStr(aGTMOpt.fScaleInit)));
  frootnode.AppendChild(fnode);

  //PC123
  fnode := fdoc.CreateElement('PC123');
  fnode.AppendChild(fdoc.CreateTextNode(aGTMOpt.PCAFile));
  frootnode.AppendChild(fnode);

  //CfgXml
  fnode := fdoc.CreateElement('CfgXml');
  fnode.AppendChild(fdoc.CreateTextNode(aGTMOpt.CfgXml));
  frootnode.AppendChild(fnode);


  //Finally, append the <GTMOptions> node to the document
  fdoc.AppendChild(frootnode);

  //Write file
  WriteXMLFile(fdoc, xmlnme);
  FreeAndNil(sl);
end;


procedure TGTMXML.ReadGTMModel(aGTMBase: TGTMBase; xmlnme: string);
var
  stype: string;
begin
  ReadXMLFile(fdoc, xmlnme);
  frootnode := fdoc.DocumentElement;
  stype := frootnode.GetAttribute('Type');
  aGTMBase.N := StrToInt(frootnode.GetAttribute('N'));
  aGTMBase.D := StrToInt(frootnode.GetAttribute('D'));
  aGTMBase.nIter := StrToInt(frootnode.GetAttribute('nIter'));
  fnode := (frootnode.FirstChild as TDOMElement);
  while fnode <> nil do
  begin
    ReadNode(aGTMBase);
    fnode := (fnode.NextSibling as TDOMElement);
  end;
  FreeAndNil(fdoc);
end;

procedure TGTMXML.ReadGTMModel(aGTMFull: TGTMFull; xmlnme: string);
var
  stype: string;
begin
  ReadXMLFile(fdoc, xmlnme);
  frootnode := fdoc.DocumentElement;
  stype := frootnode.GetAttribute('Type');
  aGTMFull.N := StrToInt(frootnode.GetAttribute('N'));
  aGTMFull.D := StrToInt(frootnode.GetAttribute('D'));
  aGTMFull.nIter := StrToInt(frootnode.GetAttribute('nIter'));
  aGTMFull.istd := StrToInt(frootnode.GetAttribute('Preprocess'));
  fnode := (frootnode.FirstChild as TDOMElement);
  while fnode <> nil do
  begin
    ReadNode(aGTMFull);
    fnode := (fnode.NextSibling as TDOMElement);
  end;
  FreeAndNil(fdoc);
  //TGTMBase(aGTMFull).Init;
  //writeln('ICI2');
end;

procedure TGTMXML.ReadGTMModel(aGTMSparse: TGTMSparse; xmlnme: string);
var
  stype: string;
begin
  ReadXMLFile(fdoc, xmlnme);
  frootnode := fdoc.DocumentElement;
  stype := frootnode.GetAttribute('Type');
  aGTMSparse.N := StrToInt(frootnode.GetAttribute('N'));
  aGTMSparse.D := StrToInt(frootnode.GetAttribute('D'));
  aGTMSparse.nIter := StrToInt(frootnode.GetAttribute('nIter'));
  fnode := (frootnode.FirstChild as TDOMElement);
  while fnode <> nil do
  begin
    ReadNode(aGTMSparse);
    fnode := (fnode.NextSibling as TDOMElement);
  end;
  FreeAndNil(fdoc);
end;

procedure TGTMXML.ReadGTMModel(aGTMOpt: TRGtmOptions; xmlnme: string);
var
  nls: TDOMNodeList;
  ik, im: integer;
  KK, MM, D: integer;
  stype, salpha, sistd: string;
  sigma: double;
  sl,sl0: TStringList;
  aMatX, aMatM: TMatrix;
begin
  stype := '';
  salpha := '';
  sigma := -1;
  ReadXMLFile(fdoc, xmlnme);
  frootnode := fdoc.DocumentElement;
  stype := frootnode.GetAttribute('Type');
  if stype = 'BISHOP' then
    aGTMOpt.GTMType := BISHOP
  else if stype = 'INCREMENTAL' then
    aGTMOpt.GTMType := BISHOP
  else if stype = 'MULTINOMIAL' then
    aGTMOpt.GTMType := MULTINOMIAL
  else
    aGTMOpt.GTMType := UNKGTM;
  if (aGTMOpt.GTMType = BISHOP) or (aGTMOpt.GTMType = INCREMENTAL) then
  begin
    sistd := frootnode.GetAttribute('Preprocess');
  end;
  if sistd <> '' then
    aGTMOpt.preprocess := StrToInt(sistd);

  nls := frootnode.GetElementsByTagName('Manifold');
  if nls.Count > 0 then
  begin
    fnode := (nls.Item[0] as TDOMElement);
    KK := StrToInt(fnode.GetAttribute('K'));
    aGTMOpt.nSamples := KK;
    MM := StrToInt(fnode.GetAttribute('M'));
    aGTMOpt.nCenters := MM;
    sigma := StrToFloat(fnode.GetAttribute('sigma'));
    aGTMOpt.sigma := sigma;
    if (aGTMOpt.GTMType = BISHOP) or (aGTMOpt.GTMType = INCREMENTAL) then
    begin
      salpha := fnode.GetAttribute('alpha');
    end;
    if salpha <> '' then
      aGTMOpt.alpha := StrToFloat(salpha);
  end;
  //Read latent samples
  sl := TStringList.Create;
  sl0 := TStringList.Create;
  nls := frootnode.GetElementsByTagName('LatentSamples');
  sl.Clear;
  sl.Text := nls.Item[0].FirstChild.NodeValue;
  DimMatrix(aMatX, aGTMOpt.nSamples, 2);//Carefull! Memory is allocated here
  DimMatrix(aMatM, aGTMOpt.nCenters, 2);
  for ik := 1 to aGTMOpt.nSamples do
  begin
    sl0.Clear;
    sl0.CommaText := sl[ik - 1];
    amatX[ik, 1] := StrToFloat(sl0[0]);
    amatX[ik, 2] := StrToFloat(sl0[1]);
  end;
  nls := frootnode.GetElementsByTagName('LatentTraits');
  //Read latent space RBF centers
  sl.Clear;
  sl.Text := nls.Item[0].FirstChild.NodeValue;
  for im := 1 to aGTMOpt.nCenters do
  begin
    sl0.Clear;
    sl0.CommaText := sl[im - 1];
    amatM[im, 1] := StrToFloat(sl0[0]);
    amatM[im, 2] := StrToFloat(sl0[1]);
  end;
  //Read latent traits
  FreeAndNil(sl);
  FreeAndNil(sl0);
  FreeAndNil(fdoc);
end;

procedure TGTMXML.ReadGTMConfig(aGTMOpt: TRGtmOptions; xmlnme: string);
var
  nls: TDOMNodeList;
  ik, im, cde, iy: integer;
  KK, MM, D: integer;
  sInput, sType, sOutput, snSamples, snTrait, swidth, sregularization, snIter, slimit, sDoProj, sNewData, sxml, sblocks, sp3D: string;
  spreprocess, sgetRmat, siScaleInit, sfScaleInit, sPC123, sCfgXml: string;
  scurrentValue: string;
  sigma: double;
begin
  {Example:
  <Type>BISHOP</Type>
  <nSample>25</nSample>
  <nTrait>1</nTrait>
  <width>4</width>
  <regularization>1</regularization>
  <nIter>100</nIter>
  <limit>0.001</limit>
  <DoProj>False</DoProj>
  <NewData></NewData>
  <xml></xml>
  <blocks>0</blocks>
  <p3D>True</p3D>
  <preprocess>1</preprocess>
  <getRmat>False</getRmat>
  <iScaleInit>0</iScaleInit>
  <fScaleInit>0</fScaleInit>
  <PC123></PC123>}
  scurrentValue := '';
  stype := '';
  sigma := -1;
  ReadXMLFile(fdoc, xmlnme);
  frootnode := fdoc.DocumentElement;

  if(frootnode.GetElementsByTagName('Type').Item[0].FirstChild<>nil) then begin
    scurrentValue := frootnode.GetElementsByTagName('Type').Item[0].FirstChild.NodeValue;
    if stype = 'BISHOP' then
      aGTMOpt.GTMType := BISHOP
    else if stype = 'INCREMENTAL' then
      aGTMOpt.GTMType := BISHOP
    else if stype = 'MULTINOMIAL' then
      aGTMOpt.GTMType := MULTINOMIAL
    else
      aGTMOpt.GTMType := UNKGTM;
    WriteLn('Type : '+scurrentValue);
  end else begin
      WriteLn('Error : No type ! Check your XML file.');
      halt;
  end;

  if(frootnode.GetElementsByTagName('nSample').Item[0].FirstChild<>nil) then begin
    scurrentValue := frootnode.GetElementsByTagName('nSample').Item[0].FirstChild.NodeValue;
    aGTMOpt.nSamples:=StrToInt(scurrentValue);
    WriteLn('Number of grid points : '+scurrentValue);
  end else begin
      WriteLn('Error : No number of grid points (nSample) ! Check your XML file.');
      halt;
  end;

  if(frootnode.GetElementsByTagName('nTrait').Item[0].FirstChild<>nil) then begin
    scurrentValue := frootnode.GetElementsByTagName('nTrait').Item[0].FirstChild.NodeValue;
    aGTMOpt.nCenters:=StrToInt(scurrentValue);
    WriteLn('Number of RBF centers : '+scurrentValue);
  end else begin
      WriteLn('Error : No number of RBF centers (nTrait) ! Check your XML file.');
      halt;
  end;

  if(frootnode.GetElementsByTagName('width').Item[0].FirstChild<>nil) then begin
    scurrentValue := frootnode.GetElementsByTagName('width').Item[0].FirstChild.NodeValue;
    aGTMOpt.sigma:=StrToFloat(scurrentValue);
    WriteLn('Width factor for radial basis functions : '+scurrentValue);
  end else begin
      WriteLn('Error : No width factor for radial basis functions ! Check your XML file.');
      halt;
  end;

  if(frootnode.GetElementsByTagName('regularization').Item[0].FirstChild<>nil) then begin
    scurrentValue := frootnode.GetElementsByTagName('regularization').Item[0].FirstChild.NodeValue;
    aGTMOpt.alpha:=StrToFloat(scurrentValue);
    WriteLn('Regularization coefficient : '+scurrentValue);
  end else begin
      WriteLn('Error : No regularization coefficient ! Check your XML file.');
      halt;
  end;

  if(frootnode.GetElementsByTagName('nIter').Item[0].FirstChild<>nil) then begin
    scurrentValue := frootnode.GetElementsByTagName('nIter').Item[0].FirstChild.NodeValue;
    aGTMOpt.nIter:=StrToInt(scurrentValue);
    WriteLn('Number of iterations : '+scurrentValue);
  end else begin
      WriteLn('Error : No number of iterations (nIter) ! Check your XML file.');
      halt;
  end;

  if(frootnode.GetElementsByTagName('limit').Item[0].FirstChild<>nil) then begin
    scurrentValue := frootnode.GetElementsByTagName('limit').Item[0].FirstChild.NodeValue;
    aGTMOpt.convCriteria:=StrToFloat(scurrentValue);
    WriteLn('Convergence criteria : '+scurrentValue);
  end else begin
      WriteLn('Error : No convergence criteria (limit) ! Check your XML file.');
      halt;
  end;

  {if(frootnode.GetElementsByTagName('DoProj').Item[0].FirstChild<>nil) then begin
    scurrentValue := frootnode.GetElementsByTagName('DoProj').Item[0].FirstChild.NodeValue;
    aGTMOpt.doProjection:=StrToBool(scurrentValue);
    WriteLn('Perform projection of training data : '+scurrentValue);
    if(aGTMOpt.doProjection=True) then begin
      if(frootnode.GetElementsByTagName('NewData').Item[0].FirstChild<>nil) then begin
        scurrentValue := frootnode.GetElementsByTagName('NewData').Item[0].FirstChild.NodeValue;
        aGTMOpt.projFile:=scurrentValue;
        WriteLn('Perform projection on data : '+scurrentValue);
      end else begin
        Val('',iy,cde);
        aGTMOpt.splitFile:=iy; //ATTENTION
        WriteLn('Perform projection on input data');   //ATTENTION
      end;
    end;
  end else begin
      WriteLn('Error : No value for perform projection of training data (DoProj) ! Check your XML file.');
      halt;
  end;}

  if(frootnode.GetElementsByTagName('xml').Item[0].FirstChild<>nil) then begin
    scurrentValue := frootnode.GetElementsByTagName('xml').Item[0].FirstChild.NodeValue;
    aGTMOpt.modelFile:=scurrentValue;
    WriteLn('Input model for projection : '+scurrentValue);
  end else begin
      WriteLn('Error : No value for the input model for projection (xml) ! Check your XML file.');
      halt;
  end;

  if(frootnode.GetElementsByTagName('blocks').Item[0].FirstChild<>nil) then begin
    scurrentValue := frootnode.GetElementsByTagName('blocks').Item[0].FirstChild.NodeValue;
    aGTMOpt.nBlocks:=StrToInt(scurrentValue);
    WriteLn('Number of instances per block for incremental or per block algorithm : '+scurrentValue);
  end else begin
      WriteLn('Error : No value for the number of instances per block for incremental or per block algorithm (blocks) ! Check your XML file.');
      halt;
  end;

  if(frootnode.GetElementsByTagName('p3D').Item[0].FirstChild<>nil) then begin
    scurrentValue := frootnode.GetElementsByTagName('p3D').Item[0].FirstChild.NodeValue;
    aGTMOpt.p3D:=StrToBool(scurrentValue);
    WriteLn('Compute manifold and data coordinates in PCA 3D space : '+scurrentValue);
  end else begin
      WriteLn('Error : No value for compute manifold and data coordinates in PCA 3D space (p3D) ! Check your XML file.');
      halt;
  end;

  if(frootnode.GetElementsByTagName('preprocess').Item[0].FirstChild<>nil) then begin
    scurrentValue := frootnode.GetElementsByTagName('preprocess').Item[0].FirstChild.NodeValue;
    aGTMOpt.preprocess:=StrToInt(scurrentValue);
    WriteLn('Pre-processing : '+scurrentValue);
  end else begin
      WriteLn('Error : No pre-processing (preprocess) ! Check your XML file.');
      halt;
  end;

  if(frootnode.GetElementsByTagName('getRmat').Item[0].FirstChild<>nil) then begin
    scurrentValue := frootnode.GetElementsByTagName('getRmat').Item[0].FirstChild.NodeValue;
    aGTMOpt.Rmat:=StrToBool(scurrentValue);
    WriteLn('Get Rmat : '+scurrentValue);
  end else begin
      WriteLn('Error : No value for getRmat ! Check your XML file.');
      halt;
  end;

  if(frootnode.GetElementsByTagName('iScaleInit').Item[0].FirstChild<>nil) then begin
    scurrentValue := frootnode.GetElementsByTagName('iScaleInit').Item[0].FirstChild.NodeValue;
    aGTMOpt.iScaleInit:=StrToInt(scurrentValue);
    WriteLn('Initial geometry of the manifold : '+scurrentValue);
  end else begin
      WriteLn('Error : No value for the initial geometry of the manifold (iScaleInit) ! Check your XML file.');
      halt;
  end;

  if(frootnode.GetElementsByTagName('iScaleInit').Item[0].FirstChild<>nil) then begin
    scurrentValue := frootnode.GetElementsByTagName('fScaleInit').Item[0].FirstChild.NodeValue;
    aGTMOpt.fScaleInit:=StrToFloat(scurrentValue);
    WriteLn('Scaling factor : '+scurrentValue);
  end else begin
      WriteLn('Error : No value for the caling factor (fScaleInit) ! If no scaling factor should be applied, please make sure that iScaleInit is set to 0 and fScaleInit is set to 0. Check your XML file.');
      halt;
  end;

  if(frootnode.GetElementsByTagName('PC123').Item[0].FirstChild<>nil) then begin
    scurrentValue := frootnode.GetElementsByTagName('PC123').Item[0].FirstChild.NodeValue;
    if(scurrentValue<>'0') then
      aGTMOpt.PCAFile:=scurrentValue;
    WriteLn('Pre-computed three first principal components : '+scurrentValue);
  end else begin
    WriteLn('No pre-computed three first principal components file given.');
  end;
end;


procedure TGTMXML.ReadNode(aGTMBase: TGTMBase);
var
  D, K, M: integer;
  beta, sigma, alpha: double;
  cde: word;
  sl, sl0: TStringList;
  id, ik, im: integer;
  sbeta, salpha: string;
  ErrCode: integer;
begin
  sl := TStringList.Create;
  sl0 := TStringList.Create;
  D := aGTMBase.D;
  if fnode <> nil then
  begin
    if fnode.NodeName = 'Manifold' then
    begin
      K := StrToInt(fnode.GetAttribute('K'));
      aGTMBase.K := K;
      M := StrToInt(fnode.GetAttribute('M'));
      aGTMBase.M := M;
      val(fnode.GetAttribute('sigma'), sigma, ErrCode);
      aGTMBase.sigma := sigma;
      aGTMBase.DimW;
      sl.Clear;
      sl.Text := fnode.FirstChild.NodeValue;
      for id := 1 to aGTMBase.D do
      begin
        sl0.Clear;
        sl0.CommaText := sl[id - 1];
        for im := 0 to aGTMBase.M do
          val(sl0[im], aGTMBase.W[id, im], ErrCode);
      end;
    end
    else
    if fnode.NodeName = 'LatentSamples' then
    begin
      //Read latent space samples
      sl.Clear;
      sl.Text := fnode.FirstChild.NodeValue;
      aGTMBase.DimMatX;
      aGTMBase.DimSelNode;
      for ik := 1 to aGTMBase.K do
      begin
        sl0.Clear;
        sl0.CommaText := sl[ik - 1];
        aGTMBase.matX[ik, 1] := StrToFloat(sl0[0]);
        aGTMBase.matX[ik, 2] := StrToFloat(sl0[1]);
      end;
      //--Read selected nodes
      if fnode.FindNode('SelectedNodes')<>nil then
      begin
        fchildnode:=(fnode.FindNode('SelectedNodes') as TDOMElement);
        sl.Clear;
        sl.Text := fchildnode.FirstChild.NodeValue;
        for ik:=1 to aGTMBase.K do
          if sl[ik-1]='0' then aGTMBase.SelNode[ik]:=False else aGTMBase.SelNode[ik]:=True;
      end else
      begin
        for ik:=1 to aGTMBase.K do
          aGTMBase.SelNode[ik]:=False;
      end;
    end
    else
    if fnode.NodeName = 'LatentTraits' then
    begin
      //Read latent space RBF centers
      sl.Clear;
      sl.Text := fnode.FirstChild.NodeValue;
      //DimMatrix(aGTMFull.matL,aGTMFull.M,2);
      aGTMBase.DimMatM;
      for im := 1 to aGTMBase.M do
      begin
        sl0.Clear;
        sl0.CommaText := sl[im - 1];
        aGTMBase.matM[im, 1] := StrToFloat(sl0[0]);
        aGTMBase.matM[im, 2] := StrToFloat(sl0[1]);
      end;
    end
    else
    {$IfDef UNIX}
      writeln('XML reader - ignored node: ' + fnode.NodeName);
    {$EndIf}
  end;
  FreeAndNil(sl);
  FreeAndNil(sl0);
end;

procedure TGTMXML.ReadNode(aGTMFull: TGTMFull);
var
  D, K, M: integer;
  beta, sigma, alpha: double;
  cde: word;
  sl, sl0: TStringList;
  id, ik, im: integer;
  sbeta, salpha: string;
  ErrCode: integer;
begin
  sl := TStringList.Create;
  sl0 := TStringList.Create;
  D := aGTMFull.D;
  if fnode <> nil then
  begin
    if fnode.NodeName = 'Mean' then
    begin
      aGTMFull.DimMean;
      sl.Clear;
      sl.CommaText := fnode.FirstChild.NodeValue;
      for id := 1 to aGTMFull.D do
        Val(sl[id - 1], aGTMFull.Mean[id], ErrCode);
      //aGTMFull.Mean[id]:=StrToFloat(sl[id-1]);
    end
    else if fnode.NodeName = 'SD' then
    begin
      aGTMFull.DimSD;
      sl.Clear;
      sl.CommaText := fnode.FirstChild.NodeValue;
      for id := 1 to aGTMFull.D do
        val(sl[id - 1], aGTMFull.SD[id], ErrCode);//aGTMFull.SD[id]:=StrToFloat(sl[id-1]);
    end
    else
    if fnode.NodeName = 'Manifold' then
    begin
      K := StrToInt(fnode.GetAttribute('K'));
      aGTMFull.K := K;
      M := StrToInt(fnode.GetAttribute('M'));
      aGTMFull.M := M;
      val(fnode.GetAttribute('sigma'), sigma, ErrCode);
      //sigma:=StrToFloat(fnode.GetAttribute('sigma'));
      aGTMFull.sigma := sigma;
      sbeta := fnode.GetAttribute('beta');
      if sbeta <> '' then
        Val(sbeta, beta, ErrCode){beta:=StrToFloat(sbeta)}
      else
        beta := 0;
      aGTMFull.beta := beta;
      salpha := fnode.GetAttribute('alpha');
      if salpha <> '' then
        Val(salpha, alpha, ErrCode)
      else
        alpha := 0;
      if (aGTMFull is TcGTM) or (aGTMFull is TiGTM) then
        TcGTM(aGTMFull).alpha := alpha;
      aGTMFull.DimW;
      sl.Clear;
      sl.Text := fnode.FirstChild.NodeValue;
      for id := 1 to aGTMFull.D do
      begin
        sl0.Clear;
        sl0.CommaText := sl[id - 1];
        for im := 0 to aGTMFull.M do
          val(sl0[im], aGTMFull.W[id, im], ErrCode);
        // aGTMFull.W[id,im]:=StrToFloat(sl0[im]);
      end;
    end
    else
    if (fnode.NodeName = 'PC123') then
    begin
      //PC123 - 3 first principal components
      aGTMFull.DimPC123;
      sl.Clear;
      sl.Text := fnode.FirstChild.NodeValue;
      val(fnode.GetAttribute('EV1'),aGTMFull.PC123[0,1],ErrCode);
      val(fnode.GetAttribute('EV2'),aGTMFull.PC123[0,2],ErrCode);
      val(fnode.GetAttribute('EV3'),aGTMFull.PC123[0,3],ErrCode);
      for id := 1 to aGTMFull.D do
      begin
        sl0.Clear;
        sl0.CommaText := sl[id - 1];
        val(sl0[0], aGTMFull.PC123[id, 1], ErrCode);
        //aGTMFull.PC123[id,1]:=StrToFloat(sl0[0]);
        val(sl0[1], aGTMFull.PC123[id, 2], ErrCode);
        //aGTMFull.PC123[id,2]:=StrToFloat(sl0[1]);
        val(sl0[2], aGTMFull.PC123[id, 3], ErrCode);
        //aGTMFull.PC123[id,3]:=StrToFloat(sl0[2]);
      end;
    end
    else
    if fnode.NodeName = 'LatentSamples' then
    begin
      //Read latent space samples
      sl.Clear;
      sl.Text := fnode.FirstChild.NodeValue;
      //writeln('K='+IntToStr(aGTMFull.K));
      //DimMatrix(aGTMFull.matX,aGTMFull.K,2);
      aGTMFull.DimMatX;
      for ik := 1 to aGTMFull.K do
      begin
        sl0.Clear;
        sl0.CommaText := sl[ik - 1];
        aGTMFull.matX[ik, 1] := StrToFloat(sl0[0]);
        aGTMFull.matX[ik, 2] := StrToFloat(sl0[1]);
      end;
      //--Read selected nodes
      if fnode.FindNode('SelectedNodes')<>nil then
      begin
        fchildnode:=(fnode.FindNode('SelectedNodes') as TDOMElement);
        sl.Clear;
        aGTMFull.DimSelNode();
        sl.Text := fchildnode.FirstChild.NodeValue;
        for ik:=1 to aGTMFull.K do
          if sl[ik-1]='0' then aGTMFull.SelNode[ik]:=False else aGTMFull.SelNode[ik]:=True;
      end else
      begin
        aGTMFull.DimSelNode();
        for ik:=1 to aGTMFull.K do
          aGTMFull.SelNode[ik]:=False;
      end;
    end
    else
    if fnode.NodeName = 'LatentTraits' then
    begin
      //Read latent space RBF centers
      sl.Clear;
      sl.Text := fnode.FirstChild.NodeValue;
      //DimMatrix(aGTMFull.matL,aGTMFull.M,2);
      aGTMFull.DimMatM;
      for im := 1 to aGTMFull.M do
      begin
        sl0.Clear;
        sl0.CommaText := sl[im - 1];
        aGTMFull.matM[im, 1] := StrToFloat(sl0[0]);
        aGTMFull.matM[im, 2] := StrToFloat(sl0[1]);
      end;
    end
    else
    {$IfDef UNIX}
      writeln('XML reader - ignored node: ' + fnode.NodeName);
    {$EndIf}
  end;
  FreeAndNil(sl);
  FreeAndNil(sl0);
end;

procedure TGTMXML.ReadNode(aGTMSparse: TGTMSparse);
var
  D, K, M: integer;
  sigma: double;
  cde: word;
  sl, sl0: TStringList;
  id, ik, im: integer;
begin
  sl := TStringList.Create;
  sl0 := TStringList.Create;
  D := aGTMSparse.D;
  if fnode <> nil then
  begin
    if fnode.NodeName = 'Manifold' then
    begin
      K := StrToInt(fnode.GetAttribute('K'));
      aGTMSparse.K := K;
      M := StrToInt(fnode.GetAttribute('M'));
      aGTMSparse.M := M;
      D := StrToInt(fnode.GetAttribute('D'));
      sigma := StrToFloat(fnode.GetAttribute('sigma'));
      aGTMSparse.sigma := sigma;
      aGTMSparse.DimW(aGTMSparse.D, aGTMSparse.M);
      sl.Clear;
      sl.Text := fnode.FirstChild.NodeValue;
      for id := 1 to aGTMSparse.D do
      begin
        sl0.Clear;
        sl0.CommaText := sl[id - 1];
        for im := 0 to aGTMSparse.M do
          aGTMSparse.W[id, im] := StrToFloat(sl0[im]);
      end;
    end;
    if fnode.NodeName = 'LatentSamples' then
    begin
      //Read latent space samples
      sl.Clear;
      sl.Text := fnode.FirstChild.NodeValue;
      aGTMSparse.DimMatX;
      for ik := 1 to aGTMSparse.K do
      begin
        sl0.Clear;
        sl0.CommaText := sl[ik - 1];
        aGTMSparse.matX[ik, 1] := StrToFloat(sl0[0]);
        aGTMSparse.matX[ik, 2] := StrToFloat(sl0[1]);
      end;
      //--Read selected nodes
      if fnode.FindNode('SelectedNodes')<>nil then
      begin
        fchildnode:=(fnode.FindNode('SelectedNodes') as TDOMElement);
        sl.Clear;
        aGTMSparse.DimSelNode();
        sl.Text := fchildnode.FirstChild.NodeValue;
        for ik:=1 to aGTMSparse.K do
          if sl[ik]='0' then aGTMSparse.SelNode[ik]:=False else aGTMSparse.SelNode[ik]:=True;
      end else
      begin
        aGTMSparse.DimSelNode();
        for ik:=1 to aGTMSparse.K do
          aGTMSparse.SelNode[ik]:=False;
      end;
    end;
    if fnode.NodeName = 'LatentTraits' then
    begin
      //Read latent space RBF centers
      sl.Clear;
      sl.Text := fnode.FirstChild.NodeValue;
      aGTMSparse.DimMatM;
      for im := 1 to aGTMSparse.M do
      begin
        sl0.Clear;
        sl0.CommaText := sl[im - 1];
        aGTMSparse.matM[im, 1] := StrToFloat(sl0[0]);
        aGTMSparse.matM[im, 2] := StrToFloat(sl0[1]);
      end;
    end;
  end;
  FreeAndNil(sl);
  FreeAndNil(sl0);
end;

constructor TGTMXML.Create;
begin
  fdoc := nil;//TXMLDocument.Create;
  frootnode := nil;
  fnode := nil;
  fchildnode:=nil;
end;

destructor TGTMXML.Destroy;
begin
  inherited Destroy;
  if fdoc <> nil then
    FreeAndNil(fdoc);
  //if frootnode<>nil then Freeandnil(frootnode);
  //if fnode<>nil then freeandnil(fnode);
end;

end.
