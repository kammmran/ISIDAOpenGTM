unit GTMRegFunctions;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, strutils, streamex, XMLRead, XMLWrite, DOM, Math, UGTMReg,ulinalg, utypes, UnitClsStat;

type
  TArr2D = array of array of double;
  checkedMols = array of integer;
  ClassArray_type = array of integer;
  PropertyArray_type = array of double;
  predClasses_type = array of array of integer;
  integer_vector = array of integer;
  double_vector = array of double;

  XMLData = record
    Density: array of double;
    Landscape: array of double;
    MinRespAD: double;
    MinRespToNode: double;
    MinDensityLS: double;
    nNode: integer;
    PrpMean: double;
  end;

function readRespFile(file_name: string; out nInst: integer;
  out nNodes: integer; kNodes: integer = 0): TArr2D;
function checkMolsForAD(resp_array: TArr2D; ADthreshold: real): checkedMols;
function readPropertyFile(file_name: string; mols_list_in_AD: array of integer;
  out comment: string): PropertyArray_type;
procedure saveLandscape(outName: string; author: string; aGTMReg: TGTMReg; title, comment: string);
procedure readLandscape(fileName: string; var aGTMReg: TGTMReg);
function readLandscape(fileName: string): XMLData;
procedure writeOut(outName: string; predictions: PropertyArray_type;
  list_of_checkedProjectedMols: checkedMols; putDefVal: boolean; defVal: double);
procedure TrainLandscape(aGTMReg: TGTMReg; trRspFileNme, trPrpFileNme, sOutFileName, sAuthor, sTitle, sComment: string; SLlog: TStrings);
procedure TrainLandscape(aGTMReg: TGTMReg; trRspPrp: TStringList; sOutFileName, sAuthor, sTitle, sComment: string; SLlog: TStrings);//trRspPrp, property is a double associated to the corresponding responsibilities string
procedure UseLandscape(aGTMReg: TGTMReg; teRspFileNme, sOutFileName: string; SLlog: TStrings);
procedure UseLandscape(aGTMReg: TGTMReg; teRsp: TStringList; sOutFileName: string; aClsStat: TClsStat; SLlog: TStrings);

implementation

function readRespFile(file_name: string; out nInst: integer;
  out nNodes: integer; kNodes: integer = 0): TArr2D;
  {function to read new matR file; The first line and the last line are comments}
var
  //resp_array: TArr2D;
  f: textfile;
  line: string;
  line_index: integer;
  node_index: integer;
  column_index: integer;
  temp_resp_array: TStringList;
  temp_node_resp_array: TStringList;
begin
  assignfile(f, file_name);
  Result := nil;
  nInst := 0;
  try
    temp_resp_array := TStringList.Create;
    temp_node_resp_array := TStringList.Create;
    line_index := 0;
    reset(f);
    while not EOF(f) do
    begin
      readln(f, line);
      if (line <> '') then
      begin
        Inc(nInst);
        SetLength(Result, (line_index + 1));
        temp_resp_array.Delimiter := ' ';
        temp_resp_array.StrictDelimiter := False;
        temp_resp_array.DelimitedText := line;
        temp_node_resp_array.Delimiter := ':';
        temp_node_resp_array.StrictDelimiter := True;
        {temp_resp_array.CommaText:=line; }
        temp_node_resp_array.DelimitedText := temp_resp_array[temp_resp_array.Count - 1];
        nNodes := StrToInt(temp_node_resp_array[0]);
        if (kNodes <> 0) and (kNodes <> nNodes) then
        begin
          writeln('ERROR readRespFile: Unexpected number of nodes reading file ' +
            file_name);
          halt;
        end;
        node_index := 1;
        SetLength(Result[line_index], nNodes);
        for column_index := 1 to (nNodes) do
        begin
          temp_node_resp_array.DelimitedText := temp_resp_array[node_index];
          if StrToInt(temp_node_resp_array[0]) > column_index then
          begin
            Result[line_index, column_index - 1] := 0.0;
          end
          else
          begin
            Result[line_index, column_index - 1] := StrToFloat(temp_node_resp_array[1]);
            Inc(node_index);
          end;
        end;
        Inc(line_index);
      end;
    end;
    FreeAndNil(temp_resp_array);
    Close(f);
  except
    Close(f);
    writeln('!!!An Error Occured During The Reading Of File With Responsibilities For The Color Set!!!');
  end;
end;

function checkMolsForAD(resp_array: TArr2D; ADthreshold: real): checkedMols;
  {function to remove molecules which are out of AD}
var
  molecule_index: integer;
  resp_index: integer;
  maxResp: real;
  list_index: integer;
begin
  list_index := 0;
  Result := nil;
  SetLength(Result, Length(resp_array));
  for molecule_index := Low(resp_array) to High(resp_array) do
  begin
    maxResp := 0.0;
    for resp_index := Low(resp_array[molecule_index])
      to High(resp_array[molecule_index]) do
    begin
      if resp_array[molecule_index][resp_index] > maxResp then
      begin
        maxResp := resp_array[molecule_index][resp_index];
      end;
    end;
    if maxResp >= ADthreshold then
    begin
      Result[molecule_index] := molecule_index;
      Inc(list_index);
    end
    else
      Result[molecule_index] := -1;
  end;
end;

function readPropertyFile(file_name: string; mols_list_in_AD: array of integer;
  out comment: string): PropertyArray_type;
  {function to read new activity file; The first line is a comment}
var
  f: textfile;
  line: string;
  line_index: integer;
begin
  assignfile(f, file_name);
  Result := nil;
  try
    line_index := 0;
    reset(f);
    while not EOF(f) do
    begin
      readln(f, line);
      if (line_index > 0) and (line <> '') and (mols_list_in_AD[line_index - 1] <> -1) then
      begin
        SetLength(Result, length(Result) + 1);
        Result[High(Result)] := StrToFloat(line);
      end
      else if (line_index = 0) then
      begin
        comment := line;
      end;
      Inc(line_index);
    end;
    Close(f);
  except
    Close(f);
    writeln('!!!An Error Occured During The Reading Of File With Property Values For The Color Set!!!');
  end;
end;

procedure saveLandscape(outName: string; author: string; aGTMReg: TGTMReg; title, comment: string);
{saves a Landscape into an xml file}
var
  index1: integer;
  frootnode, fnode, fnode2,fnode4: TDOMElement;
  fdoc: TXMLDocument;
  temp_var: string;
  SLlog: TStringList; // A string list to prepare outputs
begin
  SLlog:=TStringList.Create;
  fdoc := TXMLDocument.Create;
  frootnode := fdoc.CreateElement('GTM');
  frootnode.SetAttribute('tool', 'GTMReg');
  frootnode.SetAttribute('date', DateTimeToStr(Now));
  frootnode.SetAttribute('author', author);
  frootnode.SetAttribute('title', title);
  frootnode.SetAttribute('comment', comment);
  fdoc.AppendChild(frootnode);
  fnode := fdoc.CreateElement('Landscape');
  fnode.SetAttribute('threshold_On_Applicability_Domain', FloatToStr(aGTMReg.MinRspAD));
  fnode.SetAttribute('node_Threshold', FloatToStr(aGTMReg.MinRspToNode));
  fnode.SetAttribute('density_Threshold', FloatToStr(aGTMReg.MinDensityLS));
  fnode.SetAttribute('number_of_nodes', IntToStr(aGTMReg.K));
  fnode.SetAttribute('averaged_value', FloatToStr(aGTMReg.PrpMean));
  fnode.SetAttribute('std_dev_value', FloatToStr(aGTMReg.PrpStdDev));
  frootnode.AppendChild(fnode);
  fnode2 := fdoc.CreateElement('Property');
  fnode2.SetAttribute('class',aGTMReg.PrpName);
  fnode2.SetAttribute('mean',FloatToStrF(aGTMReg.PrpMean,ffGeneral,10,2));
  temp_var := FloatToStr(aGTMReg.Landscape[1]);
  for index1 := 2 to aGTMReg.K do {run through the nodes}
      temp_var := temp_var + ','+ FloatToStr(aGTMReg.Landscape[index1]);//FloatToStrF(aGTMReg.Landscape[index1 + 1],ffFixed,8,3);//FloatToStr(SimpleRoundTo(aGTMReg.Landscape[index1 + 1], -3));
  fnode2.AppendChild(fdoc.CreateTextNode(temp_var));
  fnode.AppendChild(fnode2);
  fnode2 := fdoc.CreateElement('PropertyStdDev');
  fnode2.SetAttribute('class',aGTMReg.PrpName);
  fnode2.SetAttribute('StdDev',FloatToStrF(aGTMReg.PrpStdDev,ffGeneral,10,2));
  temp_var := FloatToStr(aGTMReg.Landscape2[1]);
  for index1 := 2 to aGTMReg.K do {run through the nodes}
      temp_var := temp_var + ','+ FloatToStr(aGTMReg.Landscape2[index1]);
  fnode2.AppendChild(fdoc.CreateTextNode(temp_var));
  fnode.AppendChild(fnode2);
  fnode2 := fdoc.CreateElement('Coherence');
  fnode2.SetAttribute('class',aGTMReg.PrpName);
  fnode2.SetAttribute('MinProperty',FloatToStrF(aGTMReg.dPrpMin,ffGeneral,10,2));
  fnode2.SetAttribute('MaxProperty',FloatToStrF(aGTMReg.dPrpMax,ffGeneral,10,2));
  fnode2.SetAttribute('RngProperty',FloatToStrF(aGTMReg.dPrpRng,ffGeneral,10,2));
  temp_var := FloatToStr(aGTMReg.Coherence[1]);
  for index1 := 2 to aGTMReg.K do {run through the nodes}
      temp_var := temp_var + ','+ FloatToStr(aGTMReg.Coherence[index1]);
  fnode2.AppendChild(fdoc.CreateTextNode(temp_var));
  fnode.AppendChild(fnode2);
  fnode2 := fdoc.CreateElement('Trustworthiness');
  fnode2.SetAttribute('class',aGTMReg.PrpName);
  fnode2.SetAttribute('tau',FloatToStrF(aGTMReg.dTtau,ffGeneral,10,2));
  fnode2.SetAttribute('alpha',FloatToStrF(aGTMReg.dTalpha,ffGeneral,10,2));
  fnode2.SetAttribute('beta',FloatToStrF(aGTMReg.dTbeta,ffGeneral,10,2));
  fnode2.SetAttribute('threshold',FloatToStrF(aGTMReg.dTT,ffGeneral,10,2));
  temp_var := FloatToStr(aGTMReg.Trustworthiness[1]);
  for index1 := 2 to aGTMReg.K do {run through the nodes}
      temp_var := temp_var + ','+ FloatToStr(aGTMReg.Trustworthiness[index1]);
  fnode2.AppendChild(fdoc.CreateTextNode(temp_var));
  fnode.AppendChild(fnode2);
  fnode2 := fdoc.CreateElement('Density');
  fnode2.SetAttribute('Expected_min_density', FloatToStr(
    SimpleRoundTo(aGTMReg.hmgDensity(), -3)));
  fnode2.SetAttribute('Min_density', FloatToStrF(aGTMReg.minDensity(),ffGeneral,10,5));
  fnode2.SetAttribute('Max_density', FloatToStrF(aGTMReg.maxDensity(),ffGeneral,10,5));
  temp_var := FloatToStr(aGTMReg.Density[1]);
  for index1 := 2 to aGTMReg.K do {run through the nodes}
    temp_var := temp_var + ','+ FloatToStr(aGTMReg.Density[index1]);//FloatToStr(SimpleRoundTo(aGTMReg.Density[index1 + 1], -2));
  fnode2.AppendChild(fdoc.CreateTextNode(temp_var));
  fnode.AppendChild(fnode2);
  //The latent samples (X,Y) coordinates are located at the root
  fnode4:=fdoc.CreateElement('LatentSamples');
  fnode4.SetAttribute('K',IntToStr(aGTMReg.K));
  PrintMat(aGTMReg.matX,1,aGTMReg.K,1,2,SLlog);
  fnode4.AppendChild(fdoc.CreateTextNode(SLlog.Text));
  frootnode.AppendChild(fnode4);
  WriteXMLFile(fdoc, outName);
  FreeAndNil(SLlog);
  FreeAndNil(fdoc);
end;

procedure readLandscape(fileName: string; var aGTMReg: TGTMReg);
var
  fnode, fnode2: TDOMElement;
  fdoc: TXMLDocument;
  node: TDOMNodeList;
  index1: integer;
  nNode: integer;
  temp_resp_array: TStringList;
  SLlog: TStringList; // String list for input interpretation
  dx,dy: double; //temporary double storage
begin
  temp_resp_array:=TStringList.create;
  SLlog:= TStringList.Create;
  { create xml object and load xml file }
  //fdoc:=TXMLDocument.Create;
  ReadXMLFile(fdoc,fileName);
  { reading the attributes for the Landscape node }
  node:=fdoc.DocumentElement.GetElementsByTagName('Landscape');
  if node.Length=0 then
  begin
    raise exception.Create('ERROR: '+fileName+' is not a lanscape file.');
    FreeAndNil(aGTMReg);
    exit;
  end;
  fnode:=(node.Item[0] as TDOMElement);
  nNode:= StrToInt(fnode.GetAttribute('number_of_nodes'));
  if aGTMReg.K<>nNode then
    begin
      if aGTMReg.K=0 then
      begin
        aGTMReg.K:=nNode; // The aGTMReg will initialize partially based on landscape information
        aGTMReg.DoInitialize();
      end else
      begin
        raise Exception.Create('ERROR: reading landscape file. Inconsistent number of nodes between landscape and manifold');
        halt;
      end;
    end;
  aGTMReg.MinRspAD:=StrToFloat(fnode.GetAttribute('threshold_On_Applicability_Domain'));
  aGTMReg.MinRspToNode:=StrToFloat(fnode.GetAttribute('node_Threshold'));
  aGTMReg.MinDensityLS:=StrToFloat(fnode.GetAttribute('density_Threshold'));
  aGTMReg.K:=nNode;
  aGTMReg.PrpMean:=StrToFloat(fnode.GetAttribute('averaged_value'));
  aGTMReg.PrpStdDev:=StrToFloat(fnode.GetAttribute('std_dev_value'));
  FreeAndNil(node);

  node := fdoc.DocumentElement.GetElementsByTagName('Property');
  if node<>nil then
  begin
    fnode2:=(node.Item[0] as TDOMElement);
    SLlog.Clear;
    SLlog.CommaText:=fnode2.FirstChild.NodeValue;
    try
      for index1:=1 to nNode do
      begin
        aGTMReg.Landscape[index1]:=StrToFloat(SLlog[index1-1]);
      end;
    except
      writeln('ERROR: reading landscape file. Impossible to interpret property value number '+IntToStr(index1));
      halt;
    end;
  end;
  FreeAndNil(node);

  node := fdoc.DocumentElement.GetElementsByTagName('PropertyStdDev');
  if node<>nil then
  begin
    fnode2:=(node.Item[0] as TDOMElement);
    SLlog.Clear;
    SLlog.CommaText:=fnode2.FirstChild.NodeValue;
    try
      for index1:=1 to nNode do
      begin
        aGTMReg.Landscape2[index1]:=StrToFloat(SLlog[index1-1]);
      end;
    except
      writeln('ERROR: reading landscape file. Impossible to interpret property value number '+IntToStr(index1));
      halt;
    end;
  end;
  FreeAndNil(node);

  node := fdoc.DocumentElement.GetElementsByTagName('Coherence');
  if node<>nil then begin
     fnode2:=(node.Item[0] as TDOMElement);
     aGTMReg.dPrpMin:=StrToFloat(TDOMElement(fnode2).GetAttribute('MinProperty'));
     aGTMReg.dPrpMax:=StrToFloat(TDOMElement(fnode2).GetAttribute('MaxProperty'));
     aGTMReg.dPrpRng:=StrToFloat(TDOMElement(fnode2).GetAttribute('RngProperty'));
     SLlog.Clear;
     SLlog.CommaText:=fnode2.FirstChild.NodeValue;
     try
       for index1:=1 to nNode do
       begin
         aGTMReg.Coherence[index1]:=StrToFloat(SLlog[index1-1]);
       end;
     except
       writeln('ERROR: reading landscape file. Impossible to interpret coherence value number '+IntToStr(index1));
       halt;
     end;
  end;
  FreeAndNil(node);

  node := fdoc.DocumentElement.GetElementsByTagName('Trustworthiness');
  if node<>nil then begin
    fnode2:=(node.Item[0] as TDOMElement);
    aGTMReg.dTtau:=StrToFloat(TDOMElement(fnode2).GetAttribute('tau'));
    aGTMReg.dTalpha:=StrToFloat(TDOMElement(fnode2).GetAttribute('alpha'));
    aGTMReg.dTbeta:=StrToFloat(TDOMElement(fnode2).GetAttribute('beta'));
    aGTMReg.dTT:=StrToFloat(TDOMElement(fnode2).GetAttribute('threshold'));
    SLlog.Clear;
    SLlog.CommaText:=fnode2.FirstChild.NodeValue;
    try
      for index1:=1 to nNode do
      begin
        aGTMReg.Trustworthiness[index1]:=StrToFloat(SLlog[index1-1]);
      end;
    except
      writeln('ERROR: reading landscape file. Impossible to interpret trustworthiness value number '+IntToStr(index1));
      halt;
    end;
  end;
  FreeAndNil(node);

  node := fdoc.DocumentElement.GetElementsByTagName('Density');
  if node<>nil then
  begin
    fnode2:=(node.Item[0] as TDOMElement);
    SLlog.Clear;
    SLlog.CommaText:=fnode2.FirstChild.NodeValue;
    try
      for index1:=1 to nNode do
        aGTMReg.Density[index1]:=StrToFloat(SLlog[index1-1]);
    except
      writeln('ERROR: reading landscape file. Impossible to interpret density value number '+IntToStr(index1));
      halt;
    end;
  end;
  FreeAndNil(node);

  node:=fdoc.DocumentElement.GetElementsByTagName('LatentSamples');
  if node<>nil then
  begin
    fnode2:=(node.Item[0] as TDOMElement);
    SLlog.Clear;
    SLLog.Text:=fnode2.FirstChild.NodeValue;
    for index1:=1 to aGTMReg.K do
    begin
      try
      dx:=StrToFloat(ExtractWord(1,SLlog[index1-1],[',']));
      dy:=StrToFloat(ExtractWord(2,SLlog[index1-1],[',']));;
      aGTMReg.matX[index1,1]:=dx;
      aGTMReg.matX[index1,2]:=dy;
      except
        Writeln('ERROR reading landscape. Impossible to interpret coordinates of node '+IntToStr(index1));
        halt(1);
      end;
    end;
  end;
  FreeAndNil(node);

  //aGTMReg.bFinalize:=True;
  FreeAndNil(SLlog);
  FreeAndNil(temp_resp_array);
  FreeAndNil(fdoc);
end;


function readLandscape(fileName: string): XMLData;
  {reads a previously saved Landscape from an xml file}
var
  fnode: TDOMElement;
  prop_node, dens_node, propstd_node: TDOMNode;
  fdoc: TXMLDocument;
  node: TDOMNodeList;
  index1: integer;
  XML: XMLData;
  SLline: TStringList;
begin
  { create xml object and load xml file }
  fdoc := TXMLDocument.Create;
  ReadXMLFile(fdoc, fileName);
  { reading the attributes for the Landscape node }
  node := fdoc.DocumentElement.GetElementsByTagName('Landscape');
  if node.Length=0 then
  begin
    raise exception.Create('ERROR: '+filename+'is not a landscape file.');
    exit;
  end;
  fnode := (node.Item[0] as TDOMElement);
  XML.MinRespAD := StrToFloat(fnode.GetAttribute('threshold_On_Applicability_Domain'));
  XML.nNode := StrToInt(fnode.GetAttribute('number_of_nodes'));
  XML.MinRespToNode := StrToFloat(fnode.GetAttribute('node_Threshold'));
  XML.MinDensityLS := StrToFloat(fnode.GetAttribute('density_Threshold'));
  XML.PrpMean := StrToFloat(fnode.GetAttribute('averaged_value'));
  { finding nodes Class which contain probabilities }
  prop_node := fnode.FindNode('Property');
  propstd_node:=fnode.FindNode('PropertStdDev');
  dens_node := fnode.FindNode('Density');
  SetLength(XML.Landscape, XML.nNode);
  SetLength(XML.Density, XML.nNode);
  SLline := TStringList.Create;
  SLline.CommaText := prop_node.FirstChild.NodeValue;
  //fnode.FirstChild.FirstChild.NodeValue;
  for index1 := 0 to XML.nNode - 1 do {run through the nodes}
  begin
    if SLline[index1] <> 'NM' then
    begin
      XML.Landscape[index1 + 1] := StrToFloat(SLline[index1]);
    end
    else
    begin
      XML.Landscape[index1] := NaN;
    end;
  end;
  SLline.Clear;
  SLline.CommaText := dens_node.FirstChild.NodeValue;
  //fnode.FirstChild.FirstChild.NodeValue;
  for index1 := 0 to XML.nNode - 1 do {run through the nodes}
  begin
    if SLline[index1] <> 'NM' then
    begin
      XML.Density[index1 + 1] := StrToFloat(SLline[index1]);
    end
    else
    begin
      XML.Density[index1] := NaN;
    end;
  end;
  fdoc.Free;
  readLandscape := XML;
end;

procedure writeOut(outName: string; predictions: PropertyArray_type;
  list_of_checkedProjectedMols: checkedMols; putDefVal: boolean; defVal: double);
{writes out the results of prediction}
var
  f: textfile;
  line: string;
  index1: integer;
begin
  assignfile(f, outName);
  rewrite(f);
  line := 'ID' + #9 + 'Prediction' + #9 + 'In/Out_of_AD';
  writeln(f, line);
  for index1 := 0 to length(list_of_checkedProjectedMols) - 1 do {run through molecules}
  begin
    line := IntToStr(index1 + 1);
    //writeln(predictions[index1]);
    if (IsNan(predictions[index1])) and (putDefVal = True) then
      line := line + #9 + FloatToStr(defVal) + #9 + '0'
    else if (IsNan(predictions[index1])) and (putDefVal = False) then
      line := line + #9 + 'NM' + #9 + '0'
    else if list_of_checkedProjectedMols[index1] = -1 then
      line := line + #9 + FloatToStr(SimpleRoundTo(predictions[index1], -2)) + #9 + '0'
    else
      line := line + #9 + FloatToStr(SimpleRoundTo(predictions[index1], -2)) + #9 + '1';
    //writeln(line);
    writeln(f, line);
  end;
  Close(f);
end;

procedure TrainLandscape(aGTMReg: TGTMReg; trRspFileNme, trPrpFileNme, sOutFileName, sAuthor, sTitle, sComment: string; SLlog: TStrings);
var
  nNodes: integer;
  StreamRsp, StreamPrp: TFileReader;
  SLout: TStringList;//Short output files as TStringList
  sl1, sl2: string; //temporary strings
  ii, jj, kk: integer; //ii: words in stringlist; jj: lines; kk: node index
  SLRspM: TStringList; // String list of responsiblities of molecule
  SLRspN: TStringList; // String list tuple node:responsibility
  dResVal: double; //a responsibility value
  aResMol: array of double; //Array of responsibilities for a molecule
  dprp: double; // a property value
  dprd: double; // a prediction value
  sout: string;//output string
  aLandscapeXYZ: TMatrix;//A landscape in XYZ format
  aLandscape2XYZ: TMatrix;//A landscape of standard dev in XYZ format
  aDensityXYZ: TMatrix;//A density in XYZ format
begin
  nNodes := aGTMReg.K;
  SetLength(aResMol, aGTMReg.K + 1);//Array of responsibilities for a molecule, 1-indexed
  SLlog.Add('Begin to read responsibilities.');
  { reading the responsibility file }
  try  //Use streams to deal with potentially very large amount of data
    StreamRsp := TFileReader.Create(trRspFileNme, fmOpenRead);
    StreamPrp := TFileReader.Create(trPrpFileNme, fmOpenRead);
    try
      StreamRsp.Reset;
      StreamPrp.Reset;
      //Prepare to read responsibilies and properties
      SLRspM := TStringList.Create;
      SLRspN := TStringList.Create;
      SLRspM.Delimiter := ' ';
      SLRspM.StrictDelimiter := False;
      SLRspN.Delimiter := ':';
      SLRspN.StrictDelimiter := True;
      sl2 := StreamPrp.ReadLine;
      sComment := sl2;
      SLlog.Add('Property file comment line: '+sComment);
      while not StreamRsp.EOF do
      begin
        sl1 := StreamRsp.ReadLine; //Read one line of responsibilities
        sl2 := StreamPrp.ReadLine; //Read one line of properties
        if (sl1 <> '') and (sl2 <> '') then
        begin
          //Interpret responsibilities text line
          dprp := StrToFloat(sl2);//Get the associated responsibility
          SLRspM.DelimitedText := sl1;
          //Check the integrity of the responsibility file
          SLRspN.DelimitedText := SLRspM.Strings[SLRspM.Count - 1];
          if (nNodes <> 0) and (nNodes <> StrToInt(SLRspN[0])) then
          begin
            raise Exception.Create('ERROR readRespFile: Unexpected number of nodes reading training file '
              + trRspFileNme);
            halt;
          end;
          for kk := 0 to nNodes do
            aResMol[kk] := 0; //Reset the array of responsibilities
          for ii := 1 to SLRspM.Count - 1 do
          begin
            SLRspN.DelimitedText := SLRspM[ii];
            kk := StrToInt(SLRspN[0]);
            dResVal := StrToFloat(SLRspN[1]);
            aResMol[kk] := dResVal;
          end;
          aGTMReg.AddMolecule(aResMol,dprp);//Add molecule to landscape
        end;
      end;
      FreeAndNil(SLRspM);
      FreeAndNil(SLRspN);
      StreamRsp.Close;
      StreamPrp.Close;
    except
      raise Exception.Create('ERROR: reading responsibility/property file while computing landscape.');
    end;
  finally
    FreeAndNil(StreamRsp);
    FreeAndNil(StreamPrp);
  end; //End of Landscape computing
  SLlog.Add('Number of molecules processed '+IntToStr(aGTMReg.nMol0));
  SLlog.Add('Number of molecules used for landscape '+IntToStr(aGTMReg.nMol1));
  SLlog.Add('--------------------------------------');
  //Finalize Landscape
  aGTMReg.DoFinalize;
  { Saving the landscape if it was created here }
  saveLandscape(ChangeFileExt(sOutFileName,'.xml'),sAuthor,aGTMReg,sTitle,sComment);
  aDensityXYZ:=aGTMReg.GetDensityXYZ();
  aLandscapeXYZ:=aGTMReg.GetLandscapeXYZ();
  aLandscape2XYZ:=aGTMReg.GetLandscape2XYZ();
  SLOut:=TStringList.Create;
  SLOut.Clear;
  PrintMat(aDensityXYZ,'Density',1,aGTMReg.K,1,3,SLout);
  SLout.SaveToFile(ChangeFileExt(sOutFileName,'Dens.mat'));
  SLlog.Add('Density column file: '+ChangeFileExt(sOutFileName,'Dens.mat'));
  SLOut.Clear;
  PrintMat(aLandscapeXYZ,'Landscape',1,aGTMReg.K,1,3,SLout);
  SLout.SaveToFile(ChangeFileExt(sOutFileName,'LS.mat'));
  SLlog.Add('Landscape column file: '+ChangeFileExt(sOutFileName,'LS.mat'));
  SLOut.Clear;
  PrintMat(aLandscape2XYZ,'Landscape Std Dev',1,aGTMReg.K,1,3,SLout);
  SLout.SaveToFile(ChangeFileExt(sOutFileName,'StdDevLS.mat'));
  SLlog.Add('Landscape Std Dev column file: '+ChangeFileExt(sOutFileName,'StdDevLS.mat'));
  FreeAndNil(SLOut);
end;

procedure TrainLandscape(aGTMReg: TGTMReg; trRspPrp: TStringList;
  sOutFileName, sAuthor, sTitle, sComment: string; SLlog: TStrings);
var
  jj: integer; // jj: lines
begin
  SLlog.Add('Processing responsibilities...');
  for jj:=0 to trRspPrp.Count-1 do
  begin
    aGTMReg.AddMolecule(trRspPrp.Strings[jj],PDouble(trRspPrp.Objects[jj])^);
  end;
  SLlog.Add('Number of molecules processed '+IntToStr(aGTMReg.nMol0));
  SLlog.Add('Number of molecules used for landscape '+IntToStr(aGTMReg.nMol1));
  SLlog.Add('--------------------------------------');
  //Finalize Landscape
  aGTMReg.DoFinalize;
  { Saving the landscape if it was created here }
  SLlog.Add('Landscape saved in '+ChangeFileExt(sOutFileName,'.xml'));
  saveLandscape(ChangeFileExt(sOutFileName,'.xml'),sAuthor,aGTMReg,sTitle,sComment);
end;

procedure UseLandscape(aGTMReg: TGTMReg; teRspFileNme, sOutFileName: string;
  SLlog: TStrings);
var
  nMol0, nMol1, nNodes: integer;
  StreamRsp: TFileReader;
  FSOut: TFileStream;
  sl1, sl2: string; //temporary strings
  ii, jj, kk: integer; //ii: words in stringlist; jj: lines; kk: node index
  SLRspM: TStringList; // String list of responsiblities of molecule
  SLRspN: TStringList; // String list tuple node:responsibility
  bInAD: boolean; //In or out of applicability domain
  dResVal: double; //a responsibility value
  aResMol: array of double; //Array of responsibilities for a molecule
  dprd: double; // a prediction value
  dprdmean, dprddev: double; // mean and std dev property estimate. dprdmean=dpr but two variables are kept to allow different data treatment.
  dTrst: double;// Trustworthiness score of a compound
  sout: string;//output string
  aLandscapeXYZ: TMatrix;//A landscape in XYZ format
  aDensityXYZ: TMatrix;//A density in XYZ format
begin
  try
    StreamRsp := TFileReader.Create(teRspFileNme);
    StreamRsp.Reset;
    if FileExists(ChangeFileExt(sOutFileName,'.tsv')) then
    begin
      SLlog.Add('WARNING: File '+ChangeFileExt(sOutFileName,'.tsv')+' is overwritten.');
    end;
    FSOut := TFileStream.Create(ChangeFileExt(sOutFileName,'.tsv'), fmCreate);
    FSOut.Size := 0;
    nNodes := aGTMReg.K;
    SetLength(aResMol, aGTMReg.K + 1);//Array of responsibilities for a molecule, 1-indexed
    sout := 'ID' + #9 + 'Prediction' + #9 + 'StdDev' + #9 + 'Trustworthiness' + #9 + 'In/Out_of_AD'+LineEnding;
    FSOut.Write(sout[1],length(sout));//WriteAnsiString(sout+LineEnding);
    try
      //Prepare to read responsibilies and properties
      SLRspM := TStringList.Create;
      SLRspN := TStringList.Create;
      SLRspM.Delimiter := ' ';
      SLRspM.StrictDelimiter := False;
      SLRspN.Delimiter := ':';
      SLRspN.StrictDelimiter := True;
      nMol0:=0; //Molecules out of AD
      nMol1:=0; //Molecules inside AD
      jj:=0; //Count lines
      while not StreamRsp.EOF do
      begin
        Inc(jj);//Count lines
        sl1 := StreamRsp.ReadLine; //Read one line of responsibilities
        if (sl1 <> '') then
        begin
          SLRspM.DelimitedText := sl1;
          //Check the integrity of the responsibility file
          SLRspN.DelimitedText := SLRspM.Strings[SLRspM.Count - 1];
          if (nNodes <> 0) and (nNodes <> StrToInt(SLRspN[0])) then
          begin
            raise Exception.Create('ERROR readRespFile: Unexpected number of nodes reading test file '
              + teRspFileNme);
            halt;
          end;
          for kk:=0 to aGTMReg.K do aResMol[kk]:=0;
          bInAD:=False;
          for ii:=1 to SLRspM.Count-1 do
          begin
            SLRspN.DelimitedText:=SLRspM[ii];
            kk:=StrToInt(SLRspN[0]);
            dResVal:=StrToFloat(SLRspN[1]);
            aResMol[kk]:=dResVal;
          end;
          dprd:=aGTMReg.PredMol(aResMol,dprdmean,dprddev,dTrst,bInAD);
          sout := IntToStr(jj) + #9 + FloatToStrF(dprd,ffFixed,6,2) + #9 + FloatToStrF(dprddev,ffFixed,9,5) + #9 + FloatToStrF(dTrst,ffFixed,6,2) + #9;
          if bInAD then
          begin
            Inc(nMol1);
            sout:=sout+'1';
          end else
          begin
            Inc(nMol0);
            sout:=sout+ '0';
          end;
          sout:=sout+LineEnding;
          FSOut.Write(sout[1],length(sout));//AnsiString(sout+LineEnding);
        end;
      end;
      FreeAndNil(SLRspM);
      FreeAndNil(SLRspN);
    except
      raise Exception.Create('ERROR: computing prediction using the landscape for the test set');
      halt;
    end;
  finally
    FreeAndNil(StreamRsp);
    FreeAndNil(FSOut);
  end;
  SLlog.Add('--------------------------------------');
  SLlog.Add('Number of molecules processed: '+IntToStr(jj+1));
  SLlog.Add('Number of molecules in AD: '+IntToStr(nMol1));
  SLlog.Add('Number of molecules out AD: '+IntToStr(nMol0));
  SLlog.Add('--------------------------------------');
end;

procedure UseLandscape(aGTMReg: TGTMReg; teRsp: TStringList;
  sOutFileName: string; aClsStat: TClsStat; SLlog: TStrings);
var
  nMol0, nMol1, nNodes: integer;
  StreamRsp: TFileReader;
  FSOut: TFileStream;
  sl1, sl2: string; //temporary strings
  ii, jj, kk: integer; //ii: words in stringlist; jj: lines; kk: node index
  SLRspM: TStringList; // String list of responsiblities of molecule
  SLRspN: TStringList; // String list tuple node:responsibility
  bInAD: boolean; //In or out of applicability domain
  dResVal: double; //a responsibility value
  aResMol: array of double; //Array of responsibilities for a molecule
  dprd: double; // a prediction value
  dprdmean, dprddev: double; // mean and std dev property estimate. dprdmean=dpr but two variables are kept to allow different data treatment.
  dTrst: double; //Trustworthiness score of a molecule
  pdexp: PDouble; // pointer to an experimental value
  sout: string;//output string
begin
  if FileExists(ChangeFileExt(sOutFileName,'.tsv')) then
  begin
    SLlog.Add('WARNING: File '+ChangeFileExt(sOutFileName,'.tsv')+' is overwritten.');
  end;
  try
    aClsStat.InitExpPred(teRsp.Count);//->Avec AD, il y a moins de données...
    FSOut := TFileStream.Create(ChangeFileExt(sOutFileName,'.tsv'), fmCreate);
    FSOut.Size := 0;
    nNodes := aGTMReg.K;
    SetLength(aResMol, aGTMReg.K + 1);//Array of responsibilities for a molecule, 1-indexed
    sout := 'ID' + #9 + 'Prediction' + #9 + 'StdDev' + #9 + 'Trustworthiness' + #9 + 'In/Out_of_AD'+LineEnding;
    FSOut.Write(sout[1],length(sout));//WriteAnsiString(sout+LineEnding);
    try
      //Prepare to read responsibilies and properties
      SLRspM := TStringList.Create;
      SLRspN := TStringList.Create;
      SLRspM.Delimiter := ' ';
      SLRspM.StrictDelimiter := False;
      SLRspN.Delimiter := ':';
      SLRspN.StrictDelimiter := True;
      nMol0:=0; //Molecules out of AD
      nMol1:=0; //Molecules inside AD
      for jj:=0 to teRsp.Count-1 do
      begin
        sl1 := teRsp[jj]; //Read one line of responsibilities
        //writeln('jj='+IntToStr(jj));
        //if (jj=11) then
        //  writeln('jj='+IntToStr(jj));
        //if (jj=15) then
        //  writeln('jj=15');
        pdexp:=PDouble(teRsp.Objects[jj]);
        if pdexp<>nil then
          aClsStat.ExpPred[jj,0]:=pdexp^
        else aClsStat.ExpPred[jj,0]:=NaN;//if no experimental value is provided
        if (sl1 <> '') then
        begin
          SLRspM.DelimitedText := sl1;
          //Check the integrity of the responsibility file
          SLRspN.DelimitedText := SLRspM.Strings[SLRspM.Count - 1];
          if (nNodes <> 0) and (nNodes <> StrToInt(SLRspN[0])) then
          begin
            raise Exception.Create('ERROR readRespFile: Unexpected number of nodes in line: '
              + sl1);
            halt;
          end;
          for kk:=0 to aGTMReg.K do aResMol[kk]:=0;
          bInAD:=False;
          for ii:=1 to SLRspM.Count-1 do
          begin
            SLRspN.DelimitedText:=SLRspM[ii];
            kk:=StrToInt(SLRspN[0]);
            dResVal:=StrToFloat(SLRspN[1]);
            aResMol[kk]:=dResVal;
          end;
          dprd:=aGTMReg.PredMol(aResMol,dprdmean,dprddev,dTrst,bInAD);
          if bInAD then //Store the predicted value
            aClsStat.ExpPred[jj,1]:=dprd
          else
            aClsStat.ExpPred[jj,1]:=NaN;
          sout := IntToStr(jj) + #9 + FloatToStrF(dprd,ffFixed,6,2) + #9+ FloatToStrF(dprddev,ffFixed,9,5) + #9+ FloatToStrF(dTrst,ffFixed,9,5) + #9;
          if bInAD then
          begin
            Inc(nMol1);
            sout:=sout+'1';
          end else
          begin
            Inc(nMol0);
            sout:=sout+ '0';
          end;
          sout:=sout+LineEnding;
          FSOut.Write(sout[1],length(sout));//AnsiString(sout+LineEnding);
        end;
      end;
      FreeAndNil(SLRspM);
      FreeAndNil(SLRspN);
    except
      raise Exception.Create('ERROR: computing prediction using the landscape for the test set');
      halt;
    end;
  finally
    FreeAndNil(FSOut);
  end;
  aClsStat.InitSS();//Compute the sum of squares
  SLlog.Add('--------------------------------------');
  SLlog.Add('Number of molecules processed: '+IntToStr(jj+1));
  SLlog.Add('Number of molecules in AD: '+IntToStr(nMol1));
  SLlog.Add('Number of molecules out AD: '+IntToStr(nMol0));
  SLlog.Add('--------------------------------------');
end;

end.
