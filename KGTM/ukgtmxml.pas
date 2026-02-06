unit UKGTMXML;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, XMLRead, XMLWrite, DOM, ukgtm_options, UGTMBase, UGTMFull,
  UGTMSparse, UcGTM, UiGTM, UGTMMN, UnitKGTM, utypes, ulinalg;

type

  { TKGTMXML }

  TKGTMXML = class(TObject)
  private
    frootnode, fnode, fchildnode: TDOMElement;
    fdoc: TXMLDocument;
  public
    procedure WriteGTMModel(aGTM: TKGTM; xmlnme: string);
    procedure ReadGTMModel(aGTM: TKGTM; xmlnme: string);
    procedure ReadGTMModel(aGTMOpt: TRKGTMOptions; xmlnme: string);
    procedure ReadNode(aGTM: TKGTM);
    constructor Create;
    destructor Destroy; override;
  end;

procedure WriteKGTMMat(aGTM: TKGTM; flename: string; b3D, bRmat: boolean);

implementation

procedure WriteKGTMMat(aGTM: TKGTM; flename: string; b3D, bRmat: boolean);
//Output relevant matrices
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
    PrintMat(cGTM.Z,'Z',1,High(cGTM.Z),1,High(cGTM.Z[0]),sl);
    sl.SaveToFile(ChangeFileExt(flename,'Z.mat'));
  end;
  FreeAndNil(sl);
end;

{ TKGTMXML }

procedure TKGTMXML.WriteGTMModel(aGTM: TKGTM; xmlnme: string);
var
  sl: TStringList;
  ik: integer;
  aKPCARootNode: TDOMNode;
begin
  sl := TStringList.Create;
  if (fdoc = nil) then
    fdoc := TXMLDocument.Create;
  frootnode := fdoc.CreateElement('GTM');
  fdoc.AppendChild(frootnode);
  frootnode.SetAttribute('Type', 'KGTM');
  frootnode.SetAttribute('N', IntToStr(aGTM.N));
  frootnode.SetAttribute('D', IntToStr(aGTM.D));
  frootnode.SetAttribute('nIter', IntToStr(aGTM.nIter));
  frootnode.SetAttribute('Preprocess', IntToStr(aGTM.istd));
  //Mean
  fnode := fdoc.CreateElement('Mean');
  frootnode.AppendChild(fnode);
  sl.Clear;
  fnode.SetAttribute('D', IntToStr(aGTM.D));
  PrintVec(aGTM.Mean, 1, aGTM.D, sl);
  fnode.AppendChild(fdoc.CreateTextNode(sl.Text));
  //SD
  fnode := fdoc.CreateElement('SD');
  frootnode.AppendChild(fnode);
  sl.Clear;
  fnode.SetAttribute('D', IntToStr(aGTM.D));
  PrintVec(aGTM.SD, 1, aGTM.D, sl);
  fnode.AppendChild(fdoc.CreateTextNode(sl.Text));
  //KPCA - principal components as lines / loadings as columns
  aKPCARootNode := fdoc.CreateElement('principal_components');
  TDOMElement(aKPCARootNode).SetAttribute('type', 'KPCA');
  frootnode.AppendChild(aKPCARootNode);
  aGTM.aKPCA.writeXML(fdoc,aKPCARootNode);
  TDOMElement(aKPCARootNode).SetAttribute('kernel', IntToStr(aGTM.metric));
  TDOMElement(aKPCARootNode).SetAttribute('kernelParam', FloatToStr(aGTM.kprm1));
  {fnode := fdoc.CreateElement('KPCA');
  frootnode.AppendChild(fnode);
  sl.Clear;
  fnode.SetAttribute('D', IntToStr(aGTM.D));
  fnode.SetAttribute('Sze', IntToStr(aGTM.aKPCA.Sze));
  for ik:=0 to aGTM.aKPCA.NPC-1 do
    fnode.SetAttribute('EV'+IntToStr(ik+1),FloatToStr(aGTM.aKPCA.EigVr[ik,0]/aGTM.aKPCA.vartot));
  PrintMatFullPrec(aGTM.aKPCA.EigVr,0,aGTM.aKPCA.NPC-1,0,aGTM.aKPCA.Sze,sl);
  fnode.AppendChild(fdoc.CreateTextNode(sl.Text));}
  //Manifold distribution
  fnode := fdoc.CreateElement('Manifold');
  frootnode.AppendChild(fnode);
  fnode.SetAttribute('K', IntToStr(aGTM.K));
  fnode.SetAttribute('M', IntToStr(aGTM.M));
  fnode.SetAttribute('D', IntToStr(aGTM.D));
  fnode.SetAttribute('sigma', FloatToStrF(aGTM.sigma, ffFixed, 8, 5));
  fnode.SetAttribute('beta', FloatToStrF(aGTM.beta, ffFixed, 8, 5));
  fnode.SetAttribute('alpha', FloatToStrF(aGTM.alpha, ffFixed, 8, 5));
  sl.Clear;
  PrintMat(aGTM.W, 1, aGTM.D, 0, aGTM.M, sl); //Write nodes coordinates
  fnode.AppendChild(fdoc.CreateTextNode(sl.Text));
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

procedure TKGTMXML.ReadGTMModel(aGTM: TKGTM; xmlnme: string);
var
  stype: string;
begin
  if not FileExists(xmlnme) then
  begin
    raise Exception.Create('ERROR TKGTMXML.ReadGTMModel: file not found - '+xmlnme);
    Halt;
  end;
  ReadXMLFile(fdoc, xmlnme);
  frootnode := fdoc.DocumentElement;
  stype := frootnode.GetAttribute('Type');
  if stype<>'KGTM' then
  begin
    raise Exception.Create('ERROR TKGTMXML.ReadGTMModel: invalid KGTM model. Type='+stype);
    Halt;
  end;
  aGTM.N := StrToInt(frootnode.GetAttribute('N'));
  aGTM.D := StrToInt(frootnode.GetAttribute('D'));
  aGTM.nIter := StrToInt(frootnode.GetAttribute('nIter'));
  aGTM.istd := StrToInt(frootnode.GetAttribute('Preprocess'));
  fnode := (frootnode.FirstChild as TDOMElement);
  while fnode <> nil do
  begin
    ReadNode(aGTM);
    fnode := (fnode.NextSibling as TDOMElement);
  end;
  FreeAndNil(fdoc);
end;

procedure TKGTMXML.ReadGTMModel(aGTMOpt: TRKGTMOptions; xmlnme: string);
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
  else if stype= 'KGTM' then
    aGTMOpt.GTMType:=KGTM
  else
    aGTMOpt.GTMType := UNK;
  if (aGTMOpt.GTMType = BISHOP) or (aGTMOpt.GTMType = INCREMENTAL) then
  begin
    sistd := frootnode.GetAttribute('Preprocess');
  end;
  //Preprocess is always 2 for KGTM
  //if sistd <> '' then
  //  aGTMOpt.preprocess := StrToInt(sistd);

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

procedure TKGTMXML.ReadNode(aGTM: TKGTM);
var
  D, K, M, Sze: integer;
  beta, sigma, alpha: double;
  cde: word;
  sl, sl0: TStringList;
  id, ik, im: integer;
  sbeta, salpha: string;
  ErrCode: integer;
begin
  sl := TStringList.Create;
  sl0 := TStringList.Create;
  D := aGTM.D;
  if fnode <> nil then
  begin
    if fnode.NodeName = 'Mean' then
    begin
      //Mean
      D := StrToInt(fnode.GetAttribute('D'));
      aGTM.D := D;
      aGTM.DimMean(D);
      sl.Clear;
      sl.CommaText := fnode.FirstChild.NodeValue;
      for id := 1 to aGTM.D do
        val(sl[id-1], aGTM.Mean[id], ErrCode);
    end else if fnode.NodeName = 'SD' then
    begin
      //SD
      D := StrToInt(fnode.GetAttribute('D'));
      aGTM.D := D;
      aGTM.DimSD(D);
      sl.Clear;
      sl.CommaText := fnode.FirstChild.NodeValue;
      for id := 1 to aGTM.D do
        val(sl[id-1], aGTM.SD[id], ErrCode);
    end else if fnode.NodeName = 'principal_components' then
    begin
      aGTM.aKPCA.readXML(fnode);
      aGTM.metric := StrToInt(fnode.GetAttribute('kernel'));
      aGTM.kprm1 := StrToFloat(fnode.GetAttribute('kernelParam'));
    end else if fnode.NodeName = 'Manifold' then
    begin
      K := StrToInt(fnode.GetAttribute('K'));
      aGTM.K := K;
      M := StrToInt(fnode.GetAttribute('M'));
      aGTM.M := M;
      val(fnode.GetAttribute('sigma'), sigma, ErrCode);
      aGTM.sigma := sigma;
      val(fnode.GetAttribute('beta'), beta, ErrCode);
      aGTM.beta := beta;
      val(fnode.GetAttribute('alpha'), alpha, ErrCode);
      aGTM.alpha := alpha;
      aGTM.DimW;
      sl.Clear;
      sl.Text := fnode.FirstChild.NodeValue;
      for id := 1 to aGTM.D do
      begin
        sl0.Clear;
        sl0.CommaText := sl[id - 1];
        for im := 0 to aGTM.M do
          val(sl0[im], aGTM.W[id, im], ErrCode);
      end;
    end
    else
    if fnode.NodeName = 'LatentSamples' then
    begin
      //Read latent space samples
      sl.Clear;
      sl.Text := fnode.FirstChild.NodeValue;
      aGTM.DimMatX;
      for ik := 1 to aGTM.K do
      begin
        sl0.Clear;
        sl0.CommaText := sl[ik - 1];
        aGTM.matX[ik, 1] := StrToFloat(sl0[0]);
        aGTM.matX[ik, 2] := StrToFloat(sl0[1]);
      end;
      //--Read selected nodes
      aGTM.DimSelNode();
      if fnode.FindNode('SelectedNodes')<>nil then
      begin
        fchildnode:=(fnode.FindNode('SelectedNodes') as TDOMElement);
        sl.Clear;
        sl.Text := fchildnode.FirstChild.NodeValue;
        for ik:=1 to aGTM.K do
          if sl[ik-1]='0' then aGTM.SelNode[ik-1]:=False else aGTM.SelNode[ik-1]:=True;
      end else
      begin
        for ik:=1 to aGTM.K do
          aGTM.SelNode[ik]:=False;
      end;
    end
    else
    if fnode.NodeName = 'LatentTraits' then
    begin
      //Read latent space RBF centers
      sl.Clear;
      sl.Text := fnode.FirstChild.NodeValue;
      //DimMatrix(aGTMFull.matL,aGTMFull.M,2);
      aGTM.DimMatM;
      for im := 1 to aGTM.M do
      begin
        sl0.Clear;
        sl0.CommaText := sl[im - 1];
        aGTM.matM[im, 1] := StrToFloat(sl0[0]);
        aGTM.matM[im, 2] := StrToFloat(sl0[1]);
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

constructor TKGTMXML.Create;
begin
  fdoc := nil;//TXMLDocument.Create;
  frootnode := nil;
  fnode := nil;
  fchildnode:=nil;
end;

destructor TKGTMXML.Destroy;
begin
  inherited Destroy;
  if fdoc <> nil then
    FreeAndNil(fdoc);
  //if frootnode<>nil then Freeandnil(frootnode);
  //if fnode<>nil then freeandnil(fnode);
end;

end.
