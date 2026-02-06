unit UGTMXML;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, XMLRead, XMLWrite, DOM, ugtm_options, UGTMBase, UGTMFull,
  UGTMSparse, UcGTM, UiGTM, UGTMMN, utypes, ulinalg;

type

{ TGTMXML }

TGTMXML = class(TObject)
private
  frootnode, fnode: TDOMElement;
  fdoc: TXMLDocument;
public
  procedure WriteGTMModel(aGTM: TGTMBase; xmlnme: string);
  procedure ReadGTMModel(aGTMFull: TGTMFull; xmlnme: string);
  procedure ReadGTMModel(aGTMSparse: TGTMSparse; xmlnme: string);
  procedure ReadGTMModel(aGTMOpt: TRGtmOptions; xmlnme: string);
  procedure ReadNode(aGTMFull: TGTMFull);
  procedure ReadNode(aGTMSparse: TGTMSparse);
  constructor Create;
  destructor Destroy; override;
end;

procedure WriteGTMMat(aGTM: TGTMBase;flename: string; b3D, bRmat: boolean);

implementation

{ TGTMXML }

procedure WriteGTMMat(aGTM: TGTMBase; flename: string; b3D,bRmat: boolean);
var
  sl: TStringList;
  WPhi3D: TMatrix;
  ik, ii, id: integer;
  cGTM: TcGTM;
  s: string;
  fsOut: TFileStream;
begin
  WPhi3D:=nil;
  sl:=TStringList.Create;
  if aGTM.R<>nil then
  begin
    if bRmat then
    begin
      sl.Clear;
      PrintMatT(aGTM.R,'R',1,aGTM.K,1,aGTM.N,sl);
      if not FileExists(ChangeFileExt(flename,'R.mat')) then
        sl.SaveToFile(ChangeFileExt(flename,'R.mat'))
      else
      begin
        fsOut:=TFileStream.Create(ChangeFileExt(flename,'R.mat'),fmOpenReadWrite);
        fsOut.Seek(0,soFromEnd);
        sl.SaveToStream(fsOut);
        FreeAndNil(fsOut);
      end;
      sl.Clear;
    end;
    //Save responsibilities as SVM, the first column are loglikelyhood contribution of the compound
    for ii:=1 to aGTM.N do
    begin
      if (aGTM is TcGTM) then s:=FloatToStrF(TcGTM(aGTM).LLM[ii],ffGeneral,8,5)
      else s:='?';
      for ik:=1 to aGTM.K-1 do
        if aGTM.R[ik,ii]>1E-5 then s:=s+' '+IntToStr(ik)+':'+FloatToStrF(aGTM.R[ik,ii],ffGeneral,8,5);
      ik:=aGTM.K;
      if aGTM.R[ik,ii]>1E-5 then s:=s+' '+IntToStr(ik)+':'+FloatToStrF(aGTM.R[ik,ii],ffGeneral,8,5) else s:=s+' '+IntToStr(ik)+':0';
      sl.Add(s);
    end;
    if not FileExists(ChangeFileExt(flename,'R.svm')) then
      sl.SaveToFile(ChangeFileExt(flename,'R.svm'))
    else
    begin
      fsOut:=TFileStream.Create(ChangeFileExt(flename,'R.svm'),fmOpenReadWrite);
      fsOut.Seek(0,soFromEnd);
      sl.SaveToStream(fsOut);
      FreeAndNil(fsOut);
    end;
    sl.Clear;
  end;
  if aGTM.matPrj<>nil then
  begin
    sl.Clear;
    PrintMat(aGTM.matPrj,'Proj(theta,phi)',1,aGTM.N,1,2,sl);
    if not FileExists(ChangeFileExt(flename,'Prj.mat')) then
      sl.SaveToFile(ChangeFileExt(flename,'Prj.mat'))
    else
    begin
      fsOut:=TFileStream.Create(ChangeFileExt(flename,'Prj.mat'),fmOpenReadWrite);
      fsOut.Seek(0,soFromEnd);
      sl.SaveToStream(fsOut);
      FreeAndNil(fsOut);
    end;
    sl.Clear;
    PrintMat(aGTM.matPrj3,'Proj(Sphere)',1,aGTM.N,1,3,sl);
    if not FileExists(ChangeFileExt(flename,'Prj3.mat')) then
      sl.SaveToFile(ChangeFileExt(flename,'Prj3.mat'))
    else
    begin
      fsOut:=TFileStream.Create(ChangeFileExt(flename,'Prj3.mat'),fmOpenReadWrite);
      fsOut.Seek(0,soFromEnd);
      sl.SaveToStream(fsOut);
      FreeAndNil(fsOut);
    end;
    sl.Clear;
  end;
  if (aGTM is TcGTM) and (b3D=True) then
  begin
    cGTM:=aGTM as TcGTM;
    sl.Clear;
    PrintMat(cGTM.matY,'WPhi',1,cGTM.K,1,cGTM.D,sl);
    sl.SaveToFile(ChangeFileExt(flename,'WPhi.mat'));
    sl.Clear;
    PrintMat(cGTM.PC123,'PC123',1,cGTM.D,1,3,sl);
    sl.SaveToFile(ChangeFileExt(flename,'PC123.mat'));
    sl.Clear;
    DimMatrix(WPhi3D,cGTM.K,3);
    for ik:=1 to cGTM.K do
      for ii:=1 to 3 do
      begin
        WPhi3D[ik,ii]:=0;
        for id:=1 to cGTM.D do
        begin
          WPhi3D[ik,ii]:=WPhi3D[ik,ii]+cGTM.matY[ik,id]*cGTM.PC123[id,ii];
        end;
      end;
    sl.Clear;
    PrintMat(WPhi3D,'WPhi3D',1,cGTM.K,1,3,sl);
    sl.SaveToFile(ChangeFileExt(flename,'WPhi3D.mat'));
    sl.Clear;
  end;
  FreeAndNil(sl);
end;

procedure TGTMXML.WriteGTMModel(aGTM: TGTMBase; xmlnme: string);
var
  sl: TStringList;
  aGTMFull: TGTMFull;
  aGTMSparse: TGTMSparse;
begin
  sl:=TStringList.Create;
  if (fdoc=nil) then fdoc:=TXMLDocument.Create;
  frootnode:=fdoc.CreateElement('GTMS3');
  fdoc.AppendChild(frootnode);
  if (aGTM is TcGTM) then frootnode.SetAttribute('Type','BISHOP');
  if (aGTM is TiGTM) then frootnode.SetAttribute('Type','BISHOP');
  if (aGTM is TuGTMMN) then frootnode.SetAttribute('Type','MULTINOMIAL');
  frootnode.SetAttribute('N',IntToStr(aGTM.N));
  frootnode.SetAttribute('D',IntToStr(aGTM.D));
  frootnode.SetAttribute('nIter',IntToStr(aGTM.nIter));
  if aGTM is TGTMFull then
  begin
    aGTMFull:=(aGTM as TGTMFull);
    frootnode.SetAttribute('Preprocess',IntToStr(aGTMFull.istd));
    if (aGTM is TcGTM) or (aGTM is TiGTM) then
    begin
      //Mean
      fnode:=fdoc.CreateElement('Mean');
      frootnode.AppendChild(fnode);
      sl.Clear;
      fnode.SetAttribute('D',IntToStr(aGTMFull.D));
      PrintVec(aGTMFull.Mean,1,aGTMFull.D,sl);
      fnode.AppendChild(fdoc.CreateTextNode(sl.Text));
      //SD
      fnode:=fdoc.CreateElement('SD');
      frootnode.AppendChild(fnode);
      sl.Clear;
      fnode.SetAttribute('D',IntToStr(aGTMFull.D));
      PrintVec(aGTMFull.SD,1,aGTMFull.D,sl);
      fnode.AppendChild(fdoc.CreateTextNode(sl.Text));
      //PC123 - 3 first principal components
      fnode:=fdoc.CreateElement('PC123');
      frootnode.AppendChild(fnode);
      sl.Clear;
      fnode.SetAttribute('D',IntToStr(aGTMFull.D));
      PrintMat(aGTMFull.PC123,1,aGTMFull.D,1,3,sl);
      fnode.AppendChild(fdoc.CreateTextNode(sl.Text));
    end;
    //Manifold distribution
    fnode:=fdoc.CreateElement('Manifold');
    frootnode.AppendChild(fnode);
    fnode.SetAttribute('K',IntToStr(aGTMFull.K));
    fnode.SetAttribute('M',IntToStr(aGTMFull.M));
    fnode.SetAttribute('D',IntToStr(aGTMFull.D));
    fnode.SetAttribute('sigma',FloatToStrF(aGTMFull.sigma,ffFixed,8,5));
    if (aGTM is TcGTM) or (aGTM is TiGTM) then
    begin
      fnode.SetAttribute('beta',FloatToStrF(aGTMFull.beta,ffFixed,8,5));
      fnode.SetAttribute('alpha',FloatToStrF(TcGTM(aGTM).alpha,ffFixed,8,5));
    end;
    sl.Clear;
    PrintMat(aGTM.W,1,aGTM.D,0,aGTM.M,sl);
    fnode.AppendChild(fdoc.CreateTextNode(sl.Text));
  end;
  if aGTM is TGTMSparse then
  begin
    aGTMSparse:=(aGTM as TGTMSparse);
    //Manifold distribution
    fnode:=fdoc.CreateElement('Manifold');
    frootnode.AppendChild(fnode);
    fnode.SetAttribute('K',IntToStr(aGTMSparse.K));
    fnode.SetAttribute('M',IntToStr(aGTMSparse.M));
    fnode.SetAttribute('D',IntToStr(aGTMSparse.D));
    fnode.SetAttribute('sigma',FloatToStrF(aGTMSparse.sigma,ffFixed,8,5));
    sl.Clear;
    PrintMat(aGTM.W,1,aGTM.D,0,aGTM.M,sl);
    fnode.AppendChild(fdoc.CreateTextNode(sl.Text));
  end;
  //Save latent space samples
  fnode:=fdoc.CreateElement('LatentSamples');
  frootnode.AppendChild(fnode);
  sl.Clear;
  PrintMat(aGTM.matX,1,aGTM.K,1,2,sl);
  fnode.AppendChild(fdoc.CreateTextNode(sl.Text));
  //Save latent space RBF centers
  fnode:=fdoc.CreateElement('LatentTraits');
  frootnode.AppendChild(fnode);
  sl.Clear;
  PrintMat(aGTM.matM,1,aGTM.M,1,2,sl);
  fnode.AppendChild(fdoc.CreateTextNode(sl.Text));
  //Write file
  WriteXMLFile(fdoc,xmlnme);
  FreeAndNil(sl);
end;

procedure TGTMXML.ReadGTMModel(aGTMFull: TGTMFull; xmlnme: string);
var
  stype: string;
begin
  ReadXMLFile(fdoc,xmlnme);
  frootnode:=fdoc.DocumentElement;
  stype:=frootnode.GetAttribute('Type');
  aGTMFull.N:=StrToInt(frootnode.GetAttribute('N'));
  aGTMFull.D:=StrToInt(frootnode.GetAttribute('D'));
  aGTMFull.nIter:=StrToInt(frootnode.GetAttribute('nIter'));
  aGTMFull.istd:=StrToInt(frootnode.GetAttribute('Preprocess'));
  fnode:=(frootnode.FirstChild as TDOMElement);
  while fnode<>nil do
  begin
    ReadNode(aGTMFull);
    fnode:=(fnode.NextSibling as TDOMElement);
  end;
  //TGTMBase(aGTMFull).Init;
  //writeln('ICI2');
end;

procedure TGTMXML.ReadGTMModel(aGTMSparse: TGTMSparse; xmlnme: string);
var
  stype: string;
begin
  ReadXMLFile(fdoc,xmlnme);
  frootnode:=fdoc.DocumentElement;
  stype:=frootnode.GetAttribute('Type');
  aGTMSparse.N:=StrToInt(frootnode.GetAttribute('N'));
  aGTMSparse.D:=StrToInt(frootnode.GetAttribute('D'));
  aGTMSparse.nIter:=StrToInt(frootnode.GetAttribute('nIter'));
  fnode:=(frootnode.FirstChild as TDOMElement);
  while fnode<>nil do
  begin
    ReadNode(aGTMSparse);
    fnode:=(fnode.NextSibling as TDOMElement);
  end;
end;

procedure TGTMXML.ReadGTMModel(aGTMOpt: TRGtmOptions; xmlnme: string);
var
  nls: TDOMNodeList;
  KK, MM, D: integer;
  stype, salpha, sistd: string;
  sigma: double;
begin
  stype:=''; salpha:=''; sigma:=-1;
  ReadXMLFile(fdoc,xmlnme);
  frootnode:=fdoc.DocumentElement;
  stype:=frootnode.GetAttribute('Type');
  if stype='BISHOP' then aGTMOpt.GTMType:=BISHOP
  else if stype='INCREMENTAL' then aGTMOpt.GTMType:=BISHOP
  else if stype='MULTINOMIAL' then aGTMOpt.GTMType:=MULTINOMIAL
  else aGTMOpt.GTMType:=UNK;
  nls:=frootnode.GetElementsByTagName('Manifold');
  if nls.Count>0 then
  begin
    fnode:=(nls.Item[0] as TDOMElement);
    KK:=StrToInt(fnode.GetAttribute('K'));
    aGTMOpt.nSamples:=KK;
    MM:=StrToInt(fnode.GetAttribute('M'));
    aGTMOpt.nCenters:=MM;
    sigma:=StrToFloat(fnode.GetAttribute('sigma'));
    aGTMOpt.sigma:=sigma;
    if (aGTMOpt.GTMType=BISHOP) or (aGTMOpt.GTMType=INCREMENTAL) then
    begin
      salpha:=fnode.GetAttribute('alpha');
      sistd:=fnode.GetAttribute('Preprocess');
    end;
    if salpha<>'' then aGTMOpt.alpha:=StrToFloat(salpha);
    if sistd<>'' then aGTMOpt.preprocess:=StrToInt(sistd);
  end;
end;

procedure TGTMXML.ReadNode(aGTMFull: TGTMFull);
var
  D,K,M: integer;
  beta, sigma: double;
  cde: Word;
  sl,sl0: TStringList;
  id,ik,im: integer;
  sbeta: string;
  ErrCode:integer;
begin
  sl:=TStringList.Create;
  sl0:=TStringList.Create;
  D:=aGTMFull.D;
  if fnode<>nil then
  begin
    if fnode.NodeName='Mean' then
    begin
      aGTMFull.DimMean;
      sl.Clear;
      sl.CommaText:=fnode.FirstChild.NodeValue;
      for id:=1 to aGTMFull.D do
        Val(sl[id-1],aGTMFull.Mean[id],ErrCode);//aGTMFull.Mean[id]:=StrToFloat(sl[id-1]);
    end else if fnode.NodeName='SD' then
    begin
      aGTMFull.DimSD;
      sl.Clear;
      sl.CommaText:=fnode.FirstChild.NodeValue;
      for id:=1 to aGTMFull.D do
        val(sl[id-1],aGTMFull.SD[id],ErrCode);//aGTMFull.SD[id]:=StrToFloat(sl[id-1]);
    end else
    if fnode.NodeName='Manifold' then
    begin
      K:=StrToInt(fnode.GetAttribute('K'));
      aGTMFull.K:=K;
      M:=StrToInt(fnode.GetAttribute('M'));
      aGTMFull.M:=M;
      val(fnode.GetAttribute('sigma'),sigma,ErrCode);//sigma:=StrToFloat(fnode.GetAttribute('sigma'));
      aGTMFull.sigma:=sigma;
      sbeta:=fnode.GetAttribute('beta');
      if sbeta<>'' then Val(sbeta,beta,ErrCode){beta:=StrToFloat(sbeta)} else beta:=0;
      aGTMFull.beta:=beta;
      aGTMFull.DimW;
      sl.Clear;
      sl.Text:=fnode.FirstChild.NodeValue;
      for id:=1 to aGTMFull.D do
      begin
        sl0.Clear;
        sl0.CommaText:=sl[id-1];
        for im:=0 to aGTMFull.M do
          val(sl0[im],aGTMFull.W[id,im],ErrCode);// aGTMFull.W[id,im]:=StrToFloat(sl0[im]);
      end;
    end else
    if (fnode.NodeName='PC123') then
    begin
      //PC123 - 3 first principal components
      aGTMFull.DimPC123;
      sl.Clear;
      sl.Text:=fnode.FirstChild.NodeValue;
      for id:=1 to aGTMFull.D do
      begin
        sl0.Clear;
        sl0.CommaText:=sl[id-1];
        val(sl0[0],aGTMFull.PC123[id,1],ErrCode);//aGTMFull.PC123[id,1]:=StrToFloat(sl0[0]);
        val(sl0[1],aGTMFull.PC123[id,2],ErrCode);//aGTMFull.PC123[id,2]:=StrToFloat(sl0[1]);
        val(sl0[2],aGTMFull.PC123[id,3],ErrCode);//aGTMFull.PC123[id,3]:=StrToFloat(sl0[2]);
      end;
    end else writeln('XML reader - ignored node: '+fnode.NodeName);
    {end else
    if fnode.NodeName='LatentSamples' then begin
      //Read latent space samples
      sl.Clear;
      sl.Text:=fnode.FirstChild.NodeValue;
      writeln('K='+IntToStr(aGTMFull.K));
      for ik:=1 to aGTMFull.K do
      begin
        sl0.Clear;
        sl0.CommaText:=sl[ik-1];
        aGTMFull.matX[ik,1]:=StrToFloat(sl0[1]);
        aGTMFull.matX[ik,2]:=StrToFloat(sl0[2]);
      end;
    end else
    if fnode.NodeName='LatentRBFs' then begin
      //Read latent space RBF centers
      sl.Clear;
      sl.Text:=fnode.FirstChild.NodeValue;
      for im:=1 to aGTMFull.M do
      begin
        sl0.Clear;
        sl0.CommaText:=sl[im-1];
        aGTMFull.matM[im,1]:=StrToFloat(sl0[1]);
        aGTMFull.matM[im,2]:=StrToFloat(sl0[2]);
      end;}
  end;
  FreeAndNil(sl);
  FreeAndNil(sl0);
end;

procedure TGTMXML.ReadNode(aGTMSparse: TGTMSparse);
var
  D,K,M: integer;
  sigma: double;
  cde: Word;
  sl,sl0: TStringList;
  id,ik,im: integer;
begin
  sl:=TStringList.Create;
  sl0:=TStringList.Create;
  D:=aGTMSparse.D;
  if fnode<>nil then
  begin
    if fnode.NodeName='Manifold' then
    begin
      K:=StrToInt(fnode.GetAttribute('K'));
      aGTMSparse.K:=K;
      M:=StrToInt(fnode.GetAttribute('M'));
      aGTMSparse.M:=M;
      D:=StrToInt(fnode.GetAttribute('D'));
      sigma:=StrToFloat(fnode.GetAttribute('sigma'));
      aGTMSparse.sigma:=sigma;
      aGTMSparse.DimW(aGTMSparse.D,aGTMSparse.M);
      sl.Clear;
      sl.Text:=fnode.FirstChild.NodeValue;
      for id:=1 to aGTMSparse.D do
      begin
        sl0.Clear;
        sl0.CommaText:=sl[id-1];
        for im:=0 to aGTMSparse.M do
          aGTMSparse.W[id,im]:=StrToFloat(sl0[im]);
      end;
    end;
    if fnode.NodeName='LatentSamples' then begin
      //Read latent space samples
      sl.Clear;
      sl.Text:=fnode.FirstChild.NodeValue;
      for ik:=1 to aGTMSparse.K do
      begin
        sl0.Clear;
        sl0.CommaText:=sl[ik-1];
        aGTMSparse.matX[ik,1]:=StrToFloat(sl0[1]);
        aGTMSparse.matX[ik,2]:=StrToFloat(sl0[2]);
      end;
    end;
    if fnode.NodeName='LatentRBFs' then begin
      //Read latent space RBF centers
      sl.Clear;
      sl.Text:=fnode.FirstChild.NodeValue;
      for im:=1 to aGTMSparse.M do
      begin
        sl0.Clear;
        sl0.CommaText:=sl[im-1];
        aGTMSparse.matX[im,1]:=StrToFloat(sl0[1]);
        aGTMSparse.matX[im,2]:=StrToFloat(sl0[2]);
      end;
    end;
  end;
  FreeAndNil(sl);
  FreeAndNil(sl0);
end;

constructor TGTMXML.Create;
begin
  fdoc:=nil;//TXMLDocument.Create;
  frootnode:=nil;
  fnode:=nil;
end;

destructor TGTMXML.Destroy;
begin
  inherited Destroy;
  FreeAndNil(fdoc);
  //if frootnode<>nil then Freeandnil(frootnode);
  //if fnode<>nil then freeandnil(fnode);
end;

end.

